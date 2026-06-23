-- ============================================================================
-- LMS Initial Schema Migration
-- 16 tables + enums + indexes + triggers + auto-generation functions
-- ============================================================================

-- ============================================================================
-- ENUMS
-- ============================================================================
CREATE TYPE user_role AS ENUM ('borrower', 'officer', 'manager', 'admin');
CREATE TYPE kyc_status AS ENUM ('pending', 'submitted', 'verified', 'rejected');
CREATE TYPE gender_type AS ENUM ('male', 'female', 'other');
CREATE TYPE employment_type AS ENUM ('salaried', 'self_employed', 'business', 'retired', 'unemployed', 'student');
CREATE TYPE loan_type AS ENUM ('personal', 'home', 'vehicle', 'education', 'business', 'gold', 'agriculture', 'other');
CREATE TYPE interest_type AS ENUM ('fixed', 'floating', 'reducing');
CREATE TYPE application_status AS ENUM ('draft', 'submitted', 'under_review', 'approved', 'rejected', 'sent_back', 'disbursed');
CREATE TYPE loan_status AS ENUM ('active', 'closed', 'npa', 'restructured', 'written_off');
CREATE TYPE emi_status AS ENUM ('upcoming', 'due', 'paid', 'overdue', 'partially_paid');
CREATE TYPE payment_mode AS ENUM ('cash', 'upi', 'razorpay', 'cheque', 'neft', 'rtgs', 'auto_debit');
CREATE TYPE payment_status AS ENUM ('initiated', 'processing', 'confirmed', 'failed', 'refunded');
CREATE TYPE document_category AS ENUM ('kyc', 'income', 'collateral', 'loan', 'other');
CREATE TYPE collateral_status AS ENUM ('submitted', 'appraised', 'approved', 'released', 'seized');
CREATE TYPE restructure_status AS ENUM ('requested', 'approved', 'rejected', 'applied');
CREATE TYPE message_type AS ENUM ('text', 'system', 'attachment');
CREATE TYPE notification_type AS ENUM ('loan_update', 'payment_reminder', 'payment_received', 'kyc_update', 'document_request', 'approval_required', 'general', 'system');
CREATE TYPE approval_action AS ENUM ('submit', 'review', 'approve', 'reject', 'send_back', 'disburse', 'escalate');
CREATE TYPE credit_bureau AS ENUM ('cibil', 'experian', 'equifax', 'crif');

-- ============================================================================
-- 1. BRANCHES
-- ============================================================================
CREATE TABLE branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    address TEXT,
    city TEXT,
    state TEXT,
    pincode TEXT,
    ifsc_prefix TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_branches_city ON branches(city);
CREATE INDEX idx_branches_state ON branches(state);
CREATE INDEX idx_branches_is_active ON branches(is_active);

-- ============================================================================
-- 2. USERS
-- ============================================================================
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    role user_role NOT NULL DEFAULT 'borrower',
    avatar_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_is_active ON users(is_active);

-- ============================================================================
-- 3. BORROWER PROFILES
-- ============================================================================
CREATE TABLE borrower_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    aadhaar_number TEXT,
    pan_number TEXT,
    date_of_birth DATE,
    gender gender_type,
    address_line1 TEXT,
    address_line2 TEXT,
    city TEXT,
    state TEXT,
    pincode TEXT,
    employment_type employment_type,
    monthly_income NUMERIC(12,2) DEFAULT 0,
    credit_score INTEGER,
    credit_bureau credit_bureau,
    kyc_status kyc_status NOT NULL DEFAULT 'pending',
    kyc_submitted_at TIMESTAMPTZ,
    kyc_verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_borrower_profiles_user_id ON borrower_profiles(user_id);
CREATE INDEX idx_borrower_profiles_kyc_status ON borrower_profiles(kyc_status);

