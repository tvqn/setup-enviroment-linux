#!/usr/bin/env bash
# =============================================================================
# install_qgis.sh - Cài đặt QGIS (Geographic Information System)
# Tài liệu: https://qgis.org/resources/installation-guide/
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="qgis"
QGIS_KEYRING="/etc/apt/keyrings/qgis-archive-keyring.gpg"
QGIS_SOURCES="/etc/apt/sources.list.d/qgis.sources"

install_qgis() {
    log_section "Cài đặt QGIS"
    init_devsetup

    # Kiểm tra đã cài chưa
    if is_installed qgis; then
        local installed_ver
        installed_ver=$(qgis --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "installed")
        log_info "Phát hiện QGIS đã cài: $installed_ver"
        log_success "QGIS $installed_ver đã được cài đặt. Bỏ qua."
        state_set "$TOOL_NAME" "$installed_ver" "installed"
        return 0
    fi

    local ubuntu_codename
    ubuntu_codename=$(lsb_release -cs)

    # Xác định repo theo version Ubuntu và QGIS_VERSION
    local repo_label
    if [[ "$QGIS_VERSION" == "ltr" ]]; then
        repo_label="ubuntu-ltr"
    else
        repo_label="ubuntu"
    fi

    log_step "Thêm QGIS GPG key & repository..."
    run_cmd sudo apt-get install -y wget gnupg software-properties-common

    sudo mkdir -p /etc/apt/keyrings
    if ! wget -qO - "https://qgis.org/downloads/qgis-archive-keyring.gpg" \
        | sudo gpg --dearmor -o "$QGIS_KEYRING" 2>/dev/null; then
        log_error "Không tải được QGIS GPG key"
        state_set "$TOOL_NAME" "unknown" "failed"
        return 1
    fi
    sudo chmod a+r "$QGIS_KEYRING"

    # Tạo sources file theo định dạng DEB822
    cat <<EOF | sudo tee "$QGIS_SOURCES" > /dev/null
Types: deb deb-src
URIs: https://qgis.org/debian
Suites: ${ubuntu_codename}
Architectures: amd64
Components: main
Signed-By: ${QGIS_KEYRING}
EOF

    apt_update_safe

    log_step "Cài đặt QGIS..."
    if run_cmd sudo apt-get install -y qgis qgis-plugin-grass; then
        local ver
        ver=$(qgis --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        log_success "QGIS $ver đã cài đặt thành công"
        state_set "$TOOL_NAME" "$ver" "installed"
    else
        # Fallback: thử ubuntu-ltr repo
        log_warn "Thử cài từ ubuntu-ltr repository..."
        cat <<EOF | sudo tee "$QGIS_SOURCES" > /dev/null
Types: deb deb-src
URIs: https://qgis.org/ubuntu-ltr
Suites: ${ubuntu_codename}
Architectures: amd64
Components: main
Signed-By: ${QGIS_KEYRING}
EOF
        apt_update_safe
        if run_cmd sudo apt-get install -y qgis; then
            local ver
            ver=$(qgis --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
            log_success "QGIS $ver đã cài đặt thành công (LTR)"
            state_set "$TOOL_NAME" "$ver" "installed"
        else
            log_error "QGIS cài đặt THẤT BẠI"
            state_set "$TOOL_NAME" "unknown" "failed"
            return 1
        fi
    fi
}

uninstall_qgis() {
    log_section "Gỡ cài đặt QGIS"
    run_cmd sudo apt-get remove -y qgis qgis-plugin-grass qgis-common 2>/dev/null || true
    run_cmd sudo apt-get autoremove -y 2>/dev/null || true
    sudo rm -f "$QGIS_SOURCES" "$QGIS_KEYRING" 2>/dev/null || true
    apt_update_safe && 2>/dev/null || true
    log_warn "Dữ liệu project QGIS vẫn còn trong thư mục của bạn."
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ QGIS"
}

case "${1:-install}" in
    install)   install_qgis ;;
    uninstall) uninstall_qgis ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
