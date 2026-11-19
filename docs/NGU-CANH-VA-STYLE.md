# Ngữ cảnh dự án và phong cách giao diện (để đọc lại khi làm tiếp)

> Khi bắt đầu chat mới, nói: "Đọc `docs/NGU-CANH-VA-STYLE.md` trong repo dungnt12384-NTD/chiatien rồi làm tiếp".
> Không ghi khoá, token hay mật khẩu vào file này.

## 1. Dự án "Chia Tiền Nhóm"
- Ứng dụng PWA một file `index.html` (JS thuần trong một IIFE), chạy trên GitHub Pages: https://dungnt12384-ntd.github.io/chiatien/
- Backend Supabase (project ref `sqxqltbszsbgdsgbdldo`): RLS, các hàm `security definer`, đăng nhập ẩn danh cho người vào bằng mã chuyến. Migration mới nhất: `supabase/008_quan_ly_tai_khoan.sql` (hàm `admin_accounts`, `admin_set_admin_email` cho mục Quản trị hệ thống → Tài khoản; đã chạy trên production 2026-11-19 qua Supabase connector). Claude được tự chạy SQL chỉ đọc và migration thêm/sửa hàm; xoá dữ liệu, xoá bảng, sửa dữ liệu hàng loạt thì hỏi chủ dự án trước.
- Đăng xuất (`doSignOut`): thử `signOut()` 4 giây, rồi `signOut({scope:'local'})` 2 giây; vẫn còn phiên thì xoá khoá `sb-*-auth-token` trong localStorage và tải lại trang (sửa lỗi không đăng xuất được trên Edge/Safari iPad).
- Service worker `sw.js`: tăng `VERSION` mỗi lần phát hành (hiện v37). Điều hướng dùng network-first, `cache:'no-cache'`.
- Chủ dự án nói tiếng Việt. Claude làm hết qua dòng lệnh: sửa, kiểm thử, push (`git push origin HEAD:main`), chạy SQL.
- Mô hình quyền: xem `docs/PHAN-QUYEN.md` (quản trị viên, người tổ chức, leader, người phụ trách, thành viên xem bằng mã `CH-XXXXXXXX`, link công khai `?v=`).

## 2. Cách kiểm thử
- Playwright (đã cài sẵn) với mock Supabase `m3.js` trong thư mục scratchpad của phiên (không nằm trong repo; nếu mất thì viết lại mock hàm `rpc`, `auth`, `from`).
- Bộ kiểm tra cũ: t200 (luồng vai trò, 42 OK), t201 (offline, `?c=`, OTP), t202 (không tràn ngang ở 360px), t210 đến t215 (người xem, ô tìm kiếm, ảnh chụp).
- Chạy server tĩnh: `python3 -m http.server 8125` trong `/home/user/chiatien`. Dùng `timeout` khi chạy node.
- Từ sandbox không mở được GitHub Pages (proxy chặn). Kiểm tra trang thật bằng localhost với Supabase thật.
- Dữ liệu thật dùng thử: mã `CH-352CUE5X` (tạo người dùng ẩn danh; chỉ xoá bằng id cụ thể, không xoá hàng loạt).
- Thư mục sao lưu DB (`dbbk2/`) không bao giờ được đưa vào repo.

## 3. Phong cách giao diện (từ v21, "iOS / Liquid Glass")
Ý tưởng: giống app iOS 26–27. Nền xám hệ thống, thẻ trắng bo tròn lớn không viền, tiêu đề lớn (Large Title), thanh tab dạng viên kính mờ nổi. MỖI TAB/MỤC MỘT MÀU HỆ THỐNG iOS riêng. **Đã bỏ hẳn quy ước màu theo chuyến** (`--tc` không còn được gán, ô chọn màu chuyến bị ẩn; trường `color` vẫn giữ trong dữ liệu để đồng bộ, chỉ báo cáo PDF còn dùng). Xanh lá chỉ cho số dương, đỏ chỉ cho số âm hoặc cảnh báo.

### Bảng màu (khối `<style id="ios">` ở cuối `<head>` của `index.html`)
| Biến | Sáng | Tối | Dùng cho |
|---|---|---|---|
| `--brand` | `#007aff` | `#0a84ff` | nút chính, liên kết, chọn ngày/tab con, chuyến đang chọn |
| `--brand-bg` | `rgba(0,122,255,.12)` | `rgba(10,132,255,.2)` | nền nhấn nhạt |
| `--bg` | `#f2f2f7` | `#000` | nền trang (grouped background) |
| `--surface` / `--surface2` | `#fff` / `#f2f2f7` | `#1c1c1e` / `#2c2c2e` | thẻ / thẻ con, ô số liệu |
| `--fill` / `--fill2` | `rgba(118,118,128,.12/.2)` | `rgba(118,118,128,.24/.34)` | ô nhập, nút phụ, chip |
| `--line` | `rgba(60,60,67,.14)` | `rgba(84,84,88,.55)` | đường kẻ mảnh |
| `--fg` / `--muted` | `#000` / `rgba(60,60,67,.62)` | `#fff` / `rgba(235,235,245,.6)` | chữ |
| `--pos` / `--neg` | `#248a3d` / `#d70015` | `#30d158` / `#ff453a` | số dương / số âm |
| `--glass` | `rgba(255,255,255,.64)` | `rgba(44,44,48,.6)` | thanh tab kính mờ (blur 24px) |
Phông: -apple-system / SF Pro (máy khác: Segoe UI, Roboto). `theme-color` = `#f2f2f7` (sáng) / `#000` (tối).

