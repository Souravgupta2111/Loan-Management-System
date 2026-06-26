-- ============================================================================
-- LMS Staff Migration V7 (Admin Reset Password Function)
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ============================================================================

-- Ensure pgcrypto is available for password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create RPC function to reset staff password
CREATE OR REPLACE FUNCTION reset_staff_password(
    p_user_id UUID,
    p_new_password TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_encrypted_password TEXT;
BEGIN
    -- Security Check: Verify caller is an administrator
    IF NOT EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = auth.uid() 
        AND role = 'admin'
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Only administrators can reset staff passwords.';
    END IF;

    -- Hash the password using bcrypt (bf)
    v_encrypted_password := crypt(p_new_password, gen_salt('bf'));

    -- Update the encrypted password in auth.users
    UPDATE auth.users
    SET encrypted_password = v_encrypted_password,
        updated_at = now()
    WHERE id = p_user_id;

    -- Return true if user was found and updated, false otherwise
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
