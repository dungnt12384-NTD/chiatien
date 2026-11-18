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

## Luồng 3 cấp (bản v15)

Đăng nhập → **Quản trị** (tài khoản, nhóm của tôi, quản trị tổng) → chọn nhóm → tab **Chuyến** → chọn chuyến → 6 tab làm việc (Người đi, Đã đóng, Phòng, Khoản chi, Tổng kết, Báo cáo).

- Đầu trang hiện thanh **Nhóm › Chuyến**; bấm tên nhóm để quay về Quản trị. Mở lại sẽ tự vào nhóm và chuyến lần trước.
- Tab Chuyến có khối **Nhóm** (Quản lý nhóm, Đổi nhóm) và khối **Chuyến này** (Thông tin và lịch sử, Link xem công khai, Thùng rác).
- Gọi tên: **Thành viên nhóm** = tài khoản đăng nhập có quyền; **Người đi** = danh sách chia tiền của chuyến; **Link xem công khai** = không cần đăng nhập, chỉ đọc.

| Thao tác | Người xem | Người nhập | Chủ nhóm | Quản trị viên |
|---|---|---|---|---|
| Tạo, sửa tên, đổi màu chuyến | ✘ | ✔ | ✔ | ✔ |
| Xoá chuyến (vào Thùng rác 30 ngày) / khôi phục | ✘ | ✔ | ✔ | ✔ |
| Xoá hẳn khỏi Thùng rác | ✘ | ✘ | ✔ | ✔ |
| Thông tin và lịch sử chuyến, link xem công khai | ✘ | ✔ | ✔ | ✔ |

Cơ sở dữ liệu: `supabase/006_thung_rac_chuyen.sql` (trash_trip, restore_trip, purge_trip, trip_trash, trip_info, trip_audit). "Tạo bởi" của chuyến lấy từ nhật ký; chuyến tạo trước khi có nhật ký hiện "không rõ".
