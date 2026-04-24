#!/usr/bin/env bash
# =============================================================================
# install_python.sh - Cài đặt Python (deadsnakes PPA)
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="python"
REQUIRED_VERSION="$PYTHON_VERSION"

install_python() {
    log_section "Cài đặt Python $REQUIRED_VERSION"
    init_devsetup

    local py_cmd="python${REQUIRED_VERSION}"
    local installed_ver=""
    if is_installed "$py_cmd"; then
        installed_ver=$("$py_cmd" --version 2>&1 | grep -oP '[0-9]+\.[0-9]+' | head -1 || echo "")
        log_info "Phát hiện Python đã cài: $installed_ver"
        if [[ "$installed_ver" == "$REQUIRED_VERSION" ]]; then
            log_success "Python $REQUIRED_VERSION đã được cài đặt. Bỏ qua."
            state_set "$TOOL_NAME" "$installed_ver" "installed"
            return 0
        fi
        check_version_conflict "$TOOL_NAME" "$REQUIRED_VERSION" "$installed_ver" || true
    fi

    log_step "Thêm deadsnakes PPA..."
    run_cmd sudo apt-get install -y software-properties-common
    run_cmd sudo add-apt-repository -y ppa:deadsnakes/ppa
    apt_update_safe

    log_step "Cài đặt Python $REQUIRED_VERSION..."
    if run_cmd sudo apt-get install -y \
            "python${REQUIRED_VERSION}" \
            "python${REQUIRED_VERSION}-venv" \
            "python${REQUIRED_VERSION}-dev" \
            "python${REQUIRED_VERSION}-distutils" \
            python3-pip; then
        # Đặt python3 trỏ vào version mới (dùng update-alternatives)
        sudo update-alternatives --install /usr/bin/python3 python3 \
            "/usr/bin/python${REQUIRED_VERSION}" 1 2>/dev/null || true
        sudo update-alternatives --install /usr/bin/python python \
            "/usr/bin/python${REQUIRED_VERSION}" 1 2>/dev/null || true

        local ver
        ver=$("$py_cmd" --version 2>&1 | awk '{print $2}')
        log_success "Python $ver đã cài đặt thành công"
        state_set "$TOOL_NAME" "$ver" "installed"
    else
        log_error "Python $REQUIRED_VERSION cài đặt THẤT BẠI"
        state_set "$TOOL_NAME" "$REQUIRED_VERSION" "failed"
        return 1
    fi
}

uninstall_python() {
    log_section "Gỡ cài đặt Python $REQUIRED_VERSION"
    log_warn "Lưu ý: Gỡ Python có thể ảnh hưởng các công cụ hệ thống phụ thuộc"
    run_cmd sudo apt-get remove -y \
        "python${REQUIRED_VERSION}" \
        "python${REQUIRED_VERSION}-venv" \
        "python${REQUIRED_VERSION}-dev" \
        "python${REQUIRED_VERSION}-distutils" 2>/dev/null || true
    run_cmd sudo apt-get autoremove -y
    sudo update-alternatives --remove python3 "/usr/bin/python${REQUIRED_VERSION}" 2>/dev/null || true
    sudo update-alternatives --remove python "/usr/bin/python${REQUIRED_VERSION}" 2>/dev/null || true
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ Python"
}

case "${1:-install}" in
    install)   install_python ;;
    uninstall) uninstall_python ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
