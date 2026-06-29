-- Add unique constraints to prevent duplicate PAN and Aadhaar usage
ALTER TABLE borrower_profiles
ADD CONSTRAINT unique_pan_number UNIQUE (pan_number);

ALTER TABLE borrower_profiles
ADD CONSTRAINT unique_aadhaar_number UNIQUE (aadhaar_number);

-- Create a security definer function to check if identity is already in use by another user
CREATE OR REPLACE FUNCTION check_identity_in_use(p_pan TEXT, p_aadhaar TEXT, p_user_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pan_in_use BOOLEAN := false;
    v_aadhaar_in_use BOOLEAN := false;
BEGIN
    IF p_pan IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM borrower_profiles 
            WHERE pan_number = p_pan 
            AND user_id != p_user_id
        ) INTO v_pan_in_use;
    END IF;
    
    IF p_aadhaar IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM borrower_profiles 
            WHERE aadhaar_number = p_aadhaar 
            AND user_id != p_user_id
        ) INTO v_aadhaar_in_use;
    END IF;
    
    RETURN json_build_object(
        'pan_in_use', v_pan_in_use,
        'aadhaar_in_use', v_aadhaar_in_use
    );
END;
$$;
