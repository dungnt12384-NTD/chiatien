# Chia Tiền Nhóm (PWA)

Ứng dụng chia tiền chuyến đi theo nhóm. Một trang tĩnh (không cần máy chủ), dữ liệu và đăng nhập qua Supabase.

## Cấu trúc
- `index.html`: toàn bộ ứng dụng (giao diện, tính toán, báo cáo, đồng bộ).
- `sw.js`: service worker, giúp mở được khi mất mạng. **Đổi `VERSION` mỗi lần phát hành.**
- `manifest.webmanifest`, `icons/`: để cài vào màn hình chính.
- `vendor/supabase.js`: thư viện Supabase (bản 2.45.4), đặt sẵn trong kho để chạy ngoại tuyến.
- `supabase/schema.sql`: cấu trúc cơ sở dữ liệu và luật truy cập ban đầu (chạy một lần trong SQL Editor của Supabase).
- `supabase/002_roles_conflicts_shares.sql`: vai trò thành viên (chủ nhóm / người nhập / chỉ xem), mã mời riêng, phát hiện sửa trùng, link xem công khai. Chạy sau `schema.sql`.
- `supabase/003`…`006`: quản trị, nhật ký, thùng rác chuyến (chạy theo thứ tự số).
- `supabase/007_leader_ma_chuyen.sql`: mô hình quyền từ v16 (quản trị viên → nhóm → người tổ chức → leader / người phụ trách theo chuyến; thành viên xem bằng mã chuyến). Cần bật **Anonymous sign-ins** trong Supabase Auth. Mô tả chi tiết: `docs/PHAN-QUYEN.md`.
- `.github/workflows/keepalive.yml`: gọi Supabase 3 ngày một lần để dự án miễn phí không bị tạm dừng.

## Phát hành
Đưa toàn bộ thư mục này lên nhánh `main` của kho, bật GitHub Pages (Settings → Pages → Deploy from a branch → main, thư mục `/ (root)`).

## Bảo mật
Khoá `anon` trong `index.html` là khoá công khai theo thiết kế của Supabase. Dữ liệu được bảo vệ bằng luật truy cập (Row Level Security) và các hàm kiểm tra quyền trong `supabase/007_leader_ma_chuyen.sql`: chỉ leader, người phụ trách và người có mã còn hạn mới đọc được chuyến; chỉ leader và người phụ trách mới ghi được. Không bao giờ đưa khoá `service_role` vào kho.

## Quay lại phiên bản cũ
Mọi lần sửa đều là một commit trên nhánh `main`. Nhánh `backup-v2-truoc-vai-tro` giữ bản chạy tốt trước khi thêm vai trò, sửa trùng và link chia sẻ. Hoàn tác một lần sửa: `git revert <mã commit>` rồi đẩy lên `main`, GitHub Pages tự cập nhật. Dữ liệu chuyến đi nằm trên Supabase, không nằm trong kho này: hãy dùng nút "Tải bản sao lưu" trong ứng dụng để có bản dự phòng.

## Trang quản trị tổng và nhật ký (supabase/004_quan_tri_nhat_ky.sql)
- Quản trị viên (bảng `platform_admins`) thấy nút **Quản trị tổng** sau khi đăng nhập: xem mọi nhóm, người tạo, thành viên, hạn mức tạo nhóm từng tài khoản, nhật ký toàn hệ thống; cấp/thu quyền quản trị.
- Chủ nhóm hoặc quản trị viên: đổi quyền, xoá thành viên (có tuỳ chọn chặn), chặn email, tạm khoá việc vào nhóm bằng mã, đổi mã (không ảnh hưởng người đã vào), xem lịch sử nhóm.
- Nhật ký (`audit_log`) ghi tự động bằng trigger: tạo/đổi tên/xoá nhóm và chuyến, thành viên vào/rời/bị xoá/đổi quyền, chặn, hạn mức. Lượt "sửa chuyến" được gộp tối đa 1 dòng/10 phút/người/chuyến.
