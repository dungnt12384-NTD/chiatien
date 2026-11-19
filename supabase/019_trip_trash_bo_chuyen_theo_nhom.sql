-- 019: Thùng rác chuyến không liệt kê / không tự dọn các chuyến bị ẩn theo nhóm đã xoá (by_group, xem 018).
--   Các chuyến đó chỉ khôi phục bằng "Khôi phục nhóm" ở Thùng rác nhóm. Chỉ sửa hàm.
-- Quay lại: chạy lại trip_trash bản cũ (bỏ 2 điều kiện "not t.by_group").

create or replace function public.trip_trash(gid uuid)
returns table(id text, name text, deleted_at timestamptz, deleted_by_email text, days_left integer)
language plpgsql security definer set search_path = public, auth as $$
begin
  delete from public.trips t where t.group_id = gid and t.deleted and not t.by_group and t.deleted_at < now() - interval '30 days';
  return query select t.id, coalesce(t.data ->> 'name', '(không tên)'), t.deleted_at, u.email::text,
      greatest(0, 30 - extract(day from now() - t.deleted_at)::int)
    from public.trips t left join auth.users u on u.id = t.deleted_by
    where t.group_id = gid and t.deleted and not t.by_group and public.can_lead_trip(t.id) order by t.deleted_at desc nulls last;
end $$;
