// ai-chat edge function
//
// Role-aware AI advisor for the LMS platform, with LIVE DATABASE ACCESS via
// Gemini function calling (a.k.a. "tools").
//
// How data access works (and why it is safe):
//   - The model does NOT get raw SQL or the schema. Instead it is given a small
//     set of role-specific "tools" (functions) it may call, e.g. an officer gets
//     `count_my_applications`. When the model wants data it emits a functionCall;
//     this function executes a hard-coded, parameterised Supabase query and
//     returns the result; the model then writes the natural-language answer.
//   - Every tool is SCOPED SERVER-SIDE to the caller. An officer's queries are
//     always filtered by THEIR `staff_profiles.id`, regardless of what the model
//     passes. The model cannot read another user's data or run arbitrary SQL.
//     This is the key difference from a raw text-to-SQL approach.
//
// Also: role-aware personas, conversation memory (replays prior turns), and
// message persistence to ai_conversations / ai_messages.
//
// Env (auto-injected in Supabase Edge runtime): SUPABASE_URL,
// SUPABASE_SERVICE_ROLE_KEY, OPENROUTER_API_KEY (optional; falls back to a smart mock).

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const HISTORY_LIMIT = 16; // prior turns replayed for memory
const MAX_TOOL_HOPS = 4; // safety cap on the tool-calling loop
const AI_MODEL = "google/gemini-2.5-flash-lite";

type StoredRole = "borrower" | "officer" | "manager";

interface CallerContext {
  userId: string | null;
  staffProfileId: string | null;
  branchId: string | null;
}

// ai_conversations.role only allows these three values (migration_v15.sql).
function normalizeRole(role: string | undefined): {
  persona: string;
  storedRole: StoredRole;
} {
  switch ((role ?? "borrower").toLowerCase()) {
    case "officer":
    case "staff":
      return { persona: "officer", storedRole: "officer" };
    case "manager":
      return { persona: "manager", storedRole: "manager" };
    case "admin":
      return { persona: "admin", storedRole: "manager" };
    default:
      return { persona: "borrower", storedRole: "borrower" };
  }
}

// Map friendly status words to the real enum values used in loan_applications.
function normalizeAppStatuses(input: unknown): string[] | null {
  if (input == null) return null;
  const s = String(input).toLowerCase().trim();
  if (!s || s === "all" || s === "any") return null;
  const pending = ["pending", "in progress", "in-progress", "open", "to review", "in review", "active"];
  if (pending.includes(s)) return ["submitted", "under_review"];
  const map: Record<string, string> = {
    "submitted": "submitted",
    "under review": "under_review",
    "under_review": "under_review",
    "approved": "approved",
    "rejected": "rejected",
    "sent back": "sent_back",
    "sent_back": "sent_back",
    "disbursed": "disbursed",
    "draft": "draft",
  };
  return [map[s] ?? s.replace(/ /g, "_")];
}

// ---------------------------------------------------------------------------
// System personas
// ---------------------------------------------------------------------------

