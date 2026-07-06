-- ============================================================================
-- LMS Migration V9: Auto-Assign Branch & Loan Officer
-- Adds geolocation to branches and creates automated assignment RPCs.
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ============================================================================

-- ============================================================================
-- 1. ADD GEOLOCATION COLUMNS TO BRANCHES
-- ============================================================================
ALTER TABLE branches
    ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- Seed coordinates for existing branches
UPDATE branches SET latitude = 18.9352, longitude = 72.8278
    WHERE id = 'a1000001-0000-0000-0000-000000000001'; -- Mumbai HQ

UPDATE branches SET latitude = 28.6315, longitude = 77.2167
    WHERE id = 'a1000001-0000-0000-0000-000000000002'; -- New Delhi

UPDATE branches SET latitude = 12.9716, longitude = 77.5946
    WHERE id = 'a1000001-0000-0000-0000-000000000003'; -- Bangalore

UPDATE branches SET latitude = 22.5726, longitude = 88.3639
    WHERE id = 'a1000001-0000-0000-0000-000000000004'; -- Kolkata

UPDATE branches SET latitude = 23.0225, longitude = 72.5714
    WHERE id = 'a1000001-0000-0000-0000-000000000005'; -- Ahmedabad

-- ============================================================================
-- 2. RPC: FIND NEAREST BRANCH BY COORDINATES (Haversine)
-- Used when no pincode match is found — calculates geographic distance.
-- ============================================================================
CREATE OR REPLACE FUNCTION find_nearest_branch_by_coords(
    p_lat DOUBLE PRECISION,
    p_lon DOUBLE PRECISION
)
RETURNS UUID AS $$
DECLARE
    v_branch_id UUID;
BEGIN
    SELECT id INTO v_branch_id
    FROM branches
    WHERE is_active = TRUE
      AND latitude IS NOT NULL
      AND longitude IS NOT NULL
    ORDER BY (
        6371 * acos(
            LEAST(1.0, GREATEST(-1.0,
                cos(radians(p_lat)) * cos(radians(latitude))
                * cos(radians(longitude) - radians(p_lon))
                + sin(radians(p_lat)) * sin(radians(latitude))
            ))
        )
    ) ASC
    LIMIT 1;

    -- Absolute fallback to HQ if no branches have coordinates
    IF v_branch_id IS NULL THEN
        SELECT id INTO v_branch_id
        FROM branches
        WHERE is_active = TRUE
        ORDER BY created_at ASC
        LIMIT 1;
    END IF;

    RETURN v_branch_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- 3. RPC: AUTO-ASSIGN BRANCH AND LEAST-LOADED OFFICER
