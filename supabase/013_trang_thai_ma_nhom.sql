-- 013: Quản trị xem nhanh nhóm nào đang bật mã nhóm (chạy sau 012). Chỉ thêm hàm đọc.
--   admin_group_codes(): mỗi nhóm có mã: đang bật hay tắt, còn hạn không, hết hạn khi nào, bao nhiêu người đang xem bằng mã
-- Quay lại: drop function public.admin_group_codes();
create or replace function public.admin_group_codes()
returns table(group_id uuid, enabled boolean, active boolean, expires_at timestamptz, viewers bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query
  select c.group_id, c.enabled, c.enabled and c.expires_at > now(), c.expires_at,
    (select count(distinct a.user_id) from public.code_access a where a.kind = 'group' and a.target = c.group_id::text and a.ver = c.ver)
  from public.group_view_codes c;
end $$;
revoke all on function public.admin_group_codes() from public, anon;
grant execute on function public.admin_group_codes() to authenticated;
