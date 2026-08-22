#!/usr/bin/env bash

set -Eeuo pipefail

SERVICE_NAME="miniops-monitor-enterprise.service"
BASE_INSTALL_DIR="/usr/local/lib/miniops-monitor-enterprise"
BASE_SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
BASE_CONFIG_FILE="/etc/default/miniops-monitor-enterprise"
INSTALL_DIR="$BASE_INSTALL_DIR"
SERVICE_FILE="$BASE_SERVICE_FILE"
CONFIG_FILE="$BASE_CONFIG_FILE"
TEST_MODE="${MINIOPS_TEST_MODE:-0}"
TEST_ROOT="${MINIOPS_TEST_ROOT:-}"
SYSTEMCTL_BIN="${MINIOPS_SYSTEMCTL:-systemctl}"
DRY_RUN=0
PURGE_CONFIG=0

if [[ -n "$TEST_ROOT" ]]; then
  INSTALL_DIR="$TEST_ROOT$BASE_INSTALL_DIR"
  SERVICE_FILE="$TEST_ROOT$BASE_SERVICE_FILE"
  CONFIG_FILE="$TEST_ROOT$BASE_CONFIG_FILE"
fi

usage() {
  cat <<'USAGE'
用法: uninstall.sh [--dry-run] [--purge-config]

--dry-run       显示清理动作，不修改系统
--purge-config  同时删除 /etc/default/miniops-monitor-enterprise
USAGE
}

fail() {
  echo "卸载失败: $*" >&2
  exit 1
}

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
    echo "停止服务失败，保留安装文件。" >&2
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

disable_and_verify() {
  local state

  if ! state="$(systemctl_enabled_state)"; then
    report_systemd_failure
    return 1
  fi
  case "$state" in
    enabled|enabled-runtime|linked|linked-runtime|alias)
      if ! systemctl_cmd disable "$SERVICE_NAME"; then
        echo "禁用服务失败，保留安装文件。" >&2
        report_systemd_failure
        return 1
      fi
      if ! state="$(systemctl_enabled_state)"; then
        report_systemd_failure
        return 1
      fi
      case "$state" in
        enabled|enabled-runtime|linked|linked-runtime|alias)
          echo "disable 已返回，但服务仍处于启用状态。" >&2
          report_systemd_failure
          return 1
          ;;
      esac
      ;;
    disabled|static|indirect|masked|masked-runtime|generated|transient|bad-setting|not-found|unknown)
      ;;
    *)
      echo "无法确认服务启用状态: $state" >&2
      report_systemd_failure
      return 1
      ;;
  esac
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --purge-config)
        PURGE_CONFIG=1
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

main() {
  parse_args "$@"
  if ((DRY_RUN == 1)); then
    echo "DRY-RUN: 停止并禁用 $SERVICE_NAME"
    echo "DRY-RUN: 删除 $SERVICE_FILE"
    echo "DRY-RUN: 删除 $INSTALL_DIR"
    if ((PURGE_CONFIG == 1)); then
      echo "DRY-RUN: 删除 $CONFIG_FILE"
    else
      echo "DRY-RUN: 保留 $CONFIG_FILE"
    fi
    return 0
  fi

  if ((TEST_MODE == 1)); then
    [[ -n "$TEST_ROOT" && "$TEST_ROOT" == /tmp/* ]] || fail "测试模式必须使用 /tmp 下的临时根目录。"
    [[ -x "$SYSTEMCTL_BIN" ]] || fail "测试模式未找到 mock systemctl: $SYSTEMCTL_BIN"
  else
    ((EUID == 0)) || fail "请使用 sudo enterprise/uninstall.sh 执行卸载。"
    command -v "$SYSTEMCTL_BIN" >/dev/null 2>&1 || fail "未找到 systemctl。"
  fi
  [[ "$INSTALL_DIR" == "$TEST_ROOT$BASE_INSTALL_DIR" ]] || fail "安装目录保护检查失败。"

  local state
  if ! state="$(systemctl_state)"; then
    fail "无法查询服务状态，未删除任何文件。"
  fi
  if ! is_stopped_state "$state" && ! stop_and_verify; then
    fail "服务未能确认停止，未删除任何文件。"
  fi
  if ! disable_and_verify; then
    fail "服务未能确认禁用，未删除任何文件。"
  fi
  if ! state="$(systemctl_state)" || ! is_stopped_state "$state"; then
    report_systemd_failure
    fail "删除前再次确认服务状态失败，未删除任何文件。"
  fi
  if ! rm -f -- "$SERVICE_FILE"; then
    fail "删除 unit 失败，保留其余文件以便人工恢复。"
  fi
  if ! rm -rf -- "$INSTALL_DIR"; then
    fail "删除安装目录失败，请根据当前状态人工恢复。"
  fi
  if ((PURGE_CONFIG == 1)); then
    if ! rm -f -- "$CONFIG_FILE"; then
      fail "删除配置失败，请根据当前状态人工恢复。"
    fi
  fi
  if ! systemctl_cmd daemon-reload; then
    report_systemd_failure
    fail "文件已删除，但 daemon-reload 失败；请手动执行 daemon-reload。"
  fi
  echo "卸载完成：服务、unit 和安装目录已清理。"
}

main "$@"
