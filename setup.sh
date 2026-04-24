#!/usr/bin/env bash
# =============================================================================
# setup.sh - Script chủ: cài đặt / gỡ cài đặt / kiểm tra trạng thái
# Sử dụng:
#   ./setup.sh install   [tool1 tool2 ...]   # Cài tất cả hoặc từng tool
#   ./setup.sh uninstall [tool1 tool2 ...]   # Gỡ tất cả hoặc từng tool
#   ./setup.sh status                        # Xem trạng thái cài đặt
#   ./setup.sh check-versions                # Kiểm tra version hiện tại
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/versions.sh"

# ── Danh sách tất cả tool và script tương ứng ────────────────────────────────
declare -A TOOL_SCRIPTS=(
    # ── Dev tools ──────────────────────────────────────────────────────────────
    [dotnet]="$SCRIPT_DIR/tools/install_dotnet.sh"
    [java]="$SCRIPT_DIR/tools/install_java.sh"
    [spark]="$SCRIPT_DIR/tools/install_spark.sh"
    [golang]="$SCRIPT_DIR/tools/install_golang.sh"
    [python]="$SCRIPT_DIR/tools/install_python.sh"
    [uv]="$SCRIPT_DIR/tools/install_uv.sh"
    [docker]="$SCRIPT_DIR/tools/install_docker.sh"
    [ollama]="$SCRIPT_DIR/tools/install_ollama.sh"
    [jmeter]="$SCRIPT_DIR/tools/install_jmeter.sh"
    [maven]="$SCRIPT_DIR/tools/install_maven.sh"
    [gradle]="$SCRIPT_DIR/tools/install_gradle.sh"
    [hadoop]="$SCRIPT_DIR/tools/install_hadoop.sh"
    [git]="$SCRIPT_DIR/tools/install_git.sh"
    [postman]="$SCRIPT_DIR/tools/install_postman.sh"
    # ── Desktop & Productivity apps ────────────────────────────────────────────
    [vscode]="$SCRIPT_DIR/tools/install_vscode.sh"
    [dbeaver]="$SCRIPT_DIR/tools/install_dbeaver.sh"
    [qgis]="$SCRIPT_DIR/tools/install_qgis.sh"
    [telegram]="$SCRIPT_DIR/tools/install_telegram.sh"
    [firefox]="$SCRIPT_DIR/tools/install_firefox.sh"
    [libreoffice]="$SCRIPT_DIR/tools/install_libreoffice.sh"
    [googledrive]="$SCRIPT_DIR/tools/install_googledrive.sh"
    [obsidian]="$SCRIPT_DIR/tools/install_obsidian.sh"
    # ── Node ecosystem ─────────────────────────────────────────────────────────
    [node]="$SCRIPT_DIR/tools/install_node.sh"
    [npm]="$SCRIPT_DIR/tools/install_node.sh"
    [yarn]="$SCRIPT_DIR/tools/install_node.sh"
    [intellij]="$SCRIPT_DIR/tools/install_intellij.sh"
)

# Thứ tự cài đặt (dependencies trước)
INSTALL_ORDER=(
    # ── Dev tools (có dependency, cài trước) ──────────────────────────────────
    git
    java
    dotnet
    python
    uv
    golang
    docker
    ollama
    maven
    gradle
    spark
    hadoop
    jmeter
    postman
    # ── Desktop & Productivity apps ───────────────────────────────────────────
    vscode
    dbeaver
    qgis
    telegram
    firefox
    libreoffice
    googledrive
    obsidian
    node
    npm
    yarn
    intellij
)

# ── Thống kê kết quả ─────────────────────────────────────────────────────────
RESULTS_SUCCESS=()
RESULTS_FAILED=()
RESULTS_SKIPPED=()

