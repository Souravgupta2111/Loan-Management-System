-- ============================================================================
-- LMS Staff Migration V8 (Branch Management Feature)
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ============================================================================

-- ============================================================================
-- 1. ADD MANAGER & HEAD OFFICER COLUMNS TO BRANCHES
-- ============================================================================
ALTER TABLE branches
    ADD COLUMN IF NOT EXISTS manager_id UUID REFERENCES users(id);

-- ============================================================================
-- 2. CREATE BRANCH_PINCODES TABLE
-- Maps pincodes to branches for proximity-based loan assignment
-- ============================================================================
CREATE TABLE IF NOT EXISTS branch_pincodes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    pincode TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT unique_pincode UNIQUE (pincode)
);

-- Enable RLS
ALTER TABLE branch_pincodes ENABLE ROW LEVEL SECURITY;

-- Admin can do everything on branch_pincodes
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'branch_pincodes' 
        AND policyname = 'Admin can manage branch pincodes'
    ) THEN
        CREATE POLICY "Admin can manage branch pincodes" ON branch_pincodes
            FOR ALL USING (is_admin());
    END IF;
END $$;

-- Staff can read branch_pincodes
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'branch_pincodes' 
        AND policyname = 'Staff can read branch pincodes'
    ) THEN
        CREATE POLICY "Staff can read branch pincodes" ON branch_pincodes
            FOR SELECT USING (is_staff());
    END IF;
END $$;

-- ============================================================================
-- 3. ADMIN RLS POLICIES FOR BRANCHES TABLE (INSERT/UPDATE/DELETE)
-- ============================================================================

-- Admin can insert branches
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'branches' 
        AND policyname = 'Admin can insert branches'
    ) THEN
        CREATE POLICY "Admin can insert branches" ON branches
            FOR INSERT WITH CHECK (is_admin());
    END IF;
END $$;

-- Admin can update branches
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'branches' 
        AND policyname = 'Admin can update branches'
    ) THEN
        CREATE POLICY "Admin can update branches" ON branches
            FOR UPDATE USING (is_admin());
    END IF;
END $$;

-- ============================================================================
-- 4. SEED PINCODES FOR EXISTING BRANCHES
-- ============================================================================
INSERT INTO branch_pincodes (branch_id, pincode)
VALUES
    -- HQ Mumbai
    ('a1000001-0000-0000-0000-000000000001', '400001'),
    ('a1000001-0000-0000-0000-000000000001', '400002'),
    ('a1000001-0000-0000-0000-000000000001', '400003'),
    -- North Zone Delhi
    ('a1000001-0000-0000-0000-000000000002', '110001'),
    ('a1000001-0000-0000-0000-000000000002', '110002'),
    ('a1000001-0000-0000-0000-000000000002', '110003'),
    -- South Zone Bangalore
    ('a1000001-0000-0000-0000-000000000003', '560001'),
    ('a1000001-0000-0000-0000-000000000003', '560002'),
    ('a1000001-0000-0000-0000-000000000003', '560003'),
    -- East Zone Kolkata
    ('a1000001-0000-0000-0000-000000000004', '700016'),
    ('a1000001-0000-0000-0000-000000000004', '700017'),
    ('a1000001-0000-0000-0000-000000000004', '700018'),
    -- West Zone Ahmedabad
    ('a1000001-0000-0000-0000-000000000005', '380015'),
    ('a1000001-0000-0000-0000-000000000005', '380016'),
    ('a1000001-0000-0000-0000-000000000005', '380017')
ON CONFLICT (pincode) DO NOTHING;

-- ============================================================================
-- 5. RPC: FIND BRANCH BY BORROWER PINCODE (Proximity Match)
-- ============================================================================
CREATE OR REPLACE FUNCTION find_branch_for_pincode(p_pincode TEXT)
RETURNS UUID AS $$
DECLARE
    v_branch_id UUID;
BEGIN
    -- Exact pincode match
    SELECT branch_id INTO v_branch_id
    FROM branch_pincodes
    WHERE pincode = p_pincode
    LIMIT 1;

    -- If no exact match, try prefix match (first 3 digits = same area)
    IF v_branch_id IS NULL THEN
        SELECT branch_id INTO v_branch_id
        FROM branch_pincodes
        WHERE LEFT(pincode, 3) = LEFT(p_pincode, 3)
        LIMIT 1;
    END IF;

    -- Fallback to HQ
    IF v_branch_id IS NULL THEN
        v_branch_id := 'a1000001-0000-0000-0000-000000000001';
    END IF;

    RETURN v_branch_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
