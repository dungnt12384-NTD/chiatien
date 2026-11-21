# chiatien – STATUS (cập nhật 20/11/2026)

Web chia tiền nhóm, chạy ở dungnt12384-ntd.github.io. Sửa trên DUNGNT-DTSM (D:\github\chiatien), push lên GitHub là có hiệu lực (chờ 1–2 phút, tải lại cứng Ctrl+Shift+R vì có sw.js).
Quy ước làm việc: sửa xong tự commit + push, không cần hỏi (chỉ áp dụng cho chiatien và hopdong).

## Đang ở đâu
- 21/11: danh sách gợi ý email (gán người vào chuyến / thêm quản trị) đổi sang bảng kính mờ, có chữ cái đầu tròn, tô vàng chữ khớp, sổ lên trên ô nhập. CHƯA xác nhận trên web thật.
- 21/11: bảng quyền (nhóm / chuyến / tài khoản) trên điện thoại hết tràn phải ở cả kiểu "Dạng bảng"; tiêu đề đổi thành dải màu, nút đóng ✕ và nút gỡ quyền (thùng rác) dạng biểu tượng, thẻ có viền màu theo vai trò. CHƯA xác nhận trên web thật.
- Tab Tổng kết, chế độ "Tất cả thành viên": tiền đã đóng của cả nhóm (chính + đi kèm) chia đều cho từng người (hàm `splitAdv`). ĐÃ XÁC NHẬN đúng bởi anh Dũng (commit 0acef9c).
- Sửa lỗi kèm theo (e4766b9): dòng thủ quỹ không còn hiện −31 triệu (không trừ tiền đang giữ); cả nhóm thủ quỹ không tính vào "Thủ quỹ cần thu thêm / trả lại" ở cả 2 chế độ. CHƯA xác nhận trên web thật.
- STT khi chọn "Chỉ thành viên chính" đánh liên tục 1..n (677686f, hàm `gNo`). CHƯA xác nhận trên web thật.

## Việc tồn
- (Bỏ qua: khoản bị mất ở Cà Mau, anh Dũng đã xác nhận bỏ.)
- Anh kiểm tra trên web: 2 lần sửa sau cùng (e4766b9, 677686f), gồm cả bảng xuất/PDF/báo cáo ở chế độ "Chỉ thành viên chính".

## Bước tiếp
1. Anh xác nhận 2 lần sửa trên.
2. Ghi sự cố/việc mới vào `docs/incidents.md`, `docs/open-items.md` khi có.
