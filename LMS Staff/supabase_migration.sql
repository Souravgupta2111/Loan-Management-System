-- ============================================================================
-- LMS Staff Credentials Migration
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ============================================================================

-- ============================================================================
-- 1. SEED BRANCHES (Multiple branches for realistic data)
-- ============================================================================
INSERT INTO branches (id, name, code, address, city, state, pincode, ifsc_prefix, is_active)
VALUES
    ('a1000001-0000-0000-0000-000000000001', 'HQ - Main Branch', 'HQ001', '1st Floor, Financial District', 'Mumbai', 'Maharashtra', '400001', 'LMSB00', TRUE),
    ('a1000001-0000-0000-0000-000000000002', 'North Zone Branch', 'NZ001', '45 Connaught Place', 'New Delhi', 'Delhi', '110001', 'LMSB01', TRUE),
    ('a1000001-0000-0000-0000-000000000003', 'South Zone Branch', 'SZ001', '12 MG Road', 'Bangalore', 'Karnataka', '560001', 'LMSB02', TRUE),
    ('a1000001-0000-0000-0000-000000000004', 'East Zone Branch', 'EZ001', '78 Park Street', 'Kolkata', 'West Bengal', '700016', 'LMSB03', TRUE),
    ('a1000001-0000-0000-0000-000000000005', 'West Zone Branch', 'WZ001', '23 SG Highway', 'Ahmedabad', 'Gujarat', '380015', 'LMSB04', TRUE)
ON CONFLICT (code) DO NOTHING;

-- ============================================================================
-- 2. FIX: Add missing RLS policy for borrower payment updates
-- (This fixes the Pay EMI bug in the Borrower app)
-- ============================================================================
DO $$
BEGIN
    -- Only create if not exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'payments' 
        AND policyname = 'Borrower can update own payments'
    ) THEN
        CREATE POLICY "Borrower can update own payments" ON payments
            FOR UPDATE USING (
                loan_id IN (SELECT id FROM loans WHERE borrower_id = auth.uid())
            )
            WITH CHECK (
                loan_id IN (SELECT id FROM loans WHERE borrower_id = auth.uid())
            );
    END IF;
END $$;

-- ============================================================================
-- 3. FIX: Add missing RLS policy for borrower EMI updates
-- ============================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'emi_schedule' 
        AND policyname = 'Borrower can update own EMI status'
    ) THEN
        CREATE POLICY "Borrower can update own EMI status" ON emi_schedule
            FOR UPDATE USING (
                loan_id IN (SELECT id FROM loans WHERE borrower_id = auth.uid())
            )
            WITH CHECK (
                loan_id IN (SELECT id FROM loans WHERE borrower_id = auth.uid())
            );
    END IF;
END $$;

