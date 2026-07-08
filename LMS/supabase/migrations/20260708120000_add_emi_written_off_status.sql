-- Adds a dedicated 'written_off' value to the emi_status enum so that when a
-- loan is written off we can settle its unpaid EMIs WITHOUT marking them as
-- 'paid' (which previously corrupted collection-efficiency calculations by
-- counting written-off installments as collected).
--
-- Idempotent: safe to run more than once.

ALTER TYPE emi_status ADD VALUE IF NOT EXISTS 'written_off';
