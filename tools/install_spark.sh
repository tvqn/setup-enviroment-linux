#!/usr/bin/env bash
# =============================================================================
# install_spark.sh - Cài đặt Apache Spark
# Yêu cầu: Java
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="spark"
REQUIRED_VERSION="$SPARK_VERSION"
ARCHIVE_NAME="spark-${SPARK_VERSION}-bin-hadoop${SPARK_HADOOP_VERSION}"
ARCHIVE_FILE="${ARCHIVE_NAME}.tgz"
ARCHIVE_PATH="spark/spark-${SPARK_VERSION}/${ARCHIVE_FILE}"

MIRRORS=(
    "https://dlcdn.apache.org/${ARCHIVE_PATH}"
    "https://downloads.apache.org/${ARCHIVE_PATH}"
    "https://ftp.cuhk.edu.hk/pub/packages/apache.org/${ARCHIVE_PATH}"
    "https://mirror.navercorp.com/apache/${ARCHIVE_PATH}"
    "https://apache.mirror.digitalpacific.com.au/${ARCHIVE_PATH}"
    "https://archive.apache.org/dist/${ARCHIVE_PATH}"
)

pick_fastest_mirror() {
    log_step "Đo tốc độ các mirror Spark..."
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
    if wget --progress=bar:force --timeout=180 "$fastest_url" -O "$dest" >> "$LOG_FILE" 2>&1; then
        return 0
    fi
    log_warn "Mirror chính thất bại, thử các mirror khác..."
    for url in "${MIRRORS[@]}"; do
        [[ "$url" == "$fastest_url" ]] && continue
        log_info "Thử: $url"
        if wget --progress=bar:force --timeout=180 "$url" -O "$dest" >> "$LOG_FILE" 2>&1; then
            log_success "Tải thành công từ: $url"
            return 0
        fi
    done
    return 1
}

install_spark() {
    log_section "Cài đặt Apache Spark $REQUIRED_VERSION"
    init_devsetup

    if ! is_installed java; then
        log_warn "Java chưa được cài. Đang cài Java trước..."
        bash "$SCRIPT_DIR/install_java.sh" install || {
            log_error "Không thể cài Java. Dừng cài Spark."
            return 1
        }
        source_profile
    fi

    if [[ -d "${SPARK_INSTALL_DIR}" ]]; then
        local installed_ver
        installed_ver=$("${SPARK_INSTALL_DIR}/bin/spark-shell" --version 2>&1 \
            | grep "version" | awk '{print $NF}' | head -1 || echo "")
        log_info "Phát hiện Spark đã cài: $installed_ver"
        check_version_conflict "$TOOL_NAME" "$REQUIRED_VERSION" "$installed_ver" || true
        if [[ "$installed_ver" == "$REQUIRED_VERSION" ]]; then
            log_success "Spark $REQUIRED_VERSION đã được cài đặt. Bỏ qua."
            state_set "$TOOL_NAME" "$installed_ver" "installed"
            return 0
        fi
        sudo rm -rf "${SPARK_INSTALL_DIR}"
    fi

    sudo apt-get install -y wget curl >> "$LOG_FILE" 2>&1

    local tmp_file
    tmp_file=$(mktemp /tmp/spark_XXXXXX.tgz)

    if ! download_with_fallback "$tmp_file"; then
        log_error "Không tải được Spark $REQUIRED_VERSION từ tất cả mirror"
        state_set "$TOOL_NAME" "$REQUIRED_VERSION" "failed"
        rm -f "$tmp_file"
        return 1
    fi

    local file_size
    file_size=$(stat -c%s "$tmp_file" 2>/dev/null || echo 0)
    log_info "Kích thước file: $(( file_size / 1024 / 1024 ))MB"
    if [[ "$file_size" -lt 52428800 ]]; then   # < 50MB
        log_error "File tải về quá nhỏ — có thể lỗi mạng"
        rm -f "$tmp_file"
        state_set "$TOOL_NAME" "$REQUIRED_VERSION" "failed"
        return 1
    fi

    log_step "Giải nén Spark vào $SPARK_INSTALL_DIR..."
    sudo mkdir -p "$(dirname "${SPARK_INSTALL_DIR}")"
    sudo tar -xzf "$tmp_file" -C "$(dirname "${SPARK_INSTALL_DIR}")" >> "$LOG_FILE" 2>&1
    sudo mv "$(dirname "${SPARK_INSTALL_DIR}")/${ARCHIVE_NAME}" "${SPARK_INSTALL_DIR}"
    rm -f "$tmp_file"

    add_env_var "SPARK_HOME"      "$SPARK_INSTALL_DIR" "DEVSETUP: SPARK_HOME"
    add_env_var "PYSPARK_PYTHON"  "python3"            "DEVSETUP: PYSPARK_PYTHON"
    add_to_path "\$SPARK_HOME/bin:\$SPARK_HOME/sbin"   "DEVSETUP: Spark PATH"

    log_success "Apache Spark $REQUIRED_VERSION đã cài đặt tại $SPARK_INSTALL_DIR"
    state_set "$TOOL_NAME" "$REQUIRED_VERSION" "installed"
}

uninstall_spark() {
    log_section "Gỡ cài đặt Apache Spark"
    if [[ -d "$SPARK_INSTALL_DIR" ]]; then
        sudo rm -rf "$SPARK_INSTALL_DIR"
        log_success "Đã xoá $SPARK_INSTALL_DIR"
    else
        log_warn "Spark không tìm thấy tại $SPARK_INSTALL_DIR"
    fi
    sed -i '/DEVSETUP: SPARK_HOME/d; /SPARK_HOME/d; /DEVSETUP: Spark PATH/d; /DEVSETUP: PYSPARK_PYTHON/d; /PYSPARK_PYTHON/d' \
        "$HOME/.bashrc" 2>/dev/null || true
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ Spark"
}

case "${1:-install}" in
    install)   install_spark ;;
    uninstall) uninstall_spark ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
