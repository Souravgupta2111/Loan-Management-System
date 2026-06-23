-- ============================================================================
-- Storage Buckets for Documents & Avatars
-- ============================================================================

-- KYC and loan documents bucket (private)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'documents',
    'documents',
    FALSE,
    10485760,  -- 10MB limit
    ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/heic', 'image/heif', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']
);

-- Avatar images bucket (public)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    TRUE,
    2097152,  -- 2MB limit
    ARRAY['image/jpeg', 'image/png', 'image/heic', 'image/heif', 'image/webp']
);

-- ============================================================================
-- Storage RLS Policies — Documents (Private)
-- ============================================================================

-- Users can upload their own documents: documents/{user_id}/{filename}
CREATE POLICY "Users can upload own documents" ON storage.objects
    FOR INSERT
    WITH CHECK (
        bucket_id = 'documents'
        AND (storage.foldername(name))[1] = auth.uid()::TEXT
    );

-- Users can read their own documents
CREATE POLICY "Users can read own documents" ON storage.objects
    FOR SELECT
    USING (
        bucket_id = 'documents'
        AND (storage.foldername(name))[1] = auth.uid()::TEXT
    );

-- Staff can read all documents
CREATE POLICY "Staff can read all documents" ON storage.objects
    FOR SELECT
    USING (
        bucket_id = 'documents'
        AND EXISTS (
            SELECT 1 FROM users
            WHERE id = auth.uid()
            AND role IN ('officer', 'manager', 'admin')
        )
    );

-- Users can delete their own documents
CREATE POLICY "Users can delete own documents" ON storage.objects
    FOR DELETE
    USING (
        bucket_id = 'documents'
        AND (storage.foldername(name))[1] = auth.uid()::TEXT
    );

-- ============================================================================
-- Storage RLS Policies — Avatars (Public read, auth upload)
-- ============================================================================

-- Anyone can view avatars (bucket is public)
-- No SELECT policy needed for public bucket

-- Users can upload their own avatar: avatars/{user_id}/{filename}
CREATE POLICY "Users can upload own avatar" ON storage.objects
    FOR INSERT
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::TEXT
    );

-- Users can update their own avatar
CREATE POLICY "Users can update own avatar" ON storage.objects
    FOR UPDATE
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::TEXT
    );

-- Users can delete their own avatar
CREATE POLICY "Users can delete own avatar" ON storage.objects
    FOR DELETE
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::TEXT
    );