-- ============================================================================
-- 4. STAFF PROFILES
-- ============================================================================
CREATE TABLE staff_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    employee_id TEXT NOT NULL UNIQUE,
    designation TEXT,
    department TEXT,
    branch_id UUID REFERENCES branches(id) ON DELETE SET NULL,
    reports_to UUID REFERENCES staff_profiles(id) ON DELETE SET NULL,
    max_loan_approval_limit NUMERIC(14,2) DEFAULT 0,
    can_disburse BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_staff_profiles_user_id ON staff_profiles(user_id);
CREATE INDEX idx_staff_profiles_branch_id ON staff_profiles(branch_id);
CREATE INDEX idx_staff_profiles_reports_to ON staff_profiles(reports_to);

-- ============================================================================
-- 5. LOAN PRODUCTS
-- ============================================================================
CREATE TABLE loan_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    type loan_type NOT NULL,
    description TEXT,
    min_amount NUMERIC(14,2) NOT NULL DEFAULT 10000,
    max_amount NUMERIC(14,2) NOT NULL DEFAULT 10000000,
    min_tenure_months INTEGER NOT NULL DEFAULT 3,
    max_tenure_months INTEGER NOT NULL DEFAULT 360,
    base_interest_rate NUMERIC(5,2) NOT NULL DEFAULT 10.00,
    interest_type interest_type NOT NULL DEFAULT 'reducing',
    processing_fee_pct NUMERIC(5,2) NOT NULL DEFAULT 1.00,
    prepayment_penalty_pct NUMERIC(5,2) NOT NULL DEFAULT 2.00,
    late_penalty_pct_per_month NUMERIC(5,2) NOT NULL DEFAULT 2.00,
    requires_collateral BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    eligibility_criteria JSONB DEFAULT '{}',
    required_documents JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_amount_range CHECK (min_amount <= max_amount),
    CONSTRAINT chk_tenure_range CHECK (min_tenure_months <= max_tenure_months),
    CONSTRAINT chk_interest_rate CHECK (base_interest_rate >= 0 AND base_interest_rate <= 100),
    CONSTRAINT chk_processing_fee CHECK (processing_fee_pct >= 0 AND processing_fee_pct <= 100),
    CONSTRAINT chk_prepayment_penalty CHECK (prepayment_penalty_pct >= 0),
    CONSTRAINT chk_late_penalty CHECK (late_penalty_pct_per_month >= 0)
);

CREATE INDEX idx_loan_products_type ON loan_products(type);
CREATE INDEX idx_loan_products_is_active ON loan_products(is_active);

-- ============================================================================
-- 6. LOAN APPLICATIONS
-- ============================================================================

-- Auto-generate application numbers: LMS-APP-000001
CREATE SEQUENCE loan_application_seq START 1;

