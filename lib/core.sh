#!/usr/bin/env bash
# =============================================================================
# core.sh - Thư viện lõi: logging, version control, conflict detection
# =============================================================================

set -euo pipefail

# ── Màu sắc ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Xác định HOME thực của user gọi script ────────────────────────────────────
# Khi chạy với sudo, $HOME có thể bị đổi thành /root.
# SUDO_USER giữ tên user gốc → dùng getent để lấy home thực.
if [[ -n "${SUDO_USER:-}" ]]; then
    # || true: tránh set -e thoát khi getent không tìm thấy user
    REAL_HOME=$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6 || true)
    # Fallback 1: /home/$SUDO_USER nếu getent thất bại
    [[ -z "$REAL_HOME" ]] && REAL_HOME="/home/${SUDO_USER}"
    # Fallback 2: $HOME nếu thư mục không tồn tại
    [[ -d "$REAL_HOME" ]] || REAL_HOME="$HOME"
else
    REAL_HOME="$HOME"
fi

# ── Cấu hình đường dẫn ────────────────────────────────────────────────────────
DEVSETUP_ROOT="${DEVSETUP_ROOT:-${REAL_HOME}/.devsetup}"
DEVSETUP_LOG_DIR="${DEVSETUP_ROOT}/logs"
DEVSETUP_STATE_FILE="${DEVSETUP_ROOT}/state.json"
DEVSETUP_LOCK_FILE="${DEVSETUP_ROOT}/.lock"

# Tạo thư mục ngay khi load core.sh — trước khi LOG_FILE được dùng
mkdir -p "$DEVSETUP_LOG_DIR"

# Tạo state file nếu chưa có
if [[ ! -f "$DEVSETUP_STATE_FILE" ]]; then
    echo '{"installed": {}, "versions": {}}' > "$DEVSETUP_STATE_FILE"
fi

# File log theo ngày (tạo sau khi thư mục đã sẵn sàng)
LOG_FILE="${DEVSETUP_LOG_DIR}/setup_$(date +%Y%m%d_%H%M%S).log"

# ── Khởi tạo môi trường ───────────────────────────────────────────────────────
init_devsetup() {
    # Đảm bảo thư mục tồn tại (idempotent)
    mkdir -p "$DEVSETUP_LOG_DIR"
    if [[ ! -f "$DEVSETUP_STATE_FILE" ]]; then
        echo '{"installed": {}, "versions": {}}' > "$DEVSETUP_STATE_FILE"
    fi
}

# ── Logging ───────────────────────────────────────────────────────────────────
_log() {
    local level="$1"; shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    # Đảm bảo thư mục log tồn tại trước mỗi lần ghi (lớp bảo vệ cuối)
    [[ -d "$DEVSETUP_LOG_DIR" ]] || mkdir -p "$DEVSETUP_LOG_DIR"
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
}

