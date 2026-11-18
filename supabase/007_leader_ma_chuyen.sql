-- 007: Mô hình quyền mới (chạy sau 006)
--   Quản trị viên  : toàn hệ thống (bảng platform_admins hoặc admin_emails)
--   Người tổ chức  : theo nhóm, do quản trị viên mời/duyệt, được tạo chuyến trong nhóm
--   Leader chính   : theo chuyến (nhiều người, ngang quyền)
--   Người phụ trách: theo chuyến, nhập liệu ở các tab được leader cấp
--   Thành viên     : vào bằng mã chuyến (hoặc mã nhóm nếu bật), chỉ xem, không cần tài khoản (phiên ẩn danh)
--   Public         : link xem công khai, chỉ Tổng kết và Báo cáo
-- Mã và link hết hạn sau 3 tháng. Dữ liệu chuyến giữ mãi.

-- ================= bảng =================
create table if not exists public.admin_emails(email text primary key);
-- Email quản trị viên được thêm trực tiếp trên cơ sở dữ liệu (không ghi vào kho công khai):
--   insert into public.admin_emails(email) values ('<email>') on conflict do nothing;

create table if not exists public.group_organizers(
  group_id uuid not null references public.groups(id) on delete cascade,
  email text not null, added_by text, added_at timestamptz not null default now(),
  primary key (group_id, email));
create table if not exists public.organizer_requests(
  email text primary key, user_id uuid, note text, at timestamptz not null default now());
create table if not exists public.trip_roles(
  trip_id text not null references public.trips(id) on delete cascade,
  email text not null, role text not null check (role in ('leader','helper')),
  tabs text[] not null default '{expense}', added_by text, added_at timestamptz not null default now(),
  primary key (trip_id, email));
create table if not exists public.trip_codes(
  trip_id text primary key references public.trips(id) on delete cascade,
  code text not null unique, enabled boolean not null default true,
  expires_at timestamptz not null default now() + interval '3 months', ver integer not null default 1);
create table if not exists public.group_view_codes(
  group_id uuid primary key references public.groups(id) on delete cascade,
  code text not null unique, enabled boolean not null default false,
  expires_at timestamptz not null default now() + interval '3 months', ver integer not null default 1);
create table if not exists public.code_access(
  user_id uuid not null, kind text not null check (kind in ('trip','group')), target text not null,
  ver integer not null, at timestamptz not null default now(), primary key (user_id, kind, target));
create table if not exists public.code_attempts(id bigserial primary key, user_id uuid, ok boolean not null, at timestamptz not null default now());
create index if not exists code_attempts_at on public.code_attempts(at desc);
create table if not exists public.trip_reports(
  id bigserial primary key, trip_id text not null references public.trips(id) on delete cascade,
  item_id text, item_label text, message text not null check (length(message) between 1 and 1000),
  reporter text, user_id uuid default auth.uid(), at timestamptz not null default now(),
  resolved_at timestamptz, resolved_by text, reply text);
create table if not exists public.trip_paid(
  trip_id text not null references public.trips(id) on delete cascade,
  from_id text not null, to_id text not null, amount bigint not null,
  marked_by text, user_id uuid default auth.uid(), at timestamptz not null default now(),
  primary key (trip_id, from_id, to_id));
alter table public.trips add column if not exists hide_in_group boolean not null default false;
alter table public.trips add column if not exists closed_at timestamptz;
alter table public.trips add column if not exists closed_by text;
alter table public.trip_shares add column if not exists expires_at timestamptz not null default now() + interval '3 months';

alter table public.admin_emails enable row level security;
alter table public.group_organizers enable row level security;
alter table public.organizer_requests enable row level security;
alter table public.trip_roles enable row level security;
alter table public.trip_codes enable row level security;
alter table public.group_view_codes enable row level security;
alter table public.code_access enable row level security;
alter table public.code_attempts enable row level security;
alter table public.trip_reports enable row level security;
alter table public.trip_paid enable row level security;
revoke all on public.admin_emails, public.group_organizers, public.organizer_requests, public.trip_roles, public.trip_codes,
  public.group_view_codes, public.code_access, public.code_attempts, public.trip_reports, public.trip_paid from anon, authenticated;

-- ================= hàm nền =================
create or replace function public.my_email() returns text
language sql stable security definer set search_path = public, auth as $$
  select lower(email) from auth.users
  where id = auth.uid() and not coalesce(is_anonymous, false) and email_confirmed_at is not null $$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.platform_admins where user_id = auth.uid())
      or exists (select 1 from public.admin_emails where email = public.my_email()) $$;

create or replace function public.mask_email(e text) returns text
language sql immutable as $$
  select case when e is null then null when position('@' in e) = 0 then e
    else left(split_part(e,'@',1), 3) || '***@' || split_part(e,'@',2) end $$;

