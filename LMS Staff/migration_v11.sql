-- ============================================================================
-- LMS Staff Migration V11 (Audit Log System)
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ============================================================================

-- 1. Create audit_log table
CREATE TABLE IF NOT EXISTS audit_log (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT now(),
    actor_id UUID,
    actor_role TEXT,
    table_name TEXT,
    record_id TEXT,
    action TEXT NOT NULL,
    change_summary TEXT NOT NULL,
    old_value JSONB DEFAULT '{}'::jsonb,
    new_value JSONB DEFAULT '{}'::jsonb,
    ip_address TEXT,
    user_agent TEXT
);

-- 2. Enable RLS
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- 3. Admin-only read policy
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'audit_log' 
        AND policyname = 'Admins can read audit log'
    ) THEN
        CREATE POLICY "Admins can read audit log" ON audit_log
            FOR SELECT USING (is_admin());
    END IF;
END $$;

-- 4. Staff-wide insert policy (anyone authenticated can log their actions)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'audit_log' 
        AND policyname = 'Authenticated users can insert audit logs'
    ) THEN
        CREATE POLICY "Authenticated users can insert audit logs" ON audit_log
            FOR INSERT WITH CHECK (auth.role() = 'authenticated');
    END IF;
END $$;

-- 5. Create index for faster pagination and searching
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_record_id ON audit_log(record_id);

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
