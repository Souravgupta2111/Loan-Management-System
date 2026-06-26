-- ============================================================================
-- LMS Staff Migration V6 (Fix Schema Query Error + Robust Trigger/RPC)
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ============================================================================

-- 1. CLEAN UP EXISTING NULL VALUES IN auth.users
-- This resolves the "Database error querying schema" (GoTrue/PostgREST scan errors)
DO $$
DECLARE
    col RECORD;
BEGIN
    FOR col IN 
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_schema = 'auth' 
          AND table_name = 'users' 
          AND column_name IN (
              'confirmation_token', 'recovery_token', 'email_change_token_new',
              'phone_change', 'phone_change_token', 'email_change',
              'email_change_token_current', 'reauthentication_token'
          )
    LOOP
        EXECUTE format('UPDATE auth.users SET %I = '''' WHERE %I IS NULL', col.column_name, col.column_name);
    END LOOP;
END $$;

-- 2. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';

-- 3. Fix any staff users whose public.users role is still 'borrower'
UPDATE public.users u
SET role = (au.raw_user_meta_data->>'role')::user_role
FROM auth.users au
WHERE u.id = au.id
  AND au.raw_user_meta_data->>'role' IS NOT NULL
  AND au.raw_user_meta_data->>'role' != 'borrower'
  AND u.role = 'borrower';

-- 4. Recreate create_staff_user RPC function with safety checks and updates
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
    col RECORD;
BEGIN
    v_user_id := gen_random_uuid();
    v_encrypted_password := crypt(p_password, gen_salt('bf'));

    -- A. Insert into auth.users (login account)
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

    -- B. Clean up nullable text columns on auth.users for this user to prevent scan errors
    FOR col IN 
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_schema = 'auth' 
          AND table_name = 'users' 
          AND column_name IN (
              'confirmation_token', 'recovery_token', 'email_change_token_new',
              'phone_change', 'phone_change_token', 'email_change',
              'email_change_token_current', 'reauthentication_token'
          )
    LOOP
        EXECUTE format('UPDATE auth.users SET %I = '''' WHERE id = %L AND %I IS NULL', col.column_name, v_user_id, col.column_name);
    END LOOP;

    -- C. Insert into auth.identities (required for login)
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

    -- D. Insert into public.users (skips/updates on conflict)
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

    -- E. Insert/Update public.staff_profiles (handles trigger race condition)
    INSERT INTO public.staff_profiles (user_id, employee_id, designation, branch_id)
    VALUES (
        v_user_id,
        p_employee_id,
        p_designation,
        p_branch_id
    )
    ON CONFLICT (user_id) DO UPDATE SET
        employee_id = EXCLUDED.employee_id,
        designation = EXCLUDED.designation,
        branch_id = EXCLUDED.branch_id;

    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Restore full trigger functionality but make it robust against conflicts
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_role user_role;
    v_employee_id TEXT;
BEGIN
    v_role := COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'borrower');
    
    INSERT INTO public.users (id, full_name, email, role, is_active, is_verified)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        NEW.email,
        v_role,
        TRUE,
        TRUE
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        is_verified = TRUE;

    -- Auto-create borrower_profile for borrowers
    IF v_role = 'borrower' THEN
        INSERT INTO public.borrower_profiles (user_id, kyc_status)
        VALUES (NEW.id, 'pending')
        ON CONFLICT (user_id) DO NOTHING;
    END IF;

    -- Auto-create staff_profile for staff roles (only if doesn't exist)
    IF v_role IN ('officer', 'manager', 'admin') THEN
        v_employee_id := COALESCE(NEW.raw_user_meta_data->>'employee_id', 
            UPPER(LEFT(v_role::TEXT, 3)) || '-' || LPAD(FLOOR(RANDOM() * 9999)::TEXT, 4, '0'));
        
        INSERT INTO public.staff_profiles (user_id, employee_id, designation, branch_id)
        VALUES (
            NEW.id,
            v_employee_id,
            COALESCE(NEW.raw_user_meta_data->>'designation', INITCAP(v_role::TEXT)),
            COALESCE(
                (NEW.raw_user_meta_data->>'branch_id')::UUID,
                'a1000001-0000-0000-0000-000000000001'  -- Default to HQ
            )
        )
        ON CONFLICT (user_id) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Reload schema cache again after DDL changes
NOTIFY pgrst, 'reload schema';
