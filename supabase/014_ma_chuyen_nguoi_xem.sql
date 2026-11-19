-- 014: (chạy sau 013) Chỉ thêm hàm đọc, không đổi bảng, không đổi dữ liệu.
--   admin_trip_codes(): quản trị xem chuyến nào đang bật mã chuyến, bao nhiêu người đang xem bằng mã chuyến
--   trip_viewers(tid) : quản trị viên hoặc BTC của nhóm xem ai đang có quyền xem chuyến (vai trò / mã chuyến / mã nhóm),
--                       vào từ khi nào, hoạt động lần cuối, đang đăng nhập trên mấy thiết bị
-- Quay lại: drop function public.admin_trip_codes(); drop function public.trip_viewers(text);

create or replace function public.admin_trip_codes()
returns table(trip_id text, enabled boolean, active boolean, expires_at timestamptz, viewers bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query
  select c.trip_id, c.enabled, c.enabled and c.expires_at > now(), c.expires_at,
    (select count(distinct a.user_id) from public.code_access a where a.kind = 'trip' and a.target = c.trip_id and a.ver = c.ver)
  from public.trip_codes c join public.trips t on t.id = c.trip_id where not t.deleted;
end $$;

create or replace function public.trip_viewers(tid text)
returns table(email text, anon boolean, via text, since timestamptz, last_active timestamptz, sessions bigint)
language plpgsql stable security definer set search_path = public, auth as $$
declare gid uuid; ok boolean;
begin
  select t.group_id, true into gid, ok from public.trips t where t.id = tid and not t.deleted;
  if ok is null then raise exception 'not_found'; end if;
  if not (public.is_admin() or (gid is not null and public.is_organizer(gid))) then raise exception 'forbidden'; end if;
  return query
  with x as (
    select u.id as uid, lower(r.email) as em, r.role as via, r.added_at as since
      from public.trip_roles r
      left join lateral (select y.id from auth.users y where lower(y.email) = lower(r.email) and not coalesce(y.is_anonymous, false) limit 1) u on true
      where r.trip_id = tid
    union all
    select a.user_id, null, 'trip_code', a.at
      from public.code_access a join public.trip_codes c on c.trip_id = a.target
      where a.kind = 'trip' and a.target = tid and a.ver = c.ver and c.enabled and c.expires_at > now()
    union all
    select a.user_id, null, 'group_code', a.at
      from public.trips t join public.group_view_codes g on g.group_id = t.group_id
      join public.code_access a on a.kind = 'group' and a.target = t.group_id::text and a.ver = g.ver
      where t.id = tid and not t.hide_in_group and g.enabled and g.expires_at > now()
  )
  select coalesce(x.em, lower(u.email::text)), coalesce(u.is_anonymous, false), x.via, x.since,
    (select max(coalesce(s.refreshed_at::timestamptz, s.updated_at, s.created_at)) from auth.sessions s where s.user_id = x.uid),
    (select count(*) from auth.sessions s where s.user_id = x.uid and (s.not_after is null or s.not_after > now()))
  from x left join auth.users u on u.id = x.uid
  order by 5 desc nulls last, 4 desc;
end $$;

revoke all on function public.admin_trip_codes() from public, anon;
revoke all on function public.trip_viewers(text) from public, anon;
grant execute on function public.admin_trip_codes() to authenticated;
grant execute on function public.trip_viewers(text) to authenticated;
