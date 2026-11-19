-- 016: Cài đặt mặc định của mã chuyến / mã nhóm (chạy sau 015). Chỉ THÊM bảng cài đặt nhỏ + hàm + trigger, không sửa dữ liệu cũ.
--   code_settings(kind 'trip'|'group', default_enabled, days): quản trị viên chỉnh ở tab Quản trị > Cài đặt mã
--   Mã TẠO MỚI lấy bật/tắt + hạn theo cài đặt (trigger trước khi insert). Gia hạn / đổi mã dùng số ngày theo cài đặt.
--   Mặc định giữ như cũ: mã chuyến BẬT 90 ngày, mã nhóm TẮT 90 ngày.
-- Quay lại: drop trigger trg_trip_code_def, trg_group_code_def; chạy lại trip_code_act / group_code_act bản 007; drop bảng code_settings và các hàm mới.

create table if not exists public.code_settings(
  kind text primary key check (kind in ('trip','group')),
  default_enabled boolean not null,
  days integer not null check (days between 1 and 3650),
  updated_at timestamptz not null default now(),
  updated_by text);
alter table public.code_settings enable row level security;   -- không policy: chỉ đọc/ghi qua hàm
insert into public.code_settings(kind, default_enabled, days) values ('trip', true, 90), ('group', false, 90) on conflict do nothing;

create or replace function public.code_days(k text) returns interval
language sql stable security definer set search_path = public as $$
  select make_interval(days => coalesce((select days from public.code_settings where kind = k), 90)) $$;

create or replace function public.trg_code_defaults() returns trigger
language plpgsql security definer set search_path = public as $$
declare k text := case when tg_table_name = 'trip_codes' then 'trip' else 'group' end; s record;
begin
  select default_enabled, days into s from public.code_settings where kind = k;
  if found then new.enabled := s.default_enabled; new.expires_at := now() + make_interval(days => s.days); end if;
  return new;
end $$;
drop trigger if exists trg_trip_code_def on public.trip_codes;
create trigger trg_trip_code_def before insert on public.trip_codes for each row execute function public.trg_code_defaults();
drop trigger if exists trg_group_code_def on public.group_view_codes;
create trigger trg_group_code_def before insert on public.group_view_codes for each row execute function public.trg_code_defaults();

create or replace function public.trip_code_act(tid text, p_act text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_lead_trip(tid) then raise exception 'forbidden'; end if;
  perform public.trip_code_get(tid);
  if p_act = 'renew' then update public.trip_codes set expires_at = now() + public.code_days('trip') where trip_id = tid;
  elsif p_act = 'rotate' then update public.trip_codes set code = public.gen_code('CH'), ver = ver + 1, expires_at = now() + public.code_days('trip') where trip_id = tid;
  elsif p_act = 'lock' then update public.trip_codes set enabled = false where trip_id = tid;
  elsif p_act = 'unlock' then update public.trip_codes set enabled = true where trip_id = tid;
  elsif p_act = 'hide' then update public.trips set hide_in_group = true where id = tid;
  elsif p_act = 'show' then update public.trips set hide_in_group = false where id = tid;
  else raise exception 'bad_act'; end if;
  return public.trip_code_get(tid);
end $$;

create or replace function public.group_code_act(gid uuid, p_act text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  perform public.group_code_get(gid);
  if p_act = 'renew' then update public.group_view_codes set expires_at = now() + public.code_days('group') where group_id = gid;
  elsif p_act = 'rotate' then update public.group_view_codes set code = public.gen_code('NH'), ver = ver + 1, expires_at = now() + public.code_days('group') where group_id = gid;
  elsif p_act = 'lock' then update public.group_view_codes set enabled = false where group_id = gid;
  elsif p_act = 'unlock' then update public.group_view_codes set enabled = true, expires_at = greatest(expires_at, now() + public.code_days('group')) where group_id = gid;
  else raise exception 'bad_act'; end if;
  return public.group_code_get(gid);
end $$;

-- đọc cài đặt: mọi tài khoản đăng nhập (để hiện đúng chữ "gia hạn N ngày", đúng kiểu cảnh báo)
create or replace function public.get_code_settings() returns table(kind text, default_enabled boolean, days integer, updated_at timestamptz, updated_by text)
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'need_session'; end if;
  return query select c.kind, c.default_enabled, c.days, c.updated_at,
    case when public.is_admin() then c.updated_by else null end from public.code_settings c order by c.kind desc;
end $$;

-- sửa cài đặt: chỉ quản trị viên, ghi nhật ký quản trị
create or replace function public.set_code_settings(k text, p_enabled boolean, p_days integer) returns void
language plpgsql security definer set search_path = public as $$
declare o record;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if k not in ('trip','group') or p_enabled is null or p_days is null or p_days < 1 or p_days > 3650 then raise exception 'bad_value'; end if;
  select default_enabled, days into o from public.code_settings where kind = k;
  insert into public.code_settings(kind, default_enabled, days, updated_at, updated_by) values (k, p_enabled, p_days, now(), public.my_email())
    on conflict (kind) do update set default_enabled = excluded.default_enabled, days = excluded.days, updated_at = now(), updated_by = excluded.updated_by;
  perform public.log_event('code_settings', 'admin', null, null, k, case when k = 'trip' then 'Mã chuyến' else 'Mã nhóm' end,
    jsonb_build_object('old_enabled', o.default_enabled, 'old_days', o.days, 'enabled', p_enabled, 'days', p_days));
end $$;

revoke all on function public.code_days(text) from public, anon, authenticated;
revoke all on function public.trg_code_defaults() from public, anon, authenticated;
revoke all on function public.get_code_settings() from public, anon;
revoke all on function public.set_code_settings(text, boolean, integer) from public, anon;
grant execute on function public.get_code_settings() to authenticated;
grant execute on function public.set_code_settings(text, boolean, integer) to authenticated;