-- Called after a loan application is submitted.
-- Strategy:
--   1. Exact pincode match from branch_pincodes
--   2. 3-digit prefix match (same postal zone)
--   3. Nearest branch by coordinates (if lat/lon provided)
--   4. Absolute fallback: first active branch
-- Then assigns the officer with the fewest active applications.
-- ============================================================================
CREATE OR REPLACE FUNCTION auto_assign_branch_and_officer(
    p_application_id UUID,
    p_lat DOUBLE PRECISION DEFAULT NULL,
    p_lon DOUBLE PRECISION DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_borrower_id UUID;
    v_pincode TEXT;
    v_branch_id UUID;
    v_branch_name TEXT;
    v_officer_profile_id UUID;
    v_officer_user_id UUID;
    v_officer_name TEXT;
BEGIN
    -- 1. Get borrower ID from the application
    SELECT borrower_id INTO v_borrower_id
    FROM loan_applications
    WHERE id = p_application_id;

    IF v_borrower_id IS NULL THEN
        RAISE EXCEPTION 'Application not found: %', p_application_id;
    END IF;

    -- 2. Get borrower's pincode from profile
    SELECT pincode INTO v_pincode
    FROM borrower_profiles
    WHERE user_id = v_borrower_id;

    -- 3. Find branch: exact pincode → prefix → geo → fallback
    IF v_pincode IS NOT NULL AND v_pincode != '' THEN
        -- Exact match
        SELECT branch_id INTO v_branch_id
        FROM branch_pincodes
        WHERE pincode = v_pincode
        LIMIT 1;

        -- 3-digit prefix match (same postal zone)
        IF v_branch_id IS NULL THEN
            SELECT branch_id INTO v_branch_id
            FROM branch_pincodes
            WHERE LEFT(pincode, 3) = LEFT(v_pincode, 3)
            LIMIT 1;
        END IF;
    END IF;

    -- Geo-based nearest branch (when pincode matching fails)
    IF v_branch_id IS NULL AND p_lat IS NOT NULL AND p_lon IS NOT NULL THEN
        v_branch_id := find_nearest_branch_by_coords(p_lat, p_lon);
    END IF;

    -- Absolute fallback: first active branch
    IF v_branch_id IS NULL THEN
        SELECT id INTO v_branch_id
        FROM branches
        WHERE is_active = TRUE
        ORDER BY created_at ASC
        LIMIT 1;
    END IF;

    -- Get branch name
    SELECT name INTO v_branch_name
    FROM branches
    WHERE id = v_branch_id;

    -- 4. Find the least-loaded active officer in this branch
    SELECT sp.id, sp.user_id INTO v_officer_profile_id, v_officer_user_id
    FROM staff_profiles sp
    JOIN users u ON u.id = sp.user_id
    WHERE sp.branch_id = v_branch_id
      AND u.role = 'officer'
      AND u.is_active = TRUE
    ORDER BY (
        SELECT COUNT(*) FROM loan_applications la
        WHERE la.assigned_officer_id = sp.id
          AND la.status IN ('submitted', 'under_review')
    ) ASC
    LIMIT 1;

    -- Fallback: if no officer in this branch, try any active officer
    IF v_officer_profile_id IS NULL THEN
        SELECT sp.id, sp.user_id INTO v_officer_profile_id, v_officer_user_id
        FROM staff_profiles sp
        JOIN users u ON u.id = sp.user_id
        WHERE u.role = 'officer'
          AND u.is_active = TRUE
        ORDER BY (
            SELECT COUNT(*) FROM loan_applications la
            WHERE la.assigned_officer_id = sp.id
              AND la.status IN ('submitted', 'under_review')
        ) ASC
        LIMIT 1;
    END IF;

    -- Get officer name
    IF v_officer_user_id IS NOT NULL THEN
        SELECT full_name INTO v_officer_name
        FROM users
        WHERE id = v_officer_user_id;
    END IF;

    -- 5. Update the application with branch and officer
    UPDATE loan_applications
    SET branch_id = v_branch_id,
        assigned_officer_id = v_officer_profile_id,
        last_updated_at = NOW()
    WHERE id = p_application_id;

    -- 6. Return assignment result
    RETURN jsonb_build_object(
        'branch_id', v_branch_id,
        'branch_name', COALESCE(v_branch_name, 'Unknown'),
        'officer_id', v_officer_profile_id,
        'officer_user_id', v_officer_user_id,
        'officer_name', COALESCE(v_officer_name, 'Unassigned')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. RPC: GET OFFICER WORKLOAD (for staff dashboard visibility)
-- ============================================================================
CREATE OR REPLACE FUNCTION get_officer_workload(p_branch_id UUID)
RETURNS TABLE(
    officer_profile_id UUID,
    officer_user_id UUID,
    officer_name TEXT,
    active_applications BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        sp.id AS officer_profile_id,
        sp.user_id AS officer_user_id,
        u.full_name AS officer_name,
        (
            SELECT COUNT(*) FROM loan_applications la
            WHERE la.assigned_officer_id = sp.id
              AND la.status IN ('submitted', 'under_review')
        ) AS active_applications
    FROM staff_profiles sp
    JOIN users u ON u.id = sp.user_id
    WHERE sp.branch_id = p_branch_id
      AND u.role = 'officer'
      AND u.is_active = TRUE
    ORDER BY active_applications ASC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
