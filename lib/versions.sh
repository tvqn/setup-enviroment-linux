#!/usr/bin/env bash
# =============================================================================
# versions.sh - Cấu hình version mặc định cho tất cả công cụ
# Thay đổi các giá trị ở đây để kiểm soát version cài đặt
# =============================================================================

# ── .NET Core ─────────────────────────────────────────────────────────────────
DOTNET_VERSION="${DOTNET_VERSION:-8.0}"          # 6.0 | 7.0 | 8.0 | 9.0

# ── Java (OpenJDK) ────────────────────────────────────────────────────────────
JAVA_VERSION="${JAVA_VERSION:-21}"               # 11 | 17 | 21

# ── Apache Spark ─────────────────────────────────────────────────────────────
SPARK_VERSION="${SPARK_VERSION:-3.5.1}"
SPARK_HADOOP_VERSION="${SPARK_HADOOP_VERSION:-3}"
SPARK_INSTALL_DIR="${SPARK_INSTALL_DIR:-/opt/spark}"

# ── Go ────────────────────────────────────────────────────────────────────────
GO_VERSION="${GO_VERSION:-1.22.3}"
GO_INSTALL_DIR="${GO_INSTALL_DIR:-/usr/local/go}"

# ── Python ───────────────────────────────────────────────────────────────────
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"         # 3.10 | 3.11 | 3.12

# ── uv (Python package manager) ───────────────────────────────────────────────
UV_VERSION="${UV_VERSION:-latest}"               # latest | 0.x.x

# ── Docker ───────────────────────────────────────────────────────────────────
DOCKER_VERSION="${DOCKER_VERSION:-latest}"       # latest | 24.x | 25.x

# ── Ollama ───────────────────────────────────────────────────────────────────
OLLAMA_VERSION="${OLLAMA_VERSION:-latest}"

# ── JMeter ───────────────────────────────────────────────────────────────────
JMETER_VERSION="${JMETER_VERSION:-5.6.3}"
JMETER_INSTALL_DIR="${JMETER_INSTALL_DIR:-/opt/jmeter}"

# ── Maven ────────────────────────────────────────────────────────────────────
MAVEN_VERSION="${MAVEN_VERSION:-3.9.6}"
MAVEN_INSTALL_DIR="${MAVEN_INSTALL_DIR:-/opt/maven}"

# ── Gradle ───────────────────────────────────────────────────────────────────
GRADLE_VERSION="${GRADLE_VERSION:-8.7}"
GRADLE_INSTALL_DIR="${GRADLE_INSTALL_DIR:-/opt/gradle}"

# ── Hadoop ───────────────────────────────────────────────────────────────────
HADOOP_VERSION="${HADOOP_VERSION:-3.3.6}"
HADOOP_INSTALL_DIR="${HADOOP_INSTALL_DIR:-/opt/hadoop}"

# ── Git ───────────────────────────────────────────────────────────────────────
GIT_VERSION="${GIT_VERSION:-latest}"             # apt managed

# ── Git LFS ──────────────────────────────────────────────────────────────────
GIT_LFS_VERSION="${GIT_LFS_VERSION:-latest}"

# ── Postman ──────────────────────────────────────────────────────────────────
POSTMAN_VERSION="${POSTMAN_VERSION:-latest}"
POSTMAN_INSTALL_DIR="${POSTMAN_INSTALL_DIR:-/opt/postman}"

# ── VS Code ───────────────────────────────────────────────────────────────────
VSCODE_VERSION="${VSCODE_VERSION:-latest}"       # latest | 1.x.x

# ── DBeaver Community ─────────────────────────────────────────────────────────
DBEAVER_VERSION="${DBEAVER_VERSION:-latest}"     # latest | 24.x.x

# ── QGIS ─────────────────────────────────────────────────────────────────────
QGIS_VERSION="${QGIS_VERSION:-latest}"           # latest | ltr (long-term release)

# ── Telegram ─────────────────────────────────────────────────────────────────
TELEGRAM_VERSION="${TELEGRAM_VERSION:-latest}"
TELEGRAM_INSTALL_DIR="${TELEGRAM_INSTALL_DIR:-/opt/telegram}"

# ── Firefox ───────────────────────────────────────────────────────────────────
FIREFOX_VERSION="${FIREFOX_VERSION:-latest}"     # latest | esr

# ── LibreOffice ───────────────────────────────────────────────────────────────
LIBREOFFICE_VERSION="${LIBREOFFICE_VERSION:-latest}"

# ── Google Drive (google-drive-ocamlfuse) ─────────────────────────────────────
GOOGLEDRIVE_MOUNT_DIR="${GOOGLEDRIVE_MOUNT_DIR:-$HOME/GoogleDrive}"

# ── Obsidian ──────────────────────────────────────────────────────────────────
OBSIDIAN_VERSION="${OBSIDIAN_VERSION:-latest}"   # latest | 1.x.x

# ── Node.js ───────────────────────────────────────────────────────────────────
# Cài qua nvm để dễ quản lý nhiều version
NODE_VERSION="${NODE_VERSION:-lts}"              # lts | latest | 20 | 22 | 18
NVM_VERSION="${NVM_VERSION:-latest}"             # version của nvm installer

# ── npm ───────────────────────────────────────────────────────────────────────
# npm được cài tự động cùng Node.js — biến này dùng để upgrade npm sau khi cài
NPM_VERSION="${NPM_VERSION:-latest}"             # latest | 10.x.x

# ── Yarn ──────────────────────────────────────────────────────────────────────
YARN_VERSION="${YARN_VERSION:-latest}"           # latest | classic (1.x) | 4.x.x

# ── IntelliJ IDEA ─────────────────────────────────────────────────────────────
INTELLIJ_EDITION="${INTELLIJ_EDITION:-community}" # community (free) | ultimate (trả phí)
INTELLIJ_VERSION="${INTELLIJ_VERSION:-latest}"    # latest | 2024.1 | 2023.3.x
INTELLIJ_INSTALL_DIR="${INTELLIJ_INSTALL_DIR:-/opt/intellij}"
