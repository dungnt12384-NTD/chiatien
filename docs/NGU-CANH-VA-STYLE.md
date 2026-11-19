# Ngữ cảnh dự án và phong cách giao diện (để đọc lại khi làm tiếp)

> Khi bắt đầu chat mới, nói: "Đọc `docs/NGU-CANH-VA-STYLE.md` trong repo dungnt12384-NTD/chiatien rồi làm tiếp".
> Không ghi khoá, token hay mật khẩu vào file này.

## 1. Dự án "Chia Tiền Nhóm"
- Ứng dụng PWA một file `index.html` (JS thuần trong một IIFE), chạy trên GitHub Pages: https://dungnt12384-ntd.github.io/chiatien/
- Backend Supabase (project ref `sqxqltbszsbgdsgbdldo`): RLS, các hàm `security definer`, đăng nhập ẩn danh cho người vào bằng mã chuyến. Migration mới nhất: `supabase/008_quan_ly_tai_khoan.sql` (hàm `admin_accounts`, `admin_set_admin_email` cho mục Quản trị hệ thống → Tài khoản; đã chạy trên production 2026-11-19 qua Supabase connector). Claude được tự chạy SQL chỉ đọc và migration thêm/sửa hàm; xoá dữ liệu, xoá bảng, sửa dữ liệu hàng loạt thì hỏi chủ dự án trước.
- Migration 010 (`admin_account_trips`) và 011 (`admin_groups_overview`, `my_group_access`) đã chạy: Quản trị hệ thống → Nhóm hiện sẵn chuyến (kèm leader) và BTC (kèm tình trạng đăng nhập từ `auth.sessions`), bấm "Quản lý" mới sửa; thẻ "Nhóm của bạn" hiện từng chuyến, vai trò và nguồn quyền, bấm chuyến là mở chuyến.
- Migration 012: BTC (`is_organizer`) xem được mọi chuyến trong nhóm mình, kể cả chuyến ẩn khỏi mã nhóm (chỉ xem; sửa vẫn theo `trip_roles`). `my_group_access` có thêm via `organizer`.
- v42: "Nhóm của bạn" và Quản trị → Nhóm mặc định thu gọn (nút `.lv-tog` có mũi tên), bấm mới hiện chuyến trong khung `.lv2` nhạt hơn. Nút "Đang mở" / "Đóng quản lý" giống nút thường, chữ vàng (`.btn.is-open`). Bảng Quản lý (`.lv2.mng-panel`) nằm trên danh sách chuyến; mỗi mục `.gsub.lv3` một màu (`h-ren` xanh dương, `h-org` xanh lá, `h-code` cam, `h-hist` tím, `h-del` đỏ). Chỉ quản lý 1 nhóm mỗi lúc: `admSwitch` hỏi Lưu / Không lưu / Quay lại khi còn nháp (`admDraft`: đổi tên, email BTC, ô xoá – ô xoá không bao giờ tự lưu).
- v43 + migration 013 (`admin_group_codes`): Quản trị → Nhóm có nhãn trạng thái mã trên từng nhóm (`codeBadge`: đang bật màu vàng kèm số người xem và ngày hết hạn). v44 bỏ khung cảnh báo tổng ở đầu danh sách (anh Dũng thấy rối).
- v45 + migration 014 (`admin_trip_codes`, `trip_viewers`):
  - Quản trị → Nhóm: chỉ có nút "＋ Tạo nhóm" (bấm mới hiện ô tên + Xác nhận / Huỷ bỏ; Enter / Esc) và ô tìm `#qAdmQ` (lọc theo tên nhóm hoặc tên chuyến, tô vàng chữ khớp, tự sổ nhóm có chuyến khớp).
  - Nhãn mã chuyến trên từng chuyến; dòng nhóm có nhãn "N chuyến đang bật mã chuyến".
  - Bỏ tab "Yêu cầu" và thẻ "Muốn tổ chức chuyến đi?" của người dùng (quản trị thêm BTC trực tiếp trong Quản lý nhóm). Nhật ký quản trị chỉ hiện entity `admin`, `group`, `organizer`, `quota` (`ADM_ENT`).
  - Tab Chuyến: tên nhóm hiện cạnh tiêu đề "Chuyến đi" (`#tripGrpName`). Quản trị viên / BTC của nhóm có nút "Thông tin hiện tại" (hộp thoại `viewers`): ai có quyền xem, vào bằng gì, từ khi nào, hoạt động lần cuối, số thiết bị.
