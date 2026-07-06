-- ============================================================================
-- LMS Staff Migration V3 (Fix for Create Staff Accounts)
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ============================================================================

CREATE OR REPLACE FUNCTION create_staff_user(
    p_email TEXT,
    p_password TEXT,
    p_full_name TEXT,
    p_role TEXT,
    p_employee_id TEXT,
    p_designation TEXT,
    p_branch_id UUID
)
RETURNS UUID AS $$
DECLARE
    v_user_id UUID;
    v_encrypted_password TEXT;
BEGIN
    v_user_id := gen_random_uuid();
    v_encrypted_password := crypt(p_password, gen_salt('bf'));
    
    -- Insert into auth.users
    INSERT INTO auth.users (
        id,
        instance_id,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        role,
        aud
    )
    VALUES (
        v_user_id,
        '00000000-0000-0000-0000-000000000000',
        p_email,
        v_encrypted_password,
        now(),
        '{"provider": "email", "providers": ["email"]}',
        jsonb_build_object(
            'full_name', p_full_name,
            'role', p_role,
            'employee_id', p_employee_id,
            'designation', p_designation,
            'branch_id', p_branch_id
        ),
        now(),
        now(),
        'authenticated',
        'authenticated'
    );

    -- Insert into auth.identities
    -- Fix: modern Supabase requires provider_id
    INSERT INTO auth.identities (
        id,
        provider_id,
        user_id,
        identity_data,
        provider,
        last_sign_in_at,
        created_at,
        updated_at
    )
    VALUES (
        v_user_id,
        v_user_id::text,
        v_user_id,
        jsonb_build_object('sub', v_user_id::text, 'email', p_email),
        'email',
        now(),
        now(),
        now()
    );

    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