function systemPromptFor(persona: string, context: unknown): string {
  const ctx = JSON.stringify(context ?? {});
  const shared =
    "You are an AI assistant inside a Loan Management System (LMS). Amounts are " +
    "in Indian Rupees (₹). Never invent numbers. When you need live figures " +
    "(counts, lists, totals, statuses), CALL THE PROVIDED TOOLS instead of " +
    "guessing, then answer using their results. If a tool returns nothing, say " +
    "so plainly. When asked to summarise, use short bullet points; otherwise " +
    "keep answers to 3-5 sentences.\n\n" +
    "ACTION SAFETY: For any tool that CHANGES data (e.g. approving, rejecting or " +
    "sending back an application), you MUST first call it WITHOUT confirm to get " +
    "a preview, relay that preview to the user in plain language, and only call " +
    "again with confirm=true AFTER the user explicitly says yes. If the tool " +
    "returns needsConfirmation, do not treat the action as done — ask the user " +
    "to confirm first. Require a reason for rejections and send-backs.";

  switch (persona) {
    case "officer":
      return (
        `${shared}\n\nYou are a loan underwriting co-pilot for a LOAN OFFICER. ` +
        "Use tools to look up the officer's own assigned applications and their " +
        "statuses. Help assess risk, spot red flags, and draft professional notes. " +
        "You can approve, reject, or send back an assigned application using the " +
        "action tool (always preview and confirm first). Use get_application_details " +
        "to explain the reasoning behind a decision. Never guarantee approval. " +
        `\n\nExtra context (JSON): ${ctx}`
      );
    case "manager":
      return (
        `${shared}\n\nYou are a portfolio analytics assistant for a BRANCH MANAGER. ` +
        "You CAN see the entire loan portfolio and application pipeline through your " +
        "tools. For ANY question about portfolio health, risk, NPA, collection " +
        "efficiency, disbursement, exposure, overdue EMIs, or 'how is my branch/" +
        "portfolio doing', you MUST call get_portfolio_metrics FIRST (and " +
        "list_overdue_emis or count_applications when relevant), then give a " +
        "quantified, actionable assessment. When summarising risk, explicitly " +
        "interpret the numbers: compare NPA% against a 5% concern threshold, " +
        "collection efficiency against a 90% target, note overdue-EMI and pending " +
        "workload, and total vs outstanding exposure. NEVER claim you lack the tools " +
        "or can only count applications — you have get_portfolio_metrics, " +
        "count_applications, list_overdue_emis and get_application_details, plus the " +
        "portfolio snapshot already provided in your context below. If a metric is " +
        "genuinely zero, report it as a healthy/empty figure rather than an inability. " +
        `\n\nExtra context (JSON): ${ctx}`
      );
    case "admin":
      return (
        `${shared}\n\nYou are an operations assistant for a SYSTEM ADMIN with a ` +
        "cross-branch, whole-organisation view. You CAN see all portfolio and " +
        "application data through your tools. For portfolio, risk, NPA, collection, " +
        "exposure or anomaly questions, ALWAYS call get_portfolio_metrics FIRST (and " +
        "list_overdue_emis / count_applications as needed), then give a quantified " +
        "analysis and flag anomalies (high NPA%, low collection efficiency, large " +
        "overdue concentration). NEVER claim you lack the tools or can only count " +
        "applications — you have get_portfolio_metrics, count_applications, " +
        "list_overdue_emis and get_application_details, plus the snapshot in your " +
        "context below. " +
        `\n\nExtra context (JSON): ${ctx}`
      );
    default:
      return (
        `${shared}\n\nYou are a friendly PERSONAL FINANCIAL ADVISOR for a BORROWER. ` +
        "Use tools to check their loans, next EMI and credit score. If they ask why " +
        "an application was approved/rejected/sent back, call get_my_application_status " +
        "and explain the decision clearly and kindly. Explain terms simply and never " +
        "be judgemental. " +
        `\n\nThe borrower's financial context (JSON): ${ctx}`
      );
  }
}

// ---------------------------------------------------------------------------
// Tool declarations (what the model is allowed to ask for), per persona
// ---------------------------------------------------------------------------

