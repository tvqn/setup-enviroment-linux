#!/usr/bin/env bash
# =============================================================================
# install_hadoop.sh - Cài đặt Apache Hadoop (standalone/pseudo-distributed)
# Yêu cầu: Java
#
# Mirror strategy (ưu tiên từ trên xuống):
#   1. Apache closest mirror API  → tự chọn mirror gần nhất địa lý
#   2. Các mirror châu Á tốc độ cao (Singapore, HK, Japan)
#   3. archive.apache.org         → fallback chính thức (chậm)
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="hadoop"
REQUIRED_VERSION="$HADOOP_VERSION"
ARCHIVE_FILE="hadoop-${REQUIRED_VERSION}.tar.gz"
ARCHIVE_PATH="hadoop/common/hadoop-${REQUIRED_VERSION}/${ARCHIVE_FILE}"

# ── Danh sách mirror theo thứ tự ưu tiên ─────────────────────────────────────
# Mirror châu Á / gần Việt Nam được đặt trước
MIRRORS=(
    # Apache preferred mirror API (tự chọn mirror gần nhất)
    "https://dlcdn.apache.org/${ARCHIVE_PATH}"
    # Mirror Singapore / Châu Á
    "https://downloads.apache.org/${ARCHIVE_PATH}"
    "https://mirror.dhakacom.com/apache/${ARCHIVE_PATH}"
    "https://ftp.cuhk.edu.hk/pub/packages/apache.org/${ARCHIVE_PATH}"
    "https://apache.mirror.digitalpacific.com.au/${ARCHIVE_PATH}"
    "https://mirror.navercorp.com/apache/${ARCHIVE_PATH}"
    # Fallback: archive chính thức (chậm nhất)
    "https://archive.apache.org/dist/${ARCHIVE_PATH}"
)

# ── Đo tốc độ và chọn mirror nhanh nhất ──────────────────────────────────────
pick_fastest_mirror() {
    log_step "Đo tốc độ các mirror để chọn nhanh nhất..."
    local best_url="" best_time=99999

    for url in "${MIRRORS[@]}"; do
        local time_ms http_code

        # Đo connect time — dùng awk để tránh leading zero gây lỗi octal
        time_ms=$(curl -o /dev/null -s -w "%{time_connect}" \
            --max-time 5 --head "$url" 2>/dev/null \
            | awk '{printf "%d", $1 * 1000 + 0.5}')
        time_ms=${time_ms:-99999}

        # Kiểm tra HTTP status
        http_code=$(curl -o /dev/null -s -w "%{http_code}" \
            --max-time 5 --head "$url" 2>/dev/null || echo "000")

        log_info "  $(printf '%-65s' "$url")  ${time_ms}ms [HTTP $http_code]"

        if [[ $time_ms -lt $best_time ]] && [[ "$http_code" =~ ^(200|301|302)$ ]]; then
            best_time=$time_ms
            best_url="$url"
        fi
    done

    if [[ -z "$best_url" ]]; then
        best_url="${MIRRORS[-1]}"
        log_warn "Không đo được mirror nào, dùng fallback: $best_url"
    else
        log_success "Mirror nhanh nhất: $best_url (${best_time}ms)"
    fi

    echo "$best_url"
}

# ── Tải file với retry qua nhiều mirror ──────────────────────────────────────
download_with_fallback() {
    local dest="$1"

    # Thử mirror nhanh nhất trước
    local fastest_url
    fastest_url=$(pick_fastest_mirror)

    log_step "Tải Hadoop từ mirror nhanh nhất..."
    log_info "URL: $fastest_url"

    if wget --progress=bar:force --timeout=120 \
            "$fastest_url" -O "$dest" >> "$LOG_FILE" 2>&1; then
        return 0
    fi

    log_warn "Mirror nhanh nhất thất bại, thử lần lượt các mirror còn lại..."

    for url in "${MIRRORS[@]}"; do
        [[ "$url" == "$fastest_url" ]] && continue  # bỏ qua cái đã thử

        log_info "Thử: $url"
        if wget --progress=bar:force --timeout=180 \
                "$url" -O "$dest" >> "$LOG_FILE" 2>&1; then
            log_success "Tải thành công từ: $url"
            return 0
        fi
        log_warn "Thất bại: $url"
    done

    return 1
}

