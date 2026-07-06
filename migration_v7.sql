-- ============================================================================
-- LMS Staff Migration V7 (Add Income Verification Columns)
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ============================================================================

ALTER TABLE public.borrower_profiles
ADD COLUMN IF NOT EXISTS income_verified BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS verified_annual_income NUMERIC,
ADD COLUMN IF NOT EXISTS itr_assessment_year TEXT;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
