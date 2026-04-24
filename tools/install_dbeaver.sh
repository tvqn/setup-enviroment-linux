#!/usr/bin/env bash
# =============================================================================
# install_dbeaver.sh - Cài đặt DBeaver Community Edition
#
# Chiến lược:
#   1. Snap --classic  (tự cập nhật, dễ nhất)
#   2. .deb từ GitHub Releases API (version mới nhất)
#   3. .deb từ dbeaver.io link cố định (fallback nếu API lỗi)
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="dbeaver"

install_dbeaver() {
    log_section "Cài đặt DBeaver Community Edition"
    init_devsetup

    # ── Kiểm tra đã cài chưa ────────────────────────────────────────────────
    if snap list dbeaver-ce &>/dev/null 2>&1; then
        local ver
        ver=$(snap list dbeaver-ce 2>/dev/null | awk 'NR==2{print $2}' || echo "snap")
        log_success "DBeaver $ver đã được cài đặt (snap). Bỏ qua."
        state_set "$TOOL_NAME" "$ver" "installed"
        return 0
    fi

    if dpkg -l dbeaver-ce &>/dev/null 2>&1; then
        local ver
        ver=$(dpkg -l dbeaver-ce 2>/dev/null | awk 'NR==4{print $3}' || echo "deb")
        log_success "DBeaver $ver đã được cài đặt (.deb). Bỏ qua."
        state_set "$TOOL_NAME" "$ver" "installed"
        return 0
    fi

    # ── Phương án 1: Snap với --classic ─────────────────────────────────────
    if is_installed snap; then
        log_step "Cài đặt DBeaver qua Snap (--classic)..."
        if sudo snap install dbeaver-ce --classic >> "$LOG_FILE" 2>&1; then
            local ver
            ver=$(snap list dbeaver-ce 2>/dev/null | awk 'NR==2{print $2}' || echo "snap")
            log_success "DBeaver $ver đã cài đặt thành công (snap)"
            state_set "$TOOL_NAME" "$ver" "installed"
            return 0
        fi
        log_warn "Snap thất bại, thử .deb package..."
    fi

    # ── Phương án 2 & 3: .deb package ───────────────────────────────────────
    sudo apt-get install -y wget curl >> "$LOG_FILE" 2>&1

    local deb_url=""

    # Thử GitHub API trước
    log_step "Truy vấn GitHub API để lấy URL .deb mới nhất..."
    deb_url=$(curl -fsSL --max-time 15 \
        "https://api.github.com/repos/dbeaver/dbeaver/releases/latest" \
        2>/dev/null \
        | grep "browser_download_url" \
        | grep '".*amd64\.deb"' \
        | grep -v "enterprise\|lite" \
        | head -1 \
        | cut -d'"' -f4 || echo "")

    # Fallback: dùng link cố định từ dbeaver.io
    if [[ -z "$deb_url" ]]; then
        log_warn "GitHub API không phản hồi, dùng link cố định từ dbeaver.io..."
        deb_url="https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb"
    fi

    log_info "URL tải: $deb_url"

    # Tải .deb
    local tmp_deb
    tmp_deb=$(mktemp /tmp/dbeaver_XXXXXX.deb)
    log_step "Tải DBeaver .deb..."

    if ! wget -q --show-progress --timeout=60 "$deb_url" -O "$tmp_deb" \
            >> "$LOG_FILE" 2>&1; then
        log_error "Không tải được DBeaver .deb từ: $deb_url"
        rm -f "$tmp_deb"
        state_set "$TOOL_NAME" "unknown" "failed"
        return 1
    fi

    # Kiểm tra file tải về có hợp lệ không (tối thiểu 1MB)
    local file_size
    file_size=$(stat -c%s "$tmp_deb" 2>/dev/null || echo 0)
    if [[ "$file_size" -lt 1048576 ]]; then
        log_error "File tải về quá nhỏ ($file_size bytes) — có thể bị lỗi"
        rm -f "$tmp_deb"
        state_set "$TOOL_NAME" "unknown" "failed"
        return 1
    fi

    # Cài dependencies trước
    log_step "Cài đặt DBeaver .deb..."
    sudo apt-get install -y default-jre >> "$LOG_FILE" 2>&1 || true

    if sudo dpkg -i "$tmp_deb" >> "$LOG_FILE" 2>&1; then
        sudo apt-get install -f -y >> "$LOG_FILE" 2>&1 || true
        rm -f "$tmp_deb"
        local ver
        ver=$(dpkg -l dbeaver-ce 2>/dev/null | awk 'NR==4{print $3}' || echo "unknown")
        log_success "DBeaver $ver đã cài đặt thành công (.deb)"
        state_set "$TOOL_NAME" "$ver" "installed"
    else
        # dpkg -i thất bại → thử fix dependencies rồi cài lại
        sudo apt-get install -f -y >> "$LOG_FILE" 2>&1 || true
        if sudo dpkg -i "$tmp_deb" >> "$LOG_FILE" 2>&1; then
            rm -f "$tmp_deb"
            local ver
            ver=$(dpkg -l dbeaver-ce 2>/dev/null | awk 'NR==4{print $3}' || echo "unknown")
            log_success "DBeaver $ver đã cài đặt thành công (retry)"
            state_set "$TOOL_NAME" "$ver" "installed"
        else
            rm -f "$tmp_deb"
            log_error "DBeaver cài đặt THẤT BẠI — xem: $LOG_FILE"
            state_set "$TOOL_NAME" "unknown" "failed"
            return 1
        fi
    fi
}

uninstall_dbeaver() {
    log_section "Gỡ cài đặt DBeaver"

    if snap list dbeaver-ce &>/dev/null 2>&1; then
        run_cmd sudo snap remove dbeaver-ce
    fi

    if dpkg -l dbeaver-ce &>/dev/null 2>&1; then
        run_cmd sudo apt-get remove -y dbeaver-ce
        run_cmd sudo apt-get autoremove -y
    fi

    log_warn "Cấu hình DBeaver vẫn còn tại ~/.local/share/DBeaverData. Xoá thủ công nếu cần."
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ DBeaver"
}

case "${1:-install}" in
    install)   install_dbeaver ;;
    uninstall) uninstall_dbeaver ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
