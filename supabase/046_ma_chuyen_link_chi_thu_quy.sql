-- 046: Mã chuyến và link công khai chỉ thủ quỹ (leader) và quản trị viên được xem / tạo / gia hạn / thu hồi.
-- Trước đây người hỗ trợ (helper) cũng gọi được vì các hàm dùng can_edit_trip. Đổi sang can_lead_trip
-- (= quản trị viên hoặc thủ quỹ của chuyến). Người xem và người hỗ trợ gọi sẽ nhận lỗi 'forbidden'.
-- Quay lại: chạy lại các định nghĩa trong 007_leader_ma_chuyen.sql (đổi can_lead_trip về can_edit_trip).
-- Chạy file này trong Supabase: SQL Editor -> dán toàn bộ -> Run.

create or replace function public.trip_code_get(tid text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare c record;
begin
  if not public.can_lead_trip(tid) then raise exception 'forbidden'; end if;
  insert into public.trip_codes(trip_id, code) values (tid, public.gen_code('CH')) on conflict do nothing;
  select code, enabled, expires_at, ver into c from public.trip_codes where trip_id = tid;
  return jsonb_build_object('code', c.code, 'enabled', c.enabled, 'expires_at', c.expires_at,
    'hide_in_group', (select hide_in_group from public.trips where id = tid));
end $$;

create or replace function public.create_share(p_trip text) returns text
language plpgsql security definer set search_path = public as $$
declare gid uuid; tok text; ex timestamptz;
begin
  if not public.can_lead_trip(p_trip) then raise exception 'forbidden'; end if;
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
  if not public.can_lead_trip(p_trip) then raise exception 'forbidden'; end if;
  return (select jsonb_build_object('token', token, 'expires_at', expires_at, 'expired', expires_at <= now()) from public.trip_shares where trip_id = p_trip);
end $$;

create or replace function public.renew_share(p_trip text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_lead_trip(p_trip) then raise exception 'forbidden'; end if;
  update public.trip_shares set expires_at = now() + interval '3 months' where trip_id = p_trip;
end $$;

create or replace function public.revoke_share(p_trip text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_lead_trip(p_trip) then raise exception 'forbidden'; end if;
  delete from public.trip_shares where trip_id = p_trip;
end $$;
