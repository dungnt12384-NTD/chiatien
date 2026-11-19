-- 017: Xem lại báo sai ĐÃ xử lý (chạy sau 016). Chỉ thêm hàm, không đổi bảng / dữ liệu.
--   my_resolved_reports(p_limit): báo sai đã xử lý ở các chuyến mình được xử lý (quản trị viên, BTC nhóm, leader / người phụ trách),
--   mới nhất trước: ai xử lý, lúc nào, trả lời gì -> người khác trong BTC / leader biết đã có người xử lý.
-- Quay lại: drop function public.my_resolved_reports(integer);

create or replace function public.my_resolved_reports(p_limit integer default 50)
returns table(id bigint, trip_id text, trip_name text, group_id uuid, group_name text, item_label text, message text, reporter text,
              at timestamptz, resolved_at timestamptz, resolved_by text, reply text)
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'need_session'; end if;
  return query
  select r.id, r.trip_id, coalesce(nullif(t.data ->> 'name', ''), '(chưa đặt tên)'), t.group_id, g.name,
         r.item_label, r.message, r.reporter, r.at, r.resolved_at, r.resolved_by, r.reply
  from public.trip_reports r
  join public.trips t on t.id = r.trip_id and not t.deleted
  left join public.groups g on g.id = t.group_id
  where r.resolved_at is not null and public.can_handle_reports(r.trip_id)
  order by r.resolved_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
end $$;

revoke all on function public.my_resolved_reports(integer) from public, anon;
grant execute on function public.my_resolved_reports(integer) to authenticated;
