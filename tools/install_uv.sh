#!/usr/bin/env bash
# =============================================================================
# install_uv.sh - Cài đặt uv (Python package & project manager)
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="uv"
REQUIRED_VERSION="$UV_VERSION"

install_uv() {
    log_section "Cài đặt uv (Python package manager)"
    init_devsetup

    local installed_ver=""
    if is_installed uv; then
        installed_ver=$(uv --version 2>/dev/null | awk '{print $2}' || echo "")
        log_info "Phát hiện uv đã cài: $installed_ver"
        if [[ "$REQUIRED_VERSION" == "latest" || "$installed_ver" == "$REQUIRED_VERSION" ]]; then
            log_success "uv $installed_ver đã được cài đặt."
            if [[ "$REQUIRED_VERSION" == "latest" ]]; then
                log_info "Kiểm tra cập nhật uv..."
                uv self update >> "$LOG_FILE" 2>&1 || true
            fi
            state_set "$TOOL_NAME" "$installed_ver" "installed"
            return 0
        fi
        check_version_conflict "$TOOL_NAME" "$REQUIRED_VERSION" "$installed_ver" || true
    fi

    log_step "Cài đặt uv qua installer chính thức..."
    run_cmd sudo apt-get install -y curl
    if curl -LsSf https://astral.sh/uv/install.sh | sh; then
        # uv cài vào ~/.cargo/bin hoặc ~/.local/bin
        add_to_path "$HOME/.cargo/bin" "DEVSETUP: uv (cargo) PATH"
        add_to_path "$HOME/.local/bin" "DEVSETUP: uv (local) PATH"
        export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

        local ver
        ver=$(uv --version 2>/dev/null | awk '{print $2}' || echo "unknown")
        log_success "uv $ver đã cài đặt thành công"
        state_set "$TOOL_NAME" "$ver" "installed"
    else
        log_error "uv cài đặt THẤT BẠI"
        state_set "$TOOL_NAME" "$REQUIRED_VERSION" "failed"
        return 1
    fi
}

uninstall_uv() {
    log_section "Gỡ cài đặt uv"
    if is_installed uv; then
        uv self uninstall --no-confirm >> "$LOG_FILE" 2>&1 || true
    fi
    rm -f "$HOME/.cargo/bin/uv" "$HOME/.local/bin/uv" 2>/dev/null || true
    sed -i '/DEVSETUP: uv/d' "$HOME/.bashrc" 2>/dev/null || true
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ uv"
}

case "${1:-install}" in
    install)   install_uv ;;
    uninstall) uninstall_uv ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
