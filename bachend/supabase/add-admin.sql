-- Make an account an admin of the Spilver menu.
--
-- 1. First create the account: Supabase dashboard > Authentication > Users > Add user > Create new user
--    (your email, a password you choose yourself, and tick "Auto Confirm User").
-- 2. Replace the email below with that same email, then run this file in the SQL Editor.

insert into public.admins (user_id)
select id from auth.users where email = 'YOUR-EMAIL@example.com'
on conflict (user_id) do nothing;

-- Check: this should list your email. If it comes back empty, the email above does not match the account.
select u.email, a.created_at as admin_since
from public.admins a
join auth.users u on u.id = a.user_id;
