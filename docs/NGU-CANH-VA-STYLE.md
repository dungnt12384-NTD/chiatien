# Ngữ cảnh dự án và phong cách giao diện (để đọc lại khi làm tiếp)

> Khi bắt đầu chat mới, nói: "Đọc `docs/NGU-CANH-VA-STYLE.md` trong repo dungnt12384-NTD/chiatien rồi làm tiếp".
> Không ghi khoá, token hay mật khẩu vào file này.

## 1. Dự án "Chia Tiền Nhóm"
- Ứng dụng PWA một file `index.html` (JS thuần trong một IIFE), chạy trên GitHub Pages: https://dungnt12384-ntd.github.io/chiatien/
- Backend Supabase (project ref `sqxqltbszsbgdsgbdldo`): RLS, các hàm `security definer`, đăng nhập ẩn danh cho người vào bằng mã chuyến. Migration mới nhất: `supabase/007_leader_ma_chuyen.sql` (đã chạy trên production).
- Service worker `sw.js`: tăng `VERSION` mỗi lần phát hành (hiện v28). Điều hướng dùng network-first, `cache:'no-cache'`.
- Chủ dự án nói tiếng Việt. Claude làm hết qua dòng lệnh: sửa, kiểm thử, push (`git push origin HEAD:main`), chạy SQL.
- Mô hình quyền: xem `docs/PHAN-QUYEN.md` (quản trị viên, người tổ chức, leader, người phụ trách, thành viên xem bằng mã `CH-XXXXXXXX`, link công khai `?v=`).

## 2. Cách kiểm thử
- Playwright (đã cài sẵn) với mock Supabase `m3.js` trong thư mục scratchpad của phiên (không nằm trong repo; nếu mất thì viết lại mock hàm `rpc`, `auth`, `from`).
- Bộ kiểm tra cũ: t200 (luồng vai trò, 42 OK), t201 (offline, `?c=`, OTP), t202 (không tràn ngang ở 360px), t210 đến t215 (người xem, ô tìm kiếm, ảnh chụp).
- Chạy server tĩnh: `python3 -m http.server 8125` trong `/home/user/chiatien`. Dùng `timeout` khi chạy node.
- Từ sandbox không mở được GitHub Pages (proxy chặn). Kiểm tra trang thật bằng localhost với Supabase thật.
- Dữ liệu thật dùng thử: mã `CH-352CUE5X` (tạo người dùng ẩn danh; chỉ xoá bằng id cụ thể, không xoá hàng loạt).
- Thư mục sao lưu DB (`dbbk2/`) không bao giờ được đưa vào repo.

## 3. Phong cách giao diện (từ v20, "ứng dụng PWA")
Ý tưởng: giống một app điện thoại. Nền xám xanh nhạt, thẻ trắng bo tròn, MỖI TAB/MỤC MỘT MÀU RIÊNG cố định, icon khối 3D. **Bỏ hẳn quy ước màu theo chuyến** (`--tc` không còn được gán, ô chọn màu chuyến bị ẩn; trường `color` của chuyến vẫn giữ trong dữ liệu để đồng bộ, chỉ báo cáo PDF còn dùng). Xanh lá chỉ cho số dương, đỏ chỉ cho số âm hoặc cảnh báo.

### Bảng màu (khối `<style id="app">` ở cuối `<head>` của `index.html`)
| Biến | Sáng | Tối | Dùng cho |
|---|---|---|---|
| `--brand` / `--brand-d` | `#2563eb` / `#1d4ed8` | `#60a5fa` / `#93c5fd` | nút chính, chọn ngày/tab con, chuyến đang chọn |
| `--brand-bg` | `#e8f0fe` | `#172a4a` | nền nhấn nhạt, hàng tổng |
| `--bg` | `#eef2f7` | `#0b1220` | nền trang |
| `--surface` / `--surface2` | `#fff` / `#f5f7fb` | `#131c2e` / `#1a2540` | thẻ / nền phụ, ô nhập |
| `--line` | `#e2e8f0` | `#26334d` | viền |
| `--fg` / `--muted` | `#0f172a` / `#64748b` | `#e6ebf5` / `#94a3b8` | chữ |
| `--pos` / `--neg` | `#15803d` / `#dc2626` | `#4ade80` / `#f87171` | số dương / số âm |
Phông: Segoe UI / system-ui.

### Màu từng tab (`--k`)
Của tôi `#0891b2` · Chuyến `#2563eb` · Người đi `#0d9488` · Đã đóng `#d97706` · Phòng `#7c3aed` · Khoản chi `#ea580c` · Tổng kết `#16a34a` · Báo cáo `#db2777`. Gán theo `.tab[data-go=…]` và `.sec[data-tab=…]`.

### Thành phần
- **Icon 3D:** ô bo 9–13px, nền chuyển sắc của `--k` (sáng → `--k` → tối), viền sáng trên, đáy tối, bóng nổi; nét trắng có đổ bóng. Dùng cho icon tab và icon tiêu đề mục.
- **Thẻ đầu (`.tripbar`):** nền chuyển sắc `#16325c → #1d4ed8`, bo 20px, chữ trắng; dòng 1 tên nhóm, dòng 2 tên chuyến 22px, dòng 3 số người/ngày/tổng.
- **Thanh tab máy tính:** kính mờ trắng, bo 18px, dính trên; mỗi tab icon trên nhãn ngắn dưới; tab đang chọn nền nhạt màu `--k`, chữ màu `--k`.
- **Thanh đáy điện thoại:** cố định đáy, bo trên 20px, không đóng khung từng tab; tab đang chọn icon to lên + gạch màu `--k` dưới.
- **Thẻ mục (`.sec`):** bo 20px (điện thoại 18px), viền mảnh, bóng nhẹ, tiêu đề không băng màu, chữ thường 18px. Tiêu đề phụ `.sub` chữ thường 14px.
- **Nút:** chính = chuyển sắc `--brand`, bo 12px, cao ≥42px; phụ (`.ghost`) nền trắng viền `--line`; xoá/nguy hiểm nền đỏ nhạt chữ đỏ.
- **Ô nhập:** bo 12px, cao 44px, nền `--surface2`; focus viền `--brand` + vòng sáng.
- **Bảng:** tiêu đề nền `--surface2`, chữ `--muted` hoa nhỏ; hàng tổng nền `--brand-bg`.

### Cách áp dụng
Khối `<style id="app">` nằm cuối, ghi đè các lớp cũ v1–v17 (nhiều chỗ dùng `!important` vì lớp cũ cũng dùng). Muốn đổi màu thương hiệu sửa `--brand`; đổi màu một tab sửa bảng `--k`.

## 4. Việc dang dở / cần hỏi chủ dự án
- Thông tin liên hệ cho điều khoản riêng tư (`PRIVACY_HTML`) chưa có.
- Báo cáo PDF vẫn dùng màu của chuyến (`trip().color`).
- Các lớp CSS cũ (v1–v17) còn nhiều quy tắc thừa; có thể dọn sau.
- Chủ dự án có thể muốn: chi tiết từng nhóm trong Quản trị tự mở khi có nhiều nhóm; bỏ thẻ "Xem chuyến khác bằng mã" cho cả người không phải quản trị.

## 5. Kiểm tra trước khi báo xong
Xem trang thật (GitHub Pages, mã thử `CH-352CUE5X`) ở 375px và 1280px, sáng và tối; kiểm tra không tab nào tràn ngang (`scrollWidth - innerWidth = 0`). Chủ dự án cho phép sửa xong push thẳng `main`.
