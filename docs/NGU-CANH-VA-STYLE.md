# Ngữ cảnh dự án và phong cách giao diện (để đọc lại khi làm tiếp)

> Khi bắt đầu chat mới, nói: "Đọc `docs/NGU-CANH-VA-STYLE.md` trong repo dungnt12384-NTD/chiatien rồi làm tiếp".
> Không ghi khoá, token hay mật khẩu vào file này.

## 1. Dự án "Chia Tiền Nhóm"
- Ứng dụng PWA một file `index.html` (JS thuần trong một IIFE), chạy trên GitHub Pages: https://dungnt12384-ntd.github.io/chiatien/
- Backend Supabase (project ref `sqxqltbszsbgdsgbdldo`): RLS, các hàm `security definer`, đăng nhập ẩn danh cho người vào bằng mã chuyến. Migration mới nhất: `supabase/007_leader_ma_chuyen.sql` (đã chạy trên production).
- Service worker `sw.js`: tăng `VERSION` mỗi lần phát hành (hiện v24). Điều hướng dùng network-first, `cache:'no-cache'`.
- Chủ dự án nói tiếng Việt. Claude làm hết qua dòng lệnh: sửa, kiểm thử, push (`git push origin HEAD:main`), chạy SQL.
- Mô hình quyền: xem `docs/PHAN-QUYEN.md` (quản trị viên, người tổ chức, leader, người phụ trách, thành viên xem bằng mã `CH-XXXXXXXX`, link công khai `?v=`).

## 2. Cách kiểm thử
- Playwright (đã cài sẵn) với mock Supabase `m3.js` trong thư mục scratchpad của phiên (không nằm trong repo; nếu mất thì viết lại mock hàm `rpc`, `auth`, `from`).
- Bộ kiểm tra cũ: t200 (luồng vai trò, 42 OK), t201 (offline, `?c=`, OTP), t202 (không tràn ngang ở 360px), t210 đến t215 (người xem, ô tìm kiếm, ảnh chụp).
- Chạy server tĩnh: `python3 -m http.server 8125` trong `/home/user/chiatien`. Dùng `timeout` khi chạy node.
- Từ sandbox không mở được GitHub Pages (proxy chặn). Kiểm tra trang thật bằng localhost với Supabase thật.
- Dữ liệu thật dùng thử: mã `CH-352CUE5X` (tạo người dùng ẩn danh; chỉ xoá bằng id cụ thể, không xoá hàng loạt).
- Thư mục sao lưu DB (`dbbk2/`) không bao giờ được đưa vào repo.

## 3. Phong cách giao diện (từ v17, "sang trọng")
Ý tưởng: nền ngà ấm, mực xanh đen, vàng đồng làm điểm nhấn. Màu riêng của chuyến (`--tc`) chỉ là điểm nhấn nhỏ. Xanh lá chỉ cho số dương, đỏ chỉ cho số âm hoặc cảnh báo.

### Bảng màu (CSS biến trong `:root`)
| Biến | Sáng | Tối | Dùng cho |
|---|---|---|---|
| `--bg` | `#f5f2ea` | `#0d1320` | nền trang |
| `--surface` | `#fffefb` | `#141c2c` | thẻ, ô |
| `--surface2` | `#faf7f0` | `#1a2438` | nền phụ, chip |
| `--line` | `#e4ddcc` | `#2a3650` | viền |
| `--fg` / `--muted` | `#18202e` / `#5f6675` | `#ecebe6` / `#a3adc0` | chữ |
| `--ink` | `#14213a` | `#0a101c` | thanh tab, nút chính, tiêu đề bảng, biểu tượng |
| `--ink2` | `#1d2f52` | `#17223a` | trạng thái hover của nút chính |
| `--gold` | `#b58a3c` | `#d8b062` | viền trên thẻ, gạch tab, vạch KPI, icon |
| `--gold-bg` | `#f6edd9` | `#3a3018` | nền nhấn nhạt (huy hiệu, mục đang chọn) |
| `--pos` / `--neg` | `#14703f` / `#b42323` | | số dương / số âm |
Phông chữ: Be Vietnam Pro.

### Thành phần
- **Thanh tab:** nền `--ink`, bo 16px, đổ bóng. Chữ và biểu tượng sáng mờ. Tab đang chọn: nền `--surface`, chữ `--ink`, gạch vàng 3px phía dưới (`inset 0 -3px 0 var(--gold)`). Huy hiệu đếm: nền trắng mờ chữ vàng nhạt. Trên điện thoại thanh nằm cố định ở đáy.
- **Thẻ mục (`.sec`):** bo 18px, viền `--line`, vạch vàng 3px ở trên, bóng nhẹ. Tiêu đề mục nền `--surface`, chữ `--ink` đậm. Biểu tượng là ô vuông bo 12px nền `--ink`, nét `--gold`.
- **Thẻ số liệu (`.stat`, `.kpi`, `.rcard`):** nền `--surface`, viền `--line`, vạch vàng 3px bên trái, số lớn màu `--ink`.
- **Nút:** nút chính nền `--ink`, chữ trắng, bo 11px. Nút phụ (`.ghost`) nền trong, viền be `#c9c0a8`, hover nền `--gold-bg`. Nút nguy hiểm: chữ và viền đỏ.
- **Chọn ngày, tab con, nút bật/tắt:** đang chọn thì nền `--ink`, chữ trắng, gạch vàng dưới. Nút bật/tắt (`button.tog`) đang bật thì nền `--gold-bg`, viền vàng.
- **Bảng:** hàng tiêu đề nền `--ink`, chữ ngà. Hàng tổng nền `--gold-bg`, viền trên vàng.
- **Thanh chuyến (`.tripbar`):** nền `--ink`, chữ ngà, vạch trái 5px màu chuyến.
- **Ô nhập:** viền be `#d3cab3`; khi focus có viền vàng 2px.
- **Quản trị:** một tông duy nhất, tiêu đề từng thẻ là dải `--ink`, vạch trái vàng, nhóm đang mở nền `--gold-bg`.

### Cách áp dụng (đã làm trong repo)
CSS v17 là các khối nối thêm ở cuối thẻ `<style>` cuối cùng của `index.html`. Nhiều quy tắc cũ có độ ưu tiên cao nên các quy tắc mới dùng `!important` ở chỗ cần (tab, biểu tượng, KPI, tab con). Muốn đổi bảng màu thì sửa các biến `--ink`, `--gold`, `--bg`, `--surface`... ở khối đầu của v17.

## 4. Việc dang dở / cần hỏi chủ dự án
- Thông tin liên hệ cho điều khoản riêng tư (`PRIVACY_HTML`) chưa có.
- Chưa chụp ảnh kiểm tra chế độ tối của giao diện v17.
- Chủ dự án có thể muốn: chi tiết từng nhóm trong Quản trị tự mở khi có nhiều nhóm; bỏ thẻ "Xem chuyến khác bằng mã" cho cả người không phải quản trị.

## 5. Dùng phong cách này cho trang khác (portal)
Khi áp dụng cho portal của chủ dự án: giữ đúng bảng màu và các thành phần ở mục 3. Đọc mã nguồn portal, thay bảng màu bằng các biến trên, dựng lại thanh điều hướng, tiêu đề mục, thẻ số liệu, nút và bảng theo mô tả. Kiểm tra ở 390px và 1280px, cả chế độ sáng và tối, bằng Playwright trước khi báo hoàn thành.
