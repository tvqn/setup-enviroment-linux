#!/usr/bin/env bash
# =============================================================================
# install_docker.sh - Cài đặt Docker Engine (official repository)
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="docker"
REQUIRED_VERSION="$DOCKER_VERSION"

install_docker() {
    log_section "Cài đặt Docker Engine"
    init_devsetup

    local installed_ver=""
    if is_installed docker; then
        installed_ver=$(docker --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
        log_info "Phát hiện Docker đã cài: $installed_ver"
        if [[ "$REQUIRED_VERSION" == "latest" || "$installed_ver" == "$REQUIRED_VERSION" ]]; then
            log_success "Docker $installed_ver đã được cài đặt. Bỏ qua."
            state_set "$TOOL_NAME" "$installed_ver" "installed"
            return 0
        fi
        check_version_conflict "$TOOL_NAME" "$REQUIRED_VERSION" "$installed_ver" || true
    fi

    log_step "Gỡ các phiên bản Docker cũ nếu có..."
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        sudo apt-get remove -y "$pkg" 2>/dev/null || true
    done

    log_step "Cài đặt các dependency..."
    apt_update_safe
    run_cmd sudo apt-get install -y ca-certificates curl gnupg lsb-release

    log_step "Thêm Docker GPG key & repository..."
    sudo install -m 0755 -d /etc/apt/keyrings
    if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null; then
        log_error "Không tải được Docker GPG key"
        state_set "$TOOL_NAME" "$REQUIRED_VERSION" "failed"
        return 1
    fi
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt_update_safe

    log_step "Cài đặt Docker Engine..."
    local pkg_suffix=""
    if [[ "$REQUIRED_VERSION" != "latest" ]]; then
        # Tìm version cụ thể trong repo
        local available_ver
        available_ver=$(apt-cache madison docker-ce | grep "$REQUIRED_VERSION" | head -1 | awk '{print $3}' || echo "")
        if [[ -n "$available_ver" ]]; then
            pkg_suffix="=$available_ver"
        else
            log_warn "Không tìm thấy Docker $REQUIRED_VERSION trong repo, sẽ cài latest"
        fi
    fi

    # shellcheck disable=SC2086
    if run_cmd sudo apt-get install -y \
            "docker-ce${pkg_suffix}" \
            "docker-ce-cli${pkg_suffix}" \
            containerd.io \
            docker-buildx-plugin \
            docker-compose-plugin; then

        # Thêm user hiện tại vào nhóm docker
        sudo usermod -aG docker "$USER" 2>/dev/null || true
        sudo systemctl enable docker --now >> "$LOG_FILE" 2>&1 || true

        local ver
        ver=$(docker --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        log_success "Docker $ver đã cài đặt thành công"
        log_warn "Đăng xuất và đăng nhập lại để dùng Docker không cần sudo"
        state_set "$TOOL_NAME" "$ver" "installed"
    else
        log_error "Docker cài đặt THẤT BẠI"
        state_set "$TOOL_NAME" "$REQUIRED_VERSION" "failed"
        return 1
    fi
}

uninstall_docker() {
    log_section "Gỡ cài đặt Docker"
    log_warn "Tất cả containers, images, volumes sẽ bị xoá!"
    run_cmd sudo apt-get purge -y \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin \
        docker-ce-rootless-extras 2>/dev/null || true
    run_cmd sudo rm -rf /var/lib/docker /var/lib/containerd
    sudo rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.gpg 2>/dev/null || true
    apt_update_safe
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ Docker"
}

case "${1:-install}" in
    install)   install_docker ;;
    uninstall) uninstall_docker ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