# ── In tiêu đề ────────────────────────────────────────────────────────────────
print_banner() {
    clear
    echo -e "${BOLD}${CYAN}"
    cat <<'EOF'
╔══════════════════════════════════════════════════════════════════╗
║          Ubuntu Dev Environment Setup                           ║
║          Quản lý môi trường phát triển phần mềm                ║
╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${RESET}"
    echo -e "  ${BOLD}Script DIR :${RESET} $SCRIPT_DIR"
    echo -e "  ${BOLD}Log DIR    :${RESET} $DEVSETUP_LOG_DIR"
    echo -e "  ${BOLD}State File :${RESET} $DEVSETUP_STATE_FILE"
    echo ""
}

# ── Chạy một tool script ──────────────────────────────────────────────────────
run_tool() {
    local action="$1"
    local tool="$2"
    local script="${TOOL_SCRIPTS[$tool]:-}"

    if [[ -z "$script" ]]; then
        log_warn "Không tìm thấy script cho '$tool'. Bỏ qua."
        RESULTS_SKIPPED+=("$tool (không tìm thấy script)")
        return
    fi

    if [[ ! -f "$script" ]]; then
        log_error "Script không tồn tại: $script"
        RESULTS_FAILED+=("$tool")
        return
    fi

    chmod +x "$script"
    log_info "[$tool] → $action"

    # node/npm/yarn dùng chung một script với sub-action
    local sub_action="$action"
    if [[ "$action" == "install" ]]; then
        case "$tool" in
            npm)  sub_action="install-npm"  ;;
            yarn) sub_action="install-yarn" ;;
        esac
    fi

    if bash "$script" "$sub_action"; then
        if [[ "$action" == "install" ]]; then
            RESULTS_SUCCESS+=("$tool")
        fi
    else
        log_error "[$tool] $action THẤT BẠI"
        RESULTS_FAILED+=("$tool")
    fi
}

