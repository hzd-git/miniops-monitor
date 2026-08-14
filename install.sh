#!/usr/bin/env bash
# MiniOps Monitor 安装器，仅面向 Ubuntu 22.04 的 systemd 主机。
# 本项目参考 nuver-labs/vps-audit 的资源检查思路后以极简方式重写。
# Copyright (c) 2024 Israel Abebe Kokiso. Licensed under the MIT License.

set -euo pipefail

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SOURCE_SCRIPT="$PROJECT_DIR/src/miniops-monitor.sh"
INSTALL_DIR="/usr/local/lib/miniops-monitor"
SERVICE_NAME="miniops-monitor.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"

fail() {
  echo "安装失败: $*" >&2
  exit 1
}

require_root() {
  (( EUID == 0 )) || fail "请使用 sudo ./install.sh 执行安装。"
}

check_environment() {
  [[ -r /etc/os-release ]] || fail "无法读取 /etc/os-release。"
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "22.04" ]] || \
    fail "仅支持 Ubuntu 22.04。"
  [[ "$(</proc/1/comm)" == "systemd" ]] || fail "当前系统未以 systemd 作为 PID 1。"
  [[ -f "$SOURCE_SCRIPT" ]] || fail "未找到源脚本: $SOURCE_SCRIPT"
}

install_dependencies() {
  echo "[1/3] 安装依赖 procps..."
  apt-get update
  apt-get install -y procps
}

install_monitor() {
  echo "[2/3] 安装监控脚本..."
  install -Dm755 "$SOURCE_SCRIPT" "$INSTALL_DIR/miniops-monitor.sh"
}

register_service() {
  echo "[3/3] 注册并启动 Systemd 服务..."
  # unit 内联生成，以保持仓库只包含三个脚本或配置文件。
  cat > "$SERVICE_FILE" <<'UNIT'
# 此文件由 MiniOps Monitor 的 install.sh 生成。
[Unit]
Description=MiniOps Monitor - 简易系统资源监控教学服务

[Service]
Type=simple
# 使用动态低权限用户，服务不保留 root 身份。
DynamicUser=yes
NoNewPrivileges=yes
ExecStart=/usr/local/lib/miniops-monitor/miniops-monitor.sh --loop
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=miniops-monitor

[Install]
WantedBy=multi-user.target
UNIT

  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME"
  systemctl restart "$SERVICE_NAME"
}

require_root
check_environment
install_dependencies
install_monitor
register_service
echo "安装完成: 使用 sudo systemctl status $SERVICE_NAME 查看状态。"
