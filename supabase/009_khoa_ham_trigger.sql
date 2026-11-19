-- 009: Khoá quyền gọi trực tiếp (qua /rest/v1/rpc) các hàm trigger ghi nhật ký (chạy sau 008)
-- Trigger vẫn chạy bình thường: PostgreSQL không kiểm tra quyền EXECUTE khi trigger kích hoạt.
-- Quay lại: grant execute on function public.trg_xxx() to anon, authenticated;
revoke all on function public.trg_bans()    from public, anon, authenticated;
revoke all on function public.trg_groups()  from public, anon, authenticated;
revoke all on function public.trg_members() from public, anon, authenticated;
revoke all on function public.trg_trips()   from public, anon, authenticated;