# ── Lệnh INSTALL ──────────────────────────────────────────────────────────────
cmd_install() {
    local tools=("$@")
    # Nếu không chỉ định tool, cài tất cả theo thứ tự
    if [[ ${#tools[@]} -eq 0 ]]; then
        tools=("${INSTALL_ORDER[@]}")
    fi

    print_banner
    log_section "BẮT ĐẦU CÀI ĐẶT: ${tools[*]}"
    init_devsetup
    acquire_lock
    assert_ubuntu
    assert_root_or_sudo

    local start_time=$SECONDS
    for tool in "${tools[@]}"; do
        run_tool install "$tool"
    done

    print_summary "install" "$((SECONDS - start_time))"
}

# ── Lệnh UNINSTALL ────────────────────────────────────────────────────────────
cmd_uninstall() {
    local tools=("$@")
    if [[ ${#tools[@]} -eq 0 ]]; then
        # Gỡ theo thứ tự ngược
        mapfile -t tools < <(printf '%s\n' "${INSTALL_ORDER[@]}" | tac)
    fi

    print_banner
    log_section "BẮT ĐẦU GỠ CÀI ĐẶT: ${tools[*]}"
    init_devsetup

    echo -e "${RED}${BOLD}⚠  CẢNH BÁO: Sắp gỡ cài đặt ${#tools[@]} công cụ!${RESET}"
    echo -ne "   Tiếp tục? [y/N] "
    read -r confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { log_info "Đã huỷ."; exit 0; }

    local start_time=$SECONDS
    for tool in "${tools[@]}"; do
        run_tool uninstall "$tool"
    done

    print_summary "uninstall" "$((SECONDS - start_time))"
}

# ── Lệnh STATUS ───────────────────────────────────────────────────────────────
cmd_status() {
    print_banner
    init_devsetup
    log_section "TRẠNG THÁI CÀI ĐẶT"

    printf "%-15s %-14s %-20s %s\n" "TOOL" "TRẠNG THÁI" "VERSION (state)" "VERSION (live)"
    printf "%-15s %-14s %-20s %s\n" "────────────" "──────────────" "──────────────" "────────────"

    for tool in "${INSTALL_ORDER[@]}"; do
        local status ver live_ver
        status=$(state_get "$tool")
        ver=$(state_version "$tool")

        # Lấy version hiện tại trực tiếp từ lệnh
        case "$tool" in
            dotnet)      live_ver=$(dotnet --version 2>/dev/null || echo "-") ;;
            java)        live_ver=$(java -version 2>&1 | grep version | awk -F'"' '{print $2}' || echo "-") ;;
            spark)       live_ver=$(spark-shell --version 2>&1 | grep "version" | awk '{print $NF}' | head -1 || echo "-") ;;
            golang)      live_ver=$(go version 2>/dev/null | awk '{print $3}' || echo "-") ;;
            python)      live_ver=$(python3 --version 2>/dev/null | awk '{print $2}' || echo "-") ;;
            uv)          live_ver=$(uv --version 2>/dev/null | awk '{print $2}' || echo "-") ;;
            docker)      live_ver=$(docker --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "-") ;;
            ollama)      live_ver=$(ollama --version 2>/dev/null || echo "-") ;;
            jmeter)      live_ver=$(jmeter --version 2>/dev/null | grep "version" | head -1 || echo "-") ;;
            maven)       live_ver=$(mvn --version 2>/dev/null | head -1 | awk '{print $3}' || echo "-") ;;
            gradle)      live_ver=$(gradle --version 2>/dev/null | grep "^Gradle" | awk '{print $2}' || echo "-") ;;
            hadoop)      live_ver=$(hadoop version 2>/dev/null | head -1 | awk '{print $2}' || echo "-") ;;
            git)         live_ver=$(git --version 2>/dev/null | awk '{print $3}' || echo "-") ;;
            postman)     live_ver=$(snap list postman 2>/dev/null | awk 'NR==2{print $2}' || echo "-") ;;
            vscode)      live_ver=$(code --version 2>/dev/null | head -1 || echo "-") ;;
            dbeaver)     live_ver=$(snap list dbeaver-ce 2>/dev/null | awk 'NR==2{print $2}' || dpkg -l dbeaver-ce 2>/dev/null | awk 'NR==4{print $3}' || echo "-") ;;
            qgis)        live_ver=$(qgis --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "-") ;;
            telegram)    live_ver=$(snap list telegram-desktop 2>/dev/null | awk 'NR==2{print $2}' || echo "-") ;;
            firefox)     live_ver=$(firefox --version 2>/dev/null | grep -oP '[0-9]+\.[0-9.]+' | head -1 || echo "-") ;;
            libreoffice) live_ver=$(libreoffice --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "-") ;;
            googledrive) live_ver=$(google-drive-ocamlfuse -version 2>/dev/null | head -1 || echo "-") ;;
            obsidian)    live_ver=$(dpkg -l obsidian 2>/dev/null | awk 'NR==4{print $3}' || snap list obsidian 2>/dev/null | awk 'NR==2{print $2}' || echo "-") ;;
            node)        live_ver=$(node --version 2>/dev/null || echo "-") ;;
            npm)         live_ver=$(npm --version 2>/dev/null || echo "-") ;;
            yarn)        live_ver=$(yarn --version 2>/dev/null || echo "-") ;;
            intellij)    live_ver=$(python3 -c "import json; d=json.load(open('${INTELLIJ_INSTALL_DIR}/product-info.json')); print(d.get('version',''))" 2>/dev/null \
                             || snap list intellij-idea-community 2>/dev/null | awk 'NR==2{print $2}' \
                             || echo "-") ;;
            *)           live_ver="-" ;;
        esac

        # ── Auto-sync: tool đã cài thực tế nhưng state trống → cập nhật state ──
        if [[ "$status" == "" && "$live_ver" != "-" && -n "$live_ver" ]]; then
            state_set "$tool" "$live_ver" "installed"
            status="installed"
            ver="$live_ver"
            log_warn "[$tool] Phát hiện đã cài nhưng chưa có state → tự đồng bộ"
        fi

        # Màu theo trạng thái
        local color="$RESET"
        local status_display="$status"
        case "$status" in
            installed) color="$GREEN"; status_display="✓ installed" ;;
            failed)    color="$RED";   status_display="✗ failed" ;;
            "")        color="$YELLOW"; status_display="⊘ not run" ;;
        esac

        printf "${color}%-15s %-14s %-20s %s${RESET}\n" \
            "$tool" "$status_display" "${ver:-—}" "${live_ver:-—}"
    done
    echo ""
    echo -e "  Log gần nhất: $(ls -t "$DEVSETUP_LOG_DIR"/*.log 2>/dev/null | head -1 || echo 'không có')"
}

