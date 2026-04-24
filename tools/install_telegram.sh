#!/usr/bin/env bash
# =============================================================================
# install_telegram.sh - Cài đặt Telegram Desktop
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="telegram"
SYMLINK="/usr/local/bin/telegram"
DESKTOP_FILE="/usr/share/applications/telegram.desktop"

install_telegram() {
    log_section "Cài đặt Telegram Desktop"
    init_devsetup

    # Kiểm tra đã cài qua snap
    if snap list telegram-desktop &>/dev/null 2>&1; then
        local ver
        ver=$(snap list telegram-desktop 2>/dev/null | awk 'NR==2{print $2}' || echo "snap")
        log_success "Telegram $ver đã được cài đặt (snap). Bỏ qua."
        state_set "$TOOL_NAME" "$ver" "installed"
        return 0
    fi

    # Kiểm tra binary đã tồn tại
    if [[ -f "${TELEGRAM_INSTALL_DIR}/Telegram" ]]; then
        log_success "Telegram đã được cài đặt tại $TELEGRAM_INSTALL_DIR. Bỏ qua."
        state_set "$TOOL_NAME" "installed" "installed"
        return 0
    fi

    # Ưu tiên Snap
    if is_installed snap; then
        log_step "Cài đặt Telegram qua Snap..."
        if run_cmd sudo snap install telegram-desktop; then
            local ver
            ver=$(snap list telegram-desktop 2>/dev/null | awk 'NR==2{print $2}' || echo "snap")
            log_success "Telegram $ver đã cài đặt thành công (snap)"
            state_set "$TOOL_NAME" "$ver" "installed"
            return 0
        fi
        log_warn "Snap thất bại, thử tải binary..."
    fi

    # Fallback: tải binary chính thức
    log_step "Tải Telegram binary từ tg.dev..."
    run_cmd sudo apt-get install -y wget

    local download_url="https://telegram.org/dl/desktop/linux"
    local tmp_file
    tmp_file=$(mktemp /tmp/telegram_XXXXXX.tar.xz)

    if ! wget -q --show-progress "$download_url" -O "$tmp_file"; then
        log_error "Không tải được Telegram"
        state_set "$TOOL_NAME" "unknown" "failed"
        rm -f "$tmp_file"
        return 1
    fi

    log_step "Cài đặt Telegram vào $TELEGRAM_INSTALL_DIR..."
    run_cmd sudo apt-get install -y xz-utils
    run_cmd sudo mkdir -p "$(dirname "$TELEGRAM_INSTALL_DIR")"
    sudo tar -xJf "$tmp_file" -C "$(dirname "$TELEGRAM_INSTALL_DIR")"
    # Archive giải nén thành "Telegram"
    if [[ -d "$(dirname "$TELEGRAM_INSTALL_DIR")/Telegram" ]]; then
        sudo mv "$(dirname "$TELEGRAM_INSTALL_DIR")/Telegram" "$TELEGRAM_INSTALL_DIR"
    fi
    rm -f "$tmp_file"

    # Tạo symlink
    sudo ln -sf "${TELEGRAM_INSTALL_DIR}/Telegram" "$SYMLINK"

    # Tạo desktop entry
    cat <<EOF | sudo tee "$DESKTOP_FILE" > /dev/null
[Desktop Entry]
Version=1.0
Name=Telegram Desktop
Comment=Official Telegram Desktop Application
Exec=${TELEGRAM_INSTALL_DIR}/Telegram -- %u
Icon=${TELEGRAM_INSTALL_DIR}/telegram.png
Terminal=false
Type=Application
Categories=Network;InstantMessaging;
MimeType=x-scheme-handler/tg;
StartupWMClass=TelegramDesktop
EOF

    sudo update-desktop-database 2>/dev/null || true
    log_success "Telegram đã cài đặt tại $TELEGRAM_INSTALL_DIR"
    state_set "$TOOL_NAME" "latest" "installed"
}

uninstall_telegram() {
    log_section "Gỡ cài đặt Telegram"

    if snap list telegram-desktop &>/dev/null 2>&1; then
        run_cmd sudo snap remove telegram-desktop
    fi
    sudo rm -rf "$TELEGRAM_INSTALL_DIR" "$SYMLINK" "$DESKTOP_FILE" 2>/dev/null || true
    sudo update-desktop-database 2>/dev/null || true

    log_warn "Dữ liệu Telegram vẫn còn tại ~/.local/share/TelegramDesktop. Xoá thủ công nếu cần."
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ Telegram"
}

case "${1:-install}" in
    install)   install_telegram ;;
    uninstall) uninstall_telegram ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
