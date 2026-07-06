-- ============================================================================
-- LMS Staff Migration V2
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ============================================================================

-- ============================================================================
-- 1. NOTIFICATION TEMPLATES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS notification_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_name TEXT NOT NULL UNIQUE,
    template_text TEXT NOT NULL,
    description TEXT,
    supported_placeholders TEXT[] DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Seed default templates
INSERT INTO notification_templates (event_name, template_text, description, supported_placeholders) VALUES
('loan_approved', 'Dear {{borrower_name}}, congratulations! Your application for INR {{amount}} has been approved.', 'Sent when manager approves application terms', ARRAY['{{borrower_name}}', '{{amount}}']),
('payment_reminder', 'Dear {{borrower_name}}, this is a friendly reminder that your EMI installment is due on {{due_date}}.', 'Sent 3 days prior to monthly EMI installment due date', ARRAY['{{borrower_name}}', '{{due_date}}']),
('document_requested', 'Dear {{borrower_name}}, a loan officer has requested additional files for your review.', 'Sent when officer flags files requirements missing', ARRAY['{{borrower_name}}']),
('loan_rejected', 'Dear {{borrower_name}}, we regret to inform you that your loan application has been rejected. Reason: {{reason}}.', 'Sent when application is rejected by officer or manager', ARRAY['{{borrower_name}}', '{{reason}}']),
('loan_disbursed', 'Dear {{borrower_name}}, your loan of INR {{amount}} has been successfully disbursed to your bank account.', 'Sent after successful loan disbursement', ARRAY['{{borrower_name}}', '{{amount}}']),
('emi_overdue', 'Dear {{borrower_name}}, your EMI payment of INR {{amount}} due on {{due_date}} is overdue. Please pay immediately to avoid penalties.', 'Sent when EMI payment is overdue', ARRAY['{{borrower_name}}', '{{amount}}', '{{due_date}}']),
('kyc_verified', 'Dear {{borrower_name}}, your KYC verification has been completed successfully. You can now apply for loans.', 'Sent when KYC is verified by officer', ARRAY['{{borrower_name}}']),
('kyc_rejected', 'Dear {{borrower_name}}, your KYC document {{document_name}} has been rejected. Please resubmit.', 'Sent when KYC document is rejected', ARRAY['{{borrower_name}}', '{{document_name}}']),
('application_sent_back', 'Dear {{borrower_name}}, your application requires attention. Please review the remarks and resubmit.', 'Sent when application is sent back for revision', ARRAY['{{borrower_name}}'])
ON CONFLICT (event_name) DO NOTHING;

-- RLS for notification_templates
ALTER TABLE notification_templates ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='notification_templates' AND policyname='Staff can read templates') THEN
        CREATE POLICY "Staff can read templates" ON notification_templates FOR SELECT USING (is_staff());
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='notification_templates' AND policyname='Admin can manage templates') THEN
        CREATE POLICY "Admin can manage templates" ON notification_templates FOR ALL USING (is_admin());
    END IF;
END $$;

-- ============================================================================
-- 2. RLS POLICIES FOR LOAN PRODUCTS
-- ============================================================================
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='loan_products' AND policyname='Admin can manage products') THEN
        CREATE POLICY "Admin can manage products" ON loan_products FOR ALL USING (is_admin());
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='loan_products' AND policyname='Manager can update products') THEN
        CREATE POLICY "Manager can update products" ON loan_products FOR UPDATE USING (
            EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'manager')
        );
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='loan_products' AND policyname='Anyone can read active products') THEN
        CREATE POLICY "Anyone can read active products" ON loan_products FOR SELECT USING (true);
    END IF;
END $$;

-- ============================================================================
-- 3. RLS POLICIES FOR MESSAGES
-- ============================================================================
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='messages' AND policyname='Users can read own messages') THEN
        CREATE POLICY "Users can read own messages" ON messages FOR SELECT USING (
            sender_id = auth.uid() OR receiver_id = auth.uid() OR is_staff()
        );
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='messages' AND policyname='Users can send messages') THEN
        CREATE POLICY "Users can send messages" ON messages FOR INSERT WITH CHECK (
            sender_id = auth.uid()
        );
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='messages' AND policyname='Users can update own messages') THEN
        CREATE POLICY "Users can update own messages" ON messages FOR UPDATE USING (
            sender_id = auth.uid() OR receiver_id = auth.uid() OR is_staff()
        );
    END IF;
END $$;

-- ============================================================================
-- DONE: Run this in Supabase SQL Editor before testing the app.
-- ============================================================================
