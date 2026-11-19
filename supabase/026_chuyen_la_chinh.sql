-- 026: Chuyến là dữ liệu chính, nhóm chỉ là THƯ MỤC.
--   - Thư mục hệ thống "Chưa xếp nhóm" (uuid cố định) chứa chuyến không thuộc nhóm nào; không có mã nhóm, không xoá được.
--   - Xoá nhóm: các chuyến trong nhóm được CHUYỂN sang "Chưa xếp nhóm", không bị xoá nữa.
--   - move_trip(tid, gid): Thủ quỹ (hoặc quản trị) chuyển chuyến sang thư mục khác.
--   - my_trips(): danh sách mọi chuyến tôi xem được, kèm thư mục.
--   - admin_delete_account(email): quản trị viên xoá tài khoản (chuyến không mất); created_by / updated_by không còn chặn việc xoá.
-- Quay lại: drop function public.my_trips(), public.move_trip(text,uuid), public.admin_delete_account(text); khôi phục delete_group / can_create_trip / can_view_trip bản 024/023 và xoá nhóm hệ thống.

do $$
declare adm uuid; c record;
begin
  select user_id into adm from public.platform_admins limit 1;
  insert into public.groups(id, name, created_by) values ('00000000-0000-0000-0000-000000000001', 'Chưa xếp nhóm', adm) on conflict (id) do nothing;
  -- created_by, updated_by: không chặn việc xoá tài khoản
  alter table public.groups alter column created_by drop not null;
  for c in select conname, conrelid::regclass as t from pg_constraint where contype = 'f' and connamespace = 'public'::regnamespace
      and confrelid = 'auth.users'::regclass and ((conrelid = 'public.groups'::regclass and conkey = array[(select attnum from pg_attribute where attrelid='public.groups'::regclass and attname='created_by')])
      or (conrelid = 'public.trips'::regclass and conkey = array[(select attnum from pg_attribute where attrelid='public.trips'::regclass and attname='updated_by')])) loop
    execute format('alter table %s drop constraint %I', c.t, c.conname);
    execute format('alter table %s add constraint %I foreign key (%s) references auth.users(id) on delete set null', c.t, c.conname,
      case when c.t::text = 'groups' then 'created_by' else 'updated_by' end);
  end loop;
end $$;

-- thư mục hệ thống không được có mã xem nhóm
update public.group_view_codes set enabled = false where group_id = '00000000-0000-0000-0000-000000000001';

create or replace function public.can_view_trip(tid text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.can_edit_trip(tid)
    or exists (select 1 from public.code_access a join public.trip_codes c on c.trip_id = a.target
               where a.user_id = auth.uid() and a.kind = 'trip' and a.target = tid and a.ver = c.ver and c.enabled and c.expires_at > now())
    or exists (select 1 from public.trips t
               join public.group_view_codes g on g.group_id = t.group_id
               join public.code_access a on a.kind = 'group' and a.target = t.group_id::text and a.user_id = auth.uid() and a.ver = g.ver
               where t.id = tid and t.group_id <> '00000000-0000-0000-0000-000000000001' and not t.hide_in_group and not t.deleted and g.enabled and g.expires_at > now()) $$;

create or replace function public.can_create_trip(gid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or public.is_organizer(gid)
    or (gid = '00000000-0000-0000-0000-000000000001' and exists (select 1 from public.group_organizers o where o.email = public.my_email()))
    or exists (select 1 from public.trips t join public.trip_roles r on r.trip_id = t.id
               where t.group_id = gid and not t.deleted and r.role = 'leader' and r.email = public.my_email()) $$;

create or replace function public.delete_group(gid uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if gid = '00000000-0000-0000-0000-000000000001' then raise exception 'system_group'; end if;
  if not public.can_manage(gid) then raise exception 'forbidden'; end if;
  if not exists (select 1 from public.groups where id = gid and deleted_at is null) then raise exception 'not_found'; end if;
  update public.trips set group_id = '00000000-0000-0000-0000-000000000001', rev = rev + 1 where group_id = gid;
  update public.trip_shares set group_id = '00000000-0000-0000-0000-000000000001' where group_id = gid;
  update public.groups set deleted_at = now(), deleted_by = public.my_email() where id = gid;
end $$;

create or replace function public.my_trips()
returns table(id text, name text, closed boolean, role text, group_id uuid, group_name text, updated_at timestamptz)
language sql stable security definer set search_path = public as $$
  select t.id, coalesce(nullif(t.data ->> 'name', ''), '(chưa đặt tên)'), t.closed_at is not null,
    case when exists (select 1 from public.trip_roles r where r.trip_id = t.id and r.email = public.my_email() and r.role = 'leader') then 'leader'
         when exists (select 1 from public.trip_roles r where r.trip_id = t.id and r.email = public.my_email()) then 'helper'
         when public.is_admin() then 'admin' else 'viewer' end,
    t.group_id, g.name, t.updated_at
  from public.trips t join public.groups g on g.id = t.group_id
  where not t.deleted and g.deleted_at is null and public.can_view_trip(t.id)
  order by (t.group_id = '00000000-0000-0000-0000-000000000001'), g.name, t.updated_at desc $$;

create or replace function public.move_trip(tid text, gid uuid)
returns void language plpgsql security definer set search_path = public as $$
declare old uuid; gn text; ogn text;
begin
  select group_id into old from public.trips where id = tid and not deleted for update;
  if old is null or not public.can_lead_trip(tid) then raise exception 'forbidden'; end if;
  select name into gn from public.groups where id = gid and deleted_at is null;
  if gn is null then raise exception 'not_found'; end if;
  if gid <> '00000000-0000-0000-0000-000000000001' and not (public.is_admin() or public.can_see_group(gid)) then raise exception 'forbidden'; end if;
  if gid = old then return; end if;
  update public.trips set group_id = gid, rev = rev + 1 where id = tid;
  update public.trip_shares set group_id = gid where trip_id = tid;
  select name into ogn from public.groups where id = old;
  perform public.log_event('move', 'trip', gid, gn, tid, (select data ->> 'name' from public.trips where id = tid), jsonb_build_object('from', ogn, 'to', gn));
end $$;

create or replace function public.admin_delete_account(p_email text)
returns void language plpgsql security definer set search_path = public, auth as $$
declare em text := lower(btrim(coalesce(p_email,''))); uid uuid;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  select u.id into uid from auth.users u where lower(u.email) = em;
  if uid is null then raise exception 'not_found'; end if;
  if uid = auth.uid() then raise exception 'self'; end if;
  if exists (select 1 from public.platform_admins where user_id = uid) then raise exception 'is_admin'; end if;
  delete from public.trip_roles where lower(email) = em;
  delete from public.group_organizers where lower(email) = em;
  delete from public.user_quotas where lower(email) = em;
  delete from auth.users where id = uid;
end $$;

revoke all on function public.my_trips() from public, anon;
revoke all on function public.move_trip(text,uuid) from public, anon;
revoke all on function public.admin_delete_account(text) from public, anon;
grant execute on function public.my_trips() to authenticated;
grant execute on function public.move_trip(text,uuid) to authenticated;
grant execute on function public.admin_delete_account(text) to authenticated;
