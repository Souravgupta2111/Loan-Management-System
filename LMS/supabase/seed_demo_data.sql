-- =====================================================================
--  DEMO / TEST SEED DATA  — Loan Management System
--  Run this in the Supabase SQL editor (service role).
--
--  What it creates:
--    * Disbursed loan_applications (with approval_history timeline)
--    * loans (active / closed / npa — NO restructured, so you can test
--      write-off & restructure on the NPA ones)
--    * Full reducing-balance emi_schedule per loan
--    * Real confirmed payments for the paid installments
--
--  Scope: uses ONLY the existing staff & borrower accounts you provided.
--         It does NOT create any users / borrower_profiles / staff_profiles.
--         The main borrower is resolved by email: srvgupta007@gmail.com
--
--  Safe to re-run: it deletes its own previously-seeded rows first
--  (identified by loan_applications.purpose LIKE 'Seed data - %').
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Clean up any previous run of THIS seed (scoped to seed data only)
-- ---------------------------------------------------------------------
DELETE FROM public.payments
 WHERE loan_id IN (
   SELECT l.id FROM public.loans l
   JOIN public.loan_applications a ON a.id = l.application_id
   WHERE a.purpose LIKE 'Seed data - %');

DELETE FROM public.emi_schedule
 WHERE loan_id IN (
   SELECT l.id FROM public.loans l
   JOIN public.loan_applications a ON a.id = l.application_id
   WHERE a.purpose LIKE 'Seed data - %');

DELETE FROM public.approval_history
 WHERE application_id IN (
   SELECT id FROM public.loan_applications WHERE purpose LIKE 'Seed data - %');

DELETE FROM public.loans
 WHERE application_id IN (
   SELECT id FROM public.loan_applications WHERE purpose LIKE 'Seed data - %');

DELETE FROM public.loan_applications WHERE purpose LIKE 'Seed data - %';

-- ---------------------------------------------------------------------
-- 1. Helper that seeds ONE fully-consistent loan (+ schedule + payments)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.seed_loan(
    p_borrower       uuid,
    p_officer        uuid,   -- staff_profiles.id
    p_manager_user   uuid,   -- users.id of the branch manager (approval actor)
    p_product_type   text,   -- personal | home | vehicle | education | ...
    p_principal      numeric,
    p_rate           numeric,
    p_tenure         int,
    p_disburse_date  date,
    p_kind           text    -- 'active' | 'closed' | 'npa'
) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    v_branch      uuid;
    v_product     uuid;
    v_fee_pct     numeric;
    v_app         uuid := gen_random_uuid();
    v_loan        uuid := gen_random_uuid();
    v_app_no      text;
    v_loan_no     text;
    v_officer_user uuid;
    v_min_rate    numeric;
    v_max_rate    numeric;
    v_rate        numeric;
    v_m           numeric;
    v_emi         numeric;
    v_balance     numeric;
    v_total_pay   numeric;
    v_first_emi   date;
    v_maturity    date;
    v_due         date;
    v_open        numeric;
    v_int         numeric;
    v_prin        numeric;
    v_close       numeric;
    v_status      emi_status;
    v_emi_id      uuid;
    v_today       date := CURRENT_DATE;
    v_out_prin    numeric := 0;
    v_out_int     numeric := 0;
    v_overdue_amt numeric := 0;
    v_overdue_days int := 0;
    v_loan_status loan_status;
    i             int;
