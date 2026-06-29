-- ============================================================================
-- LMS Staff Migration V9 (Fix Documents RLS for Officers)
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ============================================================================

-- Staff can read documents
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'documents' 
        AND policyname = 'Staff can read documents'
    ) THEN
        CREATE POLICY "Staff can read documents" ON documents
            FOR SELECT USING (is_staff());
    END IF;
END $$;

-- Staff can update documents (for verifying/rejecting)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'documents' 
        AND policyname = 'Staff can update documents'
    ) THEN
        CREATE POLICY "Staff can update documents" ON documents
            FOR UPDATE USING (is_staff());
    END IF;
END $$;

-- Also ensure staff can read from storage bucket if they can't already
-- (Assuming the bucket is named 'documents')
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'storage' 
        AND tablename = 'objects' 
        AND policyname = 'Staff can read storage documents'
    ) THEN
        CREATE POLICY "Staff can read storage documents" ON storage.objects
            FOR SELECT USING (bucket_id = 'documents' AND is_staff());
    END IF;
END $$;

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