function toolDeclarationsFor(persona: string): any[] {
  const statusParam = {
    type: "STRING",
    description:
      "Optional status filter. Use 'pending' for submitted+under_review, or one " +
      "of: submitted, under_review, approved, rejected, sent_back, disbursed.",
  };

  if (persona === "officer") {
    return [
      {
        name: "count_my_applications",
        description:
          "Count the loan applications assigned to the current officer, optionally by status.",
        parameters: { type: "OBJECT", properties: { status: statusParam }, required: [] },
      },
      {
        name: "list_my_applications",
        description:
          "List the current officer's assigned applications (application number, status, amount, borrower name).",
        parameters: {
          type: "OBJECT",
          properties: {
            status: statusParam,
            limit: { type: "INTEGER", description: "Max rows (default 10, max 25)." },
          },
          required: [],
        },
      },
      {
        name: "get_application_details",
        description:
          "Get full details of one application (amount, tenure, purpose, borrower credit score/income, decision history) by application number. Use this before acting or when explaining a decision.",
        parameters: {
          type: "OBJECT",
          properties: {
            applicationNumber: { type: "STRING", description: "e.g. LMS-APP-000007" },
          },
          required: ["applicationNumber"],
        },
      },
      {
        name: "update_application_status",
        description:
          "Approve, reject, or send back an application assigned to this officer. IMPORTANT: never call with confirm=true until the user has explicitly confirmed. First call without confirm to preview, relay the preview, then call with confirm=true only after the user says yes.",
        parameters: {
          type: "OBJECT",
          properties: {
            applicationNumber: { type: "STRING", description: "e.g. LMS-APP-000007" },
            action: {
              type: "STRING",
              description: "One of: approve, reject, send_back.",
            },
            reason: { type: "STRING", description: "Reason/remarks (required for reject and send_back)." },
            confirm: { type: "BOOLEAN", description: "Set true ONLY after the user explicitly confirms." },
          },
          required: ["applicationNumber", "action"],
        },
      },
    ];
  }

  if (persona === "manager" || persona === "admin") {
    return [
      {
        name: "get_portfolio_metrics",
        description:
          "Get live portfolio metrics for risk analysis: active loans, total disbursed, total outstanding principal, average interest rate, NPA count, NPA outstanding amount, NPA %, collection efficiency, pending applications and overdue EMIs. Call this for any portfolio, risk, exposure or health question.",
        parameters: { type: "OBJECT", properties: {}, required: [] },
      },
      {
        name: "count_applications",
        description: "Count loan applications across the organisation, optionally by status.",
        parameters: { type: "OBJECT", properties: { status: statusParam }, required: [] },
      },
      {
        name: "list_overdue_emis",
        description: "List overdue EMIs (loan id, due date, amount).",
        parameters: {
          type: "OBJECT",
          properties: { limit: { type: "INTEGER", description: "Max rows (default 10, max 25)." } },
          required: [],
        },
      },
      {
        name: "get_application_details",
        description:
          "Get full details of one application (amount, tenure, purpose, borrower credit score/income, decision history) by application number.",
        parameters: {
          type: "OBJECT",
          properties: { applicationNumber: { type: "STRING", description: "e.g. LMS-APP-000007" } },
          required: ["applicationNumber"],
        },
      },
      {
        name: "update_application_status",
        description:
          "Approve, reject, or send back any application. IMPORTANT: never call with confirm=true until the user has explicitly confirmed. First call without confirm to preview, relay it, then call with confirm=true only after the user says yes.",
        parameters: {
          type: "OBJECT",
          properties: {
            applicationNumber: { type: "STRING", description: "e.g. LMS-APP-000007" },
            action: { type: "STRING", description: "One of: approve, reject, send_back." },
            reason: { type: "STRING", description: "Reason/remarks (required for reject and send_back)." },
            confirm: { type: "BOOLEAN", description: "Set true ONLY after the user explicitly confirms." },
          },
          required: ["applicationNumber", "action"],
        },
      },
    ];
  }

  // borrower
  return [
    {
      name: "get_my_loans",
      description: "Get the borrower's loans with status and outstanding principal.",
      parameters: { type: "OBJECT", properties: {}, required: [] },
    },
    {
      name: "get_next_emi",
      description: "Get the borrower's next due or upcoming EMI (amount and due date).",
      parameters: { type: "OBJECT", properties: {}, required: [] },
    },
    {
      name: "get_credit_score",
      description: "Get the borrower's current credit score.",
      parameters: { type: "OBJECT", properties: {}, required: [] },
    },
    {
      name: "get_my_application_status",
      description:
        "Get the borrower's most recent loan application, its status, and the officer's decision reason / remarks. Use this to explain WHY an application was approved, rejected, or sent back.",
      parameters: { type: "OBJECT", properties: {}, required: [] },
    },
  ];
}

// ---------------------------------------------------------------------------
// Tool execution — every query is scoped to the caller server-side
// ---------------------------------------------------------------------------

