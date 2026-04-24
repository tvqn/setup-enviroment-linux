#!/usr/bin/env bash
# =============================================================================
# install_googledrive.sh - Cài đặt Google Drive trên Ubuntu
#
# Cung cấp 2 phương án:
#   1. google-drive-ocamlfuse  → Mount Google Drive như filesystem (CLI/headless)
#   2. gnome-online-accounts   → Tích hợp với GNOME Files (Nautilus) - GUI
#
# Mặc định: cài cả 2 để tối đa khả năng sử dụng
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="googledrive"
MOUNT_DIR="${GOOGLEDRIVE_MOUNT_DIR:-$HOME/GoogleDrive}"
SYSTEMD_SERVICE="$HOME/.config/systemd/user/googledrive.service"

install_googledrive() {
    log_section "Cài đặt Google Drive"
    init_devsetup

    local already_installed=0

    # Kiểm tra google-drive-ocamlfuse
    if is_installed google-drive-ocamlfuse; then
        log_info "google-drive-ocamlfuse đã được cài đặt"
        already_installed=1
    fi

    if [[ $already_installed -eq 1 ]]; then
        log_success "Google Drive tools đã được cài đặt. Bỏ qua."
        state_set "$TOOL_NAME" "installed" "installed"
        return 0
    fi

    # ── Phương án 1: google-drive-ocamlfuse (FUSE mount) ──────────────────────
    log_step "Cài đặt google-drive-ocamlfuse (FUSE mount)..."
    run_cmd sudo apt-get install -y software-properties-common

    if sudo add-apt-repository -y ppa:alessandro-strada/ppa >> "$LOG_FILE" 2>&1; then
        apt_update_safe
        if run_cmd sudo apt-get install -y google-drive-ocamlfuse; then
            log_success "google-drive-ocamlfuse đã cài đặt thành công"

            # Tạo mount point
            mkdir -p "$MOUNT_DIR"
            log_info "Mount point: $MOUNT_DIR"

            # Tạo systemd user service để auto-mount
            mkdir -p "$(dirname "$SYSTEMD_SERVICE")"
            cat <<EOF > "$SYSTEMD_SERVICE"
[Unit]
Description=Google Drive FUSE mount
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
ExecStartPre=/bin/mkdir -p ${MOUNT_DIR}
ExecStart=/usr/bin/google-drive-ocamlfuse ${MOUNT_DIR}
ExecStop=/bin/fusermount -u ${MOUNT_DIR}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
            systemctl --user daemon-reload 2>/dev/null || true
            log_info "Đã tạo systemd user service tại: $SYSTEMD_SERVICE"
        else
            log_warn "google-drive-ocamlfuse cài thất bại"
        fi
    else
        log_warn "Không thêm được PPA, thử cài qua apt mặc định..."
        run_cmd sudo apt-get install -y google-drive-ocamlfuse 2>/dev/null || true
    fi

    # ── Phương án 2: GNOME Online Accounts (tích hợp Nautilus) ───────────────
    log_step "Cài đặt GNOME Online Accounts (tích hợp Files/Nautilus)..."
    run_cmd sudo apt-get install -y \
        gnome-online-accounts \
        gvfs-backends 2>/dev/null || true

    log_success "Google Drive đã được cài đặt"
    log_info ""
    log_info "═══════════════════════════════════════════════════════"
    log_info "  HƯỚNG DẪN SỬ DỤNG GOOGLE DRIVE"
    log_info "═══════════════════════════════════════════════════════"
    log_info ""
    log_info "  Cách 1 - FUSE mount (CLI):"
    log_info "    1. Chạy: google-drive-ocamlfuse ~/GoogleDrive"
    log_info "    2. Trình duyệt sẽ mở để xác thực Google"
    log_info "    3. Sau xác thực, Drive được mount tại ~/GoogleDrive"
    log_info ""
    log_info "  Auto-mount khi đăng nhập:"
    log_info "    systemctl --user enable googledrive"
    log_info "    systemctl --user start googledrive"
    log_info ""
    log_info "  Cách 2 - GNOME Files (GUI):"
    log_info "    Mở Settings → Online Accounts → Google"
    log_info "    Đăng nhập và bật 'Files' để truy cập qua Nautilus"
    log_info ""
    log_info "  Unmount:"
    log_info "    fusermount -u ~/GoogleDrive"
    log_info "═══════════════════════════════════════════════════════"

    state_set "$TOOL_NAME" "installed" "installed"
}

uninstall_googledrive() {
    log_section "Gỡ cài đặt Google Drive"

    # Unmount nếu đang mount
    if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
        log_step "Unmount Google Drive..."
        fusermount -u "$MOUNT_DIR" 2>/dev/null || sudo umount -l "$MOUNT_DIR" 2>/dev/null || true
    fi

    # Dừng và xoá systemd service
    systemctl --user stop googledrive 2>/dev/null || true
    systemctl --user disable googledrive 2>/dev/null || true
    rm -f "$SYSTEMD_SERVICE" 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true

    # Gỡ package
    run_cmd sudo apt-get remove -y google-drive-ocamlfuse 2>/dev/null || true
    run_cmd sudo apt-get autoremove -y 2>/dev/null || true
    sudo add-apt-repository --remove -y ppa:alessandro-strada/ppa 2>/dev/null || true
    apt_update_safe && 2>/dev/null || true

    # Xoá mount point (chỉ nếu rỗng)
    if [[ -d "$MOUNT_DIR" ]]; then
        rmdir "$MOUNT_DIR" 2>/dev/null && log_info "Đã xoá $MOUNT_DIR" || \
            log_warn "Thư mục $MOUNT_DIR không rỗng, giữ nguyên"
    fi

    log_warn "Gỡ GNOME Online Accounts: vào Settings → Online Accounts → xoá tài khoản Google thủ công"
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ Google Drive"
}

case "${1:-install}" in
    install)   install_googledrive ;;
    uninstall) uninstall_googledrive ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
