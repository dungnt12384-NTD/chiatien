-- 011: Tổng quan nhóm (chạy sau 010). Chỉ thêm hàm đọc, không đổi bảng, không đổi dữ liệu.
--   admin_groups_overview(): quản trị viên xem mỗi nhóm có chuyến nào (kèm leader), ai là BTC (người tổ chức)
--                            và hoạt động đăng nhập của từng BTC (lần đăng nhập cuối, lần hoạt động cuối, số thiết bị đang đăng nhập)
--   my_group_access()      : người dùng xem mình thấy nhóm nào, nhờ đâu (quản trị viên / BTC do quản trị gán / mã nhóm / mã chuyến / vai trò chuyến)
--                            và từng chuyến mình có quyền gì
-- Quay lại: drop function public.admin_groups_overview(); drop function public.my_group_access();

create or replace function public.admin_groups_overview()
returns table(id uuid, name text, created_at timestamptz, creator_email text, trips jsonb, organizers jsonb)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query
  select g.id, g.name, g.created_at, cu.email::text,
    coalesce((select jsonb_agg(jsonb_build_object(
        'id', t.id, 'name', coalesce(nullif(t.data ->> 'name', ''), '(chưa đặt tên)'),
        'closed', t.closed_at is not null, 'hidden', t.hide_in_group,
        'leaders', coalesce((select jsonb_agg(r.email order by r.email) from public.trip_roles r where r.trip_id = t.id and r.role = 'leader'), '[]'::jsonb),
        'helpers', (select count(*) from public.trip_roles r where r.trip_id = t.id and r.role = 'helper'))
        order by t.updated_at desc)
      from public.trips t where t.group_id = g.id and not t.deleted), '[]'::jsonb),
    coalesce((select jsonb_agg(jsonb_build_object(
        'email', o.email, 'added_at', o.added_at, 'added_by', o.added_by,
        'signed_up', u.id is not null, 'last_sign_in_at', u.last_sign_in_at,
        'last_active', (select max(coalesce(s.refreshed_at, s.updated_at, s.created_at)) from auth.sessions s where s.user_id = u.id),
        'sessions', (select count(*) from auth.sessions s where s.user_id = u.id and (s.not_after is null or s.not_after > now())),
        'devices', coalesce((select jsonb_agg(distinct case
            when s.user_agent ilike '%ipad%' then 'iPad' when s.user_agent ilike '%iphone%' then 'iPhone'
            when s.user_agent ilike '%android%' then 'Android' when s.user_agent ilike '%windows%' then 'Windows'
            when s.user_agent ilike '%mac os%' or s.user_agent ilike '%macintosh%' then 'Mac / iPad' else 'Khác' end)
          from auth.sessions s where s.user_id = u.id and (s.not_after is null or s.not_after > now())), '[]'::jsonb))
        order by o.added_at)
      from public.group_organizers o
      left join lateral (select x.id, x.last_sign_in_at from auth.users x where lower(x.email) = o.email and not coalesce(x.is_anonymous, false) limit 1) u on true
      where o.group_id = g.id), '[]'::jsonb)
  from public.groups g left join auth.users cu on cu.id = g.created_by
  order by g.created_at desc;
end $$;

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
          when exists (select 1 from public.code_access a join public.trip_codes c on c.trip_id = a.target
                        where a.user_id = auth.uid() and a.kind = 'trip' and a.target = t.id and a.ver = c.ver and c.enabled and c.expires_at > now()) then 'trip_code'
          else 'group_code' end)
        order by t.updated_at desc)
      from public.trips t where t.group_id = g.id and not t.deleted and public.can_view_trip(t.id)), '[]'::jsonb)
  from public.groups g where public.can_see_group(g.id)
  order by g.created_at;
end $$;

revoke all on function public.admin_groups_overview() from public, anon;
revoke all on function public.my_group_access() from public, anon;
grant execute on function public.admin_groups_overview() to authenticated;
grant execute on function public.my_group_access() to authenticated;
