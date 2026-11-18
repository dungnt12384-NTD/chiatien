-- 008: Quản lý tài khoản cho quản trị viên (chạy sau 007)
--   admin_accounts()                 : danh sách tài khoản email (bỏ phiên ẩn danh) kèm quyền
--   admin_set_admin_email(email,bool): thêm / gỡ quản trị viên theo email (email chưa đăng nhập lần nào vẫn thêm được)
-- Chỉ thêm hàm mới, không đổi bảng, không xoá dữ liệu. Quay lại: drop 2 hàm này.

create or replace function public.admin_accounts()
returns table(email text, created_at timestamptz, last_sign_in_at timestamptz,
              is_admin boolean, organizer_of text[], trip_roles integer, is_me boolean)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query
  with em as (
    select lower(u.email) as e from auth.users u
      where u.email is not null and not coalesce(u.is_anonymous, false)
    union select lower(a.email) from public.admin_emails a
    union select lower(p.email) from public.platform_admins p where p.email is not null
    union select lower(o.email) from public.group_organizers o
  )
  select em.e,
         u.created_at,
         u.last_sign_in_at,
         (exists (select 1 from public.admin_emails a where lower(a.email) = em.e)
           or exists (select 1 from public.platform_admins p where lower(p.email) = em.e or p.user_id = u.id)),
         coalesce((select array_agg(g.name order by g.name) from public.group_organizers o
                     join public.groups g on g.id = o.group_id where lower(o.email) = em.e), '{}'::text[]),
         (select count(*)::integer from public.trip_roles r where lower(r.email) = em.e),
         em.e = public.my_email()
  from em
  left join lateral (select x.id, x.created_at, x.last_sign_in_at from auth.users x
                     where lower(x.email) = em.e and not coalesce(x.is_anonymous, false)
                     order by x.created_at limit 1) u on true
  order by 4 desc, u.last_sign_in_at desc nulls last, em.e;
end $$;

create or replace function public.admin_set_admin_email(p_email text, on_off boolean) returns void
language plpgsql security definer set search_path = public, auth as $$
declare e text := lower(btrim(coalesce(p_email, ''))); n integer;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if e !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'bad_email'; end if;
  if on_off then
    insert into public.admin_emails(email) values (e) on conflict do nothing;
  else
    if e = public.my_email() then raise exception 'self'; end if;
    select count(*) into n from (
      select lower(email) x from public.admin_emails
      union select lower(email) from public.platform_admins where email is not null) s
      where s.x <> e;
    if n < 1 then raise exception 'last_admin'; end if;
    delete from public.admin_emails where lower(email) = e;
    delete from public.platform_admins p where lower(p.email) = e
      or p.user_id in (select id from auth.users where lower(email) = e);
  end if;
  perform public.log_event(case when on_off then 'add' else 'remove' end, 'admin', null, null, e, e, null);
end $$;

revoke all on function public.admin_accounts() from public, anon;
revoke all on function public.admin_set_admin_email(text, boolean) from public, anon;
grant execute on function public.admin_accounts() to authenticated;
grant execute on function public.admin_set_admin_email(text, boolean) to authenticated;
