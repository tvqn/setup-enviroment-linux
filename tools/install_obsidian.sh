#!/usr/bin/env bash
# =============================================================================
# install_obsidian.sh - Cài đặt Obsidian (Knowledge base / note-taking)
# Obsidian không có APT repo chính thức → tải .deb từ GitHub Releases
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="obsidian"
DESKTOP_FILE="/usr/share/applications/obsidian.desktop"

install_obsidian() {
    log_section "Cài đặt Obsidian"
    init_devsetup

    # Kiểm tra đã cài chưa
    if is_installed obsidian; then
        local installed_ver
        installed_ver=$(obsidian --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "installed")
        log_info "Phát hiện Obsidian đã cài: $installed_ver"
        log_success "Obsidian $installed_ver đã được cài đặt. Bỏ qua."
        state_set "$TOOL_NAME" "$installed_ver" "installed"
        return 0
    fi

    # Kiểm tra qua snap
    if snap list obsidian &>/dev/null 2>&1; then
        local ver
        ver=$(snap list obsidian 2>/dev/null | awk 'NR==2{print $2}' || echo "snap")
        log_success "Obsidian $ver đã được cài đặt (snap). Bỏ qua."
        state_set "$TOOL_NAME" "$ver" "installed"
        return 0
    fi

    run_cmd sudo apt-get install -y wget curl

    # ── Xác định URL tải về ───────────────────────────────────────────────────
    local deb_url=""

    if [[ "$OBSIDIAN_VERSION" == "latest" ]]; then
        log_step "Truy vấn GitHub API để lấy version mới nhất..."
        # Lấy URL .deb từ GitHub Releases API
        deb_url=$(curl -s "https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest" \
            | grep "browser_download_url" \
            | grep "\.deb\"" \
            | grep -v "arm64" \
            | head -1 \
            | cut -d'"' -f4)
    else
        deb_url="https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/obsidian_${OBSIDIAN_VERSION}_amd64.deb"
    fi

    if [[ -z "$deb_url" ]]; then
        log_error "Không lấy được URL tải Obsidian từ GitHub API"
        state_set "$TOOL_NAME" "unknown" "failed"
        return 1
    fi

    log_info "URL tải: $deb_url"

    # ── Tải .deb ─────────────────────────────────────────────────────────────
    log_step "Tải Obsidian .deb..."
    local tmp_deb
    tmp_deb=$(mktemp /tmp/obsidian_XXXXXX.deb)

    if ! wget -q --show-progress "$deb_url" -O "$tmp_deb"; then
        log_error "Không tải được Obsidian từ: $deb_url"
        state_set "$TOOL_NAME" "unknown" "failed"
        rm -f "$tmp_deb"
        return 1
    fi

    # ── Cài đặt .deb ─────────────────────────────────────────────────────────
    log_step "Cài đặt Obsidian..."

    # Obsidian cần một số thư viện Electron
    run_cmd sudo apt-get install -y \
        libgbm1 \
        libgconf-2-4 \
        libnss3 \
        libatk-bridge2.0-0 \
        libgtk-3-0 \
        libxss1 \
        libasound2 2>/dev/null || true

    if sudo dpkg -i "$tmp_deb" >> "$LOG_FILE" 2>&1; then
        sudo apt-get install -f -y >> "$LOG_FILE" 2>&1 || true  # Fix dependencies
        rm -f "$tmp_deb"

        local ver
        ver=$(dpkg -l obsidian 2>/dev/null | awk 'NR==4{print $3}' || echo "unknown")
        log_success "Obsidian $ver đã cài đặt thành công"
        state_set "$TOOL_NAME" "$ver" "installed"
    else
        # Thử fix dependencies rồi cài lại
        sudo apt-get install -f -y >> "$LOG_FILE" 2>&1 || true
        if sudo dpkg -i "$tmp_deb" >> "$LOG_FILE" 2>&1; then
            rm -f "$tmp_deb"
            local ver
            ver=$(dpkg -l obsidian 2>/dev/null | awk 'NR==4{print $3}' || echo "unknown")
            log_success "Obsidian $ver đã cài đặt thành công (lần 2)"
            state_set "$TOOL_NAME" "$ver" "installed"
        else
            rm -f "$tmp_deb"
            log_error "Obsidian cài đặt THẤT BẠI"
            state_set "$TOOL_NAME" "unknown" "failed"
            return 1
        fi
    fi

    log_info "Vault mặc định sẽ được tạo tại: ~/Documents/Obsidian Vault"
    log_info "Chạy 'obsidian' hoặc tìm trong Applications menu để mở"
}

uninstall_obsidian() {
    log_section "Gỡ cài đặt Obsidian"

    # Gỡ qua snap nếu có
    if snap list obsidian &>/dev/null 2>&1; then
        run_cmd sudo snap remove obsidian
    fi

    # Gỡ qua dpkg
    run_cmd sudo apt-get remove -y obsidian 2>/dev/null || true
    run_cmd sudo apt-get autoremove -y 2>/dev/null || true

    log_warn "Vault và dữ liệu Obsidian vẫn còn nguyên trong thư mục của bạn."
    log_warn "Plugin/theme tại: ~/.config/obsidian/ — xoá thủ công nếu cần."
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ Obsidian"
}

case "${1:-install}" in
    install)   install_obsidian ;;
    uninstall) uninstall_obsidian ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
