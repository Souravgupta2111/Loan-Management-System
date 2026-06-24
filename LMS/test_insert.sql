-- Insert a dummy user to see the exact error
INSERT INTO public.users (id, full_name, email, role)
VALUES (
    'a230114d-e50b-4821-a121-87492504804c', -- id from the dropped test
    'Test Name',
    'test.debug.dropped@gmail.com',
    'borrower'::user_role
);
