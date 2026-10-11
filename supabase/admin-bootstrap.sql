-- One-time admin registration step.
-- 1. Create a user in Supabase Dashboard > Authentication > Users (email/password).
-- 2. Replace the example email below and run this SQL in SQL Editor.
-- 3. Then sign in to ../admin/index.html with that user's credentials.
-- Do not expose a service_role or secret key in the app or admin HTML.

insert into public.video_admins (user_id)
select id
from auth.users
where lower(email) = lower('YOUR_ADMIN_EMAIL@example.com')
on conflict (user_id) do nothing;

-- Verify the registration:
select a.user_id, u.email, a.created_at
from public.video_admins a
join auth.users u on u.id = a.user_id;
