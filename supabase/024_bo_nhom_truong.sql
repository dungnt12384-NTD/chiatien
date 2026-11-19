-- 024: Bỏ vai "Nhóm trưởng". group_organizers chỉ còn là cờ "được tạo chuyến mới trong nhóm" (quản trị viên cấp),
--   KHÔNG còn quyền xem mọi chuyến của nhóm và KHÔNG còn xử lý báo sai thay người khác.
--   Quyền xem / sửa / báo sai chỉ theo chuyến: quản trị viên, Thủ quỹ, Người hỗ trợ, mã xem.
--   Không xoá dòng dữ liệu nào.
-- Quay lại (bản 023 trở về trước):
--   can_view_trip: thêm lại  or exists (select 1 from public.trips t where t.id = tid and not t.deleted and public.is_organizer(t.group_id))
--   can_handle_reports: thêm lại  or exists (select 1 from public.trips t where t.id = tid and not t.deleted and t.group_id is not null and public.is_organizer(t.group_id))

create or replace function public.can_view_trip(tid text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.can_edit_trip(tid)
    or exists (select 1 from public.code_access a join public.trip_codes c on c.trip_id = a.target
               where a.user_id = auth.uid() and a.kind = 'trip' and a.target = tid and a.ver = c.ver and c.enabled and c.expires_at > now())
    or exists (select 1 from public.trips t
               join public.group_view_codes g on g.group_id = t.group_id
               join public.code_access a on a.kind = 'group' and a.target = t.group_id::text and a.user_id = auth.uid() and a.ver = g.ver
               where t.id = tid and not t.hide_in_group and not t.deleted and g.enabled and g.expires_at > now()) $$;

create or replace function public.can_handle_reports(tid text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.can_edit_trip(tid) $$;