# =============================================================================
# INSTALL
# =============================================================================
install_hadoop() {
    log_section "Cài đặt Apache Hadoop $REQUIRED_VERSION"
    init_devsetup

    # ── Kiểm tra Java ────────────────────────────────────────────────────────
    if ! is_installed java; then
        log_warn "Java chưa được cài. Đang cài Java trước..."
        bash "$SCRIPT_DIR/install_java.sh" install || {
            log_error "Không thể cài Java. Dừng cài Hadoop."
            return 1
        }
        source_profile
    fi

    # ── Kiểm tra đã cài chưa ────────────────────────────────────────────────
    if [[ -d "$HADOOP_INSTALL_DIR" ]]; then
        local installed_ver
        installed_ver=$("${HADOOP_INSTALL_DIR}/bin/hadoop" version 2>/dev/null \
            | grep "^Hadoop" | awk '{print $2}' || echo "")
        log_info "Phát hiện Hadoop đã cài: $installed_ver"
        check_version_conflict "$TOOL_NAME" "$REQUIRED_VERSION" "$installed_ver" || true
        if [[ "$installed_ver" == "$REQUIRED_VERSION" ]]; then
            log_success "Hadoop $REQUIRED_VERSION đã được cài đặt. Bỏ qua."
            state_set "$TOOL_NAME" "$installed_ver" "installed"
            return 0
        fi
        log_warn "Xoá version cũ tại $HADOOP_INSTALL_DIR..."
        sudo rm -rf "$HADOOP_INSTALL_DIR"
    fi

    sudo apt-get install -y wget curl ssh rsync >> "$LOG_FILE" 2>&1

    # ── Tải Hadoop ───────────────────────────────────────────────────────────
    local tmp_file
    tmp_file=$(mktemp /tmp/hadoop_XXXXXX.tar.gz)

    if ! download_with_fallback "$tmp_file"; then
        log_error "Không tải được Hadoop $REQUIRED_VERSION từ tất cả mirror"
        log_error "Thử chạy lại sau hoặc đặt HADOOP_MIRROR để chỉ định URL thủ công:"
        log_error "  HADOOP_MIRROR=https://... ./setup.sh install hadoop"
        state_set "$TOOL_NAME" "$REQUIRED_VERSION" "failed"
        rm -f "$tmp_file"
        return 1
    fi

    # Kiểm tra file tải về hợp lệ (Hadoop ~700MB)
    local file_size
    file_size=$(stat -c%s "$tmp_file" 2>/dev/null || echo 0)
    log_info "Kích thước file tải về: $(( file_size / 1024 / 1024 ))MB"
    if [[ "$file_size" -lt 104857600 ]]; then   # < 100MB → lỗi
        log_error "File tải về quá nhỏ ($file_size bytes) — có thể bị lỗi mạng"
        rm -f "$tmp_file"
        state_set "$TOOL_NAME" "$REQUIRED_VERSION" "failed"
        return 1
    fi

    # ── Giải nén và cài đặt ──────────────────────────────────────────────────
    log_step "Giải nén Hadoop vào $HADOOP_INSTALL_DIR..."
    sudo mkdir -p "$(dirname "$HADOOP_INSTALL_DIR")"
    sudo tar -xzf "$tmp_file" -C "$(dirname "$HADOOP_INSTALL_DIR")" >> "$LOG_FILE" 2>&1
    sudo mv "$(dirname "$HADOOP_INSTALL_DIR")/hadoop-${REQUIRED_VERSION}" \
            "$HADOOP_INSTALL_DIR"
    rm -f "$tmp_file"

    # ── Thiết lập JAVA_HOME trong hadoop-env.sh ───────────────────────────────
    local java_home
    java_home=$(readlink -f /usr/bin/java 2>/dev/null | sed 's|/bin/java||' \
        || echo "/usr/lib/jvm/default-java")
    sudo sed -i "s|# export JAVA_HOME=.*|export JAVA_HOME=${java_home}|" \
        "${HADOOP_INSTALL_DIR}/etc/hadoop/hadoop-env.sh" 2>/dev/null || true
    log_info "JAVA_HOME trong hadoop-env.sh: $java_home"

    # ── Thiết lập biến môi trường ─────────────────────────────────────────────
    add_env_var "HADOOP_HOME"        "$HADOOP_INSTALL_DIR"  "DEVSETUP: HADOOP_HOME"
    add_env_var "HADOOP_INSTALL"     "$HADOOP_INSTALL_DIR"  "DEVSETUP: HADOOP_INSTALL"
    add_env_var "HADOOP_MAPRED_HOME" "\$HADOOP_HOME"        "DEVSETUP: HADOOP_MAPRED_HOME"
    add_env_var "HADOOP_COMMON_HOME" "\$HADOOP_HOME"        "DEVSETUP: HADOOP_COMMON_HOME"
    add_env_var "HADOOP_HDFS_HOME"   "\$HADOOP_HOME"        "DEVSETUP: HADOOP_HDFS_HOME"
    add_env_var "YARN_HOME"          "\$HADOOP_HOME"        "DEVSETUP: YARN_HOME"
    add_to_path "\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin"      "DEVSETUP: Hadoop PATH"
    export PATH="${HADOOP_INSTALL_DIR}/bin:${HADOOP_INSTALL_DIR}/sbin:$PATH"

    local ver
    ver=$("${HADOOP_INSTALL_DIR}/bin/hadoop" version 2>/dev/null \
        | grep "^Hadoop" | awk '{print $2}' || echo "unknown")
    log_success "Hadoop $ver đã cài đặt tại $HADOOP_INSTALL_DIR"
    log_info "Cấu hình thêm tại: ${HADOOP_INSTALL_DIR}/etc/hadoop/"
    state_set "$TOOL_NAME" "$ver" "installed"
}

# =============================================================================
# UNINSTALL
# =============================================================================
uninstall_hadoop() {
    log_section "Gỡ cài đặt Hadoop"
    sudo rm -rf "$HADOOP_INSTALL_DIR" 2>/dev/null || true
    sed -i '/DEVSETUP: HADOOP/d; /HADOOP_HOME/d; /HADOOP_INSTALL/d;
            /HADOOP_MAPRED_HOME/d; /HADOOP_COMMON_HOME/d; /HADOOP_HDFS_HOME/d;
            /YARN_HOME/d; /DEVSETUP: Hadoop PATH/d' \
        "$HOME/.bashrc" 2>/dev/null || true
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ Hadoop"
}

# =============================================================================
# ENTRYPOINT
# =============================================================================
case "${1:-install}" in
    install)   install_hadoop ;;
    uninstall) uninstall_hadoop ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
