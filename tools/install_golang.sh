#!/usr/bin/env bash
# =============================================================================
# install_golang.sh - Cài đặt Go
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="golang"
REQUIRED_VERSION="$GO_VERSION"
ARCH="$(uname -m)"
[[ "$ARCH" == "x86_64" ]] && GO_ARCH="amd64" || GO_ARCH="arm64"
DOWNLOAD_URL="https://go.dev/dl/go${REQUIRED_VERSION}.linux-${GO_ARCH}.tar.gz"

install_golang() {
    log_section "Cài đặt Go $REQUIRED_VERSION"
    init_devsetup

    local installed_ver=""
    if is_installed go; then
        installed_ver=$(go version 2>/dev/null | grep -oP 'go\K[0-9]+\.[0-9]+\.[0-9]+' || echo "")
        log_info "Phát hiện Go đã cài: $installed_ver"
        check_version_conflict "$TOOL_NAME" "$REQUIRED_VERSION" "$installed_ver" || true
        if [[ "$installed_ver" == "$REQUIRED_VERSION" ]]; then
            log_success "Go $REQUIRED_VERSION đã được cài đặt. Bỏ qua."
            state_set "$TOOL_NAME" "$installed_ver" "installed"
            return 0
        fi
        log_warn "Sẽ cài đè Go (gỡ version cũ trước)"
        sudo rm -rf "$GO_INSTALL_DIR"
    fi

    log_step "Tải Go $REQUIRED_VERSION (${GO_ARCH})..."
    run_cmd sudo apt-get install -y wget
    local tmp_file
    tmp_file=$(mktemp /tmp/go_XXXXXX.tar.gz)

    if ! wget -q --show-progress "$DOWNLOAD_URL" -O "$tmp_file"; then
        log_error "Không tải được Go từ $DOWNLOAD_URL"
        state_set "$TOOL_NAME" "$REQUIRED_VERSION" "failed"
        rm -f "$tmp_file"
        return 1
    fi

    log_step "Cài đặt Go vào $GO_INSTALL_DIR..."
    sudo rm -rf "$GO_INSTALL_DIR"
    run_cmd sudo tar -C /usr/local -xzf "$tmp_file"
    rm -f "$tmp_file"

    add_to_path "$GO_INSTALL_DIR/bin" "DEVSETUP: Go PATH"
    add_env_var "GOPATH" "$HOME/go" "DEVSETUP: GOPATH"
    add_to_path "\$GOPATH/bin" "DEVSETUP: GOPATH bin"

    export PATH="$GO_INSTALL_DIR/bin:$PATH"
    local ver
    ver=$(go version 2>/dev/null | awk '{print $3}' || echo "unknown")
    log_success "Go $ver đã cài đặt thành công"
    state_set "$TOOL_NAME" "$ver" "installed"
}

uninstall_golang() {
    log_section "Gỡ cài đặt Go"
    if [[ -d "$GO_INSTALL_DIR" ]]; then
        run_cmd sudo rm -rf "$GO_INSTALL_DIR"
        log_success "Đã xoá $GO_INSTALL_DIR"
    else
        log_warn "Go không tìm thấy tại $GO_INSTALL_DIR"
    fi
    sed -i '/DEVSETUP: Go PATH/d; /DEVSETUP: GOPATH/d; /GOPATH/d' "$HOME/.bashrc" 2>/dev/null || true
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ Go"
}

case "${1:-install}" in
    install)   install_golang ;;
    uninstall) uninstall_golang ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
