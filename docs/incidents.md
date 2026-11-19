# Nhật ký sự cố – chiatien (mới nhất ở trên)

## 2026-11-19 – Khoản chi không lưu được lên máy chủ (save_trip trả 400)
- Triệu chứng: Thủ quỹ duyệt "Tôi đã trả" và người hỗ trợ nhập khoản chi, nhưng khoản không xuất hiện ở các máy khác; app không báo lỗi gì.
- Nguyên nhân (đã xác nhận): khoản chi mang `"rooms": null`; `jsonb_array_length(coalesce(x->'rooms','[]'))` lỗi "cannot get array length of a scalar" khi giá trị là JSON null, nên mọi lần cập nhật chuyến bị 400.
- Đã làm: hàm `has_rooms(e)` dùng trong `log_changes` và `trip_guard` (supabase/030); thử lại Thủ quỹ và người hỗ trợ lưu khoản có rooms=null đều được. v98: thêm thanh cảnh báo đỏ khi lưu thất bại.
- Còn lại: khoản "cà phê trưa 580.000" và khoản của người hỗ trợ trong chuyến Cà Mau bị mất, cần nhập lại.

## 2026-11-19 – Gửi "Tôi đã trả" xong form vẫn giữ giá trị, bấm gửi trùng
- Nguyên nhân (chưa tái hiện được, suy đoán): bước tải lại danh sách sau khi gửi có thể báo lỗi giữa chừng làm form không vẽ lại.
- Đã làm: v101 xoá form + hiện "✅ Đã gửi" ngay; máy chủ chặn đề nghị trùng đang chờ duyệt (supabase/034).

## 2026-11-19 – Ô số tiền: xoá 1 số từ 5.600 ra 5.60 rồi 5.6
- Nguyên nhân: bộ định dạng coi "5.60" là số lẻ nên giữ nguyên. Đã sửa ở v100: mọi dấu chấm là dấu hàng nghìn, giữ vị trí con trỏ.
