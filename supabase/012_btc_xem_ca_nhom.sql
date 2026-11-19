-- 012: BTC (người tổ chức) xem được MỌI chuyến trong nhóm mình (chỉ xem; sửa vẫn theo vai trò leader / người phụ trách).
--   Kể cả chuyến leader đã "ẩn khỏi mã nhóm" (ẩn chỉ áp dụng cho người vào bằng mã nhóm).
-- Chỉ đổi hàm, không đổi bảng, không đổi dữ liệu.
-- Quay lại: chạy lại phần can_view_trip / my_group_access của 011 và bản can_view_trip cũ (không có dòng is_organizer).

create or replace function public.can_view_trip(tid text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.can_edit_trip(tid)
    or exists (select 1 from public.trips t where t.id = tid and not t.deleted and public.is_organizer(t.group_id))
    or exists (select 1 from public.code_access a join public.trip_codes c on c.trip_id = a.target
               where a.user_id = auth.uid() and a.kind = 'trip' and a.target = tid and a.ver = c.ver and c.enabled and c.expires_at > now())
    or exists (select 1 from public.trips t
               join public.group_view_codes g on g.group_id = t.group_id
               join public.code_access a on a.kind = 'group' and a.target = t.group_id::text and a.user_id = auth.uid() and a.ver = g.ver
               where t.id = tid and not t.hide_in_group and not t.deleted and g.enabled and g.expires_at > now()) $$;

create or replace function public.my_group_access()
returns table(id uuid, name text, is_admin boolean, is_organizer boolean, group_code text, group_code_expires timestamptz, trips jsonb)
language plpgsql stable security definer set search_path = public as $$
declare me text := public.my_email(); adm boolean := public.is_admin();
begin
  if auth.uid() is null then raise exception 'need_session'; end if;
  return query
  select g.id, g.name, adm, public.is_organizer(g.id),
    (select case when c.group_id is null then 'gone' when a.ver = c.ver and c.enabled and c.expires_at > now() then 'valid' else 'off' end
       from public.code_access a left join public.group_view_codes c on c.group_id::text = a.target
       where a.user_id = auth.uid() and a.kind = 'group' and a.target = g.id::text),
    (select c.expires_at from public.code_access a join public.group_view_codes c on c.group_id::text = a.target
       where a.user_id = auth.uid() and a.kind = 'group' and a.target = g.id::text),
    coalesce((select jsonb_agg(jsonb_build_object(
        'id', t.id, 'name', coalesce(nullif(t.data ->> 'name', ''), '(chưa đặt tên)'), 'closed', t.closed_at is not null,
        'role', coalesce((select r.role from public.trip_roles r where r.trip_id = t.id and r.email = me order by (r.role = 'leader') desc limit 1),
                         case when adm then 'admin' else 'viewer' end),
        'via', case
          when exists (select 1 from public.trip_roles r where r.trip_id = t.id and r.email = me) then 'role'
          when adm then 'admin'
          when public.is_organizer(g.id) then 'organizer'
          when exists (select 1 from public.code_access a join public.trip_codes c on c.trip_id = a.target
                        where a.user_id = auth.uid() and a.kind = 'trip' and a.target = t.id and a.ver = c.ver and c.enabled and c.expires_at > now()) then 'trip_code'
          else 'group_code' end)
        order by t.updated_at desc)
      from public.trips t where t.group_id = g.id and not t.deleted and public.can_view_trip(t.id)), '[]'::jsonb)
  from public.groups g where public.can_see_group(g.id)
  order by g.created_at;
end $$;
