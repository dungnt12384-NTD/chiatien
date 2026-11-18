# Vai trò, quyền, tab và chức năng

## Vai trò
| Vai trò | Là ai | Phạm vi |
|---|---|---|
| Khách | Chưa đăng nhập | Chỉ thấy tab **Quản trị** (đăng nhập) |
| Người xem | Vào nhóm bằng mã "Người xem" | Xem Chuyến đi, Tổng kết, Báo cáo của nhóm |
| Người nhập | Vào nhóm bằng mã "Người nhập" | Xem và nhập/sửa dữ liệu chuyến của nhóm |
| Chủ nhóm | Người tạo nhóm | Toàn quyền một nhóm |
| Quản trị viên | Bảng `platform_admins` | Toàn quyền mọi nhóm, tài khoản, hạn mức, nhật ký |
| Người xem qua link | Có link `?v=...` | Chỉ đọc Tổng kết, Báo cáo của một chuyến, không cần đăng nhập |

## Tab hiển thị
| Tab | Khách | Người xem | Người nhập | Chủ nhóm | Quản trị viên |
|---|---|---|---|---|---|
| Quản trị | ✔ (đăng nhập) | ✔ | ✔ | ✔ | ✔ |
| Chuyến đi | | ✔ (xem) | ✔ | ✔ | ✔ |
| Người đi (thành viên chuyến) | | | ✔ | ✔ | ✔ |
| Đã đóng | | | ✔ | ✔ | ✔ |
| Phòng | | | ✔ | ✔ | ✔ |
| Khoản chi | | | ✔ | ✔ | ✔ |
| Tổng kết | | ✔ | ✔ | ✔ | ✔ |
| Báo cáo | | ✔ | ✔ | ✔ | ✔ |
Nhóm chưa có chuyến nào: chỉ hiện Quản trị và Chuyến đi (để tạo chuyến đầu tiên).

## Chức năng
| Chức năng | Người xem | Người nhập | Chủ nhóm | Quản trị viên |
|---|---|---|---|---|
| Đăng nhập, đăng xuất | ✔ | ✔ | ✔ | ✔ |
| Xem danh sách nhóm của mình, đổi nhóm đang dùng | ✔ | ✔ | ✔ | ✔ |
| Vào nhóm bằng mã mời | ✔ | ✔ | ✔ | ✔ |
| Tạo nhóm mới | theo quyền được cấp + hạn mức | theo quyền được cấp + hạn mức | theo quyền được cấp + hạn mức | luôn được, không giới hạn |
| Rời nhóm | ✔ | ✔ | ✘ (xoá nhóm) | ✔ |
| Xem Tổng kết, Báo cáo, xuất Excel/PDF | ✔ | ✔ | ✔ | ✔ |
| Tạo / sửa / xoá chuyến | ✘ | ✔ | ✔ | ✔ |
| Thành viên chuyến, tiền đã đóng, phòng, khoản chi | ✘ | ✔ | ✔ | ✔ |
| Tạo / thu hồi link xem công khai | ✘ | ✔ | ✔ | ✔ |
| Tải bản sao lưu | ✔ | ✔ | ✔ | ✔ |
| Khôi phục từ file sao lưu | ✘ | ✔ | ✔ | ✔ |
| Quản lý thành viên nhóm: đổi quyền, xoá, xoá và chặn | ✘ | ✘ | ✔ | ✔ |
| Xem / đổi mã mời, tạm khoá việc vào bằng mã | ✘ | ✘ | ✔ | ✔ |
| Danh sách chặn, chặn trước theo email | ✘ | ✘ | ✔ | ✔ |
| Đổi tên, xoá nhóm | ✘ | ✘ | ✔ | ✔ |
| Lịch sử (nhật ký) của nhóm | ✘ | ✘ | ✔ | ✔ |
| Quản trị tổng: mọi nhóm, mọi tài khoản | ✘ | ✘ | ✘ | ✔ |
| Đặt quyền tạo nhóm và hạn mức từng người, mặc định | ✘ | ✘ | ✘ | ✔ |
| Cấp / thu quyền quản trị viên | ✘ | ✘ | ✘ | ✔ |
| Nhật ký toàn hệ thống | ✘ | ✘ | ✘ | ✔ |
| Mở xem/sửa dữ liệu nhóm không tham gia | ✘ | ✘ | ✘ | ✔ |
