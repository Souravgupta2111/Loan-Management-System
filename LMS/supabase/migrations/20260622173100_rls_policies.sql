-- ============================================================================
-- Row Level Security Policies
-- Strategy: Email-only auth, role-based access
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE borrower_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE loan_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE loan_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE approval_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE emi_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE loan_restructures ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE collateral ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_configs ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- Helper function: get current user's role
-- ============================================================================
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS user_role AS $$
    SELECT role FROM users WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Helper: check if user is staff (officer, manager, admin)
CREATE OR REPLACE FUNCTION is_staff()
RETURNS BOOLEAN AS $$
    SELECT get_user_role() IN ('officer', 'manager', 'admin');
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Helper: check if user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
    SELECT get_user_role() = 'admin';
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Helper: check if user is manager or admin
CREATE OR REPLACE FUNCTION is_manager_or_admin()
RETURNS BOOLEAN AS $$
    SELECT get_user_role() IN ('manager', 'admin');
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================================================
-- USERS
-- ============================================================================
CREATE POLICY "Users can read own row" ON users
    FOR SELECT USING (id = auth.uid());

CREATE POLICY "Staff can read all users" ON users
    FOR SELECT USING (is_staff());

CREATE POLICY "Users can update own row" ON users
    FOR UPDATE USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

CREATE POLICY "Admins can manage users" ON users
    FOR ALL USING (is_admin());

-- ============================================================================
-- BRANCHES
-- ============================================================================
CREATE POLICY "Authenticated users can read branches" ON branches
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can manage branches" ON branches
    FOR ALL USING (is_admin());

-- ============================================================================
-- BORROWER PROFILES
-- ============================================================================
CREATE POLICY "Borrower can read own profile" ON borrower_profiles
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Staff can read all borrower profiles" ON borrower_profiles
    FOR SELECT USING (is_staff());

CREATE POLICY "Borrower can insert own profile" ON borrower_profiles
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Borrower can update own profile" ON borrower_profiles
    FOR UPDATE USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Staff can update borrower profiles" ON borrower_profiles
    FOR UPDATE USING (is_staff());

-- ============================================================================
-- STAFF PROFILES
-- ============================================================================
CREATE POLICY "Staff can read own profile" ON staff_profiles
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Staff can read all staff profiles" ON staff_profiles
    FOR SELECT USING (is_staff());

CREATE POLICY "Admins can manage staff profiles" ON staff_profiles
    FOR ALL USING (is_admin());

-- ============================================================================
-- LOAN PRODUCTS
-- ============================================================================
CREATE POLICY "Authenticated users can read active products" ON loan_products
    FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = TRUE);

CREATE POLICY "Staff can read all products" ON loan_products
    FOR SELECT USING (is_staff());

CREATE POLICY "Admins can manage loan products" ON loan_products
    FOR ALL USING (is_admin());

CREATE POLICY "Managers can manage loan products" ON loan_products
    FOR ALL USING (is_manager_or_admin());

-- ============================================================================
-- LOAN APPLICATIONS
-- ============================================================================
CREATE POLICY "Borrower can read own applications" ON loan_applications
    FOR SELECT USING (borrower_id = auth.uid());

CREATE POLICY "Borrower can insert own application" ON loan_applications
    FOR INSERT WITH CHECK (borrower_id = auth.uid());

CREATE POLICY "Borrower can update own draft applications" ON loan_applications
    FOR UPDATE USING (borrower_id = auth.uid() AND status = 'draft')
    WITH CHECK (borrower_id = auth.uid());

CREATE POLICY "Staff can read all applications" ON loan_applications
    FOR SELECT USING (is_staff());

CREATE POLICY "Staff can update applications" ON loan_applications
    FOR UPDATE USING (is_staff());

-- ============================================================================
-- LOANS
-- ============================================================================
CREATE POLICY "Borrower can read own loans" ON loans
    FOR SELECT USING (borrower_id = auth.uid());

CREATE POLICY "Staff can read all loans" ON loans
    FOR SELECT USING (is_staff());

CREATE POLICY "Staff can manage loans" ON loans
    FOR ALL USING (is_staff());

-- ============================================================================
-- APPROVAL HISTORY
-- ============================================================================
CREATE POLICY "Borrower can read own application approvals" ON approval_history
    FOR SELECT USING (
        application_id IN (
            SELECT id FROM loan_applications WHERE borrower_id = auth.uid()
        )
    );

