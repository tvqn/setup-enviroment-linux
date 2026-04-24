#!/usr/bin/env bash
# =============================================================================
# install_vscode.sh - Cài đặt Visual Studio Code
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="vscode"

install_vscode() {
    log_section "Cài đặt Visual Studio Code"
    init_devsetup

    # Kiểm tra đã cài chưa
    local installed_ver=""
    if is_installed code; then
        installed_ver=$(code --version 2>/dev/null | head -1 || echo "")
        log_info "Phát hiện VS Code đã cài: $installed_ver"
        log_success "VS Code $installed_ver đã được cài đặt. Bỏ qua."
        state_set "$TOOL_NAME" "$installed_ver" "installed"
        return 0
    fi

    # Thử Snap trước (dễ nhất)
    if is_installed snap; then
        log_step "Cài đặt VS Code qua Snap..."
        if run_cmd sudo snap install code --classic; then
            local ver
            ver=$(code --version 2>/dev/null | head -1 || echo "snap")
            log_success "VS Code $ver đã cài đặt thành công (snap)"
            state_set "$TOOL_NAME" "$ver" "installed"
            return 0
        fi
        log_warn "Snap thất bại, thử qua Microsoft repository..."
    fi

    # Fallback: Microsoft APT repository
    log_step "Thêm Microsoft GPG key & APT repository..."
    run_cmd sudo apt-get install -y wget gpg apt-transport-https

    if ! wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor \
        | sudo tee /etc/apt/keyrings/microsoft-vscode.gpg > /dev/null; then
        log_error "Không tải được Microsoft GPG key"
        state_set "$TOOL_NAME" "unknown" "failed"
        return 1
    fi
    sudo chmod a+r /etc/apt/keyrings/microsoft-vscode.gpg

    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft-vscode.gpg] \
https://packages.microsoft.com/repos/code stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

    apt_update_safe
    if run_cmd sudo apt-get install -y code; then
        local ver
        ver=$(code --version 2>/dev/null | head -1 || echo "unknown")
        log_success "VS Code $ver đã cài đặt thành công"
        state_set "$TOOL_NAME" "$ver" "installed"
    else
        log_error "VS Code cài đặt THẤT BẠI"
        state_set "$TOOL_NAME" "unknown" "failed"
        return 1
    fi
}

uninstall_vscode() {
    log_section "Gỡ cài đặt VS Code"

    # Gỡ qua snap
    if snap list code &>/dev/null 2>&1; then
        run_cmd sudo snap remove code
    fi

    # Gỡ qua apt
    run_cmd sudo apt-get remove -y code 2>/dev/null || true
    sudo rm -f /etc/apt/sources.list.d/vscode.list \
               /etc/apt/keyrings/microsoft-vscode.gpg 2>/dev/null || true
    apt_update_safe && 2>/dev/null || true

    log_warn "Cấu hình VS Code vẫn còn tại ~/.config/Code. Xoá thủ công nếu cần."
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ VS Code"
}

case "${1:-install}" in
    install)   install_vscode ;;
    uninstall) uninstall_vscode ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