- Báo sai: chỉ lưu trong `trip_reports`, hiện số chưa xử lý trên nút "Báo sai" cho leader / phụ trách. CHƯA gửi email hay thông báo (chưa có dịch vụ gửi thư). Tab Chuyến bỏ nút "Phần của tôi" (xem ở tab Tổng kết).
- Người không có quyền sửa: nút `.btn` trong mục bị khoá được làm xám (`lk-off`, disabled) thay vì ẩn; ô nhập bị khoá xám có sọc.
- Đăng xuất (`doSignOut`): thử `signOut()` 4 giây, rồi `signOut({scope:'local'})` 2 giây; vẫn còn phiên thì xoá khoá `sb-*-auth-token` trong localStorage và tải lại trang (sửa lỗi không đăng xuất được trên Edge/Safari iPad).
- Service worker `sw.js`: tăng `VERSION` mỗi lần phát hành (hiện v58 – v58: **NGUYÊN TẮC CHUNG: BẤM RA NGOÀI VÙNG ĐANG THAO TÁC = ĐÓNG**, có thay đổi thì hỏi Lưu / Không lưu / Quay lại. Thêm vào `FX_DEFS` với `dim:false` (không làm xám): form khoản chi (`expSig` so với lúc bắt đầu sửa), sửa tiền đóng từng người (`advDraft`), đổi tên thành viên, tạo phòng mới (`nrDraft`), phòng đang sửa / chọn người. Chỉ làm xám ở chỗ anh yêu cầu. Đang có hộp hỏi thì bỏ qua. v57: **CÀI ĐẶT MÃ** (supabase/016, bảng `code_settings`, `get_code_settings` / `set_code_settings`, trigger `trg_code_defaults`): tab Quản trị > Cài đặt mã chỉnh bật/tắt sẵn + số ngày hạn cho mã chuyến và mã nhóm (áp dụng mã tạo mới, gia hạn, đổi mã; ghi nhật ký quản trị). Cảnh báo mã chỉ khi KHÁC mặc định (`codeWarn`): mã chuyến mặc định bật -> cảnh báo khi tắt / hết hạn. **CHẾ ĐỘ TẬP TRUNG DÙNG CHUNG** (`FX_DEFS`, `fxApply`, lớp `.fx-dim`): tab Người đi "Chọn nhiều để xoá", tab Đã đóng "Thu chung nhanh" -> phần khác xám + khoá, bấm ngoài = thoát, còn dở thì hỏi. Thêm chỗ mới: thêm 1 mục vào `FX_DEFS`. Tiền đóng: nút ✕ xoá từng đợt của từng người ngay ở chế độ xem (có hỏi). v56: **TAB CHUYẾN – CHẾ ĐỘ TẬP TRUNG**: đang mở "Sửa chuyến" hoặc "Tạo chuyến mới" thì phần khác (thanh chuyến, menu tab, danh sách chuyến, ô mã, khung chuyến) xám và không bấm được (`html.trip-focus`, `tripFocusBox`); bấm ra ngoài = thoát (`tripExit`), nếu đang sửa tên / đã gõ tên chuyến mới thì hỏi Lưu / Không lưu / Quay lại. v55: **HỘP "BÁO SAI CẦN XỬ LÝ"** ở đầu tab Nhóm/Của tôi (supabase/015, `my_open_reports`, `can_handle_reports`): quản trị viên, BTC nhóm, leader / người phụ trách thấy mọi báo sai chưa xử lý của mọi chuyến mình phụ trách, trả lời + "Đã xử lý" ngay tại hộp, "Mở chuyến"; số đỏ trên tab; BTC cũng xử lý được trong chuyến. Tên nhóm trên thanh chuyến (trên cùng) bấm để chọn nhóm, chọn xong về tab Chuyến. v54: **KIỂU CHUNG CHO MỌI NHẬT KÝ / LỊCH SỬ**: tiêu đề + nút "Hiện nhật ký / Đóng lại" (`logHead`), mặc định đóng, mở ra là khung cuộn `.hist-scroll` cao đúng 10 dòng (`fitLogs`). Đang áp cho: Quản trị → Nhật ký, Quản lý nhóm → Lịch sử nhóm, hộp "Lịch sử thay đổi" của chuyến. Nhật ký mới sau này cũng dùng kiểu này; v53: tên nhóm cạnh tiêu đề "Chuyến đi" là nút (`data-tx="pickgrp"`), bấm hiện hộp chọn nhóm (dùng `ask` với `choices`, kèm số chuyến), chọn thì `connectGroup` ngay tại tab Chuyến; v52: đang Quản lý nhóm thì phần xung quanh vừa xám vừa bị vô hiệu (`pointer-events:none`, Tab không ra ngoài); bấm bất kỳ chỗ nào ngoài khung nhóm đang quản lý = thoát quản lý (qua `admSwitch(null)`, vẫn hỏi lưu nếu sửa dở), cú bấm đó không làm việc khác; v51: tab Chuyến có ô "Nhập mã chuyến để thêm chuyến" ngay dưới danh sách chuyến (`#tripCodeBox`, `renderTripCode`, dùng chung `enterCode`; ẩn với quản trị viên và trang xem công khai); v50: "Nhóm của bạn" và Quản trị → Nhóm mở danh sách chuyến kiểu 1 nhóm mỗi lúc, mở nhóm mới thì nhóm trước tự đóng (không làm xám gì); v49: Lịch sử nhóm trong Quản lý mặc định đóng, nút "Hiện danh sách / Đóng lại", khung cuộn `.hist-scroll` cao 10 dòng; v46 "chế độ tập trung chung" đã bị anh Dũng bỏ, v47 hoàn tác. v48: CHỈ khi bấm Quản lý 1 nhóm thì ẩn danh sách chuyến của nhóm đó và xám phần xung quanh (`.sec.mng-focus`); đổi tên nhóm, bật / tắt / gia hạn / đổi mã nhóm và mã chuyến đều hỏi xác nhận; khung nhóm trong tab Của tôi viền 1.5px bao quanh như thẻ chuyến, không bóng, không viền trái dày). Điều hướng dùng network-first, `cache:'no-cache'`.
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