-- ============================================================================
-- 4. SEED LOAN PRODUCTS (Real industry loan types)
-- ============================================================================
INSERT INTO loan_products (id, name, type, description, min_amount, max_amount, min_tenure_months, max_tenure_months, min_interest_rate, max_interest_rate, supported_interest_types, spread_over_base, processing_fee_pct, prepayment_penalty_pct, late_penalty_pct_per_month, requires_collateral, is_active, eligibility_criteria, required_documents)
VALUES
    (
        'b1000001-0000-0000-0000-000000000001',
        'Personal Loan Express',
        'personal',
        'Quick personal loan for salaried individuals with minimal documentation',
        50000, 2500000,
        6, 60,
        10.50, 14.50, ARRAY['reducing']::interest_type[], 2.00, 1.50, 2.00, 2.00,
        FALSE, TRUE,
        '{"min_income": 25000, "min_credit_score": 650, "min_age": 21, "max_age": 58}',
        '["Aadhaar Card", "PAN Card", "Salary Slips (3 months)", "Bank Statement (6 months)"]'
    ),
    (
        'b1000001-0000-0000-0000-000000000002',
        'Home Loan Advantage',
        'home',
        'Affordable home loans with competitive floating rates',
        500000, 50000000,
        60, 360,
        8.50, 12.50, ARRAY['reducing', 'floating']::interest_type[], 2.00, 0.50, 3.00, 2.00,
        TRUE, TRUE,
        '{"min_income": 40000, "min_credit_score": 700, "min_age": 23, "max_age": 60}',
        '["Aadhaar Card", "PAN Card", "Income Proof", "Property Documents", "Sale Agreement", "NOC from Builder"]'
    ),
    (
        'b1000001-0000-0000-0000-000000000003',
        'Vehicle Loan',
        'vehicle',
        'New and used vehicle financing with flexible tenure',
        100000, 10000000,
        12, 84,
        9.25, 13.25, ARRAY['fixed']::interest_type[], 2.00, 1.00, 4.00, 2.50,
        TRUE, TRUE,
        '{"min_income": 20000, "min_credit_score": 650, "min_age": 21, "max_age": 65}',
        '["Aadhaar Card", "PAN Card", "Income Proof", "Vehicle Quotation", "Driving License"]'
    ),
    (
        'b1000001-0000-0000-0000-000000000004',
        'Education Loan',
        'education',
        'Support higher education dreams with moratorium period',
        100000, 7500000,
        36, 180,
        9.00, 12.00, ARRAY['reducing']::interest_type[], 2.00, 0.00, 0.00, 1.50,
        FALSE, TRUE,
        '{"min_credit_score": 600, "min_age": 18, "max_age": 35}',
        '["Aadhaar Card", "PAN Card", "Admission Letter", "Fee Structure", "Co-applicant Income Proof"]'
    ),
    (
        'b1000001-0000-0000-0000-000000000005',
        'Business Loan MSME',
        'business',
        'Working capital and expansion loans for MSMEs',
        200000, 25000000,
        12, 120,
        11.50, 15.50, ARRAY['reducing']::interest_type[], 3.00, 2.00, 3.00, 2.50,
        FALSE, TRUE,
        '{"min_income": 50000, "min_credit_score": 680, "min_age": 25, "max_age": 65, "min_business_years": 3}',
        '["Aadhaar Card", "PAN Card", "GST Registration", "ITR (2 years)", "Bank Statement (12 months)", "Business Proof"]'
    ),
    (
        'b1000001-0000-0000-0000-000000000006',
        'Gold Loan Instant',
        'gold',
        'Instant loan against gold ornaments with same-day disbursal',
        10000, 5000000,
        3, 36,
        7.50, 9.50, ARRAY['fixed']::interest_type[], 1.00, 0.50, 0.00, 3.00,
        TRUE, TRUE,
        '{"min_age": 18, "max_age": 70}',
        '["Aadhaar Card", "PAN Card", "Gold Appraisal Certificate"]'
    )
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 4.5. ADMIN USER CREATION HELPER FUNCTION (RPC)
-- ============================================================================
CREATE OR REPLACE FUNCTION create_staff_user(
    p_email TEXT,
    p_password TEXT,
    p_full_name TEXT,
    p_role TEXT,
    p_employee_id TEXT,
    p_designation TEXT,
    p_branch_id UUID
)
RETURNS UUID AS $$
DECLARE
    v_user_id UUID;
    v_encrypted_password TEXT;
BEGIN
    v_user_id := gen_random_uuid();
    v_encrypted_password := crypt(p_password, gen_salt('bf'));
    
    -- Insert into auth.users
    INSERT INTO auth.users (
        id,
        instance_id,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        role,
        aud
    )
    VALUES (
        v_user_id,
        '00000000-0000-0000-0000-000000000000',
        p_email,
        v_encrypted_password,
        now(),
        '{"provider": "email", "providers": ["email"]}',
        jsonb_build_object(
            'full_name', p_full_name,
            'role', p_role,
            'employee_id', p_employee_id,
            'designation', p_designation,
            'branch_id', p_branch_id
        ),
        now(),
        now(),
        'authenticated',
        'authenticated'
    );

    -- Insert into auth.identities
    INSERT INTO auth.identities (
        id,
        user_id,
        identity_data,
        provider,
        last_sign_in_at,
        created_at,
        updated_at
    )
    VALUES (
        v_user_id,
        v_user_id,
        jsonb_build_object('sub', v_user_id::text, 'email', p_email),
        'email',
        now(),
        now(),
        now()
    );

    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 5. UPDATE handle_new_user TRIGGER
-- Auto-create staff_profiles when role is not borrower
-- ============================================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_role user_role;
    v_employee_id TEXT;
