# Chia Tiền Nhóm (PWA)

Ứng dụng chia tiền chuyến đi theo nhóm. Một trang tĩnh (không cần máy chủ), dữ liệu và đăng nhập qua Supabase.

## Cấu trúc
- `index.html`: toàn bộ ứng dụng (giao diện, tính toán, báo cáo, đồng bộ).
- `sw.js`: service worker, giúp mở được khi mất mạng. **Đổi `VERSION` mỗi lần phát hành.**
- `manifest.webmanifest`, `icons/`: để cài vào màn hình chính.
- `vendor/supabase.js`: thư viện Supabase (bản 2.45.4), đặt sẵn trong kho để chạy ngoại tuyến.
- `supabase/schema.sql`: cấu trúc cơ sở dữ liệu và luật truy cập ban đầu (chạy một lần trong SQL Editor của Supabase).
- `supabase/002_roles_conflicts_shares.sql`: vai trò thành viên (chủ nhóm / người nhập / chỉ xem), mã mời riêng, phát hiện sửa trùng, link xem công khai. Chạy sau `schema.sql`.
- `.github/workflows/keepalive.yml`: gọi Supabase 3 ngày một lần để dự án miễn phí không bị tạm dừng.

## Phát hành
Đưa toàn bộ thư mục này lên nhánh `main` của kho, bật GitHub Pages (Settings → Pages → Deploy from a branch → main, thư mục `/ (root)`).

## Bảo mật
Khoá `anon` trong `index.html` là khoá công khai theo thiết kế của Supabase. Dữ liệu được bảo vệ bằng luật truy cập (Row Level Security) trong `supabase/schema.sql`: chỉ thành viên của một nhóm mới đọc/ghi được chuyến của nhóm đó. Không bao giờ đưa khoá `service_role` vào kho.

## Quay lại phiên bản cũ
Mọi lần sửa đều là một commit trên nhánh `main`. Nhánh `backup-v2-truoc-vai-tro` giữ bản chạy tốt trước khi thêm vai trò, sửa trùng và link chia sẻ. Hoàn tác một lần sửa: `git revert <mã commit>` rồi đẩy lên `main`, GitHub Pages tự cập nhật. Dữ liệu chuyến đi nằm trên Supabase, không nằm trong kho này: hãy dùng nút "Tải bản sao lưu" trong ứng dụng để có bản dự phòng.
