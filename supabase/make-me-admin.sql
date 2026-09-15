-- हे Supabase SQL Editor मध्ये एकदा चालव — तुझं account पहिला Admin बनेल
insert into platform_admins (user_id)
select id from auth.users where email = 'abhinaygandhi5151@gmail.com'
on conflict (user_id) do nothing;

-- खात्री करण्यासाठी (optional) — हे चालवून बघ, एक रो दिसायला हवा
select p.username, p.id
from platform_admins pa
join profiles p on p.id = pa.user_id;
