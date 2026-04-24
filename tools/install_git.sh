#!/usr/bin/env bash
# =============================================================================
# install_git.sh - Cài đặt Git và Git LFS
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_GIT="git"
TOOL_LFS="git-lfs"

install_git() {
    log_section "Cài đặt Git"
    init_devsetup

    local installed_ver=""
    if is_installed git; then
        installed_ver=$(git --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
        log_info "Phát hiện Git đã cài: $installed_ver"
        log_success "Git $installed_ver đã được cài đặt. Bỏ qua."
        state_set "$TOOL_GIT" "$installed_ver" "installed"
    else
        log_step "Thêm git-core PPA (latest stable)..."
        run_cmd sudo apt-get install -y software-properties-common
        run_cmd sudo add-apt-repository -y ppa:git-core/ppa
        apt_update_safe
        if run_cmd sudo apt-get install -y git; then
            local ver
            ver=$(git --version | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            log_success "Git $ver đã cài đặt thành công"
            state_set "$TOOL_GIT" "$ver" "installed"
        else
            log_error "Git cài đặt THẤT BẠI"
            state_set "$TOOL_GIT" "unknown" "failed"
            return 1
        fi
    fi

    # Git LFS
    log_section "Cài đặt Git LFS"
    local lfs_installed=""
    if is_installed git-lfs; then
        lfs_installed=$(git lfs version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
        log_info "Phát hiện Git LFS đã cài: $lfs_installed"
        log_success "Git LFS $lfs_installed đã được cài đặt. Bỏ qua."
        state_set "$TOOL_LFS" "$lfs_installed" "installed"
        return 0
    fi

    log_step "Cài đặt Git LFS..."
    run_cmd sudo apt-get install -y curl
    if curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash; then
        if run_cmd sudo apt-get install -y git-lfs; then
            run_cmd git lfs install
            local lfs_ver
            lfs_ver=$(git lfs version | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
            log_success "Git LFS $lfs_ver đã cài đặt thành công"
            state_set "$TOOL_LFS" "$lfs_ver" "installed"
        else
            log_error "Git LFS cài đặt THẤT BẠI"
            state_set "$TOOL_LFS" "unknown" "failed"
            return 1
        fi
    else
        # Fallback: cài từ apt
        if run_cmd sudo apt-get install -y git-lfs; then
            run_cmd git lfs install
            local lfs_ver
            lfs_ver=$(git lfs version | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
            log_success "Git LFS $lfs_ver đã cài đặt (apt)"
            state_set "$TOOL_LFS" "$lfs_ver" "installed"
        else
            log_error "Git LFS cài đặt THẤT BẠI"
            state_set "$TOOL_LFS" "unknown" "failed"
            return 1
        fi
    fi
}

uninstall_git() {
    log_section "Gỡ cài đặt Git LFS"
    if is_installed git-lfs; then
        git lfs uninstall 2>/dev/null || true
        run_cmd sudo apt-get remove -y git-lfs 2>/dev/null || true
    fi
    state_remove "$TOOL_LFS"

    log_section "Gỡ cài đặt Git"
    log_warn "Lưu ý: Gỡ Git có thể ảnh hưởng nhiều công cụ phụ thuộc!"
    run_cmd sudo apt-get remove -y git 2>/dev/null || true
    run_cmd sudo apt-get autoremove -y
    state_remove "$TOOL_GIT"
    log_success "Hoàn tất gỡ Git và Git LFS"
}

case "${1:-install}" in
    install)   install_git ;;
    uninstall) uninstall_git ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
