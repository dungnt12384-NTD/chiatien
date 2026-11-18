-- Trang quản trị tổng: quản trị viên, hạn mức tạo nhóm, chặn vào nhóm, nhật ký. (Chạy sau 003)

-- ===== bảng =====
create table if not exists public.platform_admins(
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text, added_at timestamptz not null default now());
create table if not exists public.app_settings(key text primary key, value jsonb not null);
insert into public.app_settings(key, value) values ('default_max_groups', '3') on conflict do nothing;
create table if not exists public.user_quotas(
  email text primary key, max_groups integer not null check (max_groups >= 0),
  note text, updated_at timestamptz not null default now(), updated_by text);
create table if not exists public.group_bans(
  group_id uuid not null references public.groups(id) on delete cascade,
  email text not null, reason text, banned_at timestamptz not null default now(), banned_by text,
  primary key (group_id, email));
alter table public.groups add column if not exists join_enabled boolean not null default true;
create table if not exists public.audit_log(
  id bigserial primary key, at timestamptz not null default now(),
  actor_id uuid, actor_email text, action text not null, entity text not null,
  group_id uuid, group_name text, entity_id text, entity_name text, detail jsonb);
create index if not exists audit_at on public.audit_log(at desc);
create index if not exists audit_grp on public.audit_log(group_id, at desc);
alter table public.platform_admins enable row level security;
alter table public.app_settings enable row level security;
alter table public.user_quotas enable row level security;
alter table public.group_bans enable row level security;
alter table public.audit_log enable row level security;   -- không có policy: chỉ truy cập qua các hàm bên dưới
revoke all on public.platform_admins, public.app_settings, public.user_quotas, public.group_bans, public.audit_log from anon, authenticated;

-- ===== hàm nền =====
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.platform_admins where user_id = auth.uid()) $$;
create or replace function public.can_manage(gid uuid) returns boolean language sql stable security definer set search_path = public as $$
  select public.is_owner(gid) or public.is_admin() $$;
create or replace function public.cur_email() returns text language sql stable as $$
  select lower(coalesce(auth.jwt() ->> 'email', '')) $$;

create or replace function public.log_event(p_action text, p_entity text, p_gid uuid, p_gname text, p_eid text, p_ename text, p_detail jsonb default null)
returns void language plpgsql security definer set search_path = public, auth as $$
declare em text;
begin
  select email into em from auth.users where id = auth.uid();
  insert into public.audit_log(actor_id, actor_email, action, entity, group_id, group_name, entity_id, entity_name, detail)
  values (auth.uid(), em, p_action, p_entity, p_gid, p_gname, p_eid, p_ename, p_detail);
end $$;

-- ===== trigger ghi nhật ký =====
create or replace function public.trg_groups() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_event('create','group',new.id,new.name,new.id::text,new.name,null);
  elsif tg_op = 'UPDATE' then
    if new.name is distinct from old.name then
      perform public.log_event('rename','group',new.id,new.name,new.id::text,new.name,jsonb_build_object('from',old.name,'to',new.name)); end if;
    if new.join_enabled is distinct from old.join_enabled then
      perform public.log_event(case when new.join_enabled then 'join_on' else 'join_off' end,'group',new.id,new.name,new.id::text,new.name,null); end if;
  elsif tg_op = 'DELETE' then
    perform public.log_event('delete','group',old.id,old.name,old.id::text,old.name,
      jsonb_build_object('trips',(select count(*) from public.trips where group_id=old.id),'members',(select count(*) from public.group_members where group_id=old.id)));
    return old;
  end if;
  return new;
end $$;
drop trigger if exists audit_groups on public.groups;
create trigger audit_groups after insert or update on public.groups for each row execute function public.trg_groups();
drop trigger if exists audit_groups_del on public.groups;
create trigger audit_groups_del before delete on public.groups for each row execute function public.trg_groups();

create or replace function public.trg_members() returns trigger language plpgsql security definer set search_path = public, auth as $$
declare em text; gn text; uid uuid; gid uuid;
begin
  uid := coalesce(new.user_id, old.user_id); gid := coalesce(new.group_id, old.group_id);
  select name into gn from public.groups where id = gid;
  if gn is null then return coalesce(new, old); end if;          -- nhóm đã bị xoá: không ghi từng thành viên
  select email into em from auth.users where id = uid;
  if tg_op = 'INSERT' then
    if new.role <> 'owner' then perform public.log_event('join','member',gid,gn,uid::text,em,jsonb_build_object('role',new.role)); end if;
  elsif tg_op = 'UPDATE' then
    if new.role is distinct from old.role then perform public.log_event('role','member',gid,gn,uid::text,em,jsonb_build_object('from',old.role,'to',new.role)); end if;
  elsif tg_op = 'DELETE' then
    perform public.log_event(case when auth.uid() = old.user_id then 'leave' else 'kick' end,'member',gid,gn,uid::text,em,jsonb_build_object('role',old.role));
  end if;
  return coalesce(new, old);