# ── Lệnh CHECK-VERSIONS ───────────────────────────────────────────────────────
cmd_check_versions() {
    print_banner
    log_section "KIỂM TRA CONFLICT VERSIONS"
    source "$SCRIPT_DIR/lib/versions.sh"
    init_devsetup

    local conflicts=0
    check_one() {
        local tool="$1" required="$2" installed="$3"
        if [[ -n "$installed" && "$installed" != "-" ]]; then
            local cmp
            cmp=$(version_compare "$required" "$installed" 2>/dev/null || echo "0")
            if [[ "$cmp" != "0" ]]; then
                echo -e "  ${YELLOW}⚠  $tool${RESET}: yêu cầu=${required}, đã cài=${installed}"
                ((conflicts++))
            else
                echo -e "  ${GREEN}✓  $tool${RESET}: $installed (khớp)"
            fi
        else
            echo -e "  ${CYAN}○  $tool${RESET}: chưa cài (target: $required)"
        fi
    }

    check_one "dotnet"  "$DOTNET_VERSION"  "$(dotnet --version 2>/dev/null | cut -d. -f1,2 || echo '')"
    check_one "java"    "$JAVA_VERSION"    "$(java -version 2>&1 | grep -oP '(?<=version ")[0-9]+' | head -1 || echo '')"
    check_one "golang"  "$GO_VERSION"      "$(go version 2>/dev/null | grep -oP 'go\K[0-9]+\.[0-9]+\.[0-9]+' || echo '')"
    check_one "python"  "$PYTHON_VERSION"  "$(python3 --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+' | head -1 || echo '')"
    check_one "maven"   "$MAVEN_VERSION"   "$(mvn --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head-1 || echo '')"
    check_one "gradle"  "$GRADLE_VERSION"  "$(gradle --version 2>/dev/null | grep '^Gradle' | awk '{print $2}' || echo '')"
    check_one "spark"   "$SPARK_VERSION"   ""
    check_one "hadoop"  "$HADOOP_VERSION"  "$(hadoop version 2>/dev/null | awk 'NR==1{print $2}' || echo '')"
    # Desktop apps (version checking — apt/snap managed)
    check_one "vscode"       "latest"  "$(code --version 2>/dev/null | head -1 || echo '')"
    check_one "firefox"      "$FIREFOX_VERSION"  "$(firefox --version 2>/dev/null | grep -oP '[0-9]+\.[0-9.]+' | head-1 || echo '')"
    check_one "libreoffice"  "latest"  "$(libreoffice --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head-1 || echo '')"
    check_one "qgis"         "latest"  "$(qgis --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head-1 || echo '')"
    check_one "telegram"     "latest"  "$(snap list telegram-desktop 2>/dev/null | awk 'NR==2{print $2}' || echo '')"
    check_one "dbeaver"      "latest"  "$(dpkg -l dbeaver-ce 2>/dev/null | awk 'NR==4{print $3}' || echo '')"
    check_one "googledrive"  "latest"  "$(google-drive-ocamlfuse -version 2>/dev/null | head-1 || echo '')"
    check_one "obsidian"     "$OBSIDIAN_VERSION"  "$(dpkg -l obsidian 2>/dev/null | awk 'NR==4{print $3}' || echo '')"
    check_one "node"  "$NODE_VERSION"  "$(node --version 2>/dev/null | tr -d 'v' || echo '')"
    check_one "npm"   "$NPM_VERSION"   "$(npm --version 2>/dev/null || echo '')"
    check_one "yarn"  "$YARN_VERSION"  "$(yarn --version 2>/dev/null || echo '')"
    local _idea_ver=""
    _idea_ver=$(python3 -c "import json; d=json.load(open('${INTELLIJ_INSTALL_DIR}/product-info.json')); print(d.get('version',''))" 2>/dev/null || echo "")
    check_one "intellij" "$INTELLIJ_VERSION" "$_idea_ver"

    echo ""
    if [[ $conflicts -eq 0 ]]; then
        log_success "Không phát hiện conflict version nào!"
    else
        log_warn "Phát hiện $conflicts conflict version. Chạy 'install' để đồng bộ."
    fi
}

