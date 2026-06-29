-- Create trigger function for automatic assignment of loan applications
CREATE OR REPLACE FUNCTION auto_assign_loan_application()
RETURNS TRIGGER AS $$
DECLARE
    selected_branch_id UUID;
    selected_officer_id UUID;
BEGIN
    -- Only trigger when status changes to 'submitted' and it's unassigned
    IF NEW.status = 'submitted' AND OLD.status = 'draft' AND NEW.assigned_officer_id IS NULL THEN
        
        -- Pick a random active branch that has at least one active officer or manager
        SELECT b.id INTO selected_branch_id
        FROM branches b
        WHERE b.is_active = true
          AND EXISTS (
              SELECT 1 FROM staff_profiles sp
              JOIN users u ON sp.user_id = u.id
              WHERE sp.branch_id = b.id
                AND u.role IN ('officer', 'manager')
                AND u.is_active = true
          )
        ORDER BY random()
        LIMIT 1;

        IF selected_branch_id IS NOT NULL THEN
            NEW.branch_id := selected_branch_id;

            -- Find an officer or manager in this branch with the least number of active applications
            -- Active applications mean status in ('submitted', 'under_review')
            SELECT sp.id INTO selected_officer_id
            FROM staff_profiles sp
            JOIN users u ON sp.user_id = u.id
            WHERE sp.branch_id = selected_branch_id
              AND u.role IN ('officer', 'manager')
              AND u.is_active = true
            ORDER BY (
                SELECT count(*) 
                FROM loan_applications la 
                WHERE la.assigned_officer_id = sp.id 
                  AND la.status IN ('submitted', 'under_review')
            ) ASC, random()
            LIMIT 1;

            IF selected_officer_id IS NOT NULL THEN
                NEW.assigned_officer_id := selected_officer_id;
            END IF;
        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_assign_application ON loan_applications;
CREATE TRIGGER trg_auto_assign_application
BEFORE UPDATE ON loan_applications
FOR EACH ROW
EXECUTE FUNCTION auto_assign_loan_application();