end $$;
drop trigger if exists audit_members on public.group_members;
create trigger audit_members after insert or update or delete on public.group_members for each row execute function public.trg_members();

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
    elsif nm is distinct from (old.data ->> 'name') then
      perform public.log_event('rename','trip',gid,gn,new.id,nm,jsonb_build_object('from',old.data ->> 'name','to',nm));
    elsif not exists (select 1 from public.audit_log where entity='trip' and action='edit' and entity_id=new.id
                        and actor_id is not distinct from auth.uid() and at > now() - interval '10 minutes') then
      perform public.log_event('edit','trip',gid,gn,new.id,nm,null);   -- gộp: tối đa 1 dòng "sửa" / 10 phút / người / chuyến
    end if;
  elsif tg_op = 'DELETE' then
    perform public.log_event('delete','trip',gid,gn,old.id,old.data ->> 'name',null);
    return old;
  end if;
  return new;
end $$;
drop trigger if exists audit_trips on public.trips;
create trigger audit_trips after insert or update on public.trips for each row execute function public.trg_trips();
drop trigger if exists audit_trips_del on public.trips;
create trigger audit_trips_del after delete on public.trips for each row execute function public.trg_trips();

create or replace function public.trg_bans() returns trigger language plpgsql security definer set search_path = public as $$
declare gid uuid; gn text; em text;
begin
  gid := coalesce(new.group_id, old.group_id); em := coalesce(new.email, old.email);
  select name into gn from public.groups where id = gid;
  if gn is null then return coalesce(new, old); end if;
  perform public.log_event(case when tg_op='INSERT' then 'ban' else 'unban' end,'member',gid,gn,null,em,null);
  return coalesce(new, old);
end $$;
drop trigger if exists audit_bans on public.group_bans;
create trigger audit_bans after insert or delete on public.group_bans for each row execute function public.trg_bans();

