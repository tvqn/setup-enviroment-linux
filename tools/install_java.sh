#!/usr/bin/env bash
# =============================================================================
# install_java.sh - Cài đặt OpenJDK
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="java"
REQUIRED_VERSION="$JAVA_VERSION"

install_java() {
    log_section "Cài đặt OpenJDK $REQUIRED_VERSION"
    init_devsetup

    local installed_ver=""
    if is_installed java; then
        installed_ver=$(java -version 2>&1 | grep -oP '(?<=version ")[0-9]+' | head -1 || echo "")
        log_info "Phát hiện Java đã cài: $installed_ver"
        check_version_conflict "$TOOL_NAME" "$REQUIRED_VERSION" "$installed_ver" || true
        if [[ "$installed_ver" == "$REQUIRED_VERSION" ]]; then
            log_success "Java $REQUIRED_VERSION đã được cài đặt. Bỏ qua."
            state_set "$TOOL_NAME" "$installed_ver" "installed"
            return 0
        fi
    fi

    log_step "Cập nhật apt và cài OpenJDK $REQUIRED_VERSION..."
    apt_update_safe
    if run_cmd sudo apt-get install -y "openjdk-${REQUIRED_VERSION}-jdk"; then
        local ver
        ver=$(java -version 2>&1 | grep version | awk -F'"' '{print $2}')
        log_success "Java $ver đã cài đặt thành công"

        # Thiết lập JAVA_HOME
        local java_home
        java_home=$(readlink -f /usr/bin/java | sed 's|/bin/java||')
        add_env_var "JAVA_HOME" "$java_home" "DEVSETUP: JAVA_HOME"
        add_to_path "\$JAVA_HOME/bin" "DEVSETUP: Java PATH"

        state_set "$TOOL_NAME" "$ver" "installed"
        java -version >> "$LOG_FILE" 2>&1 || true
    else
        log_error "Java $REQUIRED_VERSION cài đặt THẤT BẠI"
        state_set "$TOOL_NAME" "$REQUIRED_VERSION" "failed"
        return 1
    fi
}

uninstall_java() {
    log_section "Gỡ cài đặt Java"
    local pkgs
    pkgs=$(dpkg -l | grep -E 'openjdk|java' | awk '{print $2}' | tr '\n' ' ' || echo "")
    if [[ -n "$pkgs" ]]; then
        # shellcheck disable=SC2086
        run_cmd sudo apt-get remove -y $pkgs
        run_cmd sudo apt-get autoremove -y
    else
        log_warn "Java không được tìm thấy để gỡ"
    fi
    # Xoá env từ .bashrc
    sed -i '/DEVSETUP: JAVA_HOME/d; /JAVA_HOME/d; /DEVSETUP: Java PATH/d' "$HOME/.bashrc" 2>/dev/null || true
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ Java"
}

case "${1:-install}" in
    install)   install_java ;;
    uninstall) uninstall_java ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
