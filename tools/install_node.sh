#!/usr/bin/env bash
# =============================================================================
# install_node.sh - Cài đặt Node.js + npm + Yarn
#
# Biến môi trường kiểm soát:
#   NODE_VERSION=lts|latest|20|22|18   (mặc định: lts)
#   NPM_VERSION=latest|10.x.x          (mặc định: latest)
#   YARN_VERSION=latest|classic|4.x.x  (mặc định: latest)
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NODE="node"
TOOL_NPM="npm"
TOOL_YARN="yarn"

# ── Dùng REAL_HOME từ core.sh (đã xử lý trường hợp sudo) ─────────────────────
NVM_DIR="${NVM_DIR:-${REAL_HOME}/.nvm}"
NVM_PROFILE="${REAL_HOME}/.bashrc"

# ── Helper: load nvm vào session hiện tại ─────────────────────────────────────
load_nvm() {
    export NVM_DIR="$NVM_DIR"
    # shellcheck disable=SC1090
    [[ -s "${NVM_DIR}/nvm.sh" ]] && source "${NVM_DIR}/nvm.sh" --no-use
    # shellcheck disable=SC1090
    [[ -s "${NVM_DIR}/bash_completion" ]] && source "${NVM_DIR}/bash_completion"
}

# ── Lấy version nvm mới nhất ──────────────────────────────────────────────────
get_latest_nvm_version() {
    curl -s "https://api.github.com/repos/nvm-sh/nvm/releases/latest" \
        | grep '"tag_name"' \
        | cut -d'"' -f4 2>/dev/null || echo "v0.39.7"
}

# ── Ghi cấu hình nvm vào .bashrc ──────────────────────────────────────────────
_write_nvm_to_bashrc() {
    if ! grep -q "DEVSETUP: nvm" "$NVM_PROFILE" 2>/dev/null; then
        cat >> "$NVM_PROFILE" <<'BASHRC'

# DEVSETUP: nvm (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
BASHRC
        log_info "Đã thêm nvm vào $NVM_PROFILE"
        # Quyền file .bashrc về đúng user thực
        if [[ -n "${SUDO_USER:-}" ]]; then
            chown "${SUDO_USER}:${SUDO_USER}" "$NVM_PROFILE" 2>/dev/null || true
        fi
    fi
}

# =============================================================================
# INSTALL NVM
# =============================================================================
install_nvm() {
    log_step "Cài đặt nvm (Node Version Manager)..."

    if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
        load_nvm
        local nvm_ver
        nvm_ver=$(nvm --version 2>/dev/null || echo "unknown")
        log_info "nvm $nvm_ver đã có tại $NVM_DIR"
        return 0
    fi

    sudo apt-get install -y curl >> "$LOG_FILE" 2>&1

    local nvm_ver
    if [[ "$NVM_VERSION" == "latest" ]]; then
        nvm_ver=$(get_latest_nvm_version)
        log_info "nvm version mới nhất: $nvm_ver"
    else
        nvm_ver="$NVM_VERSION"
    fi

    local install_url="https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_ver}/install.sh"
    log_info "Tải nvm từ: $install_url"

    # Tải về file tạm để tránh vấn đề pipe + sudo + set -e
    local tmp_nvm
    tmp_nvm=$(mktemp /tmp/nvm_install_XXXXXX.sh)
    if ! curl -fsSL "$install_url" -o "$tmp_nvm"; then
        log_error "Không tải được nvm installer từ $install_url"
        rm -f "$tmp_nvm"
        return 1
    fi

    # Chạy installer với HOME và NVM_DIR chỉ định rõ
    if NVM_DIR="$NVM_DIR" HOME="$REAL_HOME" bash "$tmp_nvm" >> "$LOG_FILE" 2>&1; then
        rm -f "$tmp_nvm"
        load_nvm
        local ver
        ver=$(nvm --version 2>/dev/null || echo "unknown")
        log_success "nvm $ver đã cài tại $NVM_DIR"
        # Trả quyền về user thực nếu chạy qua sudo
        if [[ -n "${SUDO_USER:-}" ]]; then
            chown -R "${SUDO_USER}:${SUDO_USER}" "$NVM_DIR" 2>/dev/null || true
        fi
    else
        rm -f "$tmp_nvm"
        log_error "nvm installer thất bại — xem: $LOG_FILE"
        return 1
    fi
}

