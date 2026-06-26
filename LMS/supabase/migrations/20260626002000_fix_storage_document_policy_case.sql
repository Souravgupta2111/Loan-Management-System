-- ============================================================================
-- Fix documents storage policies for Swift UUID casing
-- ============================================================================
--
-- Swift UUID.uuidString is uppercase by default, while auth.uid()::text is
-- lowercase. Storage RLS compares strings exactly, so uploads can be rejected
-- even when the path belongs to the signed-in user.

DROP POLICY IF EXISTS "Users can upload own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can read own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own documents" ON storage.objects;

CREATE POLICY "Users can upload own documents" ON storage.objects
    FOR INSERT
    WITH CHECK (
        bucket_id = 'documents'
        AND lower((storage.foldername(name))[1]) = auth.uid()::TEXT
    );

CREATE POLICY "Users can read own documents" ON storage.objects
    FOR SELECT
    USING (
        bucket_id = 'documents'
        AND lower((storage.foldername(name))[1]) = auth.uid()::TEXT
    );

CREATE POLICY "Users can delete own documents" ON storage.objects
    FOR DELETE
    USING (
        bucket_id = 'documents'
        AND lower((storage.foldername(name))[1]) = auth.uid()::TEXT
    );
