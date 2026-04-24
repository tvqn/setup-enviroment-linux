# Ubuntu Dev Environment Setup

Hệ thống bash script cài đặt và quản lý môi trường phát triển phần mềm trên Ubuntu.

## Cấu trúc thư mục

```
devsetup/
├── setup.sh              # Script chủ (entrypoint duy nhất)
├── uninstall_all.sh      # Shortcut gỡ toàn bộ
├── lib/
│   ├── core.sh           # Thư viện lõi: logging, version control, state
│   └── versions.sh       # Cấu hình version mặc định
└── tools/
    │── Dev Tools ─────────────────────────────────────────────
    ├── install_dotnet.sh
    ├── install_java.sh
    ├── install_spark.sh
    ├── install_golang.sh
    ├── install_python.sh
    ├── install_uv.sh
    ├── install_docker.sh
    ├── install_ollama.sh
    ├── install_jmeter.sh
    ├── install_maven.sh
    ├── install_gradle.sh
    ├── install_hadoop.sh
    ├── install_git.sh        # Bao gồm cả Git LFS
    ├── install_postman.sh
    │── Desktop & Productivity ─────────────────────────────────
    ├── install_vscode.sh
    ├── install_dbeaver.sh
    ├── install_qgis.sh
    ├── install_telegram.sh
    ├── install_firefox.sh
    ├── install_libreoffice.sh
    └── install_googledrive.sh
```

## Cách sử dụng

```bash
# Phân quyền (chỉ lần đầu)
chmod +x setup.sh uninstall_all.sh tools/*.sh

# Cài tất cả công cụ (dev tools + desktop apps)
sudo ./setup.sh install

# Cài nhóm dev tools
./setup.sh install java dotnet golang python docker

# Cài nhóm desktop apps
./setup.sh install vscode dbeaver firefox libreoffice telegram qgis googledrive

# Gỡ từng công cụ
./setup.sh uninstall ollama postman telegram

# Gỡ toàn bộ
./uninstall_all.sh

# Xem trạng thái
./setup.sh status

# Kiểm tra conflict version
./setup.sh check-versions
```

## Kiểm soát version

### Cách 1: Sửa file `lib/versions.sh`
```bash
DOTNET_VERSION="8.0"
JAVA_VERSION="21"
GO_VERSION="1.22.3"
PYTHON_VERSION="3.12"
SPARK_VERSION="3.5.1"
JMETER_VERSION="5.6.3"
MAVEN_VERSION="3.9.6"
GRADLE_VERSION="8.7"
HADOOP_VERSION="3.3.6"
```

### Cách 2: Biến môi trường (ưu tiên hơn)
```bash
JAVA_VERSION=17 ./setup.sh install java
PYTHON_VERSION=3.11 ./setup.sh install python
```

## Tính năng

| Tính năng | Mô tả |
|-----------|-------|
| **Version control** | Mỗi tool đều có version được cấu hình trong `versions.sh` |
| **Conflict detection** | Phát hiện và cảnh báo khi version yêu cầu ≠ version đã cài |
| **State tracking** | Trạng thái cài đặt lưu tại `~/.devsetup/state.json` |
| **Logging** | Log chi tiết theo timestamp tại `~/.devsetup/logs/` |
| **Skip if installed** | Bỏ qua nếu đúng version đã cài, tránh cài lại không cần thiết |
| **Dependency order** | Tự động cài dependencies (vd: Java trước Spark, Maven, Gradle) |
| **Uninstall** | Mỗi tool đều có uninstall sạch, xoá cả PATH/env vars |
| **Lock file** | Tránh chạy đồng thời nhiều tiến trình setup |

## Thứ tự cài đặt (tự động)

```
git → java → dotnet → python → uv → golang → docker → ollama
    → maven → gradle → spark → hadoop → jmeter → postman
```

## File state

Trạng thái cài đặt được lưu tại `~/.devsetup/state.json`:
```json
{
  "installed": {
    "java": "installed",
    "docker": "installed",
    "golang": "failed"
  },
  "versions": {
    "java": "21.0.3",
    "docker": "26.1.0",
    "golang": "1.22.3"
  }
}
```

## Danh sách đầy đủ các công cụ

| Tool | Loại | Phương thức cài | Ghi chú |
|------|------|-----------------|---------|
| **git** | Dev | apt (git-core PPA) | Bao gồm Git LFS |
| **java** | Dev | apt (OpenJDK) | Dependency cho Spark, Maven, Gradle, JMeter |
| **dotnet** | Dev | apt (Microsoft repo) | .NET SDK |
| **python** | Dev | apt (deadsnakes PPA) | Python 3.x + venv + dev |
| **uv** | Dev | installer script | Python package manager |
| **golang** | Dev | binary download | Tự quản lý version |
| **docker** | Dev | apt (Docker official) | Bao gồm Compose plugin |
| **ollama** | Dev | installer script | Local LLM runner |
| **maven** | Dev | binary download | Apache Maven |
| **gradle** | Dev | binary download | Apache Gradle |
| **spark** | Dev | binary download | Apache Spark (cần Java) |
| **hadoop** | Dev | binary download | Apache Hadoop (cần Java) |
| **jmeter** | Dev | binary download | Apache JMeter (cần Java) |
| **postman** | Dev | snap / binary | API testing |
| **vscode** | Desktop | snap / apt (MS repo) | Visual Studio Code |
| **dbeaver** | Desktop | snap / .deb | Database GUI client |
| **qgis** | Desktop | apt (QGIS repo) | GIS software |
| **telegram** | Desktop | snap / binary | Messenger |
| **firefox** | Desktop | apt (Mozilla repo) | Thay thế bản snap mặc định |
| **libreoffice** | Desktop | apt (LibreOffice PPA) | Bộ office + tiếng Việt |
| **googledrive** | Desktop | apt (PPA) + GNOME | FUSE mount + GNOME Files |

- Ubuntu 20.04, 22.04, hoặc 24.04 LTS
- Quyền `sudo`
- Kết nối internet
- `python3` (thường đã có sẵn, dùng để quản lý state.json)