CREATE OR REPLACE FUNCTION generate_application_number()
RETURNS TRIGGER AS $$
BEGIN
    NEW.application_number := 'LMS-APP-' || LPAD(nextval('loan_application_seq')::TEXT, 6, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE loan_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_number TEXT UNIQUE,
    borrower_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    loan_product_id UUID NOT NULL REFERENCES loan_products(id) ON DELETE RESTRICT,
    assigned_officer_id UUID REFERENCES staff_profiles(id) ON DELETE SET NULL,
    branch_id UUID REFERENCES branches(id) ON DELETE SET NULL,
    requested_amount NUMERIC(14,2) NOT NULL,
    requested_tenure_months INTEGER NOT NULL,
    purpose TEXT,
    collateral_description TEXT,
    status application_status NOT NULL DEFAULT 'draft',
    rejection_reason TEXT,
    sent_back_reason TEXT,
    revision_count INTEGER NOT NULL DEFAULT 0,
    submitted_at TIMESTAMPTZ,
    last_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    decided_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_generate_application_number
    BEFORE INSERT ON loan_applications
    FOR EACH ROW
    WHEN (NEW.application_number IS NULL)
    EXECUTE FUNCTION generate_application_number();

CREATE INDEX idx_loan_applications_borrower_id ON loan_applications(borrower_id);
CREATE INDEX idx_loan_applications_product_id ON loan_applications(loan_product_id);
CREATE INDEX idx_loan_applications_officer_id ON loan_applications(assigned_officer_id);
CREATE INDEX idx_loan_applications_branch_id ON loan_applications(branch_id);
CREATE INDEX idx_loan_applications_status ON loan_applications(status);
CREATE INDEX idx_loan_applications_submitted_at ON loan_applications(submitted_at);

-- ============================================================================
-- 7. LOANS
-- ============================================================================

-- Auto-generate loan numbers: LMS-LN-000001
CREATE SEQUENCE loan_number_seq START 1;

CREATE OR REPLACE FUNCTION generate_loan_number()
RETURNS TRIGGER AS $$
BEGIN
    NEW.loan_number := 'LMS-LN-' || LPAD(nextval('loan_number_seq')::TEXT, 6, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE loans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL UNIQUE REFERENCES loan_applications(id) ON DELETE RESTRICT,
    borrower_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    loan_product_id UUID NOT NULL REFERENCES loan_products(id) ON DELETE RESTRICT,
    disbursed_by UUID REFERENCES staff_profiles(id) ON DELETE SET NULL,
    branch_id UUID REFERENCES branches(id) ON DELETE SET NULL,
    loan_number TEXT UNIQUE,
    principal_amount NUMERIC(14,2) NOT NULL,
    interest_rate NUMERIC(5,2) NOT NULL,
    interest_type interest_type NOT NULL DEFAULT 'reducing',
    tenure_months INTEGER NOT NULL,
    processing_fee NUMERIC(12,2) NOT NULL DEFAULT 0,
    total_payable NUMERIC(14,2) NOT NULL DEFAULT 0,
    disbursement_date DATE,
    first_emi_date DATE,
    maturity_date DATE,
    status loan_status NOT NULL DEFAULT 'active',
    outstanding_principal NUMERIC(14,2) NOT NULL DEFAULT 0,
    outstanding_interest NUMERIC(14,2) NOT NULL DEFAULT 0,
    total_overdue NUMERIC(14,2) NOT NULL DEFAULT 0,
    overdue_days INTEGER NOT NULL DEFAULT 0,
    bank_account_number TEXT,
    ifsc_code TEXT,
    disbursement_reference TEXT,
    repayment_mode payment_mode NOT NULL DEFAULT 'upi',
    npa_triggered_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_generate_loan_number
    BEFORE INSERT ON loans
    FOR EACH ROW
    WHEN (NEW.loan_number IS NULL)
    EXECUTE FUNCTION generate_loan_number();

CREATE INDEX idx_loans_borrower_id ON loans(borrower_id);
CREATE INDEX idx_loans_product_id ON loans(loan_product_id);
CREATE INDEX idx_loans_branch_id ON loans(branch_id);
CREATE INDEX idx_loans_status ON loans(status);
CREATE INDEX idx_loans_disbursement_date ON loans(disbursement_date);
CREATE INDEX idx_loans_maturity_date ON loans(maturity_date);

-- ============================================================================
-- 8. APPROVAL HISTORY
-- ============================================================================
CREATE TABLE approval_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES loan_applications(id) ON DELETE CASCADE,
    actor_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    from_status application_status,
    to_status application_status NOT NULL,
    action approval_action NOT NULL,
    remarks TEXT,
    approved_amount NUMERIC(14,2),
    approved_tenure_months INTEGER,
    approved_interest_rate NUMERIC(5,2),
    actioned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ip_address TEXT
);

CREATE INDEX idx_approval_history_application_id ON approval_history(application_id);
CREATE INDEX idx_approval_history_actor_id ON approval_history(actor_id);

-- ============================================================================
-- 9. EMI SCHEDULE
-- ============================================================================
CREATE TABLE emi_schedule (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id UUID NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
    installment_number INTEGER NOT NULL,
    due_date DATE NOT NULL,
    opening_balance NUMERIC(14,2) NOT NULL DEFAULT 0,
    principal_component NUMERIC(14,2) NOT NULL DEFAULT 0,
    interest_component NUMERIC(14,2) NOT NULL DEFAULT 0,
    total_emi NUMERIC(14,2) NOT NULL DEFAULT 0,
    penalty_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    penalty_days INTEGER NOT NULL DEFAULT 0,
    closing_balance NUMERIC(14,2) NOT NULL DEFAULT 0,
    status emi_status NOT NULL DEFAULT 'upcoming',
    paid_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(loan_id, installment_number)
);

CREATE INDEX idx_emi_schedule_loan_id ON emi_schedule(loan_id);
CREATE INDEX idx_emi_schedule_due_date ON emi_schedule(due_date);
CREATE INDEX idx_emi_schedule_status ON emi_schedule(status);

-- ============================================================================
-- 10. PAYMENTS
-- ============================================================================
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id UUID NOT NULL REFERENCES loans(id) ON DELETE RESTRICT,
    emi_id UUID REFERENCES emi_schedule(id) ON DELETE SET NULL,
    collected_by UUID REFERENCES users(id) ON DELETE SET NULL,
    amount_paid NUMERIC(14,2) NOT NULL,
    principal_paid NUMERIC(14,2) NOT NULL DEFAULT 0,
    interest_paid NUMERIC(14,2) NOT NULL DEFAULT 0,
    penalty_paid NUMERIC(12,2) NOT NULL DEFAULT 0,
    excess_paid NUMERIC(12,2) NOT NULL DEFAULT 0,
    payment_mode payment_mode NOT NULL,
    razorpay_order_id TEXT,
    razorpay_payment_id TEXT,
    razorpay_signature TEXT,
    upi_transaction_id TEXT,
    cheque_number TEXT,
    bank_reference TEXT,
    status payment_status NOT NULL DEFAULT 'initiated',
    failure_reason TEXT,
    initiated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    confirmed_at TIMESTAMPTZ
);

