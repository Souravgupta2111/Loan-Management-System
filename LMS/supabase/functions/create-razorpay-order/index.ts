import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.6";

const jsonHeaders = { "Content-Type": "application/json" };

Deno.serve(async (request) => {
  try {
    const authorization = request.headers.get("Authorization");
    if (!authorization) {
      return new Response(JSON.stringify({ error: "Unauthorized", details: "Missing Authorization header" }), { status: 401, headers: jsonHeaders });
    }

    const url = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const keyId = Deno.env.get("RAZORPAY_KEY_ID");
    const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET");
    if (!keyId || !keySecret) throw new Error("Razorpay secrets are not configured");

    const supabase = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
    const token = authorization.replace(/^Bearer\s+/i, "");
    
    if (!token || token.trim() === "") {
        return new Response(JSON.stringify({ error: "Unauthorized", details: `Token is empty. Raw auth header: '${authorization}'` }), { status: 401, headers: jsonHeaders });
    }

    const { data: userData, error: userError } = await supabase.auth.getUser(token);
    if (userError || !userData?.user) {
      return new Response(JSON.stringify({ error: "Unauthorized", details: userError?.message || "User not found", rawHeader: authorization }), { status: 401, headers: jsonHeaders });
    }

    const { emiId, loanId } = await request.json();
    const { data: emi, error: emiError } = await supabase.from("emi_schedule")
      .select("id, loan_id, total_emi, penalty_amount, status")
      .eq("id", emiId).eq("loan_id", loanId).single();
    if (emiError || !emi || !["upcoming", "overdue"].includes(emi.status)) {
      return new Response(JSON.stringify({ error: "EMI is not payable" }), { status: 422, headers: jsonHeaders });
    }

    const amountPaise = Math.round((Number(emi.total_emi) + Number(emi.penalty_amount)) * 100);
    const orderResponse = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: {
        "Authorization": `Basic ${btoa(`${keyId}:${keySecret}`)}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ amount: amountPaise, currency: "INR", receipt: `emi_${emiId}` }),
    });
    const order = await orderResponse.json();
    if (!orderResponse.ok) throw new Error(order.error?.description ?? "Unable to create Razorpay order");

    const { data: payment, error: paymentError } = await supabase.from("payments").insert({
      loan_id: loanId,
      emi_id: emiId,
      amount_paid: amountPaise / 100,
      penalty_paid: Number(emi.penalty_amount),
      payment_mode: "razorpay",
      razorpay_order_id: order.id,
      status: "initiated",
    }).select("id").single();
    if (paymentError) throw paymentError;

    return new Response(JSON.stringify({
      paymentRecordId: payment.id,
      orderId: order.id,
      keyId,
      amountPaise,
      currency: "INR",
    }), { status: 200, headers: jsonHeaders });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : "Unexpected error" }), {
      status: 500,
      headers: jsonHeaders,
    });
  }
});
