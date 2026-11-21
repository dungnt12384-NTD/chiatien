-- 049: Gia cố bảo mật, không đổi hành vi ứng dụng.
-- 1) Cố định search_path cho 4 hàm còn thiếu (cảnh báo function_search_path_mutable).
-- 2) Thu hồi các quyền bảng mà ứng dụng không bao giờ dùng (TRUNCATE, TRIGGER, REFERENCES) khỏi anon và authenticated.
--    Lưu ý: TRUNCATE không bị RLS chặn, nên không để vai trò công khai giữ quyền này.
-- 3) Thu hồi quyền ghi trực tiếp (INSERT/UPDATE/DELETE) trên các bảng không có quy tắc ghi:
--    mọi thao tác ghi của ứng dụng đều đi qua hàm RPC (security definer, chạy bằng quyền chủ sở hữu) nên không ảnh hưởng.
--    Giữ SELECT (đọc danh sách chuyến và realtime vẫn do RLS kiểm soát) và giữ DELETE trên group_members (có quy tắc gm_delete).
-- Quay lại: grant insert, update, delete, truncate, references, trigger on <bảng> to anon, authenticated;
--           alter function public.touch_trip() reset search_path; (tương tự cho 3 hàm còn lại)

alter function public.touch_trip() set search_path = public;
alter function public.new_code() set search_path = public;
alter function public.cur_email() set search_path = public;
alter function public.mask_email(text) set search_path = public;

do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('revoke truncate, trigger, references on public.%I from anon, authenticated', t);
  end loop;
end $$;

revoke insert, update, delete on public.trips, public.groups, public.group_codes, public.code_settings, public.trip_shares, public.group_members from anon;
revoke insert, update, delete on public.trips, public.groups, public.group_codes, public.code_settings, public.trip_shares from authenticated;
revoke insert, update on public.group_members from authenticated;
