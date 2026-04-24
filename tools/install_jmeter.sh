#!/usr/bin/env bash
# =============================================================================
# install_jmeter.sh - Cài đặt Apache JMeter
# Yêu cầu: Java
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="jmeter"
REQUIRED_VERSION="$JMETER_VERSION"
ARCHIVE_FILE="apache-jmeter-${REQUIRED_VERSION}.tgz"
ARCHIVE_PATH="jmeter/binaries/${ARCHIVE_FILE}"
SYMLINK="/usr/local/bin/jmeter"

MIRRORS=(
    "https://dlcdn.apache.org/${ARCHIVE_PATH}"
    "https://downloads.apache.org/${ARCHIVE_PATH}"
    "https://ftp.cuhk.edu.hk/pub/packages/apache.org/${ARCHIVE_PATH}"
    "https://mirror.navercorp.com/apache/${ARCHIVE_PATH}"
    "https://apache.mirror.digitalpacific.com.au/${ARCHIVE_PATH}"
    "https://archive.apache.org/dist/${ARCHIVE_PATH}"
)

pick_fastest_mirror() {
    log_step "Đo tốc độ các mirror JMeter..."
    local best_url="" best_time=99999
    for url in "${MIRRORS[@]}"; do
        local time_ms http_code
        # Đo connect time — dùng awk để tránh leading zero gây lỗi octal
        time_ms=$(curl -o /dev/null -s -w "%{time_connect}" \
            --max-time 5 --head "$url" 2>/dev/null \
            | awk '{printf "%d", $1 * 1000 + 0.5}')
        time_ms=${time_ms:-99999}
        http_code=$(curl -o /dev/null -s -w "%{http_code}" \
            --max-time 5 --head "$url" 2>/dev/null || echo "000")
        log_info "  $(printf '%-70s' "$url")  ${time_ms}ms [HTTP $http_code]"
        if [[ $time_ms -lt $best_time ]] && [[ "$http_code" =~ ^(200|301|302)$ ]]; then
            best_time="$time_ms"
            best_url="$url"
        fi
    done
    [[ -z "$best_url" ]] && best_url="${MIRRORS[-1]}"
    log_success "Mirror nhanh nhất: $best_url (${best_time}ms)"
    echo "$best_url"
}

download_with_fallback() {
    local dest="$1"
    local fastest_url
    fastest_url=$(pick_fastest_mirror)
    log_info "Tải từ: $fastest_url"
    if wget --progress=bar:force --timeout=120 "$fastest_url" -O "$dest" >> "$LOG_FILE" 2>&1; then
        return 0
    fi
    log_warn "Mirror chính thất bại, thử các mirror khác..."
    for url in "${MIRRORS[@]}"; do
        [[ "$url" == "$fastest_url" ]] && continue
        log_info "Thử: $url"
        if wget --progress=bar:force --timeout=120 "$url" -O "$dest" >> "$LOG_FILE" 2>&1; then
            log_success "Tải thành công từ: $url"
            return 0
        fi
    done
    return 1
}

install_jmeter() {
    log_section "Cài đặt Apache JMeter $REQUIRED_VERSION"
    init_devsetup

    if ! is_installed java; then
        log_warn "Java chưa được cài. Đang cài Java trước..."
        bash "$SCRIPT_DIR/install_java.sh" install || {
            log_error "Không thể cài Java."
            return 1
        }
        source_profile
    fi

    if [[ -d "$JMETER_INSTALL_DIR" ]]; then
        local installed_ver
        installed_ver=$(cat "${JMETER_INSTALL_DIR}/bin/jmeter.properties" 2>/dev/null \
            | grep "^jmeter.version" | cut -d= -f2 | tr -d ' ' || echo "")
        log_info "Phát hiện JMeter đã cài: $installed_ver"
        check_version_conflict "$TOOL_NAME" "$REQUIRED_VERSION" "$installed_ver" || true
        if [[ "$installed_ver" == "$REQUIRED_VERSION" ]]; then
            log_success "JMeter $REQUIRED_VERSION đã được cài đặt. Bỏ qua."
            state_set "$TOOL_NAME" "$installed_ver" "installed"
            return 0
        fi
        sudo rm -rf "$JMETER_INSTALL_DIR"
    fi

    sudo apt-get install -y wget curl >> "$LOG_FILE" 2>&1

    local tmp_file
    tmp_file=$(mktemp /tmp/jmeter_XXXXXX.tgz)

    if ! download_with_fallback "$tmp_file"; then
        log_error "Không tải được JMeter $REQUIRED_VERSION từ tất cả mirror"
        state_set "$TOOL_NAME" "$REQUIRED_VERSION" "failed"
        rm -f "$tmp_file"
        return 1
    fi

    log_step "Giải nén JMeter vào $JMETER_INSTALL_DIR..."
    sudo mkdir -p "$(dirname "$JMETER_INSTALL_DIR")"
    sudo tar -xzf "$tmp_file" -C "$(dirname "$JMETER_INSTALL_DIR")" >> "$LOG_FILE" 2>&1
    sudo mv "$(dirname "$JMETER_INSTALL_DIR")/apache-jmeter-${REQUIRED_VERSION}" \
            "$JMETER_INSTALL_DIR"
    rm -f "$tmp_file"

    sudo ln -sf "${JMETER_INSTALL_DIR}/bin/jmeter" "$SYMLINK"
    add_env_var "JMETER_HOME" "$JMETER_INSTALL_DIR" "DEVSETUP: JMETER_HOME"
    add_to_path "\$JMETER_HOME/bin" "DEVSETUP: JMeter PATH"

    log_success "JMeter $REQUIRED_VERSION đã cài đặt tại $JMETER_INSTALL_DIR"
    state_set "$TOOL_NAME" "$REQUIRED_VERSION" "installed"
}

uninstall_jmeter() {
    log_section "Gỡ cài đặt JMeter"
    sudo rm -rf "$JMETER_INSTALL_DIR" "$SYMLINK" 2>/dev/null || true
    sed -i '/DEVSETUP: JMETER_HOME/d; /JMETER_HOME/d; /DEVSETUP: JMeter PATH/d' \
        "$HOME/.bashrc" 2>/dev/null || true
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ JMeter"
}

case "${1:-install}" in
    install)   install_jmeter ;;
    uninstall) uninstall_jmeter ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