### Màu từng tab (`--k`, màu hệ thống iOS)
Của tôi cyan `#32ade6` · Chuyến blue `#007aff` · Người đi teal `#30b0c7` · Đã đóng orange `#ff9500` · Phòng indigo `#5856d6` · Khoản chi pink `#ff2d55` · Tổng kết green `#34c759` · Báo cáo purple `#af52de`. Gán theo `.tab[data-go=…]` và `.sec[data-tab=…]`.

### Thành phần
- **Tiêu đề lớn (`.tripbar`):** nền trong suốt; dòng 1 tên nhóm màu `--brand` (như nút Back); dòng 2 tên chuyến 34px (điện thoại 30px) đậm; dòng 3 số người/ngày/tổng màu `--muted`.
- **Thanh tab:** viên kính mờ (bo 999px). Điện thoại: nổi cách đáy 8px, cách mép 10px. Máy tính: dính trên, icon trên nhãn dưới. Icon tab là khối đặc màu `--k`; tab đang chọn có viên nền (trắng ở máy tính, `--fill` ở điện thoại) và chữ màu `--k`.
- **Thẻ mục (`.sec`):** nền `--surface`, bo 26px (điện thoại 22px), không viền, không bóng. Tiêu đề 22px đậm, mô tả 15px `--muted`. Icon mục là squircle 40px bo 11px nền chuyển sắc `--k` có ánh bóng phía trên.
- **Thẻ con (`.gcard`), ô số liệu (`.stat`, `.kpi`, `.rcard`):** nền `--surface2`, bo 18–20px, không viền.
- **Nút:** hình viên thuốc. Chính nền `--brand` chữ trắng; phụ (`.ghost`) nền `--fill` chữ `--brand`; xoá nền đỏ nhạt chữ đỏ. Điện thoại cao 50px chữ 17px; bấm thì thu nhỏ 0.97.
- **Ô nhập:** nền `--fill`, không viền, bo 12px, cao 44px, chữ 16px; focus có vòng `--brand`.
- **Chọn ngày, tab con:** viên thuốc nền `--fill`; đang chọn nền `--brand` chữ trắng.
- **Bảng:** tiêu đề nền thẻ, chữ `--muted` 13px; đường kẻ `--line`; hàng tổng nền `--brand-bg`.

### Lớp nhận diện PetroVietnam / Biendong POC (v23, khối `<style id="brand">` đặt SAU khối `ios`)
Giữ bố cục iOS, chỉ đổi màu, nền, họa tiết theo logo và backdrop của công ty. KHÔNG gắn logo công ty vào trang (web công khai, việc cá nhân); chỉ dùng màu và họa tiết.
- Màu: tím than `--pv-navy #2e3a87` (chữ PETROVIETNAM), xanh lá `--pv-green #00a04b` (lá, BIENDONG POC), xanh dương `--pv-blue #0a6ad6`. Chuyển sắc nút/icon `--pv-grad` = xanh lá → xanh → tím than; chữ tiêu đề `--pv-text` = `#1f1d7a` → `#0a6ad6`.
- Nền: lớp `html::before` cố định, trời sáng trắng → xanh nhạt có 2 vệt sáng chéo; `html::after` là đường lượn SVG xanh lá → tím than ở góc phải dưới (điện thoại mờ hơn). Tối: nền `#070d26` có quầng xanh.
- Tiêu đề chuyến: dòng nhóm chữ hoa xanh lá nhỏ; tên chuyến chữ HOA Be Vietnam Pro 800, chuyển sắc navy → xanh (giống "NĂNG LƯỢNG QUỐC GIA").
- Thẻ mục: kính trắng mờ (blur 12px), dải màu thương hiệu 3px ở trên, tiêu đề màu tím than Be Vietnam Pro 800. Icon mục là khối bóng 3D như logo số 6.
- Nút chính chuyển sắc `--pv-grad`; nút phụ nền nhạt chữ tím than; ngày/tab con đang chọn nền tím than.
- Màu từng tab (`--k`, trong dải thương hiệu): Của tôi `#2e3a87` · Chuyến `#00a04b` · Người đi `#0b9e8a` · Đã đóng `#1d9bf0` · Phòng `#4f46e5` · Khoản chi `#0a6ad6` · Tổng kết `#3faa2b` · Báo cáo `#6d3fc7`. (Bảng màu iOS ở trên bị lớp này ghi đè.)
- `theme-color`/manifest: `#eef6fd` (sáng), `#070d26` (tối).

