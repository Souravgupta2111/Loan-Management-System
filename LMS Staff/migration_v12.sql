-- Migration v12: Auto-Logging Triggers for Audit Trail
-- Automatically logs inserts and updates to loan_applications so even borrower actions show up

-- 0. Drop any restrictive check constraints on action
ALTER TABLE public.audit_log DROP CONSTRAINT IF EXISTS audit_log_action_check;

-- 1. Create the trigger function
CREATE OR REPLACE FUNCTION public.log_audit_event()
RETURNS TRIGGER AS $$
DECLARE
    v_actor_id UUID;
    v_actor_role public.user_role;
    v_action TEXT;
    v_summary TEXT;
BEGIN
    -- Try to get the user ID making the request (if authenticated via Supabase)
    v_actor_id := auth.uid();
    
    -- Default role if we can't find it
    v_actor_role := 'borrower';

    -- Try to get the user's role from users table
    IF v_actor_id IS NOT NULL THEN
        SELECT role INTO v_actor_role FROM public.users WHERE id = v_actor_id;
        IF NOT FOUND THEN
            v_actor_role := 'borrower';
        END IF;
    END IF;

    -- Determine the action and summary
    IF TG_OP = 'INSERT' THEN
        v_action := 'CREATE';
        IF TG_TABLE_NAME = 'loan_applications' THEN
            v_summary := 'New loan application submitted (' || NEW.application_number || ')';
        ELSE
            v_summary := 'Created new record in ' || TG_TABLE_NAME;
        END IF;
        
        INSERT INTO public.audit_log (actor_id, actor_role, action, table_name, record_id, new_value, change_summary)
        VALUES (v_actor_id, v_actor_role, v_action, TG_TABLE_NAME, NEW.id, row_to_json(NEW)::jsonb, v_summary);
        
        RETURN NEW;
        
    ELSIF TG_OP = 'UPDATE' THEN
        v_action := 'UPDATE';
        IF TG_TABLE_NAME = 'loan_applications' THEN
            -- Only log if the status changed
            IF OLD.status IS DISTINCT FROM NEW.status THEN
                v_summary := 'Loan application ' || NEW.application_number || ' status changed to ' || NEW.status;
                
                INSERT INTO public.audit_log (actor_id, actor_role, action, table_name, record_id, old_value, new_value, change_summary)
                VALUES (v_actor_id, v_actor_role, v_action, TG_TABLE_NAME, NEW.id, row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb, v_summary);
            END IF;
        ELSE
            v_summary := 'Updated record in ' || TG_TABLE_NAME;
            INSERT INTO public.audit_log (actor_id, actor_role, action, table_name, record_id, old_value, new_value, change_summary)
            VALUES (v_actor_id, v_actor_role, v_action, TG_TABLE_NAME, NEW.id, row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb, v_summary);
        END IF;
        
        RETURN NEW;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Attach trigger to loan_applications
DROP TRIGGER IF EXISTS trigger_audit_loan_applications ON public.loan_applications;
CREATE TRIGGER trigger_audit_loan_applications
    AFTER INSERT OR UPDATE ON public.loan_applications
    FOR EACH ROW
    EXECUTE FUNCTION public.log_audit_event();