log_info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; _log "INFO"  "$*"; }
log_success() { echo -e "${GREEN}[OK]${RESET}    $*"; _log "OK"    "$*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; _log "WARN"  "$*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*"; _log "ERROR" "$*"; }
log_step()    { echo -e "\n${BOLD}${BLUE}▶ $*${RESET}"; _log "STEP"  "$*"; }
log_section() {
    local line="════════════════════════════════════════════════════════════"
    echo -e "\n${BOLD}${CYAN}${line}${RESET}"
    echo -e "${BOLD}${CYAN}  $*${RESET}"
    echo -e "${BOLD}${CYAN}${line}${RESET}"
    _log "SECTION" "$*"
}

# ── Quản lý trạng thái cài đặt (state.json) ───────────────────────────────────
# Ghi trạng thái: state_set <tool> <version> <status>
state_set() {
    local tool="$1" version="$2" status="$3"

    # Đảm bảo file tồn tại
    if [[ ! -f "$DEVSETUP_STATE_FILE" ]]; then
        echo '{"installed": {}, "versions": {}}' > "$DEVSETUP_STATE_FILE"
    fi

    # Đảm bảo quyền ghi (khi chạy sudo, file có thể thuộc root)
    if [[ -n "${SUDO_USER:-}" ]]; then
        chown "${SUDO_USER}:${SUDO_USER}" "$DEVSETUP_STATE_FILE" 2>/dev/null || true
        chown "${SUDO_USER}:${SUDO_USER}" "$DEVSETUP_ROOT" 2>/dev/null || true
    fi

    local err
    err=$(python3 -c "
import json, sys
try:
    with open('${DEVSETUP_STATE_FILE}') as f:
        d = json.load(f)
except Exception as e:
    d = {'installed': {}, 'versions': {}}
d['installed']['${tool}'] = '${status}'
d['versions']['${tool}']  = '${version}'
with open('${DEVSETUP_STATE_FILE}', 'w') as f:
    json.dump(d, f, indent=2)
" 2>&1)

    if [[ -n "$err" ]]; then
        # Ghi lỗi vào log nhưng không fail
        echo "[state_set ERROR] tool=$tool err=$err" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# Xoá trạng thái: state_remove <tool>
state_remove() {
    local tool="$1"
    python3 -c "
import json
with open('$DEVSETUP_STATE_FILE') as f:
    d = json.load(f)
d['installed'].pop('$tool', None)
d['versions'].pop('$tool', None)
with open('$DEVSETUP_STATE_FILE', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null || true
}

# Đọc trạng thái: state_get <tool>  → "installed" | "failed" | ""
state_get() {
    local tool="$1"
    python3 -c "
import json
with open('$DEVSETUP_STATE_FILE') as f:
    d = json.load(f)
print(d['installed'].get('$tool', ''))
" 2>/dev/null || echo ""
}

# Đọc version đã cài: state_version <tool>
state_version() {
    local tool="$1"
    python3 -c "
import json
with open('$DEVSETUP_STATE_FILE') as f:
    d = json.load(f)
print(d['versions'].get('$tool', ''))
" 2>/dev/null || echo ""
}

# ── Kiểm tra version ──────────────────────────────────────────────────────────
# So sánh version: version_compare <v1> <v2>  → 0(eq), 1(v1>v2), 2(v1<v2)
version_compare() {
    if [[ "$1" == "$2" ]]; then echo 0; return; fi
    local IFS=.
    local i v1=($1) v2=($2)
    for ((i=0; i<${#v1[@]} || i<${#v2[@]}; i++)); do
        local a=${v1[i]:-0} b=${v2[i]:-0}
        if   ((10#$a > 10#$b)); then echo 1; return
        elif ((10#$a < 10#$b)); then echo 2; return
        fi
    done
    echo 0
}

# Kiểm tra conflict version: check_version_conflict <tool> <required_ver> <installed_ver>
check_version_conflict() {
    local tool="$1" required="$2" installed="$3"
    if [[ -z "$installed" ]]; then return 0; fi
    local cmp
    cmp=$(version_compare "$required" "$installed")
    if [[ "$cmp" != "0" ]]; then
        log_warn "Version conflict cho $tool:"
        log_warn "  → Yêu cầu  : $required"
        log_warn "  → Đã cài   : $installed"
        log_warn "  → Script sẽ cài đè version yêu cầu"
        return 1
    fi
    return 0
}

# ── Kiểm tra công cụ đã tồn tại ───────────────────────────────────────────────
is_installed() {
    local tool="$1"
    command -v "$tool" &>/dev/null
}

# ── Chạy lệnh có log ──────────────────────────────────────────────────────────
run_cmd() {
    log_info "Chạy: $*"
    if "$@" >> "$LOG_FILE" 2>&1; then
        return 0
    else
        local exit_code=$?
        log_error "Lệnh thất bại (exit $exit_code): $*"
        log_error "Xem chi tiết: $LOG_FILE"
        return $exit_code
    fi
}

# ── apt-get update bỏ qua lỗi PPA bên thứ ba ─────────────────────────────────
# apt-get update trả về exit code != 0 nếu BẤT KỲ repo nào lỗi (kể cả không
# liên quan). Hàm này chạy update, phát hiện repo lỗi, disable chúng rồi retry.
apt_update_safe() {
    log_info "Chạy: apt-get update (safe mode)..."

    # Lần 1: chạy update, bắt output lỗi
    local update_output
    update_output=$(sudo apt-get update 2>&1 | tee -a "$LOG_FILE") || true

    # Tìm các repo lỗi (không có Release file)
    local broken_repos
    broken_repos=$(echo "$update_output" \
        | grep -oP "(?<=The repository ').*?(?=' does not have a Release file)" \
        || true)

    if [[ -z "$broken_repos" ]]; then
        # Không có lỗi repo, kiểm tra exit code thực sự
        if echo "$update_output" | grep -q "^Err:"; then
            log_warn "apt-get update có một số lỗi nhỏ, tiếp tục..."
        fi
        return 0
    fi

    # Có repo lỗi → disable từng cái một
    log_warn "Phát hiện repository lỗi, đang tạm disable..."
    while IFS= read -r repo_url; do
        [[ -z "$repo_url" ]] && continue
        log_warn "  Disable repo lỗi: $repo_url"

        # Tìm file .list chứa URL này và comment out
        local list_files
        list_files=$(grep -rl "$repo_url" \
            /etc/apt/sources.list \
            /etc/apt/sources.list.d/ 2>/dev/null || true)

        for f in $list_files; do
            # Backup rồi comment dòng chứa URL lỗi
            sudo cp "$f" "${f}.bak_devsetup" 2>/dev/null || true
            sudo sed -i "\\|${repo_url}|s|^deb |# DISABLED_BY_DEVSETUP deb |g" "$f" 2>/dev/null || true
            log_info "  Đã comment trong: $f (backup: ${f}.bak_devsetup)"
        done

        # Thử xóa qua add-apt-repository nếu là PPA
        if echo "$repo_url" | grep -q "ppa.launchpadcontent.net\|ppa.launchpad.net"; then
            local ppa_name
            ppa_name=$(echo "$repo_url" \
                | grep -oP "(?<=launchpad(?:content)?\.net/).*?(?=/ubuntu)" \
                | sed 's|/|:|' || true)
            if [[ -n "$ppa_name" ]]; then
                sudo add-apt-repository --remove "ppa:${ppa_name}" -y \
                    >> "$LOG_FILE" 2>&1 || true
                log_info "  Đã remove PPA: ppa:${ppa_name}"
            fi
        fi
    done <<< "$broken_repos"

    # Lần 2: chạy lại update sau khi đã disable repo lỗi
    log_info "Chạy lại apt-get update sau khi disable repo lỗi..."
    sudo apt-get update >> "$LOG_FILE" 2>&1 || {
        log_warn "apt-get update vẫn còn cảnh báo nhỏ — tiếp tục cài đặt..."
    }
    return 0
}

# ── Khôi phục các repo đã bị disable bởi devsetup ────────────────────────────
restore_disabled_repos() {
    log_info "Khôi phục các repo đã bị tạm disable..."
    local restored=0
    find /etc/apt/sources.list.d/ -name "*.bak_devsetup" 2>/dev/null | while read -r bak; do
        local original="${bak%.bak_devsetup}"
        sudo cp "$bak" "$original" 2>/dev/null && sudo rm -f "$bak" && ((restored++)) || true
        log_info "  Khôi phục: $original"
    done
    # Khôi phục sources.list chính nếu có
    if [[ -f /etc/apt/sources.list.bak_devsetup ]]; then
        sudo cp /etc/apt/sources.list.bak_devsetup /etc/apt/sources.list
        sudo rm -f /etc/apt/sources.list.bak_devsetup
        ((restored++))
    fi
    [[ $restored -gt 0 ]] && log_info "Đã khôi phục $restored repo file(s)" || true
}

# ── Kiểm tra OS ───────────────────────────────────────────────────────────────
assert_ubuntu() {
    if ! grep -qi ubuntu /etc/os-release 2>/dev/null; then
        log_error "Script chỉ hỗ trợ Ubuntu. Hệ điều hành hiện tại không được hỗ trợ."
        exit 1
    fi
}

assert_root_or_sudo() {
    if ! sudo -n true 2>/dev/null && [[ $EUID -ne 0 ]]; then
        log_error "Cần quyền sudo để chạy script này."
        exit 1
    fi
}

# ── Lock để tránh chạy đồng thời ─────────────────────────────────────────────
acquire_lock() {
    if [[ -f "$DEVSETUP_LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$DEVSETUP_LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_error "Một tiến trình setup khác đang chạy (PID: $pid). Thoát."
            exit 1
        fi
    fi
    echo $$ > "$DEVSETUP_LOCK_FILE"
    trap 'rm -f "$DEVSETUP_LOCK_FILE"' EXIT INT TERM
}

# ── Reload shell env ──────────────────────────────────────────────────────────
source_profile() {
    # shellcheck disable=SC1090
    for f in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_profile"; do
        [[ -f "$f" ]] && source "$f" 2>/dev/null || true
    done
}

# ── Export PATH helper ────────────────────────────────────────────────────────
add_to_path() {
    local dir="$1"
    local marker="$2"
    local profile="$HOME/.bashrc"
    if ! grep -q "$marker" "$profile" 2>/dev/null; then
        {
            echo ""
            echo "# $marker"
            echo "export PATH=\"$dir:\$PATH\""
        } >> "$profile"
        log_info "Đã thêm $dir vào PATH ($profile)"
    fi
    export PATH="$dir:$PATH"
}

add_env_var() {
    local varname="$1" value="$2" marker="$3"
    local profile="$HOME/.bashrc"
    if ! grep -q "$marker" "$profile" 2>/dev/null; then
        {
            echo ""
            echo "# $marker"
            echo "export $varname=\"$value\""
        } >> "$profile"
    fi
    export "$varname"="$value"
}