### Bố cục tổng thể và icon thống nhất (v24, khối `<style id="layout">` đặt SAU khối `brand`)
- **Thanh tab THẲNG, không bo hai đầu** (ghi đè mô tả viên kính ở trên):
  - Máy tính và iPad (không có `html.phone`): đầu trang và thanh tab tràn hết chiều ngang (`margin-inline:calc(50% - 50vw)`), thanh tab dính trên cùng khi cuộn, kẻ mảnh trên/dưới. Tab đang chọn: nền nhạt màu `--k` 10% và vạch thẳng 3px ở đáy. Icon 28px, nhãn ngắn `.tls` 13px.
  - Điện thoại (`html.phone`): thanh tab sát đáy, sát hai mép, chỉ kẻ mảnh ở trên. Tab đang chọn: nền nhạt `--k` và vạch 3px ở đỉnh. Cao 66px + vùng an toàn.
  - Nội dung là cột giữa rộng `--col` (820px). `html, body` có `overflow-x:clip` để phần tràn mép không gây cuộn ngang.
- **Icon thống nhất:** bỏ hết ký tự ⚠ ℹ ✓ 🔒 🗑 ✎ ✕ ⧉ ↩ 💾 ⬇; mọi icon là SVG khối đặc kiểu SF Symbols, tô `currentColor`:
  - `.si`: icon trong chữ/nút (1.15em). `.sx`: icon nút nhỏ (đóng, sửa, xong). `.chev`: mũi tên.
  - Mũi tên mở/đóng của `details.gcard` vẽ bằng `mask:var(--chev-mask)`, xoay 180° khi mở.
  - Màn hình vào: logo = banknote, 3 tính năng = receipt, chart.pie, checkmark.shield.
- Ghi chú: `100vw` tính cả thanh cuộn nên ở máy tính thanh tab lệch khoảng nửa bề rộng thanh cuộn (bị `clip` che, nhìn không thấy).

### Icon (v22, kiểu SF Symbols)
Khối đặc bo tròn, tô bằng `fill` (không dùng nét): Của tôi = person.crop.circle, Chuyến = airplane, Người đi = person.2, Đã đóng = banknote, Phòng = bed.double, Khoản chi = receipt, Tổng kết = chart.pie, Báo cáo = doc.text. Đường dẫn SVG nằm trong `TAB_DEF` (class `sf`, phần khoét dùng `fill-rule="evenodd"`). Icon tiêu đề mục được gán từ `TAB_DEF` lúc tải trang theo `data-tab`, nên chỉ cần sửa một chỗ. Ở thanh tab icon tô màu `--k`; ở tiêu đề mục icon trắng trên squircle màu `--k`.

### Cỡ chữ điện thoại (v22, `html.phone`)
Không ẩn nội dung: mô tả dưới tiêu đề mục luôn hiện. Thân chữ 17px; tiêu đề lớn 32px; tiêu đề mục 23px; tiêu đề phụ 19px; nhãn ô nhập, gợi ý, mô tả 15px; số liệu 26px (ô số liệu 1 cột); nút cao 52px chữ 17px; ô nhập cao 50px chữ 17px. Thanh tab: icon 28px, nhãn 11px, nhãn dài tự xuống 2 dòng (không cắt chữ).

### Cách áp dụng
Khối `<style id="ios">` nằm cuối, ghi đè các lớp cũ v1–v17 (nhiều chỗ dùng `!important` vì lớp cũ cũng dùng). Đổi màu nhấn sửa `--brand`; đổi màu một tab sửa bảng `--k`.

## 4. Việc dang dở / cần hỏi chủ dự án
- Thông tin liên hệ cho điều khoản riêng tư (`PRIVACY_HTML`) chưa có.
- Báo cáo PDF vẫn dùng màu của chuyến (`trip().color`).
- Các lớp CSS cũ (v1–v17) còn nhiều quy tắc thừa; có thể dọn sau.
- Chủ dự án có thể muốn: chi tiết từng nhóm trong Quản trị tự mở khi có nhiều nhóm; bỏ thẻ "Xem chuyến khác bằng mã" cho cả người không phải quản trị.

## 5. Kiểm tra trước khi báo xong
Xem trang thật (GitHub Pages, mã thử `CH-352CUE5X`) ở 375px và 1280px, sáng và tối; kiểm tra không tab nào tràn ngang (`scrollWidth - innerWidth = 0`). Chủ dự án cho phép sửa xong push thẳng `main`.
