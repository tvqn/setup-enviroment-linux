#!/usr/bin/env bash
# =============================================================================
# install_intellij.sh - Cài đặt IntelliJ IDEA (Community hoặc Ultimate)
#
# Biến môi trường kiểm soát:
#   INTELLIJ_EDITION=community|ultimate   (mặc định: community)
#   INTELLIJ_VERSION=latest|2024.1|...    (mặc định: latest)
#   INTELLIJ_INSTALL_DIR=/opt/intellij    (mặc định: /opt/intellij)
#
# Chiến lược:
#   1. Snap (ưu tiên) — tự cập nhật, sandbox, dễ nhất
#   2. JetBrains Toolbox — quản lý nhiều IDE/version JetBrains
#   3. Binary tarball từ JetBrains CDN — fallback, kiểm soát version chính xác
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="intellij"
SYMLINK="/usr/local/bin/idea"
DESKTOP_FILE="/usr/share/applications/intellij-idea.desktop"

# Snap package name theo edition
snap_pkg() {
    [[ "$INTELLIJ_EDITION" == "ultimate" ]] && echo "intellij-idea-ultimate" \
                                             || echo "intellij-idea-community"
}

# JetBrains product code cho API
jetbrains_code() {
    [[ "$INTELLIJ_EDITION" == "ultimate" ]] && echo "IIU" || echo "IIC"
}