async function executeTool(
  admin: SupabaseClient,
  persona: string,
  ctx: CallerContext,
  name: string,
  args: Record<string, unknown>,
): Promise<unknown> {
  try {
    // ----- Officer tools -----
    if (persona === "officer") {
      if (!ctx.staffProfileId) {
        return { error: "No staff profile found for this user, cannot scope officer data." };
      }
      const statuses = normalizeAppStatuses(args.status);

      if (name === "count_my_applications") {
        let q = admin
          .from("loan_applications")
          .select("id", { count: "exact", head: true })
          .eq("assigned_officer_id", ctx.staffProfileId);
        if (statuses) q = q.in("status", statuses);
        const { count } = await q;
        return { count: count ?? 0, status: args.status ?? "all" };
      }

      if (name === "list_my_applications") {
        const limit = Math.min(Number(args.limit ?? 10) || 10, 25);
        let q = admin
          .from("loan_applications")
          .select("application_number, status, requested_amount, borrower_id, created_at")
          .eq("assigned_officer_id", ctx.staffProfileId)
          .order("created_at", { ascending: false })
          .limit(limit);
        if (statuses) q = q.in("status", statuses);
        const { data } = await q;
        const rows = data ?? [];
        const names = await resolveUserNames(admin, rows.map((r: any) => r.borrower_id));
        return {
          applications: rows.map((r: any) => ({
            applicationNumber: r.application_number,
            status: r.status,
            requestedAmount: r.requested_amount,
            borrower: names[r.borrower_id] ?? "Unknown",
          })),
        };
      }

      if (name === "get_application_details") {
        return await getApplicationDetails(admin, String(args.applicationNumber ?? ""), ctx.staffProfileId);
      }
      if (name === "update_application_status") {
        return await actOnApplication(admin, ctx, args, /* requireOwnership */ true);
      }
    }

    // ----- Manager / Admin tools -----
    if (persona === "manager" || persona === "admin") {
      if (name === "get_portfolio_metrics") {
        return await portfolioMetrics(admin);
      }
      if (name === "count_applications") {
        const statuses = normalizeAppStatuses(args.status);
        let q = admin.from("loan_applications").select("id", { count: "exact", head: true });
        if (statuses) q = q.in("status", statuses);
        const { count } = await q;
        return { count: count ?? 0, status: args.status ?? "all" };
      }
      if (name === "list_overdue_emis") {
        const limit = Math.min(Number(args.limit ?? 10) || 10, 25);
        const { data } = await admin
          .from("emi_schedule")
          .select("loan_id, due_date, total_emi")
          .eq("status", "overdue")
          .order("due_date", { ascending: true })
          .limit(limit);
        return { overdueEmis: data ?? [] };
      }
      if (name === "get_application_details") {
        return await getApplicationDetails(admin, String(args.applicationNumber ?? ""), null);
      }
      if (name === "update_application_status") {
        return await actOnApplication(admin, ctx, args, /* requireOwnership */ false);
      }
    }

    // ----- Borrower tools -----
    if (persona === "borrower") {
      if (!ctx.userId) return { error: "No user id." };

      if (name === "get_my_loans") {
        const { data } = await admin
          .from("loans")
          .select("id, status, outstanding_principal, interest_rate")
          .eq("borrower_id", ctx.userId);
        return { loans: data ?? [] };
      }
      if (name === "get_next_emi") {
        const { data: loans } = await admin
          .from("loans")
          .select("id")
          .eq("borrower_id", ctx.userId)
          .eq("status", "active");
        const loanIds = (loans ?? []).map((l: any) => l.id);
        if (loanIds.length === 0) return { nextEmi: null, note: "No active loans." };
        const { data } = await admin
          .from("emi_schedule")
          .select("loan_id, due_date, total_emi, status")
          .in("loan_id", loanIds)
          .in("status", ["due", "upcoming"])
          .order("due_date", { ascending: true })
          .limit(1);
        return { nextEmi: (data && data[0]) ?? null };
      }
      if (name === "get_credit_score") {
        const { data } = await admin
          .from("borrower_profiles")
          .select("credit_score")
          .eq("user_id", ctx.userId)
          .single();
        return { creditScore: data?.credit_score ?? null };
      }
      if (name === "get_my_application_status") {
        const { data: apps } = await admin
          .from("loan_applications")
          .select("id, application_number, status, requested_amount, rejection_reason, sent_back_reason, created_at")
          .eq("borrower_id", ctx.userId)
          .order("created_at", { ascending: false })
          .limit(1);
        const app = apps && apps[0];
        if (!app) return { application: null, note: "No applications found." };
        const { data: history } = await admin
          .from("approval_history")
          .select("action, to_status, remarks, actioned_at")
          .eq("application_id", app.id)
          .order("actioned_at", { ascending: true });
        return {
          application: {
            applicationNumber: app.application_number,
            status: app.status,
            requestedAmount: app.requested_amount,
            rejectionReason: app.rejection_reason,
            sentBackReason: app.sent_back_reason,
          },
          decisionHistory: history ?? [],
        };
      }
    }

    return { error: `Unknown tool '${name}' for role '${persona}'.` };
  } catch (e) {
    return { error: `Tool '${name}' failed: ${(e as Error).message}` };
  }
}

