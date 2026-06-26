-- ============================================================================
-- LMS Staff Migration V5 (Fix: Create users + staff_profiles rows)
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ============================================================================

-- Ensure pgcrypto is available for password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- The problem: create_staff_user only inserted into auth.users and
-- auth.identities, but NEVER inserted into public.users or
-- public.staff_profiles. The handle_new_user trigger on auth.users only
-- creates public.users (not staff_profiles). So staff members had auth
-- accounts but no visible profile in the app.
--
-- This fix: The RPC now explicitly creates all 3 records:
--   1. auth.users       (login credentials)
--   2. public.users     (app-visible user record) — skips if trigger already made it
--   3. staff_profiles   (staff-specific data: employee_id, branch, designation)
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

    -- 1. Insert into auth.users (the login account)
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

    -- 2. Insert into auth.identities (required for Supabase auth to work)
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

    -- 3. Insert into public.users (the app-visible user row)
    --    Use ON CONFLICT in case the handle_new_user trigger already created it
    INSERT INTO public.users (id, full_name, email, role, is_active, is_verified)
    VALUES (
        v_user_id,
        p_full_name,
        p_email,
        p_role::user_role,
        TRUE,
        TRUE
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        is_verified = TRUE;

    -- 4. Insert into public.staff_profiles (the staff-specific record)
    INSERT INTO staff_profiles (user_id, employee_id, designation, branch_id)
    VALUES (
        v_user_id,
        p_employee_id,
        p_designation,
        p_branch_id
    );

    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
