#!/usr/bin/env bash
# =============================================================================
# install_gradle.sh - Cài đặt Gradle
# Yêu cầu: Java
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="gradle"
REQUIRED_VERSION="$GRADLE_VERSION"
DOWNLOAD_URL="https://services.gradle.org/distributions/gradle-${REQUIRED_VERSION}-bin.zip"
SYMLINK="/usr/local/bin/gradle"

install_gradle() {
    log_section "Cài đặt Gradle $REQUIRED_VERSION"
    init_devsetup

    if ! is_installed java; then
        log_warn "Java chưa được cài. Đang cài Java trước..."
        bash "$SCRIPT_DIR/install_java.sh" install || { log_error "Không thể cài Java."; return 1; }
        source_profile
    fi

    local installed_ver=""
    if is_installed gradle; then
        installed_ver=$(gradle --version 2>/dev/null | grep "^Gradle" | awk '{print $2}' || echo "")
        log_info "Phát hiện Gradle đã cài: $installed_ver"
        check_version_conflict "$TOOL_NAME" "$REQUIRED_VERSION" "$installed_ver" || true
        if [[ "$installed_ver" == "$REQUIRED_VERSION" ]]; then
            log_success "Gradle $REQUIRED_VERSION đã được cài đặt. Bỏ qua."
            state_set "$TOOL_NAME" "$installed_ver" "installed"
            return 0
        fi
        sudo rm -rf "$GRADLE_INSTALL_DIR"
    fi

    log_step "Tải Gradle $REQUIRED_VERSION..."
    run_cmd sudo apt-get install -y wget unzip
    local tmp_file
    tmp_file=$(mktemp /tmp/gradle_XXXXXX.zip)

    if ! wget -q --show-progress "$DOWNLOAD_URL" -O "$tmp_file"; then
        log_error "Không tải được Gradle từ $DOWNLOAD_URL"
        state_set "$TOOL_NAME" "$REQUIRED_VERSION" "failed"
        rm -f "$tmp_file"
        return 1
    fi

    log_step "Cài đặt Gradle vào $GRADLE_INSTALL_DIR..."
    run_cmd sudo mkdir -p "$(dirname "$GRADLE_INSTALL_DIR")"
    sudo unzip -q "$tmp_file" -d "$(dirname "$GRADLE_INSTALL_DIR")"
    sudo mv "$(dirname "$GRADLE_INSTALL_DIR")/gradle-${REQUIRED_VERSION}" "$GRADLE_INSTALL_DIR"
    rm -f "$tmp_file"

    sudo ln -sf "${GRADLE_INSTALL_DIR}/bin/gradle" "$SYMLINK"
    add_env_var "GRADLE_HOME" "$GRADLE_INSTALL_DIR" "DEVSETUP: GRADLE_HOME"
    add_to_path "\$GRADLE_HOME/bin" "DEVSETUP: Gradle PATH"
    export PATH="${GRADLE_INSTALL_DIR}/bin:$PATH"

    local ver
    ver=$(gradle --version 2>/dev/null | grep "^Gradle" | awk '{print $2}' || echo "unknown")
    log_success "Gradle $ver đã cài đặt thành công"
    state_set "$TOOL_NAME" "$ver" "installed"
}

uninstall_gradle() {
    log_section "Gỡ cài đặt Gradle"
    sudo rm -rf "$GRADLE_INSTALL_DIR" "$SYMLINK" 2>/dev/null || true
    sed -i '/DEVSETUP: GRADLE_HOME/d; /GRADLE_HOME/d; /DEVSETUP: Gradle PATH/d' \
        "$HOME/.bashrc" 2>/dev/null || true
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ Gradle"
}

case "${1:-install}" in
    install)   install_gradle ;;
    uninstall) uninstall_gradle ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
