-- 020: Tra cứu quyền cho quản trị viên (tab Quản trị > Tra cứu quyền).
--   Một hàm chỉ đọc, gom mọi quyền: quản trị viên, BTC nhóm, leader / người phụ trách chuyến,
--   người xem bằng mã nhóm / mã chuyến (chỉ mã đúng phiên bản hiện tại; active = mã còn bật và còn hạn).
--   Chỉ thêm hàm, không sửa bảng / dữ liệu.
-- Quay lại: drop function public.admin_permissions();

create or replace function public.admin_permissions()
returns table(email text, scope text, role text, group_id uuid, group_name text, trip_id text, trip_name text,
              tabs text[], active boolean, deleted boolean, closed boolean, at timestamptz)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query
  -- quản trị viên
  select x.e, 'system'::text, 'admin'::text, null::uuid, null::text, null::text, null::text, null::text[], true, false, false, null::timestamptz
    from (select lower(a.email) e from public.admin_emails a
          union select lower(p.email) from public.platform_admins p where p.email is not null) x
  union all
  -- BTC nhóm
  select lower(o.email), 'group', 'organizer', g.id, g.name, null, null, null, true, g.deleted_at is not null, false, o.added_at
    from public.group_organizers o join public.groups g on g.id = o.group_id
  union all
  -- leader / người phụ trách chuyến
  select lower(r.email), 'trip', r.role, g.id, g.name, t.id, coalesce(nullif(t.data ->> 'name', ''), '(chưa đặt tên)'),
         r.tabs, true, coalesce(t.deleted, false) or g.deleted_at is not null, t.closed_at is not null, r.added_at
    from public.trip_roles r join public.trips t on t.id = r.trip_id left join public.groups g on g.id = t.group_id
  union all
  -- xem bằng mã nhóm
  select lower(u.email), 'group', 'code_group', g.id, g.name, null, null, null,
         c.enabled and c.expires_at > now(), g.deleted_at is not null, false, a.at
    from public.code_access a join public.groups g on g.id::text = a.target
    join public.group_view_codes c on c.group_id = g.id and c.ver = a.ver
    left join auth.users u on u.id = a.user_id
   where a.kind = 'group'
  union all
  -- xem bằng mã chuyến
  select lower(u.email), 'trip', 'code_trip', g.id, g.name, t.id, coalesce(nullif(t.data ->> 'name', ''), '(chưa đặt tên)'), null,
         c.enabled and c.expires_at > now(), coalesce(t.deleted, false) or g.deleted_at is not null, t.closed_at is not null, a.at
    from public.code_access a join public.trips t on t.id = a.target
    join public.trip_codes c on c.trip_id = t.id and c.ver = a.ver
    left join public.groups g on g.id = t.group_id
    left join auth.users u on u.id = a.user_id
   where a.kind = 'trip';
end $$;

revoke all on function public.admin_permissions() from public, anon;
grant execute on function public.admin_permissions() to authenticated;
