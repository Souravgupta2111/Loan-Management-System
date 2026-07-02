-- Add missing RLS policies to allow Borrowers to see their assigned Loan Officers
-- Run this in the Supabase SQL Editor.

-- 1. Allow borrower to read the staff profile of the officer assigned to their loan
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'staff_profiles' 
        AND policyname = 'Borrowers can read their assigned officer profile'
    ) THEN
        CREATE POLICY "Borrowers can read their assigned officer profile" ON staff_profiles
            FOR SELECT USING (
                id IN (SELECT assigned_officer_id FROM loan_applications WHERE borrower_id = auth.uid())
            );
    END IF;
END $$;

-- 2. Allow borrower to read the user record (for name/email) of the officer assigned to their loan
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'users' 
        AND policyname = 'Borrowers can read their assigned officer user record'
    ) THEN
        CREATE POLICY "Borrowers can read their assigned officer user record" ON users
            FOR SELECT USING (
                id IN (
                    SELECT user_id FROM staff_profiles WHERE id IN (
                        SELECT assigned_officer_id FROM loan_applications WHERE borrower_id = auth.uid()
                    )
                )
            );
    END IF;
END $$;