BEGIN
    v_role := COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'borrower');
    
    INSERT INTO public.users (id, full_name, email, role, is_active, is_verified)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        NEW.email,
        v_role,
        TRUE,
        TRUE
    );

    -- Auto-create borrower_profile for borrowers
    IF v_role = 'borrower' THEN
        INSERT INTO public.borrower_profiles (user_id, kyc_status)
        VALUES (NEW.id, 'pending');
    END IF;

    -- Auto-create staff_profile for staff roles
    IF v_role IN ('officer', 'manager', 'admin') THEN
        v_employee_id := COALESCE(NEW.raw_user_meta_data->>'employee_id', 
            UPPER(LEFT(v_role::TEXT, 3)) || '-' || LPAD(FLOOR(RANDOM() * 9999)::TEXT, 4, '0'));
        
        INSERT INTO public.staff_profiles (user_id, employee_id, designation, branch_id)
        VALUES (
            NEW.id,
            v_employee_id,
            COALESCE(NEW.raw_user_meta_data->>'designation', INITCAP(v_role::TEXT)),
            COALESCE(
                (NEW.raw_user_meta_data->>'branch_id')::UUID,
                'a1000001-0000-0000-0000-000000000001'  -- Default to HQ
            )
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 6. ADDITIONAL RLS POLICIES FOR STAFF OPERATIONS
-- ============================================================================

-- Staff can insert into loan_applications (for creating on behalf / system)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'loan_applications' 
        AND policyname = 'Staff can insert applications'
    ) THEN
        CREATE POLICY "Staff can insert applications" ON loan_applications
            FOR INSERT WITH CHECK (is_staff());
    END IF;
END $$;

-- Staff can insert loans (for disbursement)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'loans' 
        AND policyname = 'Staff can insert loans'
    ) THEN
        CREATE POLICY "Staff can insert loans" ON loans
            FOR INSERT WITH CHECK (is_staff());
    END IF;
END $$;

-- Staff can insert EMI schedule entries
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'emi_schedule' 
        AND policyname = 'Staff can insert EMI schedules'
    ) THEN
        CREATE POLICY "Staff can insert EMI schedules" ON emi_schedule
            FOR INSERT WITH CHECK (is_staff());
    END IF;
END $$;

-- Staff can insert credit checks
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'credit_checks' 
        AND policyname = 'Staff can insert credit checks'
    ) THEN
        CREATE POLICY "Staff can insert credit checks" ON credit_checks
            FOR INSERT WITH CHECK (is_staff());
    END IF;
END $$;

-- Staff can insert documents
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'documents' 
        AND policyname = 'Staff can insert documents'
    ) THEN
        CREATE POLICY "Staff can insert documents" ON documents
            FOR INSERT WITH CHECK (is_staff());
    END IF;
END $$;

-- Staff can update users (for admin staff management)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'users' 
        AND policyname = 'Staff can update users'
    ) THEN
        CREATE POLICY "Staff can update users" ON users
            FOR UPDATE USING (is_staff());
    END IF;
END $$;

-- Staff can insert users (for admin creating staff)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'users' 
        AND policyname = 'Staff can insert users'
    ) THEN
        CREATE POLICY "Staff can insert users" ON users
            FOR INSERT WITH CHECK (is_admin());
    END IF;
END $$;

-- Staff can insert staff_profiles 
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'staff_profiles' 
        AND policyname = 'Staff can insert staff profiles'
    ) THEN
        CREATE POLICY "Staff can insert staff profiles" ON staff_profiles
            FOR INSERT WITH CHECK (is_admin());
    END IF;
END $$;

-- Staff can update staff_profiles
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'staff_profiles' 
        AND policyname = 'Staff can update staff profiles'
    ) THEN
        CREATE POLICY "Staff can update staff profiles" ON staff_profiles
            FOR UPDATE USING (is_admin());
    END IF;
END $$;

-- Staff can insert loan restructures
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'loan_restructures' 
        AND policyname = 'Staff can insert restructures'
    ) THEN
        CREATE POLICY "Staff can insert restructures" ON loan_restructures
            FOR INSERT WITH CHECK (is_staff());
    END IF;
END $$;

-- Admin notification insertion (for system notifications)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'notifications' 
        AND policyname = 'Admin can manage notifications'
    ) THEN
        CREATE POLICY "Admin can manage notifications" ON notifications
            FOR ALL USING (is_admin());
    END IF;
END $$;

-- ============================================================================
-- NOTE: After running this SQL, create the admin user via Supabase Dashboard:
-- 
-- Go to Authentication → Users → Create User:
--   Email:    guptajaihind786@gmail.com
--   Password: Admin@2026
--   User Metadata (JSON): 
--     {"full_name": "System Administrator", "role": "admin", "employee_id": "ADM-0001", "designation": "Chief Administrator", "branch_id": "a1000001-0000-0000-0000-000000000001"}
--
-- The handle_new_user trigger will auto-create the users + staff_profiles rows.
-- ============================================================================