async function resolveUserNames(
  admin: SupabaseClient,
  ids: string[],
): Promise<Record<string, string>> {
  const unique = [...new Set(ids.filter(Boolean))];
  if (unique.length === 0) return {};
  const { data } = await admin.from("users").select("id, full_name").in("id", unique);
  const map: Record<string, string> = {};
  for (const u of data ?? []) map[(u as any).id] = (u as any).full_name;
  return map;
}

// Full application detail (used for explainability and before acting).
// If `requireOfficerProfileId` is set, access is restricted to that officer.
async function getApplicationDetails(
  admin: SupabaseClient,
  appNumber: string,
  requireOfficerProfileId: string | null,
): Promise<unknown> {
  if (!appNumber) return { error: "Provide the application number, e.g. LMS-APP-000007." };
  const { data: app } = await admin
    .from("loan_applications")
    .select(
      "id, application_number, borrower_id, assigned_officer_id, requested_amount, requested_tenure_months, purpose, collateral_description, status, rejection_reason, sent_back_reason",
    )
    .eq("application_number", appNumber)
    .single();
  if (!app) return { error: `No application found with number ${appNumber}.` };
  if (requireOfficerProfileId && app.assigned_officer_id !== requireOfficerProfileId) {
    return { error: "This application is not assigned to you." };
  }
  const { data: profile } = await admin
    .from("borrower_profiles")
    .select("credit_score, monthly_income, employment_type, kyc_status")
    .eq("user_id", app.borrower_id)
    .single();
  const names = await resolveUserNames(admin, [app.borrower_id]);
  const { data: history } = await admin
    .from("approval_history")
    .select("action, to_status, remarks, actioned_at")
    .eq("application_id", app.id)
    .order("actioned_at", { ascending: true });
  return {
    applicationNumber: app.application_number,
    borrower: names[app.borrower_id] ?? "Unknown",
    requestedAmount: app.requested_amount,
    tenureMonths: app.requested_tenure_months,
    purpose: app.purpose,
    status: app.status,
    rejectionReason: app.rejection_reason,
    sentBackReason: app.sent_back_reason,
    creditScore: profile?.credit_score ?? null,
    monthlyIncome: profile?.monthly_income ?? null,
    employmentType: profile?.employment_type ?? null,
    kycStatus: profile?.kyc_status ?? null,
    decisionHistory: history ?? [],
  };
}

