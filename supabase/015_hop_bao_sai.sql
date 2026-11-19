-- 015: Hộp "Báo sai cần xử lý" chung (chạy sau 014). Chỉ thêm / sửa hàm, không đổi bảng, không đổi dữ liệu.
--   can_handle_reports(tid): ai được xem và xử lý báo sai của chuyến = quản trị viên, leader / người phụ trách của chuyến, BTC của nhóm chứa chuyến
--   my_open_reports()      : mọi báo sai CHƯA xử lý ở các chuyến mình được xử lý (để không bỏ lỡ)
--   trip_reports_list / resolve_report: cho BTC của nhóm xem và xử lý (trước đây chỉ leader / người phụ trách / quản trị)
-- Quay lại: chạy lại bản trip_reports_list / resolve_report cũ (dùng can_edit_trip), drop 2 hàm mới.

create or replace function public.can_handle_reports(tid text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.can_edit_trip(tid)
    or exists (select 1 from public.trips t where t.id = tid and not t.deleted and t.group_id is not null and public.is_organizer(t.group_id)) $$;

create or replace function public.my_open_reports()
returns table(id bigint, trip_id text, trip_name text, group_id uuid, group_name text, item_label text, message text, reporter text, at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'need_session'; end if;
  return query
  select r.id, r.trip_id, coalesce(nullif(t.data ->> 'name', ''), '(chưa đặt tên)'), t.group_id, g.name,
         r.item_label, r.message, r.reporter, r.at
  from public.trip_reports r
  join public.trips t on t.id = r.trip_id and not t.deleted
  left join public.groups g on g.id = t.group_id
  where r.resolved_at is null and public.can_handle_reports(r.trip_id)
  order by r.at desc
  limit 200;
end $$;

create or replace function public.trip_reports_list(tid text)
returns table(id bigint, item_id text, item_label text, message text, reporter text, mine boolean, at timestamptz, resolved_at timestamptz, resolved_by text, reply text)
language plpgsql stable security definer set search_path = public as $$
declare ed boolean := public.can_handle_reports(tid);
begin
  if not public.can_view_trip(tid) then raise exception 'forbidden'; end if;
  return query select r.id, r.item_id, r.item_label, r.message, r.reporter, r.user_id = auth.uid(), r.at, r.resolved_at,
      case when ed then r.resolved_by else public.mask_email(r.resolved_by) end, r.reply
    from public.trip_reports r where r.trip_id = tid and (ed or r.user_id = auth.uid()) order by r.resolved_at nulls first, r.id desc;
end $$;

create or replace function public.resolve_report(p_id bigint, p_reply text)
returns void language plpgsql security definer set search_path = public as $$
declare tid text;
begin
  select trip_id into tid from public.trip_reports where id = p_id;
  if tid is null or not public.can_handle_reports(tid) then raise exception 'forbidden'; end if;
  update public.trip_reports set resolved_at = now(), resolved_by = public.my_email(), reply = left(coalesce(p_reply,''),500) where id = p_id;
end $$;

revoke all on function public.can_handle_reports(text) from public, anon;
revoke all on function public.my_open_reports() from public, anon;
grant execute on function public.can_handle_reports(text) to authenticated;
grant execute on function public.my_open_reports() to authenticated;
