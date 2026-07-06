-- Migration v14: Realtime Notifications for Staff
-- 1. Enable Realtime on notifications table so iOS receives instant websocket updates
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
END $$;

-- 2. Update the audit trigger to ALSO dispatch a notification to Managers/Admins
--    when a new loan is submitted by a borrower.

CREATE OR REPLACE FUNCTION public.log_audit_event()
RETURNS TRIGGER AS $$
DECLARE
    v_actor_id UUID;
    v_actor_role public.user_role;
    v_action TEXT;
    v_summary TEXT;
BEGIN
    -- Try to get the user ID making the request
    v_actor_id := auth.uid();
    
    -- Default role
    v_actor_role := 'borrower';

    -- Try to get the user's role
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
            
            -- 🔥 NEW: Broadcast a notification to all Managers and Admins
            INSERT INTO public.notifications (user_id, reference_id, reference_type, type, title, body)
            SELECT id, NEW.id, 'loan_application', 'approval_required', 
                   'New Application: ' || NEW.application_number, 
                   'A new loan application for ₹' || NEW.requested_amount::text || ' requires review.'
            FROM public.users WHERE role IN ('manager', 'admin');
            
        ELSE
            v_summary := 'Created new record in ' || TG_TABLE_NAME;
        END IF;
        
        INSERT INTO public.audit_log (actor_id, actor_role, action, table_name, record_id, new_value, change_summary)
        VALUES (v_actor_id, v_actor_role, v_action, TG_TABLE_NAME, NEW.id, row_to_json(NEW)::jsonb, v_summary);
        
        RETURN NEW;
        
    ELSIF TG_OP = 'UPDATE' THEN
        v_action := 'UPDATE';
        IF TG_TABLE_NAME = 'loan_applications' THEN
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
