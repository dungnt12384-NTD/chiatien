# Vai trò, quyền, tab và chức năng (từ bản v16)

## Ý tưởng
- **Nhóm** là một cộng đồng người quen (ví dụ: Cào Cào Dưỡng Sinh, Honda Phát Tiến). Chỉ quản trị viên tạo nhóm.
- Trong nhóm, **người tổ chức** tạo các **chuyến đi**. Mỗi chuyến có một hoặc nhiều **leader** và các **người phụ trách**.
- Người đi cùng chỉ cần **mã chuyến** (CH-XXXXXXXX) để xem, không cần tài khoản.

## Vai trò
| Vai trò | Là ai | Được làm gì |
|---|---|---|
| Quản trị viên | Email trong bảng `admin_emails` hoặc `platform_admins` | Tạo, đổi tên, xoá nhóm; thêm/gỡ người tổ chức; duyệt yêu cầu; bật/tắt mã nhóm; xem mọi chuyến; sao lưu, khôi phục; nhật ký toàn hệ thống |
| Người tổ chức (theo nhóm) | Quản trị viên thêm bằng email, hoặc duyệt yêu cầu gửi trong ứng dụng | Tạo chuyến trong nhóm. Chỉ thấy chuyến mình tạo hoặc tham gia |
| Leader (theo chuyến) | Người tạo chuyến, hoặc do leader/quản trị viên thêm bằng email. Nhiều leader ngang quyền | Sửa mọi mục; thêm/gỡ leader và người phụ trách; mã chuyến, link công khai; chốt sổ / mở lại; xoá chuyến vào thùng rác. Không gỡ được leader cuối cùng |
| Người phụ trách (theo chuyến) | Leader thêm bằng email, tick các mục được nhập (mặc định: Khoản chi) | Thêm, sửa, xoá **mọi** dòng trong các mục được tick (Người đi, Đã đóng, Phòng, Khoản chi); tạo link công khai |
| Thành viên | Nhập mã chuyến, không cần tài khoản (phiên ẩn danh) | Xem đủ các tab của chuyến đó (chỉ đọc); xem lịch sử (email che bớt); báo sai; đánh dấu đã nộp / đã nhận; xem Phần của tôi |
| Người xem qua link | Có link `?v=...` | Chỉ Tổng kết và Báo cáo của một chuyến |

Mã nhóm (NH-XXXXXXXX) là tuỳ chọn, mặc định tắt, do quản trị viên bật. Người có mã nhóm xem được mọi chuyến trong nhóm, trừ chuyến leader đã ẩn.

## Mã và link
- Mã chuyến, mã nhóm và link công khai **hết hạn sau 3 tháng**, không tự đổi. Leader thấy nhắc trước 7 ngày; bấm **Gia hạn 3 tháng** hoặc **Đổi mã mới** (mã cũ mất tác dụng ngay).
- Leader có thể **tạm khoá** mã. Dữ liệu chuyến được giữ mãi cho tới khi leader xoá.
- Link `.../?c=CH-XXXXXXXX` mở ứng dụng và tự nhập mã.
- Nhập sai quá 8 lần trong 10 phút thì bị chặn tạm thời.

## Trang đăng nhập
- Giới thiệu ứng dụng, ô **Vào chuyến đi** (nhập mã) và mục thu gọn **Tôi là người tổ chức chuyến đi** (Google hoặc mã 6 số qua email).
- Đã đăng nhập trên máy thì bỏ qua trang này.

## Tab hiển thị
| Ai | Tab |
|---|---|
| Chưa đăng nhập | Trang đăng nhập |
| Đã đăng nhập, chưa có nhóm | Quản trị (xin quyền tổ chức, nhập mã) |
| Nhóm chưa có chuyến | Quản trị, Chuyến đi |
| Còn lại | Đủ 8 tab. Tab nào không có quyền nhập thì hiện nhãn **Chỉ xem**, ẩn nút thêm/sửa/xoá |

Tab đầu tiên tên là **Của tôi** với người vào bằng mã, **Quản trị** với người đăng nhập.

## Chức năng theo chuyến (khối "Chuyến này" ở tab Chuyến đi)
| Nút | Ai thấy |
|---|---|
| Phần của tôi, Lịch sử thay đổi, Báo sai | Mọi người |
| Mã chuyến, Link xem công khai, Leader và phụ trách | Leader, người phụ trách (người phụ trách chỉ xem mã, không đổi được) |
| Chốt sổ / Mở lại sổ, Thùng rác chuyến | Leader |

- **Chốt sổ**: khoá sửa với mọi người cho tới khi leader mở lại. Việc chốt và mở lại được ghi vào lịch sử.
- **Thùng rác khoản chi**: khoản chi bị xoá được giữ 30 ngày trong chuyến, khôi phục ở cuối tab Khoản chi.
- **Báo sai**: nút cạnh từng khoản chi. Leader và người phụ trách thấy danh sách, trả lời và đánh dấu đã xử lý; người báo chỉ thấy báo cáo của mình.
- **Đã nộp / Đã nhận**: ở cột Chốt sổ (Tổng kết) và trong Phần của tôi. Nếu số tiền chốt sổ thay đổi sau khi đánh dấu, dấu cũ hiện màu cam để kiểm tra lại.
- **Lịch sử**: ghi ai thêm, sửa, xoá khoản chi, tiền phòng, tiền đóng trước, người đi, người phụ trách; tạo, đổi tên, xoá, khôi phục, chốt sổ chuyến. Thành viên thấy email đã che bớt.

## Sửa cùng lúc
Hai người sửa cùng chuyến: ứng dụng tự gộp theo từng dòng. Chỉ hỏi "Lấy bản của nhóm / Giữ bản của tôi" khi cả hai cùng sửa đúng một dòng.

## Máy chủ kiểm tra lại
Mọi quyền được kiểm tra trên cơ sở dữ liệu (`supabase/007_leader_ma_chuyen.sql`): bảng chỉ truy cập qua các hàm `security definer`, `save_trip` từ chối người không có quyền sửa và chuyến đã chốt. Giao diện chỉ ẩn nút cho dễ dùng.

## Chuyển từ mô hình cũ (v15)
- Chủ nhóm cũ thành người tổ chức của nhóm và leader của mọi chuyến trong nhóm.
- Người nhập cũ thành người phụ trách (đủ 4 mục) của mọi chuyến trong nhóm.
- Người xem cũ: vào bằng mã chuyến.
- Mã mời nhóm cũ (người nhập / người xem) không còn dùng.
