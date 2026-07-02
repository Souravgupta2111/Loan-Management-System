-- Allow borrowers to update their loan applications when in pending_acceptance status
-- This allows them to accept or reject the disbursement terms.
CREATE POLICY "Borrower can accept or reject approved applications" ON loan_applications
    FOR UPDATE USING (borrower_id = auth.uid() AND status = 'pending_acceptance')
    WITH CHECK (borrower_id = auth.uid());
