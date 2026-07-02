-- 
-- Automated NPA and Delinquency Tracking 
-- Run this script in your Supabase SQL Editor
--

CREATE OR REPLACE FUNCTION update_npa_status()
RETURNS void AS $$
BEGIN
    -- 1. Mark upcoming EMIs as overdue if they have passed their due date
    UPDATE emi_schedule
    SET status = 'overdue'
    WHERE status = 'upcoming' AND due_date::date < CURRENT_DATE;

    -- 2. Calculate and update loan overdue status and NPA flagging
    WITH loan_delinquency AS (
        SELECT 
            loan_id,
            COUNT(*) as overdue_emi_count,
            MAX(CURRENT_DATE - due_date::date) as max_overdue_days
        FROM emi_schedule
        WHERE status = 'overdue'
        GROUP BY loan_id
    )
    UPDATE loans l
    SET 
        overdue_days = COALESCE(ld.max_overdue_days, 0),
        status = CASE 
            -- Flag as NPA if max overdue days >= 60 OR missed EMIs >= 2
            WHEN l.status IN ('active', 'restructured') AND (ld.max_overdue_days >= 60 OR ld.overdue_emi_count >= 2) THEN 'npa'
            ELSE l.status
        END,
        npa_triggered_at = CASE 
            WHEN l.status IN ('active', 'restructured') AND (ld.max_overdue_days >= 60 OR ld.overdue_emi_count >= 2) AND l.status != 'npa' THEN CURRENT_TIMESTAMP
            ELSE l.npa_triggered_at
        END
    FROM loan_delinquency ld
    WHERE l.id = ld.loan_id;

END;
$$ LANGUAGE plpgsql;
