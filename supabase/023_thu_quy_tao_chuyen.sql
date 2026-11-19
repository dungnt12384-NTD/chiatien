-- 023: Gộp vai Nhóm trưởng vào Thủ quỹ (bước 1, chỉ thêm quyền, không đổi dữ liệu).
--   Tạo chuyến mới trong nhóm: quản trị viên, HOẶC đang là Thủ quỹ của ít nhất 1 chuyến (chưa xoá) trong nhóm đó.
--   is_organizer vẫn giữ trong lúc chuyển dữ liệu; khi bảng group_organizers trống thì vai này tự hết tác dụng.
-- Quay lại: create or replace function public.can_create_trip(gid uuid) ... select public.is_admin() or public.is_organizer(gid)

create or replace function public.can_create_trip(gid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or public.is_organizer(gid)
    or exists (select 1 from public.trips t join public.trip_roles r on r.trip_id = t.id
               where t.group_id = gid and not t.deleted and r.role = 'leader' and r.email = public.my_email()) $$;
