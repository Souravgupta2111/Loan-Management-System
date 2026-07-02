-- Force assign all unassigned applications to the FIRST available staff member.
-- This bypasses role and activity checks, ensuring it works for testing.

DO $$
DECLARE
    app_record RECORD;
    v_staff_profile_id UUID;
    v_staff_user_id UUID;
    v_branch_id UUID;
BEGIN
    -- Get the first available staff profile
    SELECT id, user_id, branch_id INTO v_staff_profile_id, v_staff_user_id, v_branch_id
    FROM staff_profiles
    LIMIT 1;

    -- If no staff profile exists, create a dummy one for the first user
    IF v_staff_profile_id IS NULL THEN
        SELECT id INTO v_staff_user_id FROM users LIMIT 1;
        SELECT id INTO v_branch_id FROM branches LIMIT 1;
        
        IF v_staff_user_id IS NOT NULL AND v_branch_id IS NOT NULL THEN
            INSERT INTO staff_profiles (user_id, branch_id, designation)
            VALUES (v_staff_user_id, v_branch_id, 'Test Officer')
            RETURNING id INTO v_staff_profile_id;
        END IF;
    END IF;

    -- Force assign all unassigned applications
    FOR app_record IN 
        SELECT id FROM loan_applications WHERE assigned_officer_id IS NULL
    LOOP
        UPDATE loan_applications
        SET branch_id = v_branch_id,
            assigned_officer_id = v_staff_profile_id,
            last_updated_at = NOW()
        WHERE id = app_record.id;
    END LOOP;
END;
$$;
