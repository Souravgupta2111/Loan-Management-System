-- ============================================================================
-- LMS Staff Migration V4 (Complete Fixes)
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ============================================================================

-- 1. Ensure pgcrypto is available for password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Fix the Loan Products decoding issue
-- This converts any older string-based JSON fields in eligibility_criteria into proper JSON numbers.
UPDATE loan_products
SET eligibility_criteria = (
    SELECT jsonb_object_agg(key, value::text::numeric)
    FROM jsonb_each_text(eligibility_criteria)
)
WHERE eligibility_criteria IS NOT NULL 
  AND eligibility_criteria::text != '{}';

-- 3. Overwrite the create_staff_user function with guaranteed defaults
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
    
    -- Insert into auth.users (ensure all required fields)
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
        aud,
        is_super_admin
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
        'authenticated',
        FALSE
    );

    -- Insert into auth.identities (ensure provider_id is present)
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
        gen_random_uuid(),
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
