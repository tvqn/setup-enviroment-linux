#!/usr/bin/env bash
# =============================================================================
# install_maven.sh - Cài đặt Apache Maven
# Yêu cầu: Java
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="maven"
REQUIRED_VERSION="$MAVEN_VERSION"
MAJOR_MINOR=$(echo "$REQUIRED_VERSION" | cut -d. -f1,2)
DOWNLOAD_URL="https://archive.apache.org/dist/maven/maven-${REQUIRED_VERSION%%.*}/${REQUIRED_VERSION}/binaries/apache-maven-${REQUIRED_VERSION}-bin.tar.gz"
SYMLINK="/usr/local/bin/mvn"

install_maven() {
    log_section "Cài đặt Apache Maven $REQUIRED_VERSION"
    init_devsetup

    # Kiểm tra Java
    if ! is_installed java; then
        log_warn "Java chưa được cài. Đang cài Java trước..."
        bash "$SCRIPT_DIR/install_java.sh" install || { log_error "Không thể cài Java."; return 1; }
        source_profile
    fi

    # Kiểm tra version cũ
    local installed_ver=""
    if is_installed mvn; then
        installed_ver=$(mvn --version 2>/dev/null | grep "Apache Maven" | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
        log_info "Phát hiện Maven đã cài: $installed_ver"
        check_version_conflict "$TOOL_NAME" "$REQUIRED_VERSION" "$installed_ver" || true
        if [[ "$installed_ver" == "$REQUIRED_VERSION" ]]; then
            log_success "Maven $REQUIRED_VERSION đã được cài đặt. Bỏ qua."
            state_set "$TOOL_NAME" "$installed_ver" "installed"
            return 0
        fi
        sudo rm -rf "$MAVEN_INSTALL_DIR"
    fi

    log_step "Tải Maven $REQUIRED_VERSION..."
    run_cmd sudo apt-get install -y wget
    local tmp_file
    tmp_file=$(mktemp /tmp/maven_XXXXXX.tar.gz)

    if ! wget -q --show-progress "$DOWNLOAD_URL" -O "$tmp_file"; then
        log_error "Không tải được Maven từ $DOWNLOAD_URL"
        state_set "$TOOL_NAME" "$REQUIRED_VERSION" "failed"
        rm -f "$tmp_file"
        return 1
    fi

    log_step "Cài đặt Maven vào $MAVEN_INSTALL_DIR..."
    run_cmd sudo mkdir -p "$(dirname "$MAVEN_INSTALL_DIR")"
    sudo tar -xzf "$tmp_file" -C "$(dirname "$MAVEN_INSTALL_DIR")"
    sudo mv "$(dirname "$MAVEN_INSTALL_DIR")/apache-maven-${REQUIRED_VERSION}" "$MAVEN_INSTALL_DIR"
    rm -f "$tmp_file"

    sudo ln -sf "${MAVEN_INSTALL_DIR}/bin/mvn" "$SYMLINK"
    add_env_var "MAVEN_HOME" "$MAVEN_INSTALL_DIR" "DEVSETUP: MAVEN_HOME"
    add_to_path "\$MAVEN_HOME/bin" "DEVSETUP: Maven PATH"
    export PATH="${MAVEN_INSTALL_DIR}/bin:$PATH"

    local ver
    ver=$(mvn --version 2>/dev/null | grep "Apache Maven" | awk '{print $3}' || echo "unknown")
    log_success "Maven $ver đã cài đặt thành công"
    state_set "$TOOL_NAME" "$ver" "installed"
}

uninstall_maven() {
    log_section "Gỡ cài đặt Maven"
    sudo rm -rf "$MAVEN_INSTALL_DIR" "$SYMLINK" 2>/dev/null || true
    sed -i '/DEVSETUP: MAVEN_HOME/d; /MAVEN_HOME/d; /DEVSETUP: Maven PATH/d' \
        "$HOME/.bashrc" 2>/dev/null || true
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ Maven"
}

case "${1:-install}" in
    install)   install_maven ;;
    uninstall) uninstall_maven ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