# =============================================================================
# INSTALL NODE.JS
# =============================================================================
install_node() {
    log_section "Cài đặt Node.js ($NODE_VERSION)"
    init_devsetup

    install_nvm || {
        log_error "Không thể cài nvm. Dừng cài Node.js."
        state_set "$TOOL_NODE" "unknown" "failed"
        return 1
    }
    load_nvm

    if ! command -v nvm &>/dev/null; then
        log_error "nvm không load được sau khi cài. Kiểm tra: $NVM_DIR/nvm.sh"
        state_set "$TOOL_NODE" "unknown" "failed"
        return 1
    fi

    # Kiểm tra đã có Node chưa
    local current_ver=""
    current_ver=$(nvm current 2>/dev/null | tr -d 'v' || true)
    if [[ -n "$current_ver" && "$current_ver" != "none" && "$current_ver" != "system" ]]; then
        log_info "Node.js đang active: v$current_ver"
        # lts/latest: không cần so sánh version chính xác
        if [[ "$NODE_VERSION" == "lts" || "$NODE_VERSION" == "latest" || "$NODE_VERSION" == "node" ]]; then
            log_success "Node.js v$current_ver đã cài đặt. Bỏ qua."
            state_set "$TOOL_NODE" "v${current_ver}" "installed"
            _write_nvm_to_bashrc
            return 0
        fi
        if [[ "$current_ver" == ${NODE_VERSION}* ]]; then
            log_success "Node.js v$current_ver khớp yêu cầu ($NODE_VERSION). Bỏ qua."
            state_set "$TOOL_NODE" "v${current_ver}" "installed"
            _write_nvm_to_bashrc
            return 0
        fi
        log_warn "v$current_ver ≠ $NODE_VERSION → cài thêm version yêu cầu"
    fi

    log_step "Đang cài Node.js $NODE_VERSION qua nvm..."

    # Chuyển đổi NODE_VERSION sang cú pháp đúng của nvm install
    # Lưu ý: nvm use/alias KHÔNG hỗ trợ --lts, chỉ nvm install mới hỗ trợ
    local nvm_install_arg
    case "$NODE_VERSION" in
        lts|LTS)
            nvm_install_arg="--lts"
            ;;
        latest|node)
            nvm_install_arg="node"
            ;;
        *)
            # Số version cụ thể: 20, 22, 20.11.0, ...
            nvm_install_arg="$NODE_VERSION"
            ;;
    esac

    log_info "nvm install $nvm_install_arg"
    if nvm install "$nvm_install_arg" >> "$LOG_FILE" 2>&1; then
        # Sau khi install, lấy version number thực tế để dùng cho use/alias
        # (nvm use/alias không hỗ trợ --lts flag như nvm install)
        local resolved_ver
        resolved_ver=$(nvm version "$nvm_install_arg" 2>/dev/null | tr -d 'v' || true)
        if [[ -z "$resolved_ver" || "$resolved_ver" == "N/A" ]]; then
            # Fallback: lấy version hiện tại sau khi install
            resolved_ver=$(nvm current 2>/dev/null | tr -d 'v' || true)
        fi
        log_info "Version đã cài: v$resolved_ver"

        if [[ -n "$resolved_ver" && "$resolved_ver" != "none" ]]; then
            nvm use "$resolved_ver"           >> "$LOG_FILE" 2>&1 || true
            nvm alias default "$resolved_ver" >> "$LOG_FILE" 2>&1 || true
        fi

        local node_ver npm_ver
        node_ver=$(node --version 2>/dev/null || echo "unknown")
        npm_ver=$(npm  --version 2>/dev/null || echo "unknown")
        log_success "Node.js $node_ver đã cài đặt thành công"
        log_success "npm $npm_ver đi kèm sẵn"
        state_set "$TOOL_NODE" "$node_ver" "installed"
        state_set "$TOOL_NPM"  "$npm_ver"  "installed"

        if [[ -n "${SUDO_USER:-}" ]]; then
            chown -R "${SUDO_USER}:${SUDO_USER}" "$NVM_DIR" 2>/dev/null || true
        fi
        _write_nvm_to_bashrc
    else
        log_error "Node.js $NODE_VERSION cài đặt THẤT BẠI — xem: $LOG_FILE"
        state_set "$TOOL_NODE" "$NODE_VERSION" "failed"
        return 1
    fi
}

# =============================================================================
# INSTALL NPM (upgrade)
# =============================================================================
install_npm() {
    log_section "Nâng cấp npm → $NPM_VERSION"
    init_devsetup
    load_nvm

    if ! command -v npm &>/dev/null; then
        log_error "npm không tìm thấy. Cài Node.js trước: ./setup.sh install node"
        state_set "$TOOL_NPM" "unknown" "failed"
        return 1
    fi

    local current_npm
    current_npm=$(npm --version 2>/dev/null || echo "")
    log_info "npm hiện tại: $current_npm"

    log_step "Nâng cấp npm lên $NPM_VERSION..."
    if npm install -g "npm@${NPM_VERSION}" >> "$LOG_FILE" 2>&1; then
        local new_ver
        new_ver=$(npm --version 2>/dev/null || echo "unknown")
        log_success "npm $new_ver đã cài đặt thành công"
        state_set "$TOOL_NPM" "$new_ver" "installed"
    else
        log_error "npm upgrade THẤT BẠI — xem $LOG_FILE"
        state_set "$TOOL_NPM" "$NPM_VERSION" "failed"
        return 1
    fi
}

