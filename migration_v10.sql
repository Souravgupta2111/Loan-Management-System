-- ============================================================================
-- LMS Staff Migration V10 (Staff Credentials + Email Storage)
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ============================================================================

-- 1. Create staff_credentials table to store employee credentials for admin reference
CREATE TABLE IF NOT EXISTS staff_credentials (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    employee_id TEXT NOT NULL,
    email TEXT NOT NULL,
    password_plain TEXT NOT NULL,  -- Stored for admin retrieval only (internal tool)
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Enable RLS
ALTER TABLE staff_credentials ENABLE ROW LEVEL SECURITY;

-- 3. Admin-only read policy
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'staff_credentials' 
        AND policyname = 'Admins can read credentials'
    ) THEN
        CREATE POLICY "Admins can read credentials" ON staff_credentials
            FOR SELECT USING (is_admin());
    END IF;
END $$;

-- 4. Admin-only insert policy
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'staff_credentials' 
        AND policyname = 'Admins can insert credentials'
    ) THEN
        CREATE POLICY "Admins can insert credentials" ON staff_credentials
            FOR INSERT WITH CHECK (is_admin());
    END IF;
END $$;

-- 5. Admin-only update policy
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'staff_credentials' 
        AND policyname = 'Admins can update credentials'
    ) THEN
        CREATE POLICY "Admins can update credentials" ON staff_credentials
            FOR UPDATE USING (is_admin());
    END IF;
END $$;

-- 6. Admin-only delete policy
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'staff_credentials' 
        AND policyname = 'Admins can delete credentials'
    ) THEN
        CREATE POLICY "Admins can delete credentials" ON staff_credentials
            FOR DELETE USING (is_admin());
    END IF;
END $$;

-- 7. Create index on employee_id for fast lookups
CREATE INDEX IF NOT EXISTS idx_staff_credentials_employee_id 
    ON staff_credentials(employee_id);

-- 8. Create index on user_id
CREATE INDEX IF NOT EXISTS idx_staff_credentials_user_id 
    ON staff_credentials(user_id);

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