// Execute an approve/reject/send_back with a confirm-before-execute guard.
// Writes to loan_applications, approval_history, audit_log and notifies the borrower.
async function actOnApplication(
  admin: SupabaseClient,
  ctx: CallerContext,
  args: Record<string, unknown>,
  requireOwnership: boolean,
): Promise<unknown> {
  const appNumber = String(args.applicationNumber ?? "");
  const action = String(args.action ?? "").toLowerCase();
  const reason = args.reason ? String(args.reason) : null;
  const confirm = args.confirm === true;

  const statusMap: Record<string, string> = {
    approve: "approved",
    reject: "rejected",
    send_back: "sent_back",
  };
  const newStatus = statusMap[action];
  if (!newStatus) return { error: `Invalid action '${action}'. Use approve, reject, or send_back.` };
  if ((action === "reject" || action === "send_back") && !reason) {
    return { error: `A reason is required to ${action}. Ask the user for one before proceeding.` };
  }

  const { data: app } = await admin
    .from("loan_applications")
    .select("id, application_number, borrower_id, assigned_officer_id, status, requested_amount")
    .eq("application_number", appNumber)
    .single();
  if (!app) return { error: `No application found with number ${appNumber}.` };
  if (requireOwnership && app.assigned_officer_id !== ctx.staffProfileId) {
    return { error: "This application is not assigned to you, so you cannot action it." };
  }

  const names = await resolveUserNames(admin, [app.borrower_id]);

  // Confirm-before-execute: without an explicit confirm, return a preview only.
  if (!confirm) {
    return {
      needsConfirmation: true,
      message:
        `Please confirm: ${action.toUpperCase()} application ${app.application_number} ` +
        `(borrower ${names[app.borrower_id] ?? "Unknown"}, ₹${app.requested_amount}, currently ${app.status})` +
        `${reason ? `, reason: "${reason}"` : ""}. This is final and will be recorded in the audit log.`,
    };
  }

  const update: Record<string, unknown> = {
    status: newStatus,
    last_updated_at: new Date().toISOString(),
  };
  if (action === "reject") {
    update.rejection_reason = reason;
    update.decided_at = new Date().toISOString();
  } else if (action === "send_back") {
    update.sent_back_reason = reason;
  } else if (action === "approve") {
    update.decided_at = new Date().toISOString();
  }

  const { error: upErr } = await admin.from("loan_applications").update(update).eq("id", app.id);
  if (upErr) return { error: `Update failed: ${upErr.message}` };

  await admin.from("approval_history").insert({
    application_id: app.id,
    actor_id: ctx.userId,
    action,
    to_status: newStatus,
    remarks: reason ?? `${action} via AI assistant`,
  });

  await admin.from("audit_log").insert({
    actor_id: ctx.userId,
    table_name: "loan_applications",
    record_id: app.id,
    action: "UPDATE",
    change_summary: `AI assistant: ${action} -> ${newStatus} for ${app.application_number}. Reason: ${reason ?? "N/A"}`,
  });

  const titleMap: Record<string, string> = {
    approve: "Loan Approved!",
    reject: "Loan Application Update",
    send_back: "Action Required on Your Application",
  };
  const bodyMap: Record<string, string> = {
    approve: "Congratulations! Your loan application has been approved.",
    reject: `Your application was not approved. Reason: ${reason}`,
    send_back: `Your application was sent back for revision. Reason: ${reason}`,
  };
  await admin.from("notifications").insert({
    user_id: app.borrower_id,
    type: "loan_update",
    title: titleMap[action],
    body: bodyMap[action],
    reference_id: app.id,
    reference_type: "loan_applications",
  });

  return { success: true, applicationNumber: app.application_number, newStatus };
}

async function portfolioMetrics(admin: SupabaseClient) {
  // NOTE: the real table is `emi_schedule`; `loans` holds `principal_amount`
  // (there is no `approved_amount`); application_status has no `recommended`
  // and emi_status has no `pending`.
  const { data: active } = await admin
    .from("loans")
    .select("principal_amount, outstanding_principal, interest_rate")
    .eq("status", "active");
  const { data: npaLoans } = await admin
    .from("loans")
    .select("outstanding_principal")
    .eq("status", "npa");
  const npaCount = npaLoans?.length ?? 0;
  const { count: pending } = await admin
    .from("loan_applications")
    .select("id", { count: "exact", head: true })
    .in("status", ["submitted", "under_review"]);
  const { count: overdue } = await admin
    .from("emi_schedule")
    .select("id", { count: "exact", head: true })
    .eq("status", "overdue");
  const { count: paidCount } = await admin
    .from("emi_schedule")
    .select("id", { count: "exact", head: true })
    .eq("status", "paid");

  const activeCount = active?.length ?? 0;
  const totalDisbursed = (active ?? []).reduce(
    (s: number, l: any) => s + (l.principal_amount ?? 0),
    0,
  );
  const totalOutstanding = (active ?? []).reduce(
    (s: number, l: any) => s + (l.outstanding_principal ?? 0),
    0,
  );
  const avgInterestRate =
    activeCount === 0
      ? 0
      : (active ?? []).reduce((s: number, l: any) => s + (l.interest_rate ?? 0), 0) / activeCount;
  const npa = npaCount;
  const npaOutstanding = (npaLoans ?? []).reduce(
    (s: number, l: any) => s + (l.outstanding_principal ?? 0),
    0,
  );
  const npaPct = activeCount + npa === 0 ? 0 : (npa / (activeCount + npa)) * 100;
  const paid = paidCount ?? 0;
  const settled = paid + (overdue ?? 0);
  const collectionEff = settled === 0 ? 100 : (paid / settled) * 100;

  return {
    totalActiveLoans: activeCount,
    totalDisbursedAmount: totalDisbursed,
    totalOutstandingPrincipal: Number(totalOutstanding.toFixed(0)),
    averageInterestRate: Number(avgInterestRate.toFixed(2)),
    npaCount: npa,
    npaOutstandingAmount: Number(npaOutstanding.toFixed(0)),
    npaPercentage: Number(npaPct.toFixed(1)),
    collectionEfficiency: Number(collectionEff.toFixed(1)),
    pendingApplications: pending ?? 0,
    overdueEmis: overdue ?? 0,
  };
}

