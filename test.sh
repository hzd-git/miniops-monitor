#!/usr/bin/env bash
# MiniOps Monitor 自动验证脚本，需在 install.sh 成功后以 sudo 执行。
# 本项目参考 nuver-labs/vps-audit 的资源检查思路后以极简方式重写。
# Copyright (c) 2024 Israel Abebe Kokiso. Licensed under the MIT License.

set -uo pipefail

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SERVICE_NAME="miniops-monitor.service"
INSTALLED_SCRIPT="/usr/local/lib/miniops-monitor/miniops-monitor.sh"
FAILURES=0

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1" >&2
  FAILURES=$((FAILURES + 1))
}

check_project_file_count() {
  local count
  count=$(find "$PROJECT_DIR" -type f \( -name '*.sh' -o -name '*.service' \) | wc -l)
  if [[ "$count" -eq 3 ]]; then
    pass "仓库仅包含 3 个脚本或配置文件"
  else
    fail "脚本或配置文件数量为 $count，预期为 3"
  fi
}

check_syntax() {
  local script syntax_failures=0
  for script in "$PROJECT_DIR/install.sh" "$PROJECT_DIR/test.sh" "$PROJECT_DIR/src/miniops-monitor.sh"; do
    if ! bash -n "$script"; then
      syntax_failures=$((syntax_failures + 1))
    fi
  done
  if (( syntax_failures == 0 )); then
    pass "三个 Bash 脚本语法正确"
  else
    fail "Bash 语法检查失败"
  fi
}

check_line_budget() {
  local lines
  lines=$(awk '!/^[[:space:]]*(#|$)/ { count++ } END { print count + 0 }' \
    "$PROJECT_DIR/install.sh" "$PROJECT_DIR/test.sh" "$PROJECT_DIR/src/miniops-monitor.sh")
  if (( lines <= 300 )); then
    pass "非注释非空代码共 $lines 行，未超过 300 行"
  else
    fail "非注释非空代码共 $lines 行，超过 300 行"
  fi
}

check_installed_script() {
  if [[ -x "$INSTALLED_SCRIPT" ]]; then
    pass "监控脚本已安装"
  else
    fail "未找到已安装监控脚本: $INSTALLED_SCRIPT"
  fi
}

check_service_enabled() {
  if systemctl is-enabled --quiet "$SERVICE_NAME"; then
    pass "服务已设置为开机自启"
  else
    fail "服务未设置为开机自启"
  fi
}

check_service_active() {
  if systemctl is-active --quiet "$SERVICE_NAME"; then
    pass "服务正在运行"
  else
    fail "服务未运行，请执行 journalctl -u $SERVICE_NAME -n 30 --no-pager"
  fi
}

restart_service() {
  if systemctl restart "$SERVICE_NAME" >/dev/null 2>&1; then
    pass "服务重启成功"
  else
    fail "服务重启失败"
  fi
}

check_recent_log() {
  local attempt
  # 重启后轮询 journal，避免刚启动时日志尚未写入造成误报。
  for attempt in {1..5}; do
    if journalctl -u "$SERVICE_NAME" --since '2 minutes ago' --no-pager 2>/dev/null | \
      grep -q 'event=resource_sample'; then
      pass "资源采样日志已写入 journal"
      return
    fi
    sleep 1
  done
  fail "未找到近期资源采样日志"
}

check_alert_path() {
  if [[ -x "$INSTALLED_SCRIPT" ]] && \
    "$INSTALLED_SCRIPT" --self-test 2>/dev/null | grep -q 'level=ALERT event=threshold_exceeded resource=demo'; then
    pass "告警输出链路正常"
  else
    fail "告警自检未输出预期 ALERT"
  fi
}

finish() {
  if (( FAILURES == 0 )); then
    echo "PASS: 全部检查通过。"
    return 0
  fi
  echo "FAIL: 共 $FAILURES 项检查失败。" >&2
  return 1
}

check_project_file_count
check_syntax
check_line_budget

if (( EUID != 0 )); then
  fail "请使用 sudo ./test.sh 执行服务检查"
  finish
  exit $?
fi

check_installed_script
check_service_enabled
restart_service
check_service_active
check_recent_log
check_alert_path
finish