# =============================================================================
# INSTALL YARN
# =============================================================================
install_yarn() {
    log_section "Cài đặt Yarn ($YARN_VERSION)"
    init_devsetup
    load_nvm

    if ! command -v npm &>/dev/null; then
        log_error "npm không tìm thấy. Cài Node.js trước: ./setup.sh install node"
        state_set "$TOOL_YARN" "unknown" "failed"
        return 1
    fi

    if command -v yarn &>/dev/null; then
        local installed_ver
        installed_ver=$(yarn --version 2>/dev/null || echo "")
        log_info "Yarn đã cài: $installed_ver"
        if [[ "$YARN_VERSION" == "latest" || "$installed_ver" == "$YARN_VERSION"* ]]; then
            log_success "Yarn $installed_ver đã được cài đặt. Bỏ qua."
            state_set "$TOOL_YARN" "$installed_ver" "installed"
            return 0
        fi
        check_version_conflict "$TOOL_YARN" "$YARN_VERSION" "$installed_ver" || true
    fi

    # Yarn Classic (1.x)
    if [[ "$YARN_VERSION" == "classic" || "$YARN_VERSION" == 1* ]]; then
        log_step "Cài đặt Yarn Classic (1.x) qua npm..."
        local pkg="yarn@1"
        [[ "$YARN_VERSION" != "classic" ]] && pkg="yarn@${YARN_VERSION}"
        if npm install -g "$pkg" >> "$LOG_FILE" 2>&1; then
            local ver; ver=$(yarn --version 2>/dev/null || echo "unknown")
            log_success "Yarn $ver (Classic) đã cài đặt thành công"
            state_set "$TOOL_YARN" "$ver" "installed"
        else
            log_error "Yarn Classic cài THẤT BẠI — xem $LOG_FILE"
            state_set "$TOOL_YARN" "$YARN_VERSION" "failed"
            return 1
        fi
        return 0
    fi

    # Yarn Modern (Berry 4.x) — Corepack (built-in từ Node 16+)
    log_step "Cài đặt Yarn Modern qua Corepack..."
    if corepack enable >> "$LOG_FILE" 2>&1; then
        local yarn_pkg="yarn"
        [[ "$YARN_VERSION" != "latest" ]] && yarn_pkg="yarn@${YARN_VERSION}"
        if corepack prepare "$yarn_pkg" --activate >> "$LOG_FILE" 2>&1; then
            local ver; ver=$(yarn --version 2>/dev/null || echo "unknown")
            log_success "Yarn $ver (Modern) đã cài đặt thành công qua Corepack"
            state_set "$TOOL_YARN" "$ver" "installed"
            return 0
        fi
        log_warn "Corepack prepare thất bại, thử cài qua npm..."
    else
        log_warn "Corepack không khả dụng, cài qua npm..."
    fi

    # Fallback: npm install -g yarn
    local pkg="yarn"
    [[ "$YARN_VERSION" != "latest" ]] && pkg="yarn@${YARN_VERSION}"
    if npm install -g "$pkg" >> "$LOG_FILE" 2>&1; then
        local ver; ver=$(yarn --version 2>/dev/null || echo "unknown")
        log_success "Yarn $ver đã cài đặt (npm fallback)"
        state_set "$TOOL_YARN" "$ver" "installed"
    else
        log_error "Yarn cài đặt THẤT BẠI — xem $LOG_FILE"
        state_set "$TOOL_YARN" "$YARN_VERSION" "failed"
        return 1
    fi
}

# =============================================================================
# UNINSTALL
# =============================================================================
uninstall_node() {
    log_section "Gỡ cài đặt Yarn"
    load_nvm
    if command -v yarn &>/dev/null; then
        npm uninstall -g yarn >> "$LOG_FILE" 2>&1 || true
        corepack disable 2>/dev/null || true
    fi
    state_remove "$TOOL_YARN"
    log_success "Đã gỡ Yarn"

    log_section "Gỡ cài đặt Node.js và nvm"
    load_nvm
    if command -v nvm &>/dev/null; then
        local versions
        versions=$(nvm ls --no-colors 2>/dev/null | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "")
        for ver in $versions; do
            log_info "Gỡ Node.js $ver..."
            nvm uninstall "$ver" >> "$LOG_FILE" 2>&1 || true
        done
    fi
    rm -rf "$NVM_DIR"
    log_success "Đã xoá $NVM_DIR"

    sed -i '/DEVSETUP: nvm/d; /NVM_DIR/d; /nvm\.sh/d; /bash_completion.*nvm/d' \
        "$NVM_PROFILE" 2>/dev/null || true

    state_remove "$TOOL_NODE"
    state_remove "$TOOL_NPM"
    log_success "Hoàn tất gỡ Node.js, npm, Yarn"
}

# =============================================================================
# ENTRYPOINT
# =============================================================================
case "${1:-install}" in
    install)
        install_node
        install_npm
        install_yarn
        ;;
    install-node) install_node ;;
    install-npm)  install_npm  ;;
    install-yarn) install_yarn ;;
    uninstall)    uninstall_node ;;
    *)
        echo "Dùng: $0 [install|install-node|install-npm|install-yarn|uninstall]"
        exit 1
        ;;
esac
