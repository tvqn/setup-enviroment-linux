#!/usr/bin/env bash
# =============================================================================
# install_firefox.sh - Cài đặt Firefox (Mozilla official PPA)
# Ubuntu 22.04+ đã gỡ Firefox khỏi apt, dùng Mozilla PPA để cài bản .deb
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="firefox"
MOZILLA_KEYRING="/etc/apt/keyrings/packages.mozilla.org.asc"
MOZILLA_SOURCES="/etc/apt/sources.list.d/mozilla.list"
MOZILLA_PREFS="/etc/apt/preferences.d/mozilla"

install_firefox() {
    log_section "Cài đặt Firefox"
    init_devsetup

    # Kiểm tra đã cài chưa (apt hoặc snap)
    if is_installed firefox; then
        local installed_ver
        installed_ver=$(firefox --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+' | head -1 || echo "installed")
        log_info "Phát hiện Firefox đã cài: $installed_ver"

        # Kiểm tra có phải bản snap không
        if snap list firefox &>/dev/null 2>&1; then
            log_warn "Firefox hiện là bản Snap. Script sẽ cài lại bản .deb từ Mozilla PPA."
            log_step "Gỡ Firefox Snap..."
            run_cmd sudo snap remove firefox 2>/dev/null || true
        else
            log_success "Firefox $installed_ver đã được cài đặt (.deb). Bỏ qua."
            state_set "$TOOL_NAME" "$installed_ver" "installed"
            return 0
        fi
    fi

    log_step "Thêm Mozilla GPG key & APT repository..."
    run_cmd sudo apt-get install -y wget curl gpg

    sudo mkdir -p /etc/apt/keyrings
    if ! wget -qO- "https://packages.mozilla.org/apt/repo-signing-key.gpg" \
        | sudo tee "$MOZILLA_KEYRING" > /dev/null; then
        log_error "Không tải được Mozilla GPG key"
        state_set "$TOOL_NAME" "unknown" "failed"
        return 1
    fi
    sudo chmod a+r "$MOZILLA_KEYRING"

    echo "deb [signed-by=${MOZILLA_KEYRING}] https://packages.mozilla.org/apt mozilla main" \
        | sudo tee "$MOZILLA_SOURCES" > /dev/null

    # Đặt ưu tiên để dùng Mozilla repo thay vì snap
    cat <<EOF | sudo tee "$MOZILLA_PREFS" > /dev/null
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

    apt_update_safe

    # Chọn package theo FIREFOX_VERSION
    local pkg="firefox"
    if [[ "$FIREFOX_VERSION" == "esr" ]]; then
        pkg="firefox-esr"
        log_info "Cài đặt Firefox ESR (Extended Support Release)"
    else
        log_info "Cài đặt Firefox (latest stable)"
    fi

    log_step "Cài đặt $pkg..."
    if run_cmd sudo apt-get install -y "$pkg"; then
        local ver
        ver=$(firefox --version 2>/dev/null | grep -oP '[0-9]+\.[0-9.]+' | head -1 || echo "unknown")
        log_success "Firefox $ver đã cài đặt thành công"
        state_set "$TOOL_NAME" "$ver" "installed"
    else
        log_error "Firefox cài đặt THẤT BẠI"
        state_set "$TOOL_NAME" "unknown" "failed"
        return 1
    fi
}

uninstall_firefox() {
    log_section "Gỡ cài đặt Firefox"

    # Gỡ snap nếu có
    if snap list firefox &>/dev/null 2>&1; then
        run_cmd sudo snap remove firefox
    fi

    run_cmd sudo apt-get remove -y firefox firefox-esr 2>/dev/null || true
    run_cmd sudo apt-get autoremove -y 2>/dev/null || true
    sudo rm -f "$MOZILLA_SOURCES" "$MOZILLA_KEYRING" "$MOZILLA_PREFS" 2>/dev/null || true
    apt_update_safe && 2>/dev/null || true

    log_warn "Profile Firefox vẫn còn tại ~/.mozilla. Xoá thủ công nếu cần."
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ Firefox"
}

case "${1:-install}" in
    install)   install_firefox ;;
    uninstall) uninstall_firefox ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