CREATE INDEX idx_payments_loan_id ON payments(loan_id);
CREATE INDEX idx_payments_emi_id ON payments(emi_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_initiated_at ON payments(initiated_at);

-- ============================================================================
-- 11. LOAN RESTRUCTURES
-- ============================================================================
CREATE TABLE loan_restructures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    original_loan_id UUID NOT NULL REFERENCES loans(id) ON DELETE RESTRICT,
    approved_by UUID REFERENCES users(id) ON DELETE SET NULL,
    reason TEXT NOT NULL,
    waived_penalty NUMERIC(12,2) NOT NULL DEFAULT 0,
    revised_interest_rate NUMERIC(5,2),
    revised_tenure_months INTEGER,
    revised_first_emi_date DATE,
    status restructure_status NOT NULL DEFAULT 'requested',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    approved_at TIMESTAMPTZ
);

CREATE INDEX idx_loan_restructures_loan_id ON loan_restructures(original_loan_id);
CREATE INDEX idx_loan_restructures_status ON loan_restructures(status);

-- ============================================================================
-- 12. DOCUMENTS
-- ============================================================================
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    owner_type TEXT NOT NULL CHECK (owner_type IN ('borrower', 'application')),
    application_id UUID REFERENCES loan_applications(id) ON DELETE SET NULL,
    document_type TEXT NOT NULL,
    category document_category NOT NULL DEFAULT 'other',
    file_name TEXT NOT NULL,
    file_url TEXT,
    storage_bucket TEXT,
    storage_path TEXT,
    file_size_bytes BIGINT,
    mime_type TEXT,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    rejection_reason TEXT,
    verified_by UUID REFERENCES users(id) ON DELETE SET NULL,
    verified_at TIMESTAMPTZ,
    expiry_date DATE,
    is_expired BOOLEAN NOT NULL DEFAULT FALSE,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_documents_owner_id ON documents(owner_id);
CREATE INDEX idx_documents_application_id ON documents(application_id);
CREATE INDEX idx_documents_category ON documents(category);
CREATE INDEX idx_documents_is_verified ON documents(is_verified);

