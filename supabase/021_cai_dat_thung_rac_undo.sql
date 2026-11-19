-- 021: Cài đặt chung chỉnh được ở tab Quản trị > Cài đặt:
--   trash_days: số ngày giữ chuyến trong thùng rác trước khi tự xoá hẳn (0 = không bao giờ tự xoá). Mặc định 30 (như cũ).
--   undo_max  : số bước Hoàn tác / Làm lại mỗi chuyến nhớ trên máy (5..500). Mặc định 50.
--   Thêm 2 dòng app_settings (không ghi đè nếu đã có), hàm get_app_prefs / set_app_pref, trip_trash đọc trash_days.
-- Quay lại: chạy lại trip_trash bản 019 (30 ngày cố định); drop function get_app_prefs(), set_app_pref(text,integer);
--           delete from app_settings where key in ('trash_days','undo_max');

insert into public.app_settings(key, value) values ('trash_days', to_jsonb(30)), ('undo_max', to_jsonb(50))
  on conflict (key) do nothing;

create or replace function public.app_pref_int(k text, d integer)
returns integer language sql stable security definer set search_path = public as $$
  select coalesce((select (value #>> '{}')::int from public.app_settings where key = k), d) $$;

create or replace function public.get_app_prefs()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'need_session'; end if;
  return jsonb_build_object('trash_days', public.app_pref_int('trash_days', 30), 'undo_max', public.app_pref_int('undo_max', 50));
end $$;

create or replace function public.set_app_pref(k text, n integer)
returns void language plpgsql security definer set search_path = public as $$
declare o integer;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if k = 'trash_days' then if n is null or n < 0 or n > 3650 then raise exception 'bad_value'; end if;
  elsif k = 'undo_max' then if n is null or n < 5 or n > 500 then raise exception 'bad_value'; end if;
  else raise exception 'bad_value'; end if;
  o := public.app_pref_int(k, null);
  insert into public.app_settings(key, value) values (k, to_jsonb(n)) on conflict (key) do update set value = excluded.value;
  perform public.log_event('app_pref', 'admin', null, null, k,
    case when k = 'trash_days' then 'Thùng rác tự dọn' else 'Số bước hoàn tác' end, jsonb_build_object('old', o, 'new', n));
end $$;

create or replace function public.trip_trash(gid uuid)
returns table(id text, name text, deleted_at timestamptz, deleted_by_email text, days_left integer)
language plpgsql security definer set search_path = public, auth as $$
declare d integer := public.app_pref_int('trash_days', 30);
begin
  if d > 0 then
    delete from public.trips t where t.group_id = gid and t.deleted and not t.by_group and t.deleted_at < now() - make_interval(days => d);
  end if;
  return query select t.id, coalesce(t.data ->> 'name', '(không tên)'), t.deleted_at, u.email::text,
      case when d > 0 then greatest(0, d - extract(day from now() - t.deleted_at)::int) else null end
    from public.trips t left join auth.users u on u.id = t.deleted_by
    where t.group_id = gid and t.deleted and not t.by_group and public.can_lead_trip(t.id) order by t.deleted_at desc nulls last;
end $$;

revoke all on function public.get_app_prefs() from public, anon;
revoke all on function public.set_app_pref(text, integer) from public, anon;
revoke all on function public.app_pref_int(text, integer) from public, anon;
grant execute on function public.get_app_prefs() to authenticated;
grant execute on function public.set_app_pref(text, integer) to authenticated;