// ---------------------------------------------------------------------------
// Gemini call with function-calling loop
// ---------------------------------------------------------------------------

async function generateWithTools(
  apiKey: string,
  persona: string,
  contextData: unknown,
  history: { role: string; content: string }[],
  message: string,
  admin: SupabaseClient | null,
  ctx: CallerContext,
): Promise<string> {
  const url = "https://openrouter.ai/api/v1/chat/completions";

  const messages: any[] = [
    { role: "system", content: systemPromptFor(persona, contextData) },
    ...history.map((m) => ({
      role: m.role === "assistant" ? "assistant" : "user",
      content: m.content,
    })),
    { role: "user", content: message },
  ];

  let openAITools: any[] | undefined = undefined;
  if (admin) {
    openAITools = toolDeclarationsFor(persona).map((t) => {
      const properties: any = {};
      if (t.parameters?.properties) {
        for (const [k, v] of Object.entries<any>(t.parameters.properties)) {
          properties[k] = { ...v, type: v.type ? v.type.toLowerCase() : "string" };
        }
      }
      return {
        type: "function",
        function: {
          name: t.name,
          description: t.description,
          parameters: {
            type: "object",
            properties,
            required: t.parameters?.required ?? [],
          },
        },
      };
    });
  }

  for (let hop = 0; hop < MAX_TOOL_HOPS; hop++) {
    const body: any = {
      model: AI_MODEL,
      messages,
      temperature: 0.3,
      max_tokens: 900,
    };
    if (openAITools && openAITools.length > 0) {
      body.tools = openAITools;
    }

    const resp = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://lms-app.local",
        "X-Title": "LMS AI Chat"
      },
      body: JSON.stringify(body),
    });
    
    if (!resp.ok) {
        const errText = await resp.text();
        throw new Error(`OpenRouter API error: ${resp.status} ${errText}`);
    }
    
    const data = await resp.json();
    if (data.error) throw new Error(data.error.message);

    const choice = data?.choices?.[0];
    const responseMessage = choice?.message;
    if (!responseMessage) {
        return "I couldn't generate a response just now. Please try again.";
    }

    const toolCalls = responseMessage.tool_calls || [];

    // No tool requested -> return the text answer.
    if (toolCalls.length === 0) {
      return responseMessage.content?.trim() || "I couldn't generate a response just now. Please try again.";
    }

    // Record the model's turn, then execute each requested tool.
    messages.push(responseMessage);
    
    for (const tc of toolCalls) {
      if (tc.type !== "function") continue;
      
      let args = {};
      try {
          args = JSON.parse(tc.function.arguments || "{}");
      } catch (e) {
          // ignore parsing errors
      }
      
      const result = admin
        ? await executeTool(admin, persona, ctx, tc.function.name, args)
        : { error: "Data tools unavailable." };
        
      messages.push({
        role: "tool",
        tool_call_id: tc.id,
        name: tc.function.name,
        content: JSON.stringify(result)
      });
    }
  }

  return "I wasn't able to finish looking that up. Please try rephrasing your question.";
}

// ---------------------------------------------------------------------------
// Offline mock (no OPENROUTER_API_KEY) — still answers common data questions
// ---------------------------------------------------------------------------

