#!/usr/bin/env bash
# =============================================================================
# install_ollama.sh - Cài đặt Ollama (local LLM runner)
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

TOOL_NAME="ollama"

install_ollama() {
    log_section "Cài đặt Ollama"
    init_devsetup

    local installed_ver=""
    if is_installed ollama; then
        installed_ver=$(ollama --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
        log_info "Phát hiện Ollama đã cài: $installed_ver"
        log_success "Ollama $installed_ver đã được cài đặt. Bỏ qua."
        state_set "$TOOL_NAME" "$installed_ver" "installed"
        return 0
    fi

    log_step "Cài đặt Ollama qua installer chính thức..."
    run_cmd sudo apt-get install -y curl

    if curl -fsSL https://ollama.com/install.sh | sh; then
        # Kích hoạt service
        sudo systemctl enable ollama --now >> "$LOG_FILE" 2>&1 || true
        local ver
        ver=$(ollama --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        log_success "Ollama $ver đã cài đặt thành công"
        log_info "Chạy 'ollama pull llama3' để tải model"
        state_set "$TOOL_NAME" "$ver" "installed"
    else
        log_error "Ollama cài đặt THẤT BẠI"
        state_set "$TOOL_NAME" "unknown" "failed"
        return 1
    fi
}

uninstall_ollama() {
    log_section "Gỡ cài đặt Ollama"
    sudo systemctl stop ollama 2>/dev/null || true
    sudo systemctl disable ollama 2>/dev/null || true
    sudo rm -f /usr/local/bin/ollama
    sudo rm -f /etc/systemd/system/ollama.service
    sudo rm -rf /usr/share/ollama
    sudo userdel ollama 2>/dev/null || true
    sudo groupdel ollama 2>/dev/null || true
    sudo systemctl daemon-reload 2>/dev/null || true
    log_warn "Models Ollama vẫn còn tại ~/.ollama. Xoá thủ công nếu cần: rm -rf ~/.ollama"
    state_remove "$TOOL_NAME"
    log_success "Hoàn tất gỡ Ollama"
}

case "${1:-install}" in
    install)   install_ollama ;;
    uninstall) uninstall_ollama ;;
    *) echo "Dùng: $0 [install|uninstall]"; exit 1 ;;
esac
