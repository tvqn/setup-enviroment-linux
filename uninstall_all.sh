#!/usr/bin/env bash
# =============================================================================
# uninstall_all.sh - Gỡ toàn bộ môi trường phát triển
# Đây là shortcut cho: ./setup.sh uninstall
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   GỠ TOÀN BỘ MÔI TRƯỜNG PHÁT TRIỂN                  ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  Script này sẽ gỡ cài đặt TẤT CẢ công cụ:"
echo "  dotnet, java, spark, golang, python, uv, docker,"
echo "  ollama, jmeter, maven, gradle, hadoop, git, postman"
echo ""

bash "$SCRIPT_DIR/setup.sh" uninstall "$@"
