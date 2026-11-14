-- Create your admin user in Supabase Authentication > Users first.
-- Replace the email below, then run this script in SQL Editor.
insert into public.admins(user_id)
select id from auth.users where lower(email)=lower('YOUR_ADMIN_EMAIL@example.com')
on conflict (user_id) do nothing;
insert into public.profiles(id,email,role)
select id,email,'admin' from auth.users where lower(email)=lower('YOUR_ADMIN_EMAIL@example.com')
on conflict (id) do update set role='admin';