async function mockReply(
  persona: string,
  message: string,
  context: any,
  admin: SupabaseClient | null,
  ctx: CallerContext,
): Promise<string> {
  const lower = message.toLowerCase();

  if (admin && persona === "officer" && ctx.staffProfileId && lower.includes("applica")) {
    const r: any = await executeTool(admin, persona, ctx, "count_my_applications", {
      status: lower.includes("pending") ? "pending" : undefined,
    });
    return `You have ${r.count ?? 0} ${lower.includes("pending") ? "pending" : ""} applications assigned to you. (Set OPENROUTER_API_KEY for full conversational answers.)`;
  }

  if (
    admin && (persona === "manager" || persona === "admin") &&
    (lower.includes("portfolio") || lower.includes("npa") || lower.includes("metric") ||
      lower.includes("risk") || lower.includes("summar") || lower.includes("collection") ||
      lower.includes("overdue") || lower.includes("exposure"))
  ) {
    const m: any = await executeTool(admin, persona, ctx, "get_portfolio_metrics", {});
    const riskNote = m.npaPercentage > 5
      ? "NPA is above the 5% concern threshold — review overdue accounts."
      : (m.collectionEfficiency < 90 ? "Collection efficiency is below the 90% target." : "Portfolio looks healthy.");
    return (
      `Portfolio: ${m.totalActiveLoans} active loans, ₹${m.totalOutstandingPrincipal} outstanding ` +
      `(₹${m.totalDisbursedAmount} disbursed), NPA ${m.npaPercentage}% (${m.npaCount} loans, ₹${m.npaOutstandingAmount}), ` +
      `collection efficiency ${m.collectionEfficiency}%, ${m.overdueEmis} overdue EMIs, ${m.pendingApplications} pending applications. ` +
      `${riskNote} (Set OPENROUTER_API_KEY for full conversational analysis.)`
    );
  }

  if (persona === "borrower") {
    const score = context?.profile?.creditScore;
    if (lower.includes("credit score") || lower.includes("improve"))
      return `Your current credit score is ${score ?? "unavailable"}. Pay EMIs on time and keep utilisation low to improve it.`;
    if (lower.includes("emi") || lower.includes("due")) {
      const next = (context?.emiSchedule ?? []).find((e: any) => e.status === "due" || e.status === "upcoming");
      if (next) return `Your next EMI of ₹${next.emiAmount} is due on ${next.dueDate}.`;
    }
  }

  return `This is a simulated offline response because OPENROUTER_API_KEY is not set. You asked: "${message}"`;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const admin = supabaseUrl && serviceKey ? createClient(supabaseUrl, serviceKey) : null;

  try {
    const { message, userId, role, conversationId, contextData, contextRefId } =
      await req.json();

    const { persona, storedRole } = normalizeRole(role);

    // Resolve the caller's staff profile so officer/manager tools are scoped.
    const ctx: CallerContext = { userId: userId ?? null, staffProfileId: null, branchId: null };
    if (admin && userId && persona !== "borrower") {
      const { data: sp } = await admin
        .from("staff_profiles")
        .select("id, branch_id")
        .eq("user_id", userId)
        .single();
      ctx.staffProfileId = sp?.id ?? null;
      ctx.branchId = sp?.branch_id ?? null;
    }

    // 1. Resolve / create the conversation for memory.
    let convoId: string | null = conversationId ?? null;
    if (admin && userId) {
      if (!convoId) {
        const title =
          typeof message === "string" && message.length > 0 ? message.slice(0, 60) : "New conversation";
        const { data: created } = await admin
          .from("ai_conversations")
          .insert({ user_id: userId, role: storedRole, title, context_ref_id: contextRefId ?? null })
          .select("id")
          .single();
        convoId = created?.id ?? null;
      } else {
        await admin
          .from("ai_conversations")
          .update({ updated_at: new Date().toISOString() })
          .eq("id", convoId);
      }
    }

    // 2. Load prior turns.
    const history: { role: string; content: string }[] = [];
    if (admin && convoId) {
      const { data: prior } = await admin
        .from("ai_messages")
        .select("role, content, created_at")
        .eq("conversation_id", convoId)
        .order("created_at", { ascending: false })
        .limit(HISTORY_LIMIT);
      for (const m of (prior ?? []).reverse()) history.push({ role: m.role, content: m.content });
    }

    // 3. Persist the incoming user message.
    if (admin && convoId) {
      await admin.from("ai_messages").insert({ conversation_id: convoId, role: "user", content: message });
    }

    // 4. Generate the reply.
    const apiKey = Deno.env.get("OPENROUTER_API_KEY");
    let reply = "";
    if (!apiKey) {
      reply = await mockReply(persona, message, contextData, admin, ctx);
    } else {
      reply = await generateWithTools(apiKey, persona, contextData, history, message, admin, ctx);
    }

    // 5. Persist the assistant reply.
    if (admin && convoId) {
      await admin.from("ai_messages").insert({ conversation_id: convoId, role: "assistant", content: reply });
    }

    return new Response(
      JSON.stringify({ reply, conversationId: convoId ?? crypto.randomUUID() }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        reply: `Sorry, something went wrong: ${(error as Error).message || String(error)}`,
        conversationId: crypto.randomUUID(),
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 },
    );
  }
});
