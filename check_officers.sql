-- Query to check if there are any active officers in the database.
-- Run this in the Supabase SQL Editor.

SELECT 
    u.id as user_id, 
    u.full_name, 
    u.role, 
    u.is_active, 
    sp.id as staff_profile_id, 
    sp.branch_id
FROM users u
LEFT JOIN staff_profiles sp ON u.id = sp.user_id
WHERE u.role = 'officer';
