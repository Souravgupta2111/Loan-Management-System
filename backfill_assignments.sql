-- Script to backfill assigned officers for all existing unassigned loan applications.
-- Run this in the Supabase SQL Editor.

DO $$
DECLARE
    app_record RECORD;
BEGIN
    FOR app_record IN 
        SELECT id FROM loan_applications WHERE assigned_officer_id IS NULL
    LOOP
        -- This will automatically assign the nearest branch and least-loaded officer
        PERFORM auto_assign_branch_and_officer(app_record.id);
    END LOOP;
END;
$$;
