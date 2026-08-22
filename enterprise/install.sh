#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SCRIPT="$PROJECT_DIR/src/miniops-monitor.sh"
CONFIG_EXAMPLE="$PROJECT_DIR/config/miniops-monitor.env.example"
SERVICE_TEMPLATE="$PROJECT_DIR/systemd/miniops-monitor-enterprise.service"

SERVICE_NAME="miniops-monitor-enterprise.service"
INSTALL_DIR="/usr/local/lib/miniops-monitor-enterprise"
INSTALL_SCRIPT="$INSTALL_DIR/miniops-monitor.sh"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
CONFIG_FILE="/etc/default/miniops-monitor-enterprise"

TEST_MODE="${MINIOPS_TEST_MODE:-0}"
TEST_ROOT="${MINIOPS_TEST_ROOT:-}"
SYSTEMCTL_BIN="${MINIOPS_SYSTEMCTL:-systemctl}"

if [[ -n "$TEST_ROOT" ]]; then
  INSTALL_DIR="$TEST_ROOT$INSTALL_DIR"
  INSTALL_SCRIPT="$INSTALL_DIR/miniops-monitor.sh"
  SERVICE_FILE="$TEST_ROOT$SERVICE_FILE"
  CONFIG_FILE="$TEST_ROOT$CONFIG_FILE"
fi

DRY_RUN=0
TEMP_DIR=""
CONFIG_CREATED=0
PREVIOUS_SCRIPT=0
PREVIOUS_SERVICE=0
PREVIOUS_ACTIVE=0
PREVIOUS_ENABLED=0

cleanup() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf -- "$TEMP_DIR"
  fi
}

trap cleanup EXIT

systemctl_cmd() {
  "$SYSTEMCTL_BIN" "$@"
}

report_systemd_failure() {
  echo "请执行以下命令诊断：" >&2
  echo "  systemctl status $SERVICE_NAME --no-pager" >&2
  echo "  journalctl -u $SERVICE_NAME -n 50 --no-pager" >&2
}

systemctl_state() {
  local output status
  if output="$("$SYSTEMCTL_BIN" is-active "$SERVICE_NAME" 2>&1)"; then
    status=0
  else
    status=$?
  fi

  case "$output" in
    active|activating|deactivating|reloading|inactive|failed)
      printf '%s\n' "$output"
      return 0
      ;;
    unknown)
      printf 'not-found\n'
      return 0
      ;;
    *)
      echo "无法查询服务状态: status=$status output=${output:-<empty>}" >&2
      return 1
      ;;
  esac
}

systemctl_enabled_state() {
  local output status
  if output="$("$SYSTEMCTL_BIN" is-enabled "$SERVICE_NAME" 2>&1)"; then
    status=0
  else
    status=$?
  fi

  case "$output" in
    enabled|enabled-runtime|linked|linked-runtime|alias|masked|masked-runtime|static|indirect|disabled|generated|transient|bad-setting|not-found|unknown)
      printf '%s\n' "$output"
      return 0
      ;;
    *)
      echo "无法查询服务启用状态: status=$status output=${output:-<empty>}" >&2
      return 1
      ;;
  esac
}

is_running_state() {
  case "$1" in
    active|activating|deactivating|reloading)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_stopped_state() {
  case "$1" in
    inactive|failed|not-found)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

stop_and_verify() {
  local state

  if ! state="$(systemctl_state)"; then
    report_systemd_failure
    return 1
  fi
  if is_stopped_state "$state"; then
    return 0
  fi
  if ! is_running_state "$state"; then
    echo "无法确认服务状态: $state" >&2
    report_systemd_failure
    return 1
  fi

  if ! systemctl_cmd stop "$SERVICE_NAME"; then
    echo "停止服务失败，保留现有文件。" >&2
    report_systemd_failure
    return 1
  fi
  if ! state="$(systemctl_state)"; then
    report_systemd_failure
    return 1
  fi
  if ! is_stopped_state "$state"; then
    echo "停止命令已返回，但服务仍未确认停止: $state" >&2
    report_systemd_failure
    return 1
  fi
}

usage() {
  cat <<'USAGE'
用法: install.sh [--dry-run|--help]

--dry-run  检查源文件并显示安装动作，不需要 root，不修改系统
--help     显示帮助
USAGE
}

fail() {
  echo "安装失败: $*" >&2
  exit 1
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        usage >&2
        fail "未知参数: $1"
        ;;
    esac
  done
}

check_source_tree() {
  [[ -r "$SOURCE_SCRIPT" ]] || fail "未找到监控脚本: $SOURCE_SCRIPT"
  [[ -r "$CONFIG_EXAMPLE" ]] || fail "未找到配置示例: $CONFIG_EXAMPLE"
  [[ -r "$SERVICE_TEMPLATE" ]] || fail "未找到 systemd unit: $SERVICE_TEMPLATE"
}