CREATE POLICY "Staff can read all approval history" ON approval_history
    FOR SELECT USING (is_staff());

CREATE POLICY "Staff can insert approval actions" ON approval_history
    FOR INSERT WITH CHECK (is_staff() AND actor_id = auth.uid());

-- ============================================================================
-- EMI SCHEDULE
-- ============================================================================
CREATE POLICY "Borrower can read own EMI schedule" ON emi_schedule
    FOR SELECT USING (
        loan_id IN (SELECT id FROM loans WHERE borrower_id = auth.uid())
    );

CREATE POLICY "Staff can read all EMI schedules" ON emi_schedule
    FOR SELECT USING (is_staff());

CREATE POLICY "Staff can manage EMI schedules" ON emi_schedule
    FOR ALL USING (is_staff());

-- ============================================================================
-- PAYMENTS
-- ============================================================================
CREATE POLICY "Borrower can read own payments" ON payments
    FOR SELECT USING (
        loan_id IN (SELECT id FROM loans WHERE borrower_id = auth.uid())
    );

CREATE POLICY "Borrower can initiate payments" ON payments
    FOR INSERT WITH CHECK (
        loan_id IN (SELECT id FROM loans WHERE borrower_id = auth.uid())
    );

CREATE POLICY "Staff can read all payments" ON payments
    FOR SELECT USING (is_staff());

CREATE POLICY "Staff can manage payments" ON payments
    FOR ALL USING (is_staff());

-- ============================================================================
-- LOAN RESTRUCTURES
-- ============================================================================
CREATE POLICY "Borrower can read own restructures" ON loan_restructures
    FOR SELECT USING (
        original_loan_id IN (SELECT id FROM loans WHERE borrower_id = auth.uid())
    );

CREATE POLICY "Staff can manage restructures" ON loan_restructures
    FOR ALL USING (is_staff());

-- ============================================================================
-- DOCUMENTS
-- ============================================================================
CREATE POLICY "Owner can read own documents" ON documents
    FOR SELECT USING (owner_id = auth.uid());

CREATE POLICY "Owner can upload documents" ON documents
    FOR INSERT WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Staff can read all documents" ON documents
    FOR SELECT USING (is_staff());

CREATE POLICY "Staff can verify documents" ON documents
    FOR UPDATE USING (is_staff());

-- ============================================================================
-- COLLATERAL
-- ============================================================================
CREATE POLICY "Borrower can read own collateral" ON collateral
    FOR SELECT USING (
        application_id IN (
            SELECT id FROM loan_applications WHERE borrower_id = auth.uid()
        )
    );

CREATE POLICY "Staff can manage collateral" ON collateral
    FOR ALL USING (is_staff());

-- ============================================================================
-- CREDIT CHECKS
-- ============================================================================
CREATE POLICY "Borrower can read own credit checks" ON credit_checks
    FOR SELECT USING (borrower_id = auth.uid());

CREATE POLICY "Staff can manage credit checks" ON credit_checks
    FOR ALL USING (is_staff());

-- ============================================================================
-- MESSAGES
-- ============================================================================
CREATE POLICY "User can read own messages" ON messages
    FOR SELECT USING (
        sender_id = auth.uid() OR receiver_id = auth.uid()
    );

CREATE POLICY "User can send messages" ON messages
    FOR INSERT WITH CHECK (sender_id = auth.uid());

CREATE POLICY "User can update own messages (mark read/delete)" ON messages
    FOR UPDATE USING (
        sender_id = auth.uid() OR receiver_id = auth.uid()
    );

-- ============================================================================
-- NOTIFICATIONS
-- ============================================================================
CREATE POLICY "User can read own notifications" ON notifications
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "User can update own notifications (mark read)" ON notifications
    FOR UPDATE USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Staff can insert notifications" ON notifications
    FOR INSERT WITH CHECK (is_staff());

-- ============================================================================
-- AUDIT LOG
-- ============================================================================
CREATE POLICY "Managers and admins can read audit log" ON audit_log
    FOR SELECT USING (is_manager_or_admin());

CREATE POLICY "System can insert audit log" ON audit_log
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- ============================================================================
-- SYSTEM CONFIGS
-- ============================================================================
CREATE POLICY "Authenticated users can read system configs" ON system_configs
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can manage system configs" ON system_configs
    FOR ALL USING (is_admin());
