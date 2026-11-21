-- 047: Mã chuyến và Link công khai: quản trị viên chọn vai trò nào (thủ quỹ / người hỗ trợ / người xem) được dùng, riêng từng chuyến.
-- Mặc định chỉ thủ quỹ (giống 046). Quản trị viên luôn được dùng. Chỉ quản trị viên chỉnh được bảng này.
-- Quay lại: drop function trip_feature_get(text), trip_feature_set(text,text[],text[]), can_use_feature(text,text); drop table trip_feature_perm;
--           rồi chạy lại 046 và 016 (trip_code_act).

create table if not exists public.trip_feature_perm (
  trip_id text primary key references public.trips(id) on delete cascade,
  code_roles text[] not null default array['leader'],
  link_roles text[] not null default array['leader'],
  updated_at timestamptz not null default now(),
  updated_by text
);
alter table public.trip_feature_perm enable row level security;
revoke all on public.trip_feature_perm from anon, authenticated;

create or replace function public.can_use_feature(tid text, feat text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_admin() or exists (
    select 1 from public.trip_roles r
    left join public.trip_feature_perm p on p.trip_id = r.trip_id
    where r.trip_id = tid and r.email = public.my_email()
      and r.role = any (coalesce(case when feat = 'code' then p.code_roles else p.link_roles end, array['leader']))) $$;

create or replace function public.trip_feature_get(tid text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare p record;
begin
  if not public.can_view_trip(tid) then raise exception 'forbidden'; end if;
  select code_roles, link_roles into p from public.trip_feature_perm where trip_id = tid;
  return jsonb_build_object(
    'code_roles', to_jsonb(coalesce(p.code_roles, array['leader'])),
    'link_roles', to_jsonb(coalesce(p.link_roles, array['leader'])),
    'can_code', public.can_use_feature(tid, 'code'),
    'can_link', public.can_use_feature(tid, 'link'),
    'is_admin', public.is_admin());
end $$;

create or replace function public.trip_feature_set(tid text, p_code text[], p_link text[]) returns jsonb
language plpgsql security definer set search_path = public as $$
declare ok text[] := array['leader','helper','viewer'];
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if not (coalesce(p_code, '{}') <@ ok) or not (coalesce(p_link, '{}') <@ ok) then raise exception 'bad_role'; end if;
  insert into public.trip_feature_perm(trip_id, code_roles, link_roles, updated_by)
    values (tid, coalesce(p_code, '{}'), coalesce(p_link, '{}'), public.my_email())
  on conflict (trip_id) do update set code_roles = excluded.code_roles, link_roles = excluded.link_roles,
    updated_at = now(), updated_by = excluded.updated_by;
  return public.trip_feature_get(tid);
end $$;

-- các hàm mã / link dùng quyền theo vai trò thay vì chỉ thủ quỹ
create or replace function public.trip_code_get(tid text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare c record;
begin
  if not public.can_use_feature(tid, 'code') then raise exception 'forbidden'; end if;
  insert into public.trip_codes(trip_id, code) values (tid, public.gen_code('CH')) on conflict do nothing;
  select code, enabled, expires_at, ver into c from public.trip_codes where trip_id = tid;
  return jsonb_build_object('code', c.code, 'enabled', c.enabled, 'expires_at', c.expires_at,
    'hide_in_group', (select hide_in_group from public.trips where id = tid));
end $$;

create or replace function public.trip_code_act(tid text, p_act text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_use_feature(tid, 'code') then raise exception 'forbidden'; end if;
  perform public.trip_code_get(tid);
  if p_act = 'renew' then update public.trip_codes set expires_at = now() + public.code_days('trip') where trip_id = tid;
  elsif p_act = 'rotate' then update public.trip_codes set code = public.gen_code('CH'), ver = ver + 1, expires_at = now() + public.code_days('trip') where trip_id = tid;
  elsif p_act = 'lock' then update public.trip_codes set enabled = false where trip_id = tid;
  elsif p_act = 'unlock' then update public.trip_codes set enabled = true where trip_id = tid;
  elsif p_act = 'hide' then update public.trips set hide_in_group = true where id = tid;
  elsif p_act = 'show' then update public.trips set hide_in_group = false where id = tid;
  else raise exception 'bad_act'; end if;
  return public.trip_code_get(tid);
end $$;

create or replace function public.create_share(p_trip text) returns text
language plpgsql security definer set search_path = public as $$
declare gid uuid; tok text; ex timestamptz;
begin
  if not public.can_use_feature(p_trip, 'link') then raise exception 'forbidden'; end if;
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
  if not public.can_use_feature(p_trip, 'link') then raise exception 'forbidden'; end if;
  return (select jsonb_build_object('token', token, 'expires_at', expires_at, 'expired', expires_at <= now()) from public.trip_shares where trip_id = p_trip);
end $$;

create or replace function public.renew_share(p_trip text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_use_feature(p_trip, 'link') then raise exception 'forbidden'; end if;
  update public.trip_shares set expires_at = now() + interval '3 months' where trip_id = p_trip;
end $$;

create or replace function public.revoke_share(p_trip text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_use_feature(p_trip, 'link') then raise exception 'forbidden'; end if;
  delete from public.trip_shares where trip_id = p_trip;
end $$;

revoke all on function public.can_use_feature(text, text) from public, anon;
revoke all on function public.trip_feature_get(text) from public, anon;
revoke all on function public.trip_feature_set(text, text[], text[]) from public, anon;
grant execute on function public.can_use_feature(text, text) to authenticated;
grant execute on function public.trip_feature_get(text) to authenticated;
grant execute on function public.trip_feature_set(text, text[], text[]) to authenticated;