check_environment() {
  ((DRY_RUN == 1)) && return 0
  if ((TEST_MODE == 1)); then
    [[ -n "$TEST_ROOT" && "$TEST_ROOT" == /tmp/* ]] || fail "测试模式必须使用 /tmp 下的临时根目录。"
    [[ -x "$SYSTEMCTL_BIN" ]] || fail "测试模式未找到 mock systemctl: $SYSTEMCTL_BIN"
    return 0
  fi
  ((EUID == 0)) || fail "请使用 sudo enterprise/install.sh 执行安装。"
  [[ -r /etc/os-release ]] || fail "无法读取 /etc/os-release。"
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}:${VERSION_ID:-}" in
    ubuntu:22.04|ubuntu:24.04)
      ;;
    *)
      fail "仅支持 Ubuntu 22.04/24.04。"
      ;;
  esac
  [[ "$(</proc/1/comm)" == "systemd" ]] || fail "当前系统未以 systemd 作为 PID 1。"
  command -v apt-get >/dev/null 2>&1 || fail "未找到 apt-get。"
  command -v "$SYSTEMCTL_BIN" >/dev/null 2>&1 || fail "未找到 systemctl。"
  command -v install >/dev/null 2>&1 || fail "未找到 install。"
  command -v mktemp >/dev/null 2>&1 || fail "未找到 mktemp。"
}

install_dependencies() {
  ((DRY_RUN == 1 || TEST_MODE == 1)) && return 0
  if command -v free >/dev/null 2>&1 && command -v nproc >/dev/null 2>&1; then
    echo "依赖已满足：procps。"
    return 0
  fi
  echo "安装依赖 procps..."
  apt-get update
  apt-get install -y procps
}

prepare_transaction() {
  local state

  if ! state="$(systemctl_state)"; then
    fail "无法查询服务状态，未开始安装。"
  fi
  if is_running_state "$state"; then
    PREVIOUS_ACTIVE=1
  fi
  if ! state="$(systemctl_enabled_state)"; then
    fail "无法查询服务启用状态，未开始安装。"
  fi
  case "$state" in
    enabled|enabled-runtime|linked|linked-runtime|alias)
      PREVIOUS_ENABLED=1
      ;;
  esac

  TEMP_DIR="$(mktemp -d /tmp/miniops-monitor-enterprise.XXXXXX)"
  mkdir -p "$TEMP_DIR/backup"
  if [[ -e "$INSTALL_SCRIPT" ]]; then
    cp -a "$INSTALL_SCRIPT" "$TEMP_DIR/backup/monitor.sh"
    PREVIOUS_SCRIPT=1
  fi
  if [[ -e "$SERVICE_FILE" ]]; then
    cp -a "$SERVICE_FILE" "$TEMP_DIR/backup/service"
    PREVIOUS_SERVICE=1
  fi
}

stage_files() {
  install -Dm755 "$SOURCE_SCRIPT" "$TEMP_DIR/monitor.sh"
  install -Dm644 "$CONFIG_EXAMPLE" "$TEMP_DIR/config"
  install -Dm644 "$SERVICE_TEMPLATE" "$TEMP_DIR/service"
}

rollback() {
  local status="$1" rollback_errors=0 rollback_block_delete=0 state
  set +e
  echo "安装失败，开始回滚已写入的文件..." >&2

  if [[ -e "$SERVICE_FILE" || "$PREVIOUS_SERVICE" -eq 1 ]]; then
    if ! stop_and_verify; then
      echo "无法确认服务已停止，保留当前安装文件以便人工恢复。" >&2
      report_systemd_failure
      return "$status"
    fi
  fi

  if ! systemctl_cmd daemon-reload; then
    echo "回滚前 daemon-reload 失败，保留当前安装文件。" >&2
    report_systemd_failure
    return "$status"
  fi
  if [[ -e "$SERVICE_FILE" && "$PREVIOUS_ENABLED" -eq 0 ]]; then
    if ! state="$(systemctl_enabled_state)"; then
      echo "回滚前无法查询服务启用状态，保留当前安装文件。" >&2
      report_systemd_failure
      return "$status"
    fi
    case "$state" in
      enabled|enabled-runtime|linked|linked-runtime|alias)
        if ! systemctl_cmd disable "$SERVICE_NAME"; then
          echo "回滚前禁用服务失败，保留当前安装文件。" >&2
          report_systemd_failure
          return "$status"
        fi
        if ! state="$(systemctl_enabled_state)" || [[ "$state" == enabled || "$state" == enabled-runtime || "$state" == linked || "$state" == linked-runtime || "$state" == alias ]]; then
          echo "回滚前未确认服务已禁用，保留当前安装文件。" >&2
          report_systemd_failure
          return "$status"
        fi
        ;;
    esac
  fi

  if ((PREVIOUS_SCRIPT == 1)); then
    if ! install -Dm755 "$TEMP_DIR/backup/monitor.sh" "$INSTALL_SCRIPT"; then
      rollback_errors=1
      rollback_block_delete=1
    fi
  else
    if ! rm -f -- "$INSTALL_SCRIPT"; then
      rollback_errors=1
      rollback_block_delete=1
    fi
  fi
  if ((PREVIOUS_SERVICE == 1)); then
    if ! install -Dm644 "$TEMP_DIR/backup/service" "$SERVICE_FILE"; then
      rollback_errors=1
      rollback_block_delete=1
    fi
  fi
  if ((CONFIG_CREATED == 1)); then
    if ! rm -f -- "$CONFIG_FILE"; then
      rollback_errors=1
      rollback_block_delete=1
    fi
  fi

  if ! systemctl_cmd daemon-reload; then
    rollback_errors=1
    rollback_block_delete=1
    echo "回滚期间 daemon-reload 失败。" >&2
    report_systemd_failure
  fi
  if ((rollback_block_delete == 0)); then
    if ((PREVIOUS_ENABLED == 1)); then
      if ! systemctl_cmd enable "$SERVICE_NAME"; then
        rollback_errors=1
        rollback_block_delete=1
        echo "回滚期间恢复服务启用状态失败。" >&2
        report_systemd_failure
      elif ! state="$(systemctl_enabled_state)"; then
        rollback_errors=1
        rollback_block_delete=1
        echo "回滚后无法查询服务启用状态。" >&2
        report_systemd_failure
      elif [[ "$state" != enabled && "$state" != enabled-runtime && "$state" != linked && "$state" != linked-runtime && "$state" != alias ]]; then
        rollback_errors=1
        rollback_block_delete=1
        echo "回滚后未确认服务已恢复启用状态。" >&2
        report_systemd_failure
      fi
    elif [[ -e "$SERVICE_FILE" ]]; then
      if ! systemctl_cmd disable "$SERVICE_NAME"; then
        rollback_errors=1
        rollback_block_delete=1
        echo "回滚期间清理服务启用状态失败。" >&2
        report_systemd_failure
      elif ! state="$(systemctl_enabled_state)"; then
        rollback_errors=1
        rollback_block_delete=1
        echo "回滚后无法查询服务启用状态。" >&2
        report_systemd_failure
      elif [[ "$state" == enabled || "$state" == enabled-runtime || "$state" == linked || "$state" == linked-runtime || "$state" == alias ]]; then
        rollback_errors=1
        rollback_block_delete=1
        echo "回滚后服务仍处于启用状态。" >&2
        report_systemd_failure
      fi
    fi
  fi
  if ((PREVIOUS_SERVICE == 0 && rollback_block_delete == 0)); then
    if ! rm -f -- "$SERVICE_FILE"; then
      rollback_errors=1
      rollback_block_delete=1
    elif ! systemctl_cmd daemon-reload; then
      rollback_errors=1
      rollback_block_delete=1
      echo "回滚期间清理 unit 后的 daemon-reload 失败。" >&2
      report_systemd_failure
    fi
  elif ((PREVIOUS_SERVICE == 0 && rollback_block_delete == 1)); then
    echo "回滚保留当前 unit，避免在 systemd 状态未确认时删除文件。" >&2
  fi
  if ((PREVIOUS_ACTIVE == 1)); then
    if ! systemctl_cmd restart "$SERVICE_NAME"; then
      rollback_errors=1
      echo "回滚期间恢复服务启动失败。" >&2
      report_systemd_failure
    elif ! state="$(systemctl_state)" || ! is_running_state "$state"; then
      rollback_errors=1
      echo "回滚后未确认旧服务已恢复运行。" >&2
      report_systemd_failure
    fi
  fi
  if ((rollback_errors == 1)); then
    echo "回滚未完全成功，请根据上述命令人工恢复。" >&2
  fi
  return "$status"
}

perform_install() {
  install -Dm755 "$TEMP_DIR/monitor.sh" "$INSTALL_SCRIPT" || return 1
  if [[ ! -e "$CONFIG_FILE" ]]; then
    install -Dm644 "$TEMP_DIR/config" "$CONFIG_FILE" || return 1
    CONFIG_CREATED=1
  fi
  install -Dm644 "$TEMP_DIR/service" "$SERVICE_FILE" || return 1
  systemctl_cmd daemon-reload || return 1
  systemctl_cmd enable "$SERVICE_NAME" || return 1
  systemctl_cmd restart "$SERVICE_NAME" || return 1
  systemctl_cmd is-active --quiet "$SERVICE_NAME" || return 1
}

dry_run() {
  echo "DRY-RUN: 源脚本     $SOURCE_SCRIPT"
  echo "DRY-RUN: 安装路径   $INSTALL_SCRIPT"
  echo "DRY-RUN: 配置路径   $CONFIG_FILE"
  echo "DRY-RUN: systemd    $SERVICE_FILE"
  echo "DRY-RUN: 不执行 apt-get、systemctl 或持久化写入。"
}

main() {
  parse_args "$@"
  check_source_tree
  if ((DRY_RUN == 1)); then
    dry_run
    return 0
  fi

  check_environment
  install_dependencies
  prepare_transaction
  stage_files
  if perform_install; then
    :
  else
    local status=$?
    rollback "$status"
    fail "服务未能通过启动验证。请查看 journalctl -u $SERVICE_NAME。"
  fi
  echo "安装完成：使用 sudo systemctl status $SERVICE_NAME 查看状态。"
}

main "$@"
