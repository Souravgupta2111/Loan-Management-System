-- ============================================================================
-- Migration: Fix Interest Rate Architecture
-- 
-- Problems solved:
-- 1. Loan products now have a RANGE of interest rates (min/max)
-- 2. Loan products can support MULTIPLE interest types (fixed + floating + reducing)
-- 3. Floating-rate loans track spread + base rate separately
-- 4. RBI repo rate stored centrally in system_configs
-- ============================================================================

-- ============================================================================
-- 1. LOAN PRODUCTS — Rate Range + Multiple Interest Types + Spread
-- ============================================================================

-- Add range columns
ALTER TABLE loan_products
    ADD COLUMN min_interest_rate NUMERIC(5,2),
    ADD COLUMN max_interest_rate NUMERIC(5,2),
    ADD COLUMN supported_interest_types interest_type[] NOT NULL DEFAULT ARRAY['reducing']::interest_type[],
    ADD COLUMN spread_over_base NUMERIC(5,2) NOT NULL DEFAULT 2.00;

-- Migrate existing data: copy base_interest_rate into both min and max
UPDATE loan_products SET
    min_interest_rate = base_interest_rate,
    max_interest_rate = base_interest_rate + 4.00,
    supported_interest_types = ARRAY[interest_type]::interest_type[];

-- Make the new columns NOT NULL after data migration
ALTER TABLE loan_products
    ALTER COLUMN min_interest_rate SET NOT NULL,
    ALTER COLUMN max_interest_rate SET NOT NULL;

-- Add constraints
ALTER TABLE loan_products
    ADD CONSTRAINT chk_interest_rate_range CHECK (min_interest_rate <= max_interest_rate),
    ADD CONSTRAINT chk_min_interest_rate CHECK (min_interest_rate >= 0 AND min_interest_rate <= 100),
    ADD CONSTRAINT chk_max_interest_rate CHECK (max_interest_rate >= 0 AND max_interest_rate <= 100),
    ADD CONSTRAINT chk_spread_over_base CHECK (spread_over_base >= 0 AND spread_over_base <= 50);

-- Drop old single-value columns (no longer needed)
ALTER TABLE loan_products
    DROP CONSTRAINT IF EXISTS chk_interest_rate,
    DROP COLUMN base_interest_rate,
    DROP COLUMN interest_type;

-- ============================================================================
-- 2. LOANS — Track Spread + Base Rate for Floating Loans
-- ============================================================================

-- Add spread and base rate snapshot columns
ALTER TABLE loans
    ADD COLUMN spread NUMERIC(5,2) NOT NULL DEFAULT 0,
    ADD COLUMN base_rate_at_disbursement NUMERIC(5,2) NOT NULL DEFAULT 0,
    ADD COLUMN current_base_rate NUMERIC(5,2) NOT NULL DEFAULT 0;

-- For existing loans, reverse-engineer: assume spread = 2%, base = rate - 2%
UPDATE loans SET
    spread = 2.00,
    base_rate_at_disbursement = GREATEST(interest_rate - 2.00, 0),
    current_base_rate = GREATEST(interest_rate - 2.00, 0);

-- Add constraint
ALTER TABLE loans
    ADD CONSTRAINT chk_spread CHECK (spread >= 0 AND spread <= 50);

-- Add comment explaining the rate calculation
COMMENT ON COLUMN loans.interest_rate IS 'The effective rate charged to borrower. For floating: current_base_rate + spread. For fixed: stays constant.';
COMMENT ON COLUMN loans.spread IS 'Bank markup over RBI base rate. Stays constant for the life of the loan.';
COMMENT ON COLUMN loans.base_rate_at_disbursement IS 'Snapshot of RBI repo rate when loan was disbursed. For audit trail.';
COMMENT ON COLUMN loans.current_base_rate IS 'Current RBI base rate applied to this loan. Updated when RBI changes rates (floating only).';

-- ============================================================================
-- 3. SYSTEM CONFIGS — Seed RBI Repo Rate
-- ============================================================================

INSERT INTO system_configs (config_key, config_value, value_type, description, is_editable)
VALUES
    ('rbi_repo_rate', '6.50', 'number', 'Current RBI Repo Rate (%). When updated, all floating-rate loan products automatically reflect the new base.', TRUE),
    ('rbi_rate_last_changed', '2025-04-01', 'string', 'Date when RBI last changed the repo rate.', TRUE),
    ('rbi_reverse_repo_rate', '3.35', 'number', 'Current RBI Reverse Repo Rate (%). For reference only.', TRUE)
ON CONFLICT (config_key) DO NOTHING;

-- ============================================================================
-- 4. FUNCTION — Bulk Update Floating Loans When RBI Rate Changes
-- ============================================================================

-- This function is called by admin when RBI changes the repo rate.
-- It updates current_base_rate and recalculates interest_rate for all 
-- active floating-rate loans.
CREATE OR REPLACE FUNCTION update_floating_loan_rates(new_base_rate NUMERIC)
RETURNS TABLE(loans_updated INTEGER, old_rate NUMERIC, new_rate NUMERIC) AS $$
DECLARE
    affected_count INTEGER;
    prev_rate NUMERIC;
BEGIN
    -- Get current rate
    SELECT config_value::NUMERIC INTO prev_rate
    FROM system_configs WHERE config_key = 'rbi_repo_rate';

    -- Update system config
    UPDATE system_configs
    SET config_value = new_base_rate::TEXT,
        updated_at = now()
    WHERE config_key = 'rbi_repo_rate';

    -- Update last changed date
    UPDATE system_configs
    SET config_value = CURRENT_DATE::TEXT,
        updated_at = now()
    WHERE config_key = 'rbi_rate_last_changed';

    -- Update all active floating-rate loans
    UPDATE loans
    SET current_base_rate = new_base_rate,
        interest_rate = new_base_rate + spread,
        updated_at = now()
    WHERE status = 'active'
      AND interest_type = 'floating';

    GET DIAGNOSTICS affected_count = ROW_COUNT;

    RETURN QUERY SELECT affected_count, prev_rate, new_base_rate;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Only admins should call this function (enforced at app level + RLS)
COMMENT ON FUNCTION update_floating_loan_rates IS 'Call when RBI changes repo rate. Updates all active floating-rate loans. Usage: SELECT * FROM update_floating_loan_rates(6.25);';
