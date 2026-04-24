#!/usr/bin/env bash
# =============================================================================
# install_dotnet.sh - Cài đặt .NET Core SDK
#
# Chiến lược theo Ubuntu version:
#   Ubuntu 24.04+  → apt install dotnet-sdk-X.0 (có sẵn trong Ubuntu feed)
#   Ubuntu 22.04   → Microsoft APT repository (packages.microsoft.com/ubuntu/)
#   Ubuntu 20.04   → packages-microsoft-prod.deb (cách cũ)
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="dotnet"
REQUIRED_VERSION="$DOTNET_VERSION"

# ── Lấy thông tin Ubuntu ──────────────────────────────────────────────────────
get_ubuntu_version() {
    lsb_release -rs 2>/dev/null || grep VERSION_ID /etc/os-release | cut -d'"' -f2
}

get_ubuntu_codename() {
    lsb_release -cs 2>/dev/null || grep VERSION_CODENAME /etc/os-release | cut -d= -f2
}

# =============================================================================
# INSTALL
# =============================================================================
install_dotnet() {
    log_section "Cài đặt .NET Core SDK $REQUIRED_VERSION"
    init_devsetup

    # ── Kiểm tra đã cài chưa ────────────────────────────────────────────────
    if is_installed dotnet; then
        local installed_ver
        installed_ver=$(dotnet --version 2>/dev/null | cut -d. -f1,2 || echo "")
        log_info "Phát hiện .NET đã cài: $installed_ver"
        check_version_conflict "$TOOL_NAME" "$REQUIRED_VERSION" "$installed_ver" || true
        if [[ "$installed_ver" == "$REQUIRED_VERSION"* ]]; then
            log_success ".NET $REQUIRED_VERSION đã được cài đặt. Bỏ qua."
            state_set "$TOOL_NAME" "$installed_ver" "installed"
            return 0
        fi
        log_warn "Sẽ cài thêm .NET SDK $REQUIRED_VERSION"
    fi

    local ubuntu_ver
    local ubuntu_codename
    ubuntu_ver=$(get_ubuntu_version)
    ubuntu_codename=$(get_ubuntu_codename)
    log_info "Ubuntu version: $ubuntu_ver ($ubuntu_codename)"

    apt_update_safe
    sudo apt-get install -y wget apt-transport-https ca-certificates gnupg >> "$LOG_FILE" 2>&1

    # ── Phân nhánh theo Ubuntu version ──────────────────────────────────────
    local major_ver
    major_ver=$(echo "$ubuntu_ver" | cut -d. -f1)

    if [[ "$major_ver" -ge 24 ]]; then
        _install_dotnet_ubuntu24
    elif [[ "$major_ver" -ge 22 ]]; then
        _install_dotnet_ubuntu22
    else
        _install_dotnet_ubuntu20
    fi
}

# ── Ubuntu 24.04+: dotnet có trong Ubuntu official feed ───────────────────────
_install_dotnet_ubuntu24() {
    log_step "Ubuntu 24.04+: Cài .NET từ Ubuntu official feed..."

    # Xóa conflict package nếu có (ubuntu feed và ms feed conflict nhau)
    sudo apt-get remove -y dotnet* aspnet* 2>/dev/null || true
    # Loại trừ MS feed nếu có (tránh conflict)
    if [[ -f /etc/apt/sources.list.d/microsoft-prod.list ]]; then
        log_warn "Phát hiện Microsoft repo — tạm loại trừ để tránh conflict..."
        sudo tee /etc/apt/preferences.d/dotnet-prefer-ubuntu > /dev/null <<EOF
Package: dotnet* aspnet* netstandard*
Pin: origin "packages.microsoft.com"
Pin-Priority: -10
EOF
    fi

    apt_update_safe

    local pkg="dotnet-sdk-${REQUIRED_VERSION}"
    log_step "Cài đặt $pkg..."
    if sudo apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1; then
        _dotnet_success
    else
        log_warn "Ubuntu feed thất bại, thử Microsoft repo..."
        _install_dotnet_via_ms_repo
    fi
}

# ── Ubuntu 22.04: dùng Microsoft APT repo trực tiếp ──────────────────────────
_install_dotnet_ubuntu22() {
    log_step "Ubuntu 22.04: Cài .NET từ Microsoft APT repository..."
    _install_dotnet_via_ms_repo
}

# ── Ubuntu 20.04: dùng packages-microsoft-prod.deb ───────────────────────────
_install_dotnet_ubuntu20() {
    log_step "Ubuntu 20.04: Cài .NET từ packages-microsoft-prod.deb..."
    local ubuntu_ver
    ubuntu_ver=$(get_ubuntu_version)
    local pkg_url="https://packages.microsoft.com/config/ubuntu/${ubuntu_ver}/packages-microsoft-prod.deb"

    local tmp_deb
    tmp_deb=$(mktemp /tmp/ms-prod_XXXXXX.deb)

    log_info "Tải: $pkg_url"
    if wget -q "$pkg_url" -O "$tmp_deb" >> "$LOG_FILE" 2>&1; then
        sudo dpkg -i "$tmp_deb" >> "$LOG_FILE" 2>&1 || true
        rm -f "$tmp_deb"
        apt_update_safe

        local pkg="dotnet-sdk-${REQUIRED_VERSION}"
        if sudo apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1; then
            _dotnet_success
            return 0
        fi
    else
        rm -f "$tmp_deb"
        log_warn "Không tải được packages-microsoft-prod.deb, thử MS APT repo..."
    fi
    _install_dotnet_via_ms_repo
}