# ── In tổng kết ───────────────────────────────────────────────────────────────
print_summary() {
    local action="$1" elapsed="$2"
    echo ""
    log_section "KẾT QUẢ $action"
    echo -e "  ⏱  Thời gian: ${elapsed}s"
    echo -e "  📋 Log: $LOG_FILE"
    echo ""

    if [[ ${#RESULTS_SUCCESS[@]} -gt 0 ]]; then
        echo -e "  ${GREEN}✓ Thành công (${#RESULTS_SUCCESS[@]}):${RESET}"
        for t in "${RESULTS_SUCCESS[@]}"; do echo -e "    • $t"; done
    fi
    if [[ ${#RESULTS_FAILED[@]} -gt 0 ]]; then
        echo -e "\n  ${RED}✗ Thất bại (${#RESULTS_FAILED[@]}):${RESET}"
        for t in "${RESULTS_FAILED[@]}"; do echo -e "    • $t"; done
        echo -e "  ${YELLOW}→ Xem chi tiết lỗi: $LOG_FILE${RESET}"
    fi
    if [[ ${#RESULTS_SKIPPED[@]} -gt 0 ]]; then
        echo -e "\n  ${YELLOW}⊘ Bỏ qua (${#RESULTS_SKIPPED[@]}):${RESET}"
        for t in "${RESULTS_SKIPPED[@]}"; do echo -e "    • $t"; done
    fi
    echo ""
    echo -e "  ${CYAN}Chạy './setup.sh status' để xem trạng thái đầy đủ${RESET}"
    echo ""
}

# ── Hiển thị help ─────────────────────────────────────────────────────────────
print_help() {
    cat <<EOF

${BOLD}Ubuntu Dev Setup - Script quản lý môi trường phát triển${RESET}

${BOLD}CÁCH DÙNG:${RESET}
  $(basename "$0") <lệnh> [danh_sách_tool]

${BOLD}LỆNH:${RESET}
  install   [tools...]   Cài đặt (mặc định: tất cả)
  uninstall [tools...]   Gỡ cài đặt (mặc định: tất cả)
  status                 Xem trạng thái cài đặt
  check-versions         Kiểm tra conflict version
  help                   Hiển thị trợ giúp này

${BOLD}CÁC TOOL CÓ SẴN:${RESET}
  $(printf '  %s\n' "${!TOOL_SCRIPTS[@]}" | sort | tr '\n' ' ')

${BOLD}VÍ DỤ:${RESET}
  $(basename "$0") install                   # Cài tất cả
  $(basename "$0") install java docker       # Chỉ cài java và docker
  $(basename "$0") uninstall ollama postman  # Gỡ ollama và postman
  $(basename "$0") status                    # Xem trạng thái
  
${BOLD}KIỂM SOÁT VERSION:${RESET}
  Sửa file ${SCRIPT_DIR}/lib/versions.sh để thay đổi version
  Hoặc đặt biến môi trường trước khi chạy:
    JAVA_VERSION=17 $(basename "$0") install java
    PYTHON_VERSION=3.11 $(basename "$0") install python

EOF
}

# ── Entrypoint chính ──────────────────────────────────────────────────────────
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        install)        cmd_install "$@" ;;
        uninstall)      cmd_uninstall "$@" ;;
        status)         cmd_status ;;
        check-versions) cmd_check_versions ;;
        help|--help|-h) print_help ;;
        *)
            log_error "Lệnh không hợp lệ: '$command'"
            print_help
            exit 1
            ;;
    esac
}

main "$@"
