#!/usr/bin/env bash
# =============================================================================
# install_libreoffice.sh - Cài đặt LibreOffice (bản mới nhất qua PPA)
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="libreoffice"

install_libreoffice() {
    log_section "Cài đặt LibreOffice"
    init_devsetup

    # Kiểm tra đã cài chưa
    if is_installed libreoffice; then
        local installed_ver
        installed_ver=$(libreoffice --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "installed")
        log_info "Phát hiện LibreOffice đã cài: $installed_ver"
        log_success "LibreOffice $installed_ver đã được cài đặt. Bỏ qua."
        state_set "$TOOL_NAME" "$installed_ver" "installed"
        return 0
    fi

    apt_update_safe
    run_cmd sudo apt-get install -y software-properties-common

    # Thêm LibreOffice Fresh PPA cho version mới nhất
    if [[ "$LIBREOFFICE_VERSION" == "latest" || "$LIBREOFFICE_VERSION" == "fresh" ]]; then
        log_step "Thêm LibreOffice Fresh PPA..."
        run_cmd sudo add-apt-repository -y ppa:libreoffice/ppa
        apt_update_safe
    fi
    # Nếu LIBREOFFICE_VERSION == "still" thì dùng apt mặc định của Ubuntu (bản stable)

    log_step "Cài đặt LibreOffice (full suite)..."
    if run_cmd sudo apt-get install -y \
            libreoffice \
            libreoffice-writer \
            libreoffice-calc \
            libreoffice-impress \
            libreoffice-draw \
            libreoffice-base \
            libreoffice-l10n-vi \
            libreoffice-help-vi; then
        local ver
        ver=$(libreoffice --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        log_success "LibreOffice $ver đã cài đặt thành công (bao gồm tiếng Việt)"
        state_set "$TOOL_NAME" "$ver" "installed"
    else
        log_error "LibreOffice cài đặt THẤT BẠI"
        state_set "$TOOL_NAME" "unknown" "failed"
        return 1
    fi
}

uninstall_libreoffice() {
    log_section "Gỡ cài đặt LibreOffice"
    run_cmd sudo apt-get remove -y \
        libreoffice \
        libreoffice-writer \
        libreoffice-calc \
        libreoffice-impress \
        libreoffice-draw \
        libreoffice-base \
        libreoffice-l10n-vi \
        libreoffice-help-vi \
        libreoffice-common 2>/dev/null || true
    run_cmd sudo apt-get autoremove -y

    # Xoá PPA
    sudo add-apt-repository --remove -y ppa:libreoffice/ppa 2>/dev/null || true
    apt_update_safe && 2>/dev/null || true

    log_warn "Cấu hình LibreOffice vẫn còn tại ~/.config/libreoffice. Xoá thủ công nếu cần."
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ LibreOffice"
}

case "${1:-install}" in
    install)   install_libreoffice ;;
    uninstall) uninstall_libreoffice ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