BEGIN
    -- Prefer a product of the requested type whose amount & tenure ranges fit
    -- this loan; fall back to any product of the type; then any active product.
    SELECT id, processing_fee_pct, min_interest_rate, max_interest_rate
      INTO v_product, v_fee_pct, v_min_rate, v_max_rate
      FROM public.loan_products
     WHERE type = p_product_type::loan_type AND is_active
       AND p_principal BETWEEN min_amount AND max_amount
       AND p_tenure    BETWEEN min_tenure_months AND max_tenure_months
     ORDER BY created_at LIMIT 1;
    IF v_product IS NULL THEN
        SELECT id, processing_fee_pct, min_interest_rate, max_interest_rate
          INTO v_product, v_fee_pct, v_min_rate, v_max_rate
          FROM public.loan_products
         WHERE type = p_product_type::loan_type AND is_active
         ORDER BY created_at LIMIT 1;
    END IF;
    IF v_product IS NULL THEN
        SELECT id, processing_fee_pct, min_interest_rate, max_interest_rate
          INTO v_product, v_fee_pct, v_min_rate, v_max_rate
          FROM public.loan_products WHERE is_active ORDER BY created_at LIMIT 1;
    END IF;

    -- Skip silently if we can't resolve the borrower or a product.
    IF p_borrower IS NULL OR v_product IS NULL THEN RETURN; END IF;

    -- Keep the rate inside the chosen product's allowed band.
    v_rate := LEAST(GREATEST(p_rate, COALESCE(v_min_rate, p_rate)), COALESCE(v_max_rate, p_rate));

    SELECT user_id, branch_id INTO v_officer_user, v_branch FROM public.staff_profiles WHERE id = p_officer;
    IF v_branch IS NULL THEN
        v_branch := 'a1000001-0000-0000-0000-000000000001';
    END IF;

    v_app_no  := 'LMS-APP-' || upper(substr(replace(v_app::text,  '-', ''), 1, 8));
    v_loan_no := 'LMS-' || to_char(p_disburse_date, 'YYYYMM') || '-' ||
                 upper(substr(replace(v_loan::text, '-', ''), 1, 8));

    -- Reducing-balance EMI.
    v_m := (v_rate / 12.0) / 100.0;
    IF v_m = 0 THEN
        v_emi := round((p_principal / p_tenure)::numeric, 2);
    ELSE
        v_emi := round((p_principal * v_m * power(1 + v_m, p_tenure)
                        / (power(1 + v_m, p_tenure) - 1))::numeric, 2);
    END IF;
    v_total_pay := round(v_emi * p_tenure, 2);
    v_first_emi := (p_disburse_date + interval '1 month')::date;
    v_maturity  := (p_disburse_date + (p_tenure || ' months')::interval)::date;

    IF    p_kind = 'closed' THEN v_loan_status := 'closed';
    ELSIF p_kind = 'npa'    THEN v_loan_status := 'npa';
    ELSE                         v_loan_status := 'active';
    END IF;

    -- Application (already disbursed).
    INSERT INTO public.loan_applications
        (id, application_number, borrower_id, loan_product_id, assigned_officer_id,
         branch_id, requested_amount, requested_tenure_months, purpose, status,
         submitted_at, decided_at, created_at, last_updated_at)
    VALUES
        (v_app, v_app_no, p_borrower, v_product, p_officer, v_branch,
         p_principal, p_tenure, 'Seed data - ' || p_product_type || ' loan', 'disbursed',
         (p_disburse_date - interval '10 days'), (p_disburse_date - interval '2 days'),
         (p_disburse_date - interval '12 days'), now());

    -- Approval timeline (best-effort — swallow if the action enum differs).
    BEGIN
        IF v_officer_user IS NOT NULL THEN
            INSERT INTO public.approval_history
                (id, application_id, actor_id, from_status, to_status, action, remarks, actioned_at)
            VALUES
                (gen_random_uuid(), v_app, v_officer_user, 'submitted', 'under_review',
                 'escalate', 'Reviewed and recommended to manager',
                 (p_disburse_date - interval '6 days'));
        END IF;
        IF p_manager_user IS NOT NULL THEN
            INSERT INTO public.approval_history
                (id, application_id, actor_id, from_status, to_status, action, remarks,
                 approved_amount, approved_tenure_months, approved_interest_rate, actioned_at)
            VALUES
                (gen_random_uuid(), v_app, p_manager_user, 'under_review', 'approved',
                 'approve', 'Approved within policy', p_principal, p_tenure, v_rate,
                 (p_disburse_date - interval '2 days'));
            INSERT INTO public.approval_history
                (id, application_id, actor_id, from_status, to_status, action, remarks, actioned_at)
            VALUES
                (gen_random_uuid(), v_app, p_manager_user, 'approved', 'disbursed',
                 'disburse', 'Funds disbursed to borrower account', p_disburse_date);
        END IF;
    EXCEPTION WHEN OTHERS THEN
        -- Timeline is cosmetic; never let it abort the seed.
        NULL;
    END;

    -- Loan (aggregates set after the schedule loop).
    INSERT INTO public.loans
        (id, application_id, borrower_id, loan_product_id, disbursed_by, branch_id,
         loan_number, principal_amount, interest_rate, interest_type, tenure_months,
         processing_fee, total_payable, disbursement_date, first_emi_date, maturity_date,
         status, outstanding_principal, outstanding_interest, total_overdue, overdue_days,
         bank_account_number, ifsc_code, disbursement_reference, repayment_mode,
         spread, base_rate_at_disbursement, current_base_rate, created_at)
    VALUES
        (v_loan, v_app, p_borrower, v_product, p_officer, v_branch, v_loan_no,
         p_principal, v_rate, 'reducing', p_tenure,
         round(p_principal * COALESCE(v_fee_pct, 1) / 100, 2), v_total_pay,
         p_disburse_date, v_first_emi, v_maturity, v_loan_status,
         p_principal, round(v_total_pay - p_principal, 2), 0, 0,
         '5010' || lpad((floor(random() * 1e8))::bigint::text, 8, '0'), 'HDFC0001234',
         'TXN-' || upper(substr(replace(v_loan::text, '-', ''), 1, 12)), 'auto_debit',
         2.0, v_rate - 2.0, v_rate - 2.0, p_disburse_date);

    -- Schedule + payments.
    v_balance := p_principal;
    FOR i IN 1..p_tenure LOOP
        v_open := v_balance;
        v_int  := round(v_balance * v_m, 2);
        v_prin := round(v_emi - v_int, 2);
        IF i = p_tenure THEN v_prin := v_open; END IF;      -- clear residue
        v_close := round(v_open - v_prin, 2);
        IF v_close < 0 THEN v_close := 0; END IF;
        v_due := (v_first_emi + ((i - 1) || ' months')::interval)::date;
        v_emi_id := gen_random_uuid();

        -- Status per loan kind.
        IF p_kind = 'closed' THEN
            v_status := 'paid';
        ELSIF p_kind = 'npa' THEN
            IF v_due < v_today THEN
                IF i <= 2 THEN v_status := 'paid';       -- paid the first two, then defaulted
                ELSE           v_status := 'overdue';
                END IF;
            ELSE v_status := 'upcoming';
            END IF;
        ELSE  -- active
            IF v_due < v_today THEN                       v_status := 'paid';
            ELSIF v_due <= (v_today + interval '30 days') THEN v_status := 'due';
            ELSE                                          v_status := 'upcoming';
            END IF;
        END IF;

        INSERT INTO public.emi_schedule
            (id, loan_id, installment_number, due_date, opening_balance,
             principal_component, interest_component, total_emi, penalty_amount,
             penalty_days, closing_balance, status, paid_date, created_at)
        VALUES
            (v_emi_id, v_loan, i, v_due, v_open, v_prin, v_int, round(v_prin + v_int, 2),
             CASE WHEN v_status = 'overdue'
                  THEN round((v_prin + v_int) * 0.02 * GREATEST(1, ((v_today - v_due) / 30)), 2)
                  ELSE 0 END,
             CASE WHEN v_status = 'overdue' THEN GREATEST(0, (v_today - v_due)) ELSE 0 END,
             v_close, v_status,
             CASE WHEN v_status = 'paid' THEN v_due ELSE NULL END,
             p_disburse_date);

        IF v_status = 'paid' THEN
            INSERT INTO public.payments
                (id, loan_id, emi_id, amount_paid, principal_paid, interest_paid,
                 penalty_paid, payment_mode, status, initiated_at, confirmed_at,
                 razorpay_order_id, razorpay_payment_id)
            VALUES
                (gen_random_uuid(), v_loan, v_emi_id, round(v_prin + v_int, 2),
                 v_prin, v_int, 0, 'razorpay', 'confirmed', v_due, v_due,
                 'order_' || substr(md5(random()::text), 1, 14),
                 'pay_'   || substr(md5(random()::text), 1, 14));
        ELSE
            v_out_prin := v_out_prin + v_prin;
            v_out_int  := v_out_int  + v_int;
            IF v_status = 'overdue' THEN
                v_overdue_amt  := v_overdue_amt + round(v_prin + v_int, 2);
                v_overdue_days := GREATEST(v_overdue_days, (v_today - v_due));
            END IF;
        END IF;

        v_balance := v_close;
    END LOOP;

    -- Finalise loan aggregates.
    IF p_kind = 'closed' THEN
        UPDATE public.loans
           SET outstanding_principal = 0, outstanding_interest = 0,
               total_overdue = 0, overdue_days = 0, status = 'closed',
               closed_at = (v_maturity)::timestamptz
         WHERE id = v_loan;
    ELSIF p_kind = 'npa' THEN
        UPDATE public.loans
           SET outstanding_principal = round(v_out_prin, 2),
               outstanding_interest  = round(v_out_int, 2),
               total_overdue = round(v_overdue_amt, 2),
               overdue_days  = v_overdue_days,
               status = 'npa',
               npa_triggered_at = (v_today - interval '5 days')
         WHERE id = v_loan;
    ELSE
        UPDATE public.loans
           SET outstanding_principal = round(v_out_prin, 2),
               outstanding_interest  = round(v_out_int, 2),
               total_overdue = 0, overdue_days = 0, status = 'active'
         WHERE id = v_loan;
    END IF;