# ── Cài qua Microsoft APT repo (dùng cho 22.04 và fallback) ──────────────────
_install_dotnet_via_ms_repo() {
    local ubuntu_codename
    ubuntu_codename=$(get_ubuntu_codename)

    log_step "Thêm Microsoft APT repository..."
    sudo mkdir -p /etc/apt/keyrings

    # Tải GPG key
    if ! wget -qO- "https://packages.microsoft.com/keys/microsoft.asc" \
        | gpg --dearmor \
        | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null 2>&1; then
        log_error "Không tải được Microsoft GPG key"
        state_set "$TOOL_NAME" "$REQUIRED_VERSION" "failed"
        return 1
    fi
    sudo chmod a+r /etc/apt/keyrings/microsoft.gpg

    # Thêm repo
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/ubuntu/${ubuntu_codename}/prod ${ubuntu_codename} main" \
        | sudo tee /etc/apt/sources.list.d/microsoft-dotnet.list > /dev/null

    # Fallback URL nếu codename không có trong MS repo
    apt_update_safe

    local pkg="dotnet-sdk-${REQUIRED_VERSION}"
    log_step "Cài đặt $pkg..."
    if sudo apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1; then
        _dotnet_success
    else
        # Thử thêm: cài qua snap làm last resort
        log_warn "APT repo thất bại, thử cài qua snap..."
        _install_dotnet_snap
    fi
}

# ── Cài qua Snap (last resort) ────────────────────────────────────────────────
_install_dotnet_snap() {
    if ! is_installed snap; then
        log_error ".NET cài đặt THẤT BẠI — không còn phương án nào"
        state_set "$TOOL_NAME" "$REQUIRED_VERSION" "failed"
        return 1
    fi

    log_step "Cài .NET qua Snap (last resort)..."
    # Snap chỉ có dotnet-sdk không phân biệt minor version
    if sudo snap install dotnet-sdk --classic --channel="${REQUIRED_VERSION}/stable" >> "$LOG_FILE" 2>&1; then
        sudo snap alias dotnet-sdk.dotnet dotnet >> "$LOG_FILE" 2>&1 || true
        _dotnet_success
    else
        log_error ".NET SDK $REQUIRED_VERSION cài đặt THẤT BẠI trên tất cả phương án"
        log_error "Xem log chi tiết: $LOG_FILE"
        state_set "$TOOL_NAME" "$REQUIRED_VERSION" "failed"
        return 1
    fi
}

# ── Xử lý khi cài thành công ─────────────────────────────────────────────────
_dotnet_success() {
    local ver
    ver=$(dotnet --version 2>/dev/null || echo "unknown")
    log_success ".NET SDK $ver đã cài đặt thành công"
    state_set "$TOOL_NAME" "$ver" "installed"
    dotnet --info >> "$LOG_FILE" 2>&1 || true
}

# =============================================================================
# UNINSTALL
# =============================================================================
uninstall_dotnet() {
    log_section "Gỡ cài đặt .NET Core"

    # Gỡ snap nếu có
    if snap list dotnet-sdk &>/dev/null 2>&1; then
        run_cmd sudo snap remove dotnet-sdk
    fi

    # Gỡ qua apt
    local pkgs
    pkgs=$(dpkg -l 2>/dev/null | grep -iE 'dotnet|aspnet|netstandard' \
        | awk '{print $2}' | tr '\n' ' ' || echo "")
    if [[ -n "${pkgs// }" ]]; then
        log_info "Gỡ các gói: $pkgs"
        # shellcheck disable=SC2086
        sudo apt-get remove -y $pkgs >> "$LOG_FILE" 2>&1 || true
        sudo apt-get autoremove -y   >> "$LOG_FILE" 2>&1 || true
        log_success "Đã gỡ .NET packages"
    else
        log_warn ".NET packages không tìm thấy qua apt"
    fi

    # Xoá repo và key
    sudo rm -f \
        /etc/apt/sources.list.d/microsoft-prod.list \
        /etc/apt/sources.list.d/microsoft-dotnet.list \
        /etc/apt/sources.list.d/*microsoft*.list \
        /etc/apt/keyrings/microsoft.gpg \
        /etc/apt/preferences.d/dotnet-prefer-ubuntu \
        2>/dev/null || true

    apt_update_safe
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ .NET"
}

# =============================================================================
# ENTRYPOINT
# =============================================================================
case "${1:-install}" in
    install)   install_dotnet ;;
    uninstall) uninstall_dotnet ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
