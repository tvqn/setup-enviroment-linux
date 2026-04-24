#!/usr/bin/env bash
# =============================================================================
# install_postman.sh - Cài đặt Postman
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="postman"
DESKTOP_FILE="/usr/share/applications/postman.desktop"
SYMLINK="/usr/local/bin/postman"

install_postman() {
    log_section "Cài đặt Postman"
    init_devsetup

    if [[ -d "$POSTMAN_INSTALL_DIR" ]]; then
        log_info "Phát hiện Postman đã cài tại $POSTMAN_INSTALL_DIR"
        log_success "Postman đã được cài đặt. Bỏ qua."
        state_set "$TOOL_NAME" "installed" "installed"
        return 0
    fi

    # Thử cài qua snap trước (dễ nhất và tự cập nhật)
    if is_installed snap; then
        log_step "Cài đặt Postman qua Snap..."
        if run_cmd sudo snap install postman; then
            log_success "Postman đã cài đặt thành công qua Snap"
            local ver
            ver=$(snap list postman 2>/dev/null | awk 'NR==2{print $2}' || echo "snap")
            state_set "$TOOL_NAME" "$ver" "installed"
            return 0
        fi
        log_warn "Snap cài thất bại, thử cách khác..."
    fi

    # Fallback: tải binary trực tiếp
    log_step "Tải Postman binary..."
    run_cmd sudo apt-get install -y wget libgconf-2-4

    local download_url="https://dl.pstmn.io/download/latest/linux64"
    local tmp_file
    tmp_file=$(mktemp /tmp/postman_XXXXXX.tar.gz)

    if ! wget -q --show-progress "$download_url" -O "$tmp_file"; then
        log_error "Không tải được Postman"
        state_set "$TOOL_NAME" "unknown" "failed"
        rm -f "$tmp_file"
        return 1
    fi

    log_step "Cài đặt Postman vào $POSTMAN_INSTALL_DIR..."
    run_cmd sudo mkdir -p "$(dirname "$POSTMAN_INSTALL_DIR")"
    sudo tar -xzf "$tmp_file" -C "$(dirname "$POSTMAN_INSTALL_DIR")"
    # Archive thường giải nén thành "Postman"
    if [[ -d "$(dirname "$POSTMAN_INSTALL_DIR")/Postman" ]]; then
        sudo mv "$(dirname "$POSTMAN_INSTALL_DIR")/Postman" "$POSTMAN_INSTALL_DIR"
    fi
    rm -f "$tmp_file"

    # Tạo symlink & desktop entry
    sudo ln -sf "${POSTMAN_INSTALL_DIR}/Postman" "$SYMLINK"

    cat <<EOF | sudo tee "$DESKTOP_FILE" > /dev/null
[Desktop Entry]
Encoding=UTF-8
Name=Postman
Exec=${POSTMAN_INSTALL_DIR}/Postman
Icon=${POSTMAN_INSTALL_DIR}/app/resources/app/assets/icon.png
Terminal=false
Type=Application
Categories=Development;
EOF

    sudo update-desktop-database 2>/dev/null || true
    log_success "Postman đã cài đặt tại $POSTMAN_INSTALL_DIR"
    state_set "$TOOL_NAME" "latest" "installed"
}

uninstall_postman() {
    log_section "Gỡ cài đặt Postman"
    # Thử gỡ qua snap
    if snap list postman &>/dev/null 2>&1; then
        run_cmd sudo snap remove postman
    fi
    sudo rm -rf "$POSTMAN_INSTALL_DIR" "$SYMLINK" "$DESKTOP_FILE" 2>/dev/null || true
    sudo update-desktop-database 2>/dev/null || true
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ Postman"
}

case "${1:-install}" in
    install)   install_postman ;;
    uninstall) uninstall_postman ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