END;
$$;

-- ---------------------------------------------------------------------
-- 2. Seed the loans (13 total) across the existing accounts.
-- ---------------------------------------------------------------------
DO $$
DECLARE
    -- Officers (staff_profiles.id)
    off_5976 uuid := '5c7139c9-14fd-4325-a440-f16e510817a6';
    off_6825 uuid := 'b455145e-bdd7-4fb8-a3fa-555dc81b50d5';
    off_7804 uuid := 'e3a8ddf8-9a2b-4a29-97ab-857ef589e40b';
    -- Branch manager (users.id — used as approval actor)
    mgr_user uuid := '33374032-acd1-410f-a5e6-acab75116ccd';

    -- Verified borrowers (users.id)
    b_credit626 uuid := '5f7d64d0-9971-446a-9e30-28fbe8897265';
    b_credit823 uuid := '2e9d02c5-dfc9-4f3b-9a3d-bf498c670d92';
    b_verified3 uuid := '9499f50f-a69a-4d91-affe-28e0526d4282';
    b_credit713 uuid := '434dfccf-d92a-423b-a1c8-ff6cd9c0f8a1';

    -- Main test borrower resolved by email.
    b_srv uuid;
BEGIN
    SELECT id INTO b_srv FROM public.users WHERE lower(email) = 'srvgupta007@gmail.com' LIMIT 1;
    IF b_srv IS NULL THEN
        RAISE NOTICE 'srvgupta007@gmail.com not found in users — its loans will be skipped.';
    END IF;

    -- ---- Main borrower (srvgupta007): 5 loans, mixed ----
    PERFORM public.seed_loan(b_srv, off_5976, mgr_user, 'personal',  300000, 13.5, 24, (CURRENT_DATE - interval '4 months')::date,  'active');
    PERFORM public.seed_loan(b_srv, off_6825, mgr_user, 'home',     2500000,  9.0,120, (CURRENT_DATE - interval '3 months')::date,  'active');
    PERFORM public.seed_loan(b_srv, off_7804, mgr_user, 'personal',  150000, 14.0, 12, (CURRENT_DATE - interval '15 months')::date, 'closed');
    PERFORM public.seed_loan(b_srv, off_5976, mgr_user, 'vehicle',   600000, 12.0, 36, (CURRENT_DATE - interval '7 months')::date,  'npa');
    PERFORM public.seed_loan(b_srv, off_6825, mgr_user, 'education',  400000, 11.0, 48, (CURRENT_DATE - interval '2 months')::date,  'active');

    -- ---- Other verified borrowers spread across officers: 8 loans ----
    PERFORM public.seed_loan(b_credit626, off_5976, mgr_user, 'personal',  250000, 15.0, 18, (CURRENT_DATE - interval '3 months')::date,  'active');
    PERFORM public.seed_loan(b_credit823, off_6825, mgr_user, 'home',     1800000,  8.75,96, (CURRENT_DATE - interval '5 months')::date,  'active');
    PERFORM public.seed_loan(b_credit823, off_7804, mgr_user, 'personal',  120000, 13.0, 12, (CURRENT_DATE - interval '14 months')::date, 'closed');
    PERFORM public.seed_loan(b_verified3, off_5976, mgr_user, 'personal',  350000, 16.0, 24, (CURRENT_DATE - interval '8 months')::date,  'npa');
    PERFORM public.seed_loan(b_credit713, off_6825, mgr_user, 'vehicle',   750000, 11.5, 48, (CURRENT_DATE - interval '4 months')::date,  'active');
    PERFORM public.seed_loan(b_credit713, off_7804, mgr_user, 'personal',  200000, 14.5, 18, (CURRENT_DATE - interval '1 months')::date,  'active');
    PERFORM public.seed_loan(b_credit626, off_6825, mgr_user, 'education',  500000, 12.5, 36, (CURRENT_DATE - interval '9 months')::date,  'npa');
    PERFORM public.seed_loan(b_verified3, off_7804, mgr_user, 'personal',   90000, 13.5,  9, (CURRENT_DATE - interval '12 months')::date, 'closed');
END $$;

-- ---------------------------------------------------------------------
-- 3. Tidy up the helper.
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.seed_loan(uuid, uuid, uuid, text, numeric, numeric, int, date, text);

-- ---------------------------------------------------------------------
-- 4. Verification report.
-- ---------------------------------------------------------------------
SELECT status, COUNT(*) AS loans, round(SUM(principal_amount)) AS principal,
       round(SUM(outstanding_principal + outstanding_interest)) AS outstanding
  FROM public.loans
 WHERE application_id IN (SELECT id FROM public.loan_applications WHERE purpose LIKE 'Seed data - %')
 GROUP BY status
 ORDER BY status;