# ── Lấy URL download từ JetBrains API ────────────────────────────────────────
get_download_url() {
    local code
    code=$(jetbrains_code)
    local api_url

    if [[ "$INTELLIJ_VERSION" == "latest" ]]; then
        api_url="https://data.services.jetbrains.com/products/releases?code=${code}&latest=true&type=release"
    else
        api_url="https://data.services.jetbrains.com/products/releases?code=${code}&type=release"
    fi

    local url
    url=$(curl -s "$api_url" \
        | python3 -c "
import json, sys
data = json.load(sys.stdin)
releases = data.get('${code}', [])
if not releases:
    sys.exit(1)

# Lọc đúng version nếu chỉ định
version = '${INTELLIJ_VERSION}'
if version != 'latest':
    releases = [r for r in releases if r.get('version','').startswith(version)]

if not releases:
    sys.exit(1)

release = releases[0]
downloads = release.get('downloads', {})
linux = downloads.get('linux', {})
print(linux.get('link', ''))
" 2>/dev/null || echo "")

    echo "$url"
}

# =============================================================================
# INSTALL
# =============================================================================
install_intellij() {
    log_section "Cài đặt IntelliJ IDEA ${INTELLIJ_EDITION^} ($INTELLIJ_VERSION)"
    init_devsetup

    # ── Kiểm tra đã cài chưa ────────────────────────────────────────────────
    local snap_name
    snap_name=$(snap_pkg)

    if snap list "$snap_name" &>/dev/null 2>&1; then
        local ver
        ver=$(snap list "$snap_name" 2>/dev/null | awk 'NR==2{print $2}' || echo "snap")
        log_success "IntelliJ IDEA $ver đã được cài đặt (snap). Bỏ qua."
        state_set "$TOOL_NAME" "$ver" "installed"
        return 0
    fi

    if [[ -f "${INTELLIJ_INSTALL_DIR}/bin/idea.sh" ]]; then
        local ver
        ver=$(cat "${INTELLIJ_INSTALL_DIR}/product-info.json" 2>/dev/null \
            | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('version','unknown'))" \
            2>/dev/null || echo "installed")
        log_info "Phát hiện IntelliJ đã cài tại $INTELLIJ_INSTALL_DIR: $ver"
        if [[ "$INTELLIJ_VERSION" == "latest" || "$ver" == "$INTELLIJ_VERSION"* ]]; then
            log_success "IntelliJ IDEA $ver đã được cài đặt. Bỏ qua."
            state_set "$TOOL_NAME" "$ver" "installed"
            return 0
        fi
        log_warn "Version không khớp ($ver ≠ $INTELLIJ_VERSION), sẽ cài đè"
        sudo rm -rf "$INTELLIJ_INSTALL_DIR"
    fi

    # Kiểm tra Java (IntelliJ bundled JRE nhưng vẫn nên có Java)
    if ! is_installed java; then
        log_warn "Java chưa được cài. IntelliJ có bundled JRE nhưng nên cài Java riêng..."
        log_info "Cài Java để đảm bảo tương thích đầy đủ..."
        bash "$SCRIPT_DIR/install_java.sh" install || \
            log_warn "Bỏ qua Java, IntelliJ vẫn chạy với bundled JRE"
        source_profile
    fi

    run_cmd sudo apt-get install -y curl wget python3

    # ── Phương án 1: Snap ────────────────────────────────────────────────────
    if is_installed snap; then
        log_step "Cài đặt IntelliJ IDEA qua Snap ($snap_name)..."
        local snap_opts="--classic"
        if run_cmd sudo snap install "$snap_name" $snap_opts; then
            local ver
            ver=$(snap list "$snap_name" 2>/dev/null | awk 'NR==2{print $2}' || echo "snap")
            log_success "IntelliJ IDEA $ver đã cài đặt thành công (snap)"
            log_info "Chạy: snap run $snap_name"
            state_set "$TOOL_NAME" "$ver" "installed"
            return 0
        fi
        log_warn "Snap thất bại, thử tải binary từ JetBrains CDN..."
    fi

    # ── Phương án 2: Binary tarball từ JetBrains CDN ─────────────────────────
    log_step "Truy vấn JetBrains API để lấy URL download..."
    local download_url
    download_url=$(get_download_url)

    if [[ -z "$download_url" ]]; then
        # Fallback URL cố định nếu API thất bại
        local code
        code=$(jetbrains_code)
        log_warn "JetBrains API không phản hồi, dùng URL fallback..."
        download_url="https://download.jetbrains.com/idea/ideaIC-${INTELLIJ_VERSION}.tar.gz"
        if [[ "$INTELLIJ_EDITION" == "ultimate" ]]; then
            download_url="https://download.jetbrains.com/idea/ideaIU-${INTELLIJ_VERSION}.tar.gz"
        fi
    fi

    log_info "URL tải: $download_url"
    log_step "Tải IntelliJ IDEA..."

    local tmp_file
    tmp_file=$(mktemp /tmp/intellij_XXXXXX.tar.gz)

    if ! wget -q --show-progress "$download_url" -O "$tmp_file"; then
        log_error "Không tải được IntelliJ IDEA từ: $download_url"
        state_set "$TOOL_NAME" "unknown" "failed"
        rm -f "$tmp_file"
        return 1
    fi

    # ── Giải nén và cài đặt ──────────────────────────────────────────────────
    log_step "Giải nén IntelliJ IDEA vào $INTELLIJ_INSTALL_DIR..."
    run_cmd sudo mkdir -p "$(dirname "$INTELLIJ_INSTALL_DIR")"

    # Giải nén vào thư mục tạm rồi rename
    local tmp_extract
    tmp_extract=$(mktemp -d /tmp/intellij_extract_XXXXXX)
    sudo tar -xzf "$tmp_file" -C "$tmp_extract" >> "$LOG_FILE" 2>&1
    rm -f "$tmp_file"

    # Tìm thư mục vừa giải nén (idea-IC-* hoặc idea-IU-*)
    local extracted_dir
    extracted_dir=$(find "$tmp_extract" -maxdepth 1 -type d -name "idea-*" | head -1)
    if [[ -z "$extracted_dir" ]]; then
        extracted_dir=$(find "$tmp_extract" -maxdepth 1 -type d | grep -v "^${tmp_extract}$" | head -1)
    fi

    if [[ -z "$extracted_dir" ]]; then
        log_error "Không tìm thấy thư mục IntelliJ sau khi giải nén"
        sudo rm -rf "$tmp_extract"
        state_set "$TOOL_NAME" "unknown" "failed"
        return 1
    fi

    sudo mv "$extracted_dir" "$INTELLIJ_INSTALL_DIR"
    sudo rm -rf "$tmp_extract"

    # ── Đọc version từ product-info.json ─────────────────────────────────────
    local ver
    ver=$(python3 -c "
import json
with open('${INTELLIJ_INSTALL_DIR}/product-info.json') as f:
    d = json.load(f)
print(d.get('version', 'unknown'))
" 2>/dev/null || echo "unknown")

    # ── Tạo symlink & desktop entry ───────────────────────────────────────────
    sudo ln -sf "${INTELLIJ_INSTALL_DIR}/bin/idea.sh" "$SYMLINK"

    # Tìm icon
    local icon_path="${INTELLIJ_INSTALL_DIR}/bin/idea.png"
    [[ ! -f "$icon_path" ]] && \
        icon_path=$(find "$INTELLIJ_INSTALL_DIR" -name "*.png" -path "*/bin/*" | head -1 || echo "")

    local edition_name="Community"
    [[ "$INTELLIJ_EDITION" == "ultimate" ]] && edition_name="Ultimate"

    cat <<EOF | sudo tee "$DESKTOP_FILE" > /dev/null
[Desktop Entry]
Version=1.0
Type=Application
Name=IntelliJ IDEA $edition_name
Comment=The Leading Java and Kotlin IDE
Exec=${INTELLIJ_INSTALL_DIR}/bin/idea.sh %f
Icon=${icon_path}
Terminal=false
StartupNotify=true
StartupWMClass=jetbrains-idea
Categories=Development;IDE;Java;
MimeType=text/x-java;
EOF

    sudo update-desktop-database 2>/dev/null || true

    # ── Thiết lập env ─────────────────────────────────────────────────────────
    add_env_var "IDEA_HOME" "$INTELLIJ_INSTALL_DIR" "DEVSETUP: IDEA_HOME"
    add_to_path "\$IDEA_HOME/bin" "DEVSETUP: IntelliJ PATH"

    log_success "IntelliJ IDEA $edition_name $ver đã cài đặt tại $INTELLIJ_INSTALL_DIR"
    log_info ""
    log_info "  Khởi động:"
    log_info "    idea                          # qua symlink /usr/local/bin/idea"
    log_info "    ${INTELLIJ_INSTALL_DIR}/bin/idea.sh   # trực tiếp"
    log_info "    Hoặc tìm trong Applications menu"
    log_info ""
    log_info "  Cài plugin thêm qua: File → Settings → Plugins"

    state_set "$TOOL_NAME" "$ver" "installed"
}

# =============================================================================
# UNINSTALL
# =============================================================================
uninstall_intellij() {
    log_section "Gỡ cài đặt IntelliJ IDEA"

    # Gỡ qua snap
    local snap_name
    snap_name=$(snap_pkg)
    if snap list "$snap_name" &>/dev/null 2>&1; then
        run_cmd sudo snap remove "$snap_name"
    fi

    # Gỡ binary
    if [[ -d "$INTELLIJ_INSTALL_DIR" ]]; then
        run_cmd sudo rm -rf "$INTELLIJ_INSTALL_DIR"
        log_success "Đã xoá $INTELLIJ_INSTALL_DIR"
    else
        log_warn "IntelliJ không tìm thấy tại $INTELLIJ_INSTALL_DIR"
    fi

    sudo rm -f "$SYMLINK" "$DESKTOP_FILE" 2>/dev/null || true
    sudo update-desktop-database 2>/dev/null || true

    # Xoá env
    sed -i '/DEVSETUP: IDEA_HOME/d; /IDEA_HOME/d; /DEVSETUP: IntelliJ PATH/d' \
        "$HOME/.bashrc" 2>/dev/null || true

    log_warn "Cấu hình IntelliJ vẫn còn tại ~/.config/JetBrains/. Xoá thủ công nếu cần."
    log_warn "Plugins và settings: ~/.config/JetBrains/IntelliJIdea*/  hoặc  ~/.local/share/JetBrains/"
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ IntelliJ IDEA"
}

# =============================================================================
# ENTRYPOINT
# =============================================================================
case "${1:-install}" in
    install)   install_intellij ;;
    uninstall) uninstall_intellij ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