create or replace function public.gen_code(prefix text) returns text
language plpgsql volatile set search_path = public, extensions as $$
declare a text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; s text; b bytea; i int;
begin
  loop
    b := extensions.gen_random_bytes(8); s := prefix || '-';
    for i in 0..7 loop s := s || substr(a, 1 + (get_byte(b, i) % 31), 1); end loop;
    exit when not exists (select 1 from public.trip_codes where code = s) and not exists (select 1 from public.group_view_codes where code = s);
  end loop;
  return s;
end $$;

create or replace function public.is_organizer(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.group_organizers where group_id = gid and email = public.my_email()) $$;
create or replace function public.can_create_trip(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_admin() or public.is_organizer(gid) $$;
create or replace function public.can_edit_trip(tid text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_admin() or exists (select 1 from public.trip_roles where trip_id = tid and email = public.my_email()) $$;
create or replace function public.can_lead_trip(tid text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_admin() or exists (select 1 from public.trip_roles where trip_id = tid and email = public.my_email() and role = 'leader') $$;
create or replace function public.can_view_trip(tid text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.can_edit_trip(tid)
    or exists (select 1 from public.code_access a join public.trip_codes c on c.trip_id = a.target
               where a.user_id = auth.uid() and a.kind = 'trip' and a.target = tid and a.ver = c.ver and c.enabled and c.expires_at > now())
    or exists (select 1 from public.trips t
               join public.group_view_codes g on g.group_id = t.group_id
               join public.code_access a on a.kind = 'group' and a.target = t.group_id::text and a.user_id = auth.uid() and a.ver = g.ver
               where t.id = tid and not t.hide_in_group and not t.deleted and g.enabled and g.expires_at > now()) $$;
create or replace function public.can_see_group(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_admin() or public.is_organizer(gid)
    or exists (select 1 from public.trips t where t.group_id = gid and not t.deleted and public.can_view_trip(t.id)) $$;
-- quản lý nhóm giờ chỉ còn quản trị viên
create or replace function public.can_manage(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$ select public.is_admin() $$;

-- ================= luật truy cập bảng cũ =================
drop policy if exists trips_select on public.trips;
drop policy if exists trips_insert on public.trips;
drop policy if exists trips_update on public.trips;
drop policy if exists trips_delete on public.trips;
create policy trips_select on public.trips for select using (public.can_view_trip(id));
drop policy if exists groups_select on public.groups;
drop policy if exists groups_insert on public.groups;
drop policy if exists groups_update on public.groups;
drop policy if exists groups_delete on public.groups;
create policy groups_select on public.groups for select using (public.can_see_group(id));
drop policy if exists shares_select on public.trip_shares;
drop policy if exists codes_select on public.group_codes;
-- cách vào nhóm cũ (mã nhập/xem theo nhóm) không còn dùng
revoke execute on function public.join_group(text) from authenticated, anon;

-- ================= nhật ký chi tiết =================
create or replace function public.trg_trips() returns trigger language plpgsql security definer set search_path = public as $$
declare gn text; nm text; gid uuid;
begin
  gid := coalesce(new.group_id, old.group_id);
  select name into gn from public.groups where id = gid;
  if gn is null then return coalesce(new, old); end if;
  if tg_op = 'INSERT' then
    perform public.log_event('create','trip',gid,gn,new.id,new.data ->> 'name',null);
  elsif tg_op = 'UPDATE' then
    nm := new.data ->> 'name';
    if new.deleted is distinct from old.deleted then
      perform public.log_event(case when new.deleted then 'delete' else 'restore' end,'trip',gid,gn,new.id,nm,null);
    elsif new.closed_at is distinct from old.closed_at then
      perform public.log_event(case when new.closed_at is null then 'reopen' else 'close' end,'trip',gid,gn,new.id,nm,null);
    elsif nm is distinct from (old.data ->> 'name') then
      perform public.log_event('rename','trip',gid,gn,new.id,nm,jsonb_build_object('from',old.data ->> 'name','to',nm));
    end if;
  elsif tg_op = 'DELETE' then
    perform public.log_event('delete','trip',gid,gn,old.id,old.data ->> 'name',jsonb_build_object('purge',true));
    return old;
  end if;
  return new;
end $$;

-- so sánh dữ liệu cũ/mới, ghi từng khoản chi, tiền đóng trước, người đi được thêm/sửa/xoá
create or replace function public.log_changes(tid text, gid uuid, o jsonb, n jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare gn text; r record; od jsonb; nd jsonb; mo jsonb; mn jsonb;
begin
  select name into gn from public.groups where id = gid;
  od := coalesce(o -> 'data', '{}'); nd := coalesce(n -> 'data', '{}');
  select coalesce(jsonb_object_agg(m ->> 'id', m ->> 'name'), '{}') into mo from jsonb_array_elements(coalesce(od -> 'members','[]')) m;
  select coalesce(jsonb_object_agg(m ->> 'id', m ->> 'name'), '{}') into mn from jsonb_array_elements(coalesce(nd -> 'members','[]')) m;
  -- khoản chi
  for r in
    with a as (select e ->> 'id' id, e from jsonb_array_elements(coalesce(od -> 'expenses','[]')) e),
         b as (select e ->> 'id' id, e from jsonb_array_elements(coalesce(nd -> 'expenses','[]')) e)
    select coalesce(a.id, b.id) id, a.e oe, b.e ne from a full join b on a.id = b.id
    where a.e is distinct from b.e
  loop
    perform public.log_event(
      case when r.oe is null then 'add' when r.ne is null then 'remove' else 'edit' end,
      case when jsonb_array_length(coalesce(coalesce(r.ne, r.oe) -> 'rooms','[]')) > 0 then 'room' else 'expense' end,
      gid, gn, tid, coalesce(r.ne, r.oe) ->> 'desc',
      jsonb_build_object('item', r.id, 'amount', (coalesce(r.ne, r.oe) ->> 'amount')::numeric,
        'from', case when r.oe is not null and r.ne is not null and (r.oe ->> 'amount') is distinct from (r.ne ->> 'amount') then (r.oe ->> 'amount')::numeric end));
  end loop;
  -- tiền đóng trước
  for r in
    with a as (select e ->> 'id' id, e from jsonb_array_elements(coalesce(od -> 'advances','[]')) e),
         b as (select e ->> 'id' id, e from jsonb_array_elements(coalesce(nd -> 'advances','[]')) e)
    select coalesce(a.id, b.id) id, a.e oe, b.e ne from a full join b on a.id = b.id
    where a.e is distinct from b.e
  loop
    perform public.log_event(
      case when r.oe is null then 'add' when r.ne is null then 'remove' else 'edit' end, 'advance',
      gid, gn, tid, coalesce(mn ->> (coalesce(r.ne, r.oe) ->> 'member'), mo ->> (coalesce(r.ne, r.oe) ->> 'member'), '?'),
      jsonb_build_object('item', r.id, 'amount', (coalesce(r.ne, r.oe) ->> 'amount')::numeric,
        'from', case when r.oe is not null and r.ne is not null and (r.oe ->> 'amount') is distinct from (r.ne ->> 'amount') then (r.oe ->> 'amount')::numeric end));
  end loop;
  -- người đi (thêm, xoá, đổi tên)
  for r in
    select coalesce(a.key, b.key) id, a.value #>> '{}' onm, b.value #>> '{}' nnm
    from jsonb_each(mo) a full join jsonb_each(mn) b on a.key = b.key
    where a.value is distinct from b.value
  loop
    perform public.log_event(
      case when r.onm is null then 'add' when r.nnm is null then 'remove' else 'rename' end, 'member',
      gid, gn, tid, coalesce(r.nnm, r.onm),
      case when r.onm is not null and r.nnm is not null then jsonb_build_object('item', r.id, 'from', r.onm, 'to', r.nnm) else jsonb_build_object('item', r.id) end);
  end loop;
end $$;

-- ================= lưu chuyến =================
create or replace function public.save_trip(p_id text, p_group uuid, p_data jsonb, p_base integer, p_force boolean default false)
returns jsonb language plpgsql security definer set search_path = public as $$
declare cur integer; cur_data jsonb; cl timestamptz; g uuid; del boolean; em text := public.my_email();
begin
  select rev, data, closed_at, group_id, deleted into cur, cur_data, cl, g, del from public.trips where id = p_id for update;
  if not found then
    if not public.can_create_trip(p_group) then raise exception 'forbidden'; end if;
    insert into public.trips(id, group_id, data, rev) values (p_id, p_group, p_data, 1);
    if em is not null then
      insert into public.trip_roles(trip_id, email, role, tabs, added_by) values (p_id, em, 'leader', '{member,advance,room,expense}', em) on conflict do nothing;
    end if;
    insert into public.trip_codes(trip_id, code) values (p_id, public.gen_code('CH')) on conflict do nothing;
    return jsonb_build_object('ok', true, 'rev', 1);
  end if;
  if g <> p_group or not public.can_edit_trip(p_id) then raise exception 'forbidden'; end if;
  if del then return jsonb_build_object('ok', false, 'deleted', true, 'rev', cur); end if;
  if cl is not null then return jsonb_build_object('ok', false, 'closed', true, 'rev', cur, 'data', cur_data); end if;
  if cur = p_base or p_force then
    update public.trips set data = p_data, rev = cur + 1 where id = p_id;
    perform public.log_changes(p_id, g, cur_data, p_data);
    return jsonb_build_object('ok', true, 'rev', cur + 1);
  end if;
  return jsonb_build_object('ok', false, 'conflict', true, 'rev', cur, 'data', cur_data);
end $$;

-- ================= nhóm (chỉ quản trị viên) =================
create or replace function public.admin_create_group(p_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare gid uuid;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if length(trim(coalesce(p_name,''))) = 0 then raise exception 'empty_name'; end if;
  insert into public.groups(name, created_by) values (trim(p_name), auth.uid()) returning id into gid;
  return gid;
end $$;

-- nhóm mà người đang đăng nhập (hoặc phiên ẩn danh) được thấy
create or replace function public.my_groups()
returns table(id uuid, name text, created_at timestamptz, can_create boolean, trips bigint)
language sql stable security definer set search_path = public as $$
  select g.id, g.name, g.created_at, public.can_create_trip(g.id),
    (select count(*) from public.trips t where t.group_id = g.id and not t.deleted and public.can_view_trip(t.id))
  from public.groups g where public.can_see_group(g.id) order by g.created_at $$;

-- quyền của tôi với từng chuyến trong nhóm
create or replace function public.my_trip_roles(gid uuid)
returns table(trip_id text, role text, tabs text[], hide_in_group boolean, closed_at timestamptz)
language sql stable security definer set search_path = public as $$
  select t.id,
    case when exists (select 1 from public.trip_roles r where r.trip_id = t.id and r.email = public.my_email() and r.role = 'leader') then 'leader'
         when exists (select 1 from public.trip_roles r where r.trip_id = t.id and r.email = public.my_email()) then 'helper'
         when public.is_admin() then 'admin' else 'viewer' end,
    coalesce((select r.tabs from public.trip_roles r where r.trip_id = t.id and r.email = public.my_email()),
             case when public.is_admin() then '{member,advance,room,expense}'::text[] else '{}'::text[] end),
    t.hide_in_group, t.closed_at
  from public.trips t where t.group_id = gid and not t.deleted and public.can_view_trip(t.id) $$;

-- người tổ chức của nhóm
create or replace function public.group_organizers_list(gid uuid)
returns table(email text, added_by text, added_at timestamptz, signed_in boolean)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query select o.email, o.added_by, o.added_at, exists (select 1 from auth.users u where lower(u.email) = o.email)
    from public.group_organizers o where o.group_id = gid order by o.added_at;
end $$;
create or replace function public.add_organizer(gid uuid, p_email text) returns void
language plpgsql security definer set search_path = public as $$
declare e text := lower(trim(p_email)); gn text;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if e !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'bad_email'; end if;
  insert into public.group_organizers(group_id, email, added_by) values (gid, e, public.my_email()) on conflict do nothing;
  delete from public.organizer_requests where email = e;
  select name into gn from public.groups where id = gid;
  perform public.log_event('add','organizer',gid,gn,e,e,null);
end $$;
create or replace function public.remove_organizer(gid uuid, p_email text) returns void
language plpgsql security definer set search_path = public as $$
declare gn text;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  delete from public.group_organizers where group_id = gid and email = lower(p_email);
  select name into gn from public.groups where id = gid;
  perform public.log_event('remove','organizer',gid,gn,lower(p_email),lower(p_email),null);
end $$;

-- xin quyền tổ chức chuyến
create or replace function public.request_organizer(p_note text) returns void
language plpgsql security definer set search_path = public as $$
declare e text := public.my_email();
begin
  if e is null then raise exception 'need_email'; end if;
  insert into public.organizer_requests(email, user_id, note) values (e, auth.uid(), left(coalesce(p_note,''), 300))
    on conflict (email) do update set note = excluded.note, at = now();
end $$;
create or replace function public.my_request() returns jsonb
language sql stable security definer set search_path = public as $$
  select to_jsonb(r) from public.organizer_requests r where r.email = public.my_email() $$;
create or replace function public.organizer_requests_list()
returns table(email text, note text, at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query select r.email, r.note, r.at from public.organizer_requests r order by r.at;
end $$;
create or replace function public.reject_request(p_email text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  delete from public.organizer_requests where email = lower(p_email);
end $$;

-- ================= người trong chuyến (leader, phụ trách) =================
create or replace function public.trip_people(tid text)
returns table(email text, role text, tabs text[], added_by text, added_at timestamptz, signed_in boolean)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.can_edit_trip(tid) then raise exception 'forbidden'; end if;
  return query select r.email, r.role, r.tabs, r.added_by, r.added_at, exists (select 1 from auth.users u where lower(u.email) = r.email)
    from public.trip_roles r where r.trip_id = tid order by case r.role when 'leader' then 0 else 1 end, r.added_at;
end $$;
create or replace function public.set_trip_person(tid text, p_email text, p_role text, p_tabs text[]) returns void
language plpgsql security definer set search_path = public as $$
declare e text := lower(trim(p_email)); gid uuid; gn text; nm text; old_role text; tb text[];
begin
  if not public.can_lead_trip(tid) then raise exception 'forbidden'; end if;
  if e !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'bad_email'; end if;
  if p_role not in ('leader','helper') then raise exception 'bad_role'; end if;
  select array_agg(x) into tb from unnest(coalesce(p_tabs,'{}')) x where x in ('member','advance','room','expense');
  if p_role = 'leader' then tb := '{member,advance,room,expense}'; end if;
  select role into old_role from public.trip_roles where trip_id = tid and email = e;
  if old_role = 'leader' and p_role <> 'leader'
     and (select count(*) from public.trip_roles where trip_id = tid and role = 'leader') <= 1 then raise exception 'last_leader'; end if;
  insert into public.trip_roles(trip_id, email, role, tabs, added_by) values (tid, e, p_role, coalesce(tb,'{}'), public.my_email())
    on conflict (trip_id, email) do update set role = excluded.role, tabs = excluded.tabs;
  select t.group_id, g.name, t.data ->> 'name' into gid, gn, nm from public.trips t join public.groups g on g.id = t.group_id where t.id = tid;
  perform public.log_event(case when old_role is null then 'add' else 'edit' end, 'person', gid, gn, tid, nm,
    jsonb_build_object('email', e, 'role', p_role, 'tabs', coalesce(tb,'{}')));
end $$;
create or replace function public.remove_trip_person(tid text, p_email text) returns void
language plpgsql security definer set search_path = public as $$
declare e text := lower(p_email); gid uuid; gn text; nm text; r text;
begin
  if not public.can_lead_trip(tid) then raise exception 'forbidden'; end if;
  select role into r from public.trip_roles where trip_id = tid and email = e;
  if r = 'leader' and (select count(*) from public.trip_roles where trip_id = tid and role = 'leader') <= 1 then raise exception 'last_leader'; end if;
  delete from public.trip_roles where trip_id = tid and email = e;
  select t.group_id, g.name, t.data ->> 'name' into gid, gn, nm from public.trips t join public.groups g on g.id = t.group_id where t.id = tid;
  perform public.log_event('remove','person',gid,gn,tid,nm,jsonb_build_object('email', e));
end $$;

-- ================= mã chuyến, mã nhóm =================
create or replace function public.trip_code_get(tid text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare c record;
begin
  if not public.can_edit_trip(tid) then raise exception 'forbidden'; end if;
  insert into public.trip_codes(trip_id, code) values (tid, public.gen_code('CH')) on conflict do nothing;
  select code, enabled, expires_at, ver into c from public.trip_codes where trip_id = tid;
  return jsonb_build_object('code', c.code, 'enabled', c.enabled, 'expires_at', c.expires_at,
    'hide_in_group', (select hide_in_group from public.trips where id = tid));
end $$;
-- p_act: renew (gia hạn 3 tháng), rotate (mã mới, người cũ mất quyền xem), lock, unlock, hide, show
create or replace function public.trip_code_act(tid text, p_act text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_lead_trip(tid) then raise exception 'forbidden'; end if;
  perform public.trip_code_get(tid);
  if p_act = 'renew' then update public.trip_codes set expires_at = now() + interval '3 months' where trip_id = tid;
  elsif p_act = 'rotate' then update public.trip_codes set code = public.gen_code('CH'), ver = ver + 1, expires_at = now() + interval '3 months' where trip_id = tid;
  elsif p_act = 'lock' then update public.trip_codes set enabled = false where trip_id = tid;
  elsif p_act = 'unlock' then update public.trip_codes set enabled = true where trip_id = tid;
  elsif p_act = 'hide' then update public.trips set hide_in_group = true where id = tid;
  elsif p_act = 'show' then update public.trips set hide_in_group = false where id = tid;
  else raise exception 'bad_act'; end if;
  return public.trip_code_get(tid);
end $$;
create or replace function public.group_code_get(gid uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare c record;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  insert into public.group_view_codes(group_id, code) values (gid, public.gen_code('NH')) on conflict do nothing;
  select code, enabled, expires_at into c from public.group_view_codes where group_id = gid;
  return jsonb_build_object('code', c.code, 'enabled', c.enabled, 'expires_at', c.expires_at);
end $$;
create or replace function public.group_code_act(gid uuid, p_act text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  perform public.group_code_get(gid);
  if p_act = 'renew' then update public.group_view_codes set expires_at = now() + interval '3 months' where group_id = gid;
  elsif p_act = 'rotate' then update public.group_view_codes set code = public.gen_code('NH'), ver = ver + 1, expires_at = now() + interval '3 months' where group_id = gid;
  elsif p_act = 'lock' then update public.group_view_codes set enabled = false where group_id = gid;
  elsif p_act = 'unlock' then update public.group_view_codes set enabled = true, expires_at = greatest(expires_at, now() + interval '3 months') where group_id = gid;
  else raise exception 'bad_act'; end if;
  return public.group_code_get(gid);
end $$;

-- nhập mã (phiên ẩn danh hoặc tài khoản). Giới hạn nhập sai để chống dò mã.
create or replace function public.enter_code(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare c text := upper(regexp_replace(coalesce(p_code,''), '[^A-Za-z0-9]', '', 'g')); tc record; gc record; nm text; gn text;
begin
  if auth.uid() is null then raise exception 'need_session'; end if;
  if (select count(*) from public.code_attempts where user_id = auth.uid() and not ok and at > now() - interval '10 minutes') >= 8
     or (select count(*) from public.code_attempts where not ok and at > now() - interval '10 minutes') >= 300 then
    return jsonb_build_object('error', 'rate_limited');
  end if;
  if c ~ '^(CH|NH)' then c := substr(c, 1, 2) || '-' || substr(c, 3); end if;
  select * into tc from public.trip_codes where code = c;
  if found then
    insert into public.code_attempts(user_id, ok) values (auth.uid(), true);
    if not tc.enabled then return jsonb_build_object('error', 'locked'); end if;
    if tc.expires_at <= now() then return jsonb_build_object('error', 'expired'); end if;
    select t.data ->> 'name', g.name into nm, gn from public.trips t join public.groups g on g.id = t.group_id where t.id = tc.trip_id and not t.deleted;
    if nm is null then return jsonb_build_object('error', 'gone'); end if;
    insert into public.code_access(user_id, kind, target, ver) values (auth.uid(), 'trip', tc.trip_id, tc.ver)
      on conflict (user_id, kind, target) do update set ver = excluded.ver, at = now();
    return jsonb_build_object('kind', 'trip', 'trip_id', tc.trip_id, 'name', nm, 'group_name', gn,
      'group_id', (select group_id from public.trips where id = tc.trip_id));
  end if;
  select * into gc from public.group_view_codes where code = c;
  if found then
    insert into public.code_attempts(user_id, ok) values (auth.uid(), true);
    if not gc.enabled then return jsonb_build_object('error', 'locked'); end if;
    if gc.expires_at <= now() then return jsonb_build_object('error', 'expired'); end if;
    insert into public.code_access(user_id, kind, target, ver) values (auth.uid(), 'group', gc.group_id::text, gc.ver)
      on conflict (user_id, kind, target) do update set ver = excluded.ver, at = now();
    return jsonb_build_object('kind', 'group', 'group_id', gc.group_id, 'name', (select name from public.groups where id = gc.group_id));
  end if;
  insert into public.code_attempts(user_id, ok) values (auth.uid(), false);
  delete from public.code_attempts where at < now() - interval '1 day';
  return jsonb_build_object('error', 'not_found');
end $$;

-- các mã tôi đã nhập trên thiết bị này
create or replace function public.my_codes()
returns table(kind text, target text, name text, group_name text, valid boolean, expires_at timestamptz)
language sql stable security definer set search_path = public as $$
  select a.kind, a.target,
    case when a.kind = 'trip' then (select t.data ->> 'name' from public.trips t where t.id = a.target) else (select g.name from public.groups g where g.id::text = a.target) end,
    case when a.kind = 'trip' then (select g.name from public.trips t join public.groups g on g.id = t.group_id where t.id = a.target) end,
    case when a.kind = 'trip' then exists (select 1 from public.trip_codes c join public.trips t on t.id = c.trip_id where c.trip_id = a.target and c.ver = a.ver and c.enabled and c.expires_at > now() and not t.deleted)
         else exists (select 1 from public.group_view_codes c where c.group_id::text = a.target and c.ver = a.ver and c.enabled and c.expires_at > now()) end,
    case when a.kind = 'trip' then (select c.expires_at from public.trip_codes c where c.trip_id = a.target) else (select c.expires_at from public.group_view_codes c where c.group_id::text = a.target) end
  from public.code_access a where a.user_id = auth.uid() order by a.at desc $$;
create or replace function public.forget_code(p_kind text, p_target text) returns void
language sql security definer set search_path = public as $$
  delete from public.code_access where user_id = auth.uid() and kind = p_kind and target = p_target $$;

-- ================= link xem công khai (hết hạn 3 tháng) =================
create or replace function public.create_share(p_trip text) returns text
language plpgsql security definer set search_path = public as $$
declare gid uuid; tok text; ex timestamptz;
begin
  if not public.can_edit_trip(p_trip) then raise exception 'forbidden'; end if;
  select group_id into gid from public.trips where id = p_trip;
  select token, expires_at into tok, ex from public.trip_shares where trip_id = p_trip;
  if tok is not null and ex <= now() then delete from public.trip_shares where trip_id = p_trip; tok := null; end if;
  if tok is null then
    insert into public.trip_shares(group_id, trip_id) values (gid, p_trip) returning token into tok;
  end if;
  return tok;
end $$;
create or replace function public.share_info(p_trip text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.can_edit_trip(p_trip) then raise exception 'forbidden'; end if;
  return (select jsonb_build_object('token', token, 'expires_at', expires_at, 'expired', expires_at <= now()) from public.trip_shares where trip_id = p_trip);
end $$;
create or replace function public.renew_share(p_trip text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_edit_trip(p_trip) then raise exception 'forbidden'; end if;
  update public.trip_shares set expires_at = now() + interval '3 months' where trip_id = p_trip;
end $$;
create or replace function public.revoke_share(p_trip text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_edit_trip(p_trip) then raise exception 'forbidden'; end if;
  delete from public.trip_shares where trip_id = p_trip;
end $$;
create or replace function public.get_shared_trip(p_token text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('data', t.data, 'rev', t.rev, 'closed_at', t.closed_at)
  from public.trip_shares s join public.trips t on t.id = s.trip_id
  where s.token = p_token and s.expires_at > now() and not t.deleted $$;

-- ================= thùng rác, chốt sổ, thông tin, lịch sử =================
create or replace function public.trash_trip(gid uuid, tid text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_lead_trip(tid) then raise exception 'forbidden'; end if;
  update public.trips set deleted = true, deleted_at = now(), deleted_by = auth.uid(), rev = rev + 1 where id = tid and group_id = gid;
end $$;
create or replace function public.restore_trip(gid uuid, tid text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_lead_trip(tid) then raise exception 'forbidden'; end if;
  update public.trips set deleted = false, deleted_at = null, deleted_by = null, rev = rev + 1 where id = tid and group_id = gid;
end $$;
create or replace function public.purge_trip(gid uuid, tid text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_lead_trip(tid) then raise exception 'forbidden'; end if;
  delete from public.trips where id = tid and group_id = gid and deleted;
end $$;
create or replace function public.trip_trash(gid uuid)
returns table(id text, name text, deleted_at timestamptz, deleted_by_email text, days_left integer)
language plpgsql security definer set search_path = public, auth as $$
begin
  delete from public.trips t where t.group_id = gid and t.deleted and t.deleted_at < now() - interval '30 days';
  return query select t.id, coalesce(t.data ->> 'name', '(không tên)'), t.deleted_at, u.email::text,
      greatest(0, 30 - extract(day from now() - t.deleted_at)::int)
    from public.trips t left join auth.users u on u.id = t.deleted_by
    where t.group_id = gid and t.deleted and public.can_lead_trip(t.id) order by t.deleted_at desc nulls last;
end $$;
create or replace function public.close_trip(tid text, p_close boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_lead_trip(tid) then raise exception 'forbidden'; end if;
  update public.trips set closed_at = case when p_close then now() end, closed_by = case when p_close then public.my_email() end, rev = rev + 1 where id = tid;
end $$;
create or replace function public.trip_info(gid uuid, tid text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c record; t record; ed boolean := public.can_edit_trip(tid);
begin
  if not public.can_view_trip(tid) then raise exception 'forbidden'; end if;
  select actor_email, at into c from public.audit_log where entity = 'trip' and action = 'create' and entity_id = tid order by id limit 1;
  select updated_at, closed_at, closed_by into t from public.trips where id = tid;
  return jsonb_build_object('creator', case when ed then c.actor_email else public.mask_email(c.actor_email) end, 'created_at', c.at,
    'updated_at', t.updated_at, 'closed_at', t.closed_at, 'closed_by', case when ed then t.closed_by else public.mask_email(t.closed_by) end);
end $$;
drop function if exists public.trip_audit(uuid, text, integer, bigint);
create or replace function public.trip_audit(gid uuid, tid text, p_limit integer default 50, p_before bigint default null)
returns table(id bigint, at timestamptz, actor_email text, action text, entity text, entity_name text, detail jsonb, group_name text)
language plpgsql stable security definer set search_path = public as $$
declare ed boolean := public.can_edit_trip(tid);
begin
  if not public.can_view_trip(tid) then raise exception 'forbidden'; end if;
  return query select a.id, a.at, case when ed then a.actor_email else public.mask_email(a.actor_email) end,
      a.action, a.entity, a.entity_name,
      case when ed or a.entity <> 'person' then a.detail else a.detail - 'email' end, a.group_name
    from public.audit_log a where a.entity_id = tid and a.entity in ('trip','expense','room','advance','member','person')
      and (p_before is null or a.id < p_before) order by a.id desc limit least(coalesce(p_limit, 50), 200);
end $$;

-- ================= báo sai, đã trả =================
create or replace function public.report_issue(tid text, p_item text, p_label text, p_msg text, p_name text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_view_trip(tid) then raise exception 'forbidden'; end if;
  if (select count(*) from public.trip_reports where user_id = auth.uid() and at > now() - interval '1 hour') >= 20 then raise exception 'rate_limited'; end if;
  insert into public.trip_reports(trip_id, item_id, item_label, message, reporter, user_id)
    values (tid, left(p_item,60), left(p_label,200), left(trim(p_msg),1000), left(trim(coalesce(p_name,'')),60), auth.uid());
end $$;
create or replace function public.trip_reports_list(tid text)
returns table(id bigint, item_id text, item_label text, message text, reporter text, mine boolean, at timestamptz, resolved_at timestamptz, resolved_by text, reply text)
language plpgsql stable security definer set search_path = public as $$
declare ed boolean := public.can_edit_trip(tid);
begin
  if not public.can_view_trip(tid) then raise exception 'forbidden'; end if;
  return query select r.id, r.item_id, r.item_label, r.message, r.reporter, r.user_id = auth.uid(), r.at, r.resolved_at,
      case when ed then r.resolved_by else public.mask_email(r.resolved_by) end, r.reply
    from public.trip_reports r where r.trip_id = tid and (ed or r.user_id = auth.uid()) order by r.resolved_at nulls first, r.id desc;
end $$;
create or replace function public.resolve_report(p_id bigint, p_reply text) returns void
language plpgsql security definer set search_path = public as $$
declare tid text;
begin
  select trip_id into tid from public.trip_reports where id = p_id;
  if tid is null or not public.can_edit_trip(tid) then raise exception 'forbidden'; end if;
  update public.trip_reports set resolved_at = now(), resolved_by = public.my_email(), reply = left(coalesce(p_reply,''),500) where id = p_id;
end $$;
create or replace function public.mark_paid(tid text, p_from text, p_to text, p_amount bigint, p_name text, p_on boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_view_trip(tid) then raise exception 'forbidden'; end if;
  if p_on then
    insert into public.trip_paid(trip_id, from_id, to_id, amount, marked_by) values (tid, p_from, p_to, p_amount, left(coalesce(p_name,''),60))
      on conflict (trip_id, from_id, to_id) do update set amount = excluded.amount, marked_by = excluded.marked_by, user_id = auth.uid(), at = now();
  else
    delete from public.trip_paid where trip_id = tid and from_id = p_from and to_id = p_to
      and (public.can_edit_trip(tid) or user_id = auth.uid());
  end if;
end $$;
create or replace function public.trip_paid_list(tid text)
returns table(from_id text, to_id text, amount bigint, marked_by text, mine boolean, at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.can_view_trip(tid) then raise exception 'forbidden'; end if;
  return query select p.from_id, p.to_id, p.amount, p.marked_by, p.user_id = auth.uid(), p.at from public.trip_paid p where p.trip_id = tid;
end $$;

-- ================= chuyển dữ liệu cũ =================
insert into public.group_organizers(group_id, email, added_by)
  select m.group_id, lower(u.email), 'chuyển từ chủ nhóm' from public.group_members m join auth.users u on u.id = m.user_id
  where m.role = 'owner' and u.email is not null on conflict do nothing;
insert into public.trip_roles(trip_id, email, role, tabs, added_by)
  select t.id, lower(u.email), case when m.role = 'owner' then 'leader' else 'helper' end, '{member,advance,room,expense}', 'chuyển từ nhóm'
  from public.trips t join public.group_members m on m.group_id = t.group_id and m.role in ('owner','editor')
  join auth.users u on u.id = m.user_id where u.email is not null on conflict do nothing;
insert into public.trip_codes(trip_id, code) select id, public.gen_code('CH') from public.trips on conflict do nothing;
update public.trip_shares set expires_at = greatest(expires_at, now() + interval '3 months');

-- ================= cấp quyền gọi hàm =================
do $$ declare f text; begin
  foreach f in array array[
    'my_email()','is_admin()','is_organizer(uuid)','can_create_trip(uuid)','can_edit_trip(text)','can_lead_trip(text)','can_view_trip(text)','can_see_group(uuid)',
    'admin_create_group(text)','my_groups()','my_trip_roles(uuid)','group_organizers_list(uuid)','add_organizer(uuid,text)','remove_organizer(uuid,text)',
    'request_organizer(text)','my_request()','organizer_requests_list()','reject_request(text)',
    'trip_people(text)','set_trip_person(text,text,text,text[])','remove_trip_person(text,text)',
    'trip_code_get(text)','trip_code_act(text,text)','group_code_get(uuid)','group_code_act(uuid,text)','enter_code(text)','my_codes()','forget_code(text,text)',
    'create_share(text)','share_info(text)','renew_share(text)','revoke_share(text)',
    'trash_trip(uuid,text)','restore_trip(uuid,text)','purge_trip(uuid,text)','trip_trash(uuid)','close_trip(text,boolean)','trip_info(uuid,text)','trip_audit(uuid,text,integer,bigint)',
    'report_issue(text,text,text,text,text)','trip_reports_list(text)','resolve_report(bigint,text)','mark_paid(text,text,text,bigint,text,boolean)','trip_paid_list(text)',
    'save_trip(text,uuid,jsonb,integer,boolean)']
  loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  execute 'revoke all on function public.log_changes(text,uuid,jsonb,jsonb) from public, anon, authenticated';
  execute 'revoke all on function public.gen_code(text) from public, anon, authenticated';
end $$;
grant execute on function public.get_shared_trip(text) to anon, authenticated;
