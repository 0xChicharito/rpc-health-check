#!/bin/bash

# Script cài đặt cron job để tự động kiểm tra RPC

SCRIPT_PATH="$(pwd)/rpc_health_check.sh"
CRON_SCHEDULE="*/5 * * * *"  # Chạy mỗi 5 phút

echo "=== CÀI ĐẶT CRON JOB CHO RPC HEALTH CHECK ==="
echo ""

# Kiểm tra file script có tồn tại không
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "✗ Không tìm thấy file rpc_health_check.sh"
    echo "Vui lòng chạy script này trong cùng thư mục với rpc_health_check.sh"
    exit 1
fi

# Cấp quyền thực thi
chmod +x "$SCRIPT_PATH"
echo "✓ Đã cấp quyền thực thi cho script"

# Tạo cron job
CRON_CMD="$CRON_SCHEDULE $SCRIPT_PATH >> $(pwd)/rpc_health_check.log 2>&1"

# Kiểm tra xem cron job đã tồn tại chưa
if crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
    echo "⚠ Cron job đã tồn tại!"
    echo ""
    read -p "Bạn có muốn cập nhật lại không? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Hủy cài đặt."
        exit 0
    fi
    # Xóa cron job cũ
    crontab -l | grep -v "$SCRIPT_PATH" | crontab -
fi

# Thêm cron job mới
(crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -

echo "✓ Đã cài đặt cron job thành công!"
echo ""
echo "Chi tiết cron job:"
echo "  - Lịch chạy: Mỗi 5 phút"
echo "  - Script: $SCRIPT_PATH"
echo "  - Log file: $(pwd)/rpc_health_check.log"
echo ""
echo "Để xem danh sách cron jobs: crontab -l"
echo "Để chạy thử ngay: $SCRIPT_PATH"
echo ""
echo "=== HOÀN TẤT ==="