-- ============================================================================
-- 13. COLLATERAL
-- ============================================================================
CREATE TABLE collateral (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES loan_applications(id) ON DELETE CASCADE,
    loan_id UUID REFERENCES loans(id) ON DELETE SET NULL,
    collateral_type TEXT NOT NULL,
    description TEXT,
    estimated_value NUMERIC(14,2) NOT NULL DEFAULT 0,
    appraised_value NUMERIC(14,2),
    appraiser_name TEXT,
    appraiser_license TEXT,
    appraisal_date DATE,
    custody_reference TEXT,
    status collateral_status NOT NULL DEFAULT 'submitted',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_collateral_application_id ON collateral(application_id);
CREATE INDEX idx_collateral_loan_id ON collateral(loan_id);
CREATE INDEX idx_collateral_status ON collateral(status);

-- ============================================================================
-- 14. CREDIT CHECKS
-- ============================================================================
CREATE TABLE credit_checks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    borrower_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    application_id UUID REFERENCES loan_applications(id) ON DELETE SET NULL,
    bureau_name credit_bureau NOT NULL,
    score INTEGER,
    report_reference TEXT,
    report_summary JSONB DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'expired')),
    pulled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until DATE
);

CREATE INDEX idx_credit_checks_borrower_id ON credit_checks(borrower_id);
CREATE INDEX idx_credit_checks_application_id ON credit_checks(application_id);

-- ============================================================================
-- 15. MESSAGES
-- ============================================================================
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES loan_applications(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    content TEXT NOT NULL,
    message_type message_type NOT NULL DEFAULT 'text',
    attachment_url TEXT,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_deleted_by_sender BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted_by_receiver BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_messages_application_id ON messages(application_id);
CREATE INDEX idx_messages_sender_id ON messages(sender_id);
CREATE INDEX idx_messages_receiver_id ON messages(receiver_id);
CREATE INDEX idx_messages_sent_at ON messages(sent_at);

-- ============================================================================
-- 16. NOTIFICATIONS
-- ============================================================================
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reference_id UUID,
    reference_type TEXT,
    type notification_type NOT NULL DEFAULT 'general',
    title TEXT NOT NULL,
    body TEXT,
    payload JSONB DEFAULT '{}',
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    push_sent BOOLEAN NOT NULL DEFAULT FALSE,
    push_status TEXT,
    apns_message_id TEXT,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at TIMESTAMPTZ
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_sent_at ON notifications(sent_at);

-- ============================================================================
-- 17. AUDIT LOG
-- ============================================================================
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    actor_role user_role,
    table_name TEXT NOT NULL,
    record_id UUID,
    action TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_value JSONB,
    new_value JSONB,
    change_summary TEXT,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_log_actor_id ON audit_log(actor_id);
CREATE INDEX idx_audit_log_table_name ON audit_log(table_name);
CREATE INDEX idx_audit_log_record_id ON audit_log(record_id);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at);

-- ============================================================================
-- 18. SYSTEM CONFIGS
-- ============================================================================
CREATE TABLE system_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_key TEXT NOT NULL UNIQUE,
    config_value TEXT,
    value_type TEXT NOT NULL DEFAULT 'string' CHECK (value_type IN ('string', 'number', 'boolean', 'json')),
    description TEXT,
    is_editable BOOLEAN NOT NULL DEFAULT TRUE,
    last_updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_system_configs_key ON system_configs(config_key);

-- ============================================================================
-- AUTO-UPDATE updated_at TRIGGER
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_branches_updated_at BEFORE UPDATE ON branches FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_borrower_profiles_updated_at BEFORE UPDATE ON borrower_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_staff_profiles_updated_at BEFORE UPDATE ON staff_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_loan_products_updated_at BEFORE UPDATE ON loan_products FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_loans_updated_at BEFORE UPDATE ON loans FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_emi_schedule_updated_at BEFORE UPDATE ON emi_schedule FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_collateral_updated_at BEFORE UPDATE ON collateral FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- AUTO-CREATE USER PROFILE ON AUTH SIGNUP
-- ============================================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, full_name, email, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        NEW.email,
        COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'borrower')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();
