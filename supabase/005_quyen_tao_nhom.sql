-- Phân quyền được/không được tạo nhóm; quản trị viên có toàn quyền trên mọi nhóm. (Chạy sau 004)
alter table public.user_quotas alter column max_groups drop not null;
alter table public.user_quotas add column if not exists can_create boolean;   -- null = theo mặc định
insert into public.app_settings(key, value) values ('default_can_create', 'true') on conflict do nothing;

-- quản trị viên được coi là thành viên có quyền sửa của mọi nhóm
create or replace function public.is_member(gid uuid, need_edit boolean default false)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or exists (
    select 1 from public.group_members m
    where m.group_id = gid and m.user_id = auth.uid() and (not need_edit or m.role in ('owner','editor')));
$$;

create or replace function public.can_create_group() returns jsonb language plpgsql stable security definer set search_path = public as $$
declare lim integer; allow boolean; own integer;
begin
  if auth.uid() is null then return jsonb_build_object('allowed', false); end if;
  if public.is_admin() then return jsonb_build_object('allowed', true, 'limit', null); end if;
  select max_groups, can_create into lim, allow from public.user_quotas where email = public.cur_email();
  if lim is null then select (value #>> '{}')::int into lim from public.app_settings where key = 'default_max_groups'; end if;
  if allow is null then select (value #>> '{}')::boolean into allow from public.app_settings where key = 'default_can_create'; end if;
  lim := coalesce(lim, 3); allow := coalesce(allow, true);
  select count(*) into own from public.group_members where user_id = auth.uid() and role = 'owner';
  return jsonb_build_object('allowed', allow and own < lim, 'permitted', allow, 'limit', lim, 'owned', own);
end $$;

create or replace function public.create_group(gname text)
returns public.groups language plpgsql security definer set search_path = public as $$
declare g public.groups; n text := btrim(regexp_replace(coalesce(gname,''), '\s+', ' ', 'g')); c jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if n = '' or length(n) > 40 then raise exception 'invalid name'; end if;
  c := public.can_create_group();
  if not (c ->> 'allowed')::boolean then
    if (c ->> 'permitted') is not null and not (c ->> 'permitted')::boolean then raise exception 'create forbidden'; end if;
    raise exception 'group limit';
  end if;
  insert into public.groups(name, created_by) values (n, auth.uid()) returning * into g;
  insert into public.group_members(group_id, user_id, role) values (g.id, auth.uid(), 'owner');
  insert into public.group_codes(group_id, edit_code, view_code) values (g.id, public.new_code(), public.new_code());
  return g;
end $$;

drop function if exists public.admin_users();
create or replace function public.admin_users()
returns table(user_id uuid, email text, created_at timestamptz, last_sign_in_at timestamptz, owned bigint, joined bigint,
              quota integer, custom boolean, can_create boolean, can_custom boolean, is_admin boolean)
language plpgsql stable security definer set search_path = public, auth as $$
declare def integer; defc boolean;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  select coalesce((value #>> '{}')::int, 3) into def from public.app_settings where key = 'default_max_groups';
  select coalesce((value #>> '{}')::boolean, true) into defc from public.app_settings where key = 'default_can_create';
  return query select u.id, u.email::text, u.created_at, u.last_sign_in_at,
      (select count(*) from public.group_members m where m.user_id = u.id and m.role = 'owner'),
      (select count(*) from public.group_members m where m.user_id = u.id),
      coalesce(q.max_groups, def), q.max_groups is not null,
      coalesce(q.can_create, defc), q.can_create is not null,
      exists (select 1 from public.platform_admins a where a.user_id = u.id)
    from auth.users u left join public.user_quotas q on q.email = lower(u.email) order by u.created_at;
end $$;
create or replace function public.admin_settings() returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return jsonb_build_object(
    'default_max_groups', (select coalesce((value #>> '{}')::int, 3) from public.app_settings where key='default_max_groups'),
    'default_can_create', (select coalesce((value #>> '{}')::boolean, true) from public.app_settings where key='default_can_create'));
end $$;
create or replace function public.admin_set_default_can_create(b boolean) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  update public.app_settings set value = to_jsonb(coalesce(b, true)) where key = 'default_can_create';
  perform public.log_event('default_can_create','quota',null,null,null,null,jsonb_build_object('allow',coalesce(b,true)));
end $$;
create or replace function public.admin_set_quota(p_email text, n integer) returns void language plpgsql security definer set search_path = public as $$
declare em text := lower(btrim(coalesce(p_email,'')));
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if em !~ '^[^@\s]+@[^@\s]+$' then raise exception 'bad email'; end if;
  if n is not null and (n < 0 or n > 100) then raise exception 'bad value'; end if;
  insert into public.user_quotas(email, max_groups, updated_by) values (em, n, public.cur_email())
    on conflict (email) do update set max_groups = excluded.max_groups, updated_at = now(), updated_by = excluded.updated_by;
  delete from public.user_quotas where email = em and max_groups is null and can_create is null;
  perform public.log_event('quota','quota',null,null,null,em,jsonb_build_object('max',n));
end $$;
create or replace function public.admin_set_can_create(p_email text, b boolean) returns void language plpgsql security definer set search_path = public as $$
declare em text := lower(btrim(coalesce(p_email,'')));
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if em !~ '^[^@\s]+@[^@\s]+$' then raise exception 'bad email'; end if;
  insert into public.user_quotas(email, can_create, updated_by) values (em, b, public.cur_email())
    on conflict (email) do update set can_create = excluded.can_create, updated_at = now(), updated_by = excluded.updated_by;
  delete from public.user_quotas where email = em and max_groups is null and can_create is null;
  perform public.log_event('can_create','quota',null,null,null,em,jsonb_build_object('allow',b));
end $$;

do $$ declare f record; begin
  for f in select p.oid::regprocedure as sig from pg_proc p where p.pronamespace = 'public'::regnamespace
    and p.proname in ('is_member','can_create_group','create_group','admin_users','admin_settings','admin_set_default_can_create','admin_set_quota','admin_set_can_create')
  loop
    execute format('revoke all on function %s from public, anon', f.sig);
    execute format('grant execute on function %s to authenticated', f.sig);
  end loop;
end $$;
