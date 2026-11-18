-- Bản cập nhật 2: vai trò thành viên, mã mời riêng cho người nhập / người xem,
-- phát hiện sửa trùng (phiên bản chuyến), và link xem công khai chỉ đọc.
-- Chạy một lần trong SQL Editor của Supabase (sau supabase/schema.sql).

-- ========== 1. Mã mời tách riêng, chỉ chủ nhóm đọc được ==========
create table if not exists public.group_codes (
  group_id uuid primary key references public.groups(id) on delete cascade,
  edit_code text not null unique,
  view_code text not null unique
);
alter table public.group_codes enable row level security;
drop policy if exists codes_select on public.group_codes;
create policy codes_select on public.group_codes for select to authenticated
  using (exists (select 1 from public.group_members m
                 where m.group_id = group_codes.group_id and m.user_id = auth.uid() and m.role = 'owner'));

-- chuyển mã mời cũ (nếu còn cột invite_code) sang bảng mới
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='groups' and column_name='invite_code') then
    insert into public.group_codes(group_id, edit_code, view_code)
      select id, invite_code, substr(replace(gen_random_uuid()::text,'-',''),1,10) from public.groups
      on conflict do nothing;
  end if;
end $$;

create or replace function public.new_code() returns text language sql volatile as $$
  select substr(replace(gen_random_uuid()::text,'-',''),1,10)
$$;

create or replace function public.create_group(gname text)
returns public.groups language plpgsql security definer set search_path = public as $$
declare g public.groups;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  insert into public.groups(name, created_by) values (gname, auth.uid()) returning * into g;
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
  r := case when gc.edit_code = code then 'editor' else 'viewer' end;
  insert into public.group_members(group_id, user_id, role) values (gc.group_id, auth.uid(), r)
    on conflict do nothing;
  select * into g from public.groups where id = gc.group_id;
  return g;
end $$;

alter table public.groups drop column if exists invite_code;

-- ========== 2. Quản lý thành viên (chỉ chủ nhóm) ==========
create or replace function public.is_owner(gid uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.group_members m where m.group_id = gid and m.user_id = auth.uid() and m.role = 'owner')
$$;

create or replace function public.group_roster(gid uuid)
returns table(user_id uuid, email text, role text, joined_at timestamptz)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.is_owner(gid) then raise exception 'forbidden'; end if;
  return query
    select m.user_id, u.email::text, m.role, m.joined_at
    from public.group_members m join auth.users u on u.id = m.user_id
    where m.group_id = gid order by m.joined_at;
end $$;

create or replace function public.set_member_role(gid uuid, uid uuid, new_role text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner(gid) then raise exception 'forbidden'; end if;
  if new_role not in ('editor','viewer') then raise exception 'bad role'; end if;
  update public.group_members set role = new_role
    where group_id = gid and user_id = uid and role <> 'owner';
end $$;

create or replace function public.remove_member(gid uuid, uid uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner(gid) then raise exception 'forbidden'; end if;
  delete from public.group_members where group_id = gid and user_id = uid and role <> 'owner';
end $$;

create or replace function public.reset_codes(gid uuid)
returns public.group_codes language plpgsql security definer set search_path = public as $$
declare gc public.group_codes;
begin
  if not public.is_owner(gid) then raise exception 'forbidden'; end if;
  update public.group_codes set edit_code = public.new_code(), view_code = public.new_code()
    where group_id = gid returning * into gc;
  return gc;
end $$;

-- ========== 3. Phiên bản chuyến để phát hiện sửa trùng ==========
alter table public.trips add column if not exists rev integer not null default 1;

create or replace function public.save_trip(p_id text, p_group uuid, p_data jsonb, p_base integer, p_force boolean default false)
returns jsonb language plpgsql security definer set search_path = public as $$
declare cur integer; cur_data jsonb;
begin
  if not public.is_member(p_group, true) then raise exception 'forbidden'; end if;
  select rev, data into cur, cur_data from public.trips where id = p_id and group_id = p_group for update;
  if not found then
    insert into public.trips(id, group_id, data, rev) values (p_id, p_group, p_data, 1);
    return jsonb_build_object('ok', true, 'rev', 1);
  end if;
  if cur = p_base or p_force then
    update public.trips set data = p_data, rev = cur + 1, deleted = false where id = p_id and group_id = p_group;
    return jsonb_build_object('ok', true, 'rev', cur + 1);
  end if;
  return jsonb_build_object('ok', false, 'conflict', true, 'rev', cur, 'data', cur_data);
end $$;

-- ========== 4. Link xem công khai (chỉ đọc, thu hồi được) ==========
create table if not exists public.trip_shares (
  token text primary key default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  group_id uuid not null references public.groups(id) on delete cascade,
  trip_id text not null references public.trips(id) on delete cascade,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);
create unique index if not exists trip_shares_trip_idx on public.trip_shares(trip_id);
alter table public.trip_shares enable row level security;
drop policy if exists shares_select on public.trip_shares;
create policy shares_select on public.trip_shares for select to authenticated using (public.is_member(group_id, true));

create or replace function public.create_share(p_trip text)
returns text language plpgsql security definer set search_path = public as $$
declare gid uuid; tok text;
begin
  select group_id into gid from public.trips where id = p_trip;
  if gid is null or not public.is_member(gid, true) then raise exception 'forbidden'; end if;
  select token into tok from public.trip_shares where trip_id = p_trip;
  if tok is null then
    insert into public.trip_shares(group_id, trip_id) values (gid, p_trip) returning token into tok;
  end if;
  return tok;
end $$;

create or replace function public.revoke_share(p_trip text)
returns void language plpgsql security definer set search_path = public as $$
declare gid uuid;
begin
  select group_id into gid from public.trips where id = p_trip;
  if gid is null or not public.is_member(gid, true) then raise exception 'forbidden'; end if;
  delete from public.trip_shares where trip_id = p_trip;
end $$;

create or replace function public.get_shared_trip(p_token text)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('data', t.data, 'rev', t.rev)
  from public.trip_shares s join public.trips t on t.id = s.trip_id
  where s.token = p_token
$$;

-- ========== 5. Quyền thực thi ==========
revoke all on function public.new_code() from public, anon, authenticated;
revoke all on function public.is_owner(uuid) from public, anon;
revoke all on function public.group_roster(uuid) from public, anon;
revoke all on function public.set_member_role(uuid, uuid, text) from public, anon;
revoke all on function public.remove_member(uuid, uuid) from public, anon;
revoke all on function public.reset_codes(uuid) from public, anon;
revoke all on function public.save_trip(text, uuid, jsonb, integer, boolean) from public, anon;
revoke all on function public.create_share(text) from public, anon;
revoke all on function public.revoke_share(text) from public, anon;
revoke all on function public.create_group(text) from public, anon;
revoke all on function public.join_group(text) from public, anon;
revoke all on function public.get_shared_trip(text) from public;
grant execute on function public.is_owner(uuid) to authenticated;
grant execute on function public.group_roster(uuid) to authenticated;
grant execute on function public.set_member_role(uuid, uuid, text) to authenticated;
grant execute on function public.remove_member(uuid, uuid) to authenticated;
grant execute on function public.reset_codes(uuid) to authenticated;
grant execute on function public.save_trip(text, uuid, jsonb, integer, boolean) to authenticated;
grant execute on function public.create_share(text) to authenticated;
grant execute on function public.revoke_share(text) to authenticated;
grant execute on function public.create_group(text) to authenticated;
grant execute on function public.join_group(text) to authenticated;
grant execute on function public.get_shared_trip(text) to anon, authenticated;