-- ===== tạo nhóm theo hạn mức; vào nhóm bằng mã có kiểm tra chặn =====
create or replace function public.create_group(gname text)
returns public.groups language plpgsql security definer set search_path = public as $$
declare g public.groups; n text := btrim(regexp_replace(coalesce(gname,''), '\s+', ' ', 'g')); lim integer; own integer;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if n = '' or length(n) > 40 then raise exception 'invalid name'; end if;
  if not public.is_admin() then
    select max_groups into lim from public.user_quotas where email = public.cur_email();
    if lim is null then select (value #>> '{}')::int into lim from public.app_settings where key = 'default_max_groups'; end if;
    lim := coalesce(lim, 3);
    select count(*) into own from public.group_members where user_id = auth.uid() and role = 'owner';
    if own >= lim then raise exception 'group limit'; end if;
  end if;
  insert into public.groups(name, created_by) values (n, auth.uid()) returning * into g;
  insert into public.group_members(group_id, user_id, role) values (g.id, auth.uid(), 'owner');
  insert into public.group_codes(group_id, edit_code, view_code) values (g.id, public.new_code(), public.new_code());
  return g;
end $$;

create or replace function public.join_group(code text)
returns public.groups language plpgsql security definer set search_path = public as $$
declare gc public.group_codes; g public.groups; r text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into gc from public.group_codes where edit_code = code or view_code = code;
  if not found then raise exception 'invalid code'; end if;
  select * into g from public.groups where id = gc.group_id;
  if exists (select 1 from public.group_members where group_id = g.id and user_id = auth.uid()) then return g; end if;
  if exists (select 1 from public.group_bans where group_id = g.id and email = public.cur_email()) then raise exception 'banned'; end if;
  if not g.join_enabled then raise exception 'join disabled'; end if;
  r := case when gc.edit_code = code then 'editor' else 'viewer' end;
  insert into public.group_members(group_id, user_id, role) values (g.id, auth.uid(), r) on conflict do nothing;
  return g;
end $$;

-- ===== quản lý nhóm: chủ nhóm HOẶC quản trị viên =====
create or replace function public.rename_group(gid uuid, new_name text) returns void language plpgsql security definer set search_path = public as $$
declare n text := btrim(regexp_replace(coalesce(new_name,''), '\s+', ' ', 'g'));
begin
  if not public.can_manage(gid) then raise exception 'forbidden'; end if;
  if n = '' or length(n) > 40 then raise exception 'invalid name'; end if;
  update public.groups set name = n where id = gid;
end $$;
create or replace function public.delete_group(gid uuid) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.can_manage(gid) then raise exception 'forbidden'; end if;
  delete from public.groups where id = gid;
end $$;
create or replace function public.group_roster(gid uuid)
returns table(user_id uuid, email text, role text, joined_at timestamptz) language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.can_manage(gid) then raise exception 'forbidden'; end if;
  return query select m.user_id, u.email::text, m.role, m.joined_at
    from public.group_members m join auth.users u on u.id = m.user_id where m.group_id = gid order by m.joined_at;
end $$;
create or replace function public.set_member_role(gid uuid, uid uuid, new_role text) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.can_manage(gid) then raise exception 'forbidden'; end if;
  if new_role not in ('editor','viewer') then raise exception 'bad role'; end if;
  update public.group_members set role = new_role where group_id = gid and user_id = uid and role <> 'owner';
end $$;
drop function if exists public.remove_member(uuid, uuid);
create or replace function public.remove_member(gid uuid, uid uuid, ban boolean default false, reason text default null)
returns void language plpgsql security definer set search_path = public, auth as $$
declare em text;
begin
  if not public.can_manage(gid) then raise exception 'forbidden'; end if;
  select lower(email) into em from auth.users where id = uid;
  delete from public.group_members where group_id = gid and user_id = uid and role <> 'owner';
  if ban and em is not null then
    insert into public.group_bans(group_id, email, reason, banned_by) values (gid, em, reason, public.cur_email()) on conflict do nothing;
  end if;
end $$;
create or replace function public.reset_codes(gid uuid) returns public.group_codes language plpgsql security definer set search_path = public as $$
declare gc public.group_codes;
begin
  if not public.can_manage(gid) then raise exception 'forbidden'; end if;
  update public.group_codes set edit_code = public.new_code(), view_code = public.new_code() where group_id = gid returning * into gc;
  perform public.log_event('reset_codes','group',gid,(select name from public.groups where id=gid),gid::text,null,null);
  return gc;
end $$;
create or replace function public.group_codes_get(gid uuid) returns table(edit_code text, view_code text) language plpgsql stable security definer set search_path = public as $$
begin
  if not public.can_manage(gid) then raise exception 'forbidden'; end if;
  return query select c.edit_code, c.view_code from public.group_codes c where c.group_id = gid;
end $$;
create or replace function public.set_join_enabled(gid uuid, enabled boolean) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.can_manage(gid) then raise exception 'forbidden'; end if;
  update public.groups set join_enabled = enabled where id = gid;
end $$;
create or replace function public.ban_email(gid uuid, p_email text, reason text default null) returns void language plpgsql security definer set search_path = public, auth as $$
declare em text := lower(btrim(coalesce(p_email,''))); uid uuid;
begin
  if not public.can_manage(gid) then raise exception 'forbidden'; end if;
  if em !~ '^[^@\s]+@[^@\s]+$' then raise exception 'bad email'; end if;
  select id into uid from auth.users where lower(email) = em;
  if uid is not null and exists (select 1 from public.group_members where group_id = gid and user_id = uid and role = 'owner') then raise exception 'cannot ban owner'; end if;
  insert into public.group_bans(group_id, email, reason, banned_by) values (gid, em, reason, public.cur_email()) on conflict do nothing;
  if uid is not null then delete from public.group_members where group_id = gid and user_id = uid and role <> 'owner'; end if;
end $$;
create or replace function public.unban_email(gid uuid, p_email text) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.can_manage(gid) then raise exception 'forbidden'; end if;
  delete from public.group_bans where group_id = gid and email = lower(btrim(p_email));
end $$;
create or replace function public.list_bans(gid uuid) returns table(email text, reason text, banned_at timestamptz, banned_by text) language plpgsql stable security definer set search_path = public as $$
begin
  if not public.can_manage(gid) then raise exception 'forbidden'; end if;
  return query select b.email, b.reason, b.banned_at, b.banned_by from public.group_bans b where b.group_id = gid order by b.banned_at desc;
end $$;
create or replace function public.group_info(gid uuid) returns table(creator_email text, created_at timestamptz, join_enabled boolean) language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not (public.is_member(gid) or public.is_admin()) then raise exception 'forbidden'; end if;
  return query select u.email::text, g.created_at, g.join_enabled from public.groups g left join auth.users u on u.id = g.created_by where g.id = gid;
end $$;
create or replace function public.group_audit(gid uuid, p_limit integer default 100, p_before bigint default null)
returns setof public.audit_log language plpgsql stable security definer set search_path = public as $$
begin
  if not public.can_manage(gid) then raise exception 'forbidden'; end if;
  return query select * from public.audit_log a where a.group_id = gid and (p_before is null or a.id < p_before) order by a.id desc limit least(coalesce(p_limit,100),300);
end $$;

-- ===== trang quản trị tổng (chỉ quản trị viên) =====
create or replace function public.admin_groups()
returns table(id uuid, name text, created_at timestamptz, creator_email text, join_enabled boolean, members bigint, trips bigint, last_activity timestamptz)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query select g.id, g.name, g.created_at, u.email::text, g.join_enabled,
      (select count(*) from public.group_members m where m.group_id = g.id),
      (select count(*) from public.trips t where t.group_id = g.id and not t.deleted),
      (select max(t.updated_at) from public.trips t where t.group_id = g.id)
    from public.groups g left join auth.users u on u.id = g.created_by order by g.created_at desc;
end $$;
create or replace function public.admin_users()
returns table(user_id uuid, email text, created_at timestamptz, last_sign_in_at timestamptz, owned bigint, joined bigint, quota integer, custom boolean, is_admin boolean)
language plpgsql stable security definer set search_path = public, auth as $$
declare def integer;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  select coalesce((value #>> '{}')::int, 3) into def from public.app_settings where key = 'default_max_groups';
  return query select u.id, u.email::text, u.created_at, u.last_sign_in_at,
      (select count(*) from public.group_members m where m.user_id = u.id and m.role = 'owner'),
      (select count(*) from public.group_members m where m.user_id = u.id),
      coalesce(q.max_groups, def), q.email is not null,
      exists (select 1 from public.platform_admins a where a.user_id = u.id)
    from auth.users u left join public.user_quotas q on q.email = lower(u.email) order by u.created_at;
end $$;
create or replace function public.admin_settings() returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return jsonb_build_object('default_max_groups', (select coalesce((value #>> '{}')::int, 3) from public.app_settings where key='default_max_groups'));
end $$;
create or replace function public.admin_set_default_quota(n integer) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if n is null or n < 0 or n > 100 then raise exception 'bad value'; end if;
  update public.app_settings set value = to_jsonb(n) where key = 'default_max_groups';
  perform public.log_event('default_quota','quota',null,null,null,null,jsonb_build_object('max',n));
end $$;
create or replace function public.admin_set_quota(p_email text, n integer) returns void language plpgsql security definer set search_path = public as $$
declare em text := lower(btrim(coalesce(p_email,'')));
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if em !~ '^[^@\s]+@[^@\s]+$' then raise exception 'bad email'; end if;
  if n is null then delete from public.user_quotas where email = em;
  else
    if n < 0 or n > 100 then raise exception 'bad value'; end if;
    insert into public.user_quotas(email, max_groups, updated_by) values (em, n, public.cur_email())
      on conflict (email) do update set max_groups = excluded.max_groups, updated_at = now(), updated_by = excluded.updated_by;
  end if;
  perform public.log_event('quota','quota',null,null,null,em,jsonb_build_object('max',n));
end $$;
create or replace function public.admin_set_admin(p_email text, on_off boolean) returns void language plpgsql security definer set search_path = public, auth as $$
declare uid uuid; em text := lower(btrim(coalesce(p_email,'')));
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  select id into uid from auth.users where lower(email) = em;
  if uid is null then raise exception 'user not found'; end if;
  if on_off then insert into public.platform_admins(user_id, email) values (uid, em) on conflict do nothing;
  else
    if (select count(*) from public.platform_admins) <= 1 then raise exception 'last admin'; end if;
    delete from public.platform_admins where user_id = uid;
  end if;
  perform public.log_event(case when on_off then 'admin_add' else 'admin_remove' end,'admin',null,null,uid::text,em,null);
end $$;
create or replace function public.admin_audit(p_limit integer default 100, p_before bigint default null, p_entity text default null)
returns setof public.audit_log language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query select * from public.audit_log a where (p_before is null or a.id < p_before) and (p_entity is null or a.entity = p_entity)
    order by a.id desc limit least(coalesce(p_limit,100),300);
end $$;

-- quyền thực thi: chỉ người đã đăng nhập
do $$ declare f record; begin
  for f in select p.oid::regprocedure as sig from pg_proc p where p.pronamespace = 'public'::regnamespace
    and p.proname in ('is_admin','can_manage','cur_email','log_event','create_group','join_group','rename_group','delete_group','group_roster','set_member_role','remove_member','reset_codes','group_codes_get','set_join_enabled','ban_email','unban_email','list_bans','group_info','group_audit','admin_groups','admin_users','admin_settings','admin_set_default_quota','admin_set_quota','admin_set_admin','admin_audit')
  loop
    execute format('revoke all on function %s from public, anon', f.sig);
    execute format('grant execute on function %s to authenticated', f.sig);
  end loop;
  revoke all on function public.log_event(text,text,uuid,text,text,text,jsonb) from authenticated;   -- chỉ trigger/hàm khác gọi
end $$;

-- quản trị viên đầu tiên: chủ nhóm đầu tiên của hệ thống (tài khoản của chủ ứng dụng)
insert into public.platform_admins(user_id, email)
  select id, email from auth.users where lower(email) = 'dungnt12384@gmail.com' on conflict do nothing;
