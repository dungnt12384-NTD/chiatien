-- 010: Quản trị xem quyền theo chuyến của mọi tài khoản trong một lần gọi (chạy sau 009)
--   admin_account_trips(): mỗi dòng = 1 email có vai trò (leader / người phụ trách) ở 1 chuyến
-- Chỉ thêm hàm đọc, không đổi bảng, không đổi dữ liệu. Quay lại: drop function public.admin_account_trips();
create or replace function public.admin_account_trips()
returns table(email text, trip_id text, trip_name text, group_name text, role text, tabs text[],
              deleted boolean, closed boolean, added_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query
  select lower(r.email), r.trip_id, coalesce(nullif(t.data ->> 'name', ''), '(chưa đặt tên)'), g.name,
         r.role, r.tabs, coalesce(t.deleted, false), t.closed_at is not null, r.added_at
  from public.trip_roles r
  join public.trips t on t.id = r.trip_id
  left join public.groups g on g.id = t.group_id
  order by lower(r.email), coalesce(t.deleted, false), g.name, t.data ->> 'name';
end $$;
revoke all on function public.admin_account_trips() from public, anon;
grant execute on function public.admin_account_trips() to authenticated;
