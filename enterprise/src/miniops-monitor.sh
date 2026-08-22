#!/usr/bin/env bash

export LC_ALL=C

INTERVAL_SECONDS=60
CPU_LOAD_WARN=90
MEMORY_WARN=85
DISK_WARN=80

MODE="--once"
CONFIG_FILE=""
CLI_INTERVAL=""
CLI_CPU_LOAD_WARN=""
CLI_MEMORY_WARN=""
CLI_DISK_WARN=""
HELP_REQUESTED=0
CONFIG_ERROR_REASON=""
SHUTDOWN_REQUESTED=0
PROC_ROOT="${MINIOPS_PROC_ROOT:-/proc}"

declare -A CONFIG_KEYS=()

usage() {
  cat <<'USAGE'
用法: miniops-monitor.sh [模式] [配置选项]

模式:
  --once                    采集一次，默认模式
  --loop                    持续采集
  --self-test               执行确定性的告警链路自检
  --help                    显示帮助

配置选项:
  --config PATH             读取 KEY=VALUE 配置文件
  --interval SECONDS        覆盖采样间隔
  --cpu-load-warn PERCENT   覆盖 CPU 负载阈值
  --memory-warn PERCENT     覆盖内存阈值
  --disk-warn PERCENT       覆盖磁盘阈值
USAGE
}

timestamp() {
  date '+%Y-%m-%dT%H:%M:%S%z'
}

log_event() {
  local level="$1" event="$2" details="${3:-}"
  printf 'timestamp=%s schema_version=1 level=%s event=%s' "$(timestamp)" "$level" "$event"
  if [[ -n "$details" ]]; then
    printf ' %s' "$details"
  fi
  printf '\n'
}

log_error() {
  local event="$1" reason="$2" details="${3:-}"
  local fields="reason=${reason}"
  if [[ -n "$details" ]]; then
    fields+=" ${details}"
  fi
  log_event "ERROR" "$event" "$fields"
}

set_defaults() {
  INTERVAL_SECONDS=60
  CPU_LOAD_WARN=90
  MEMORY_WARN=85
  DISK_WARN=80
  MODE="--once"
  CONFIG_FILE=""
  CLI_INTERVAL=""
  CLI_CPU_LOAD_WARN=""
  CLI_MEMORY_WARN=""
  CLI_DISK_WARN=""
  HELP_REQUESTED=0
  CONFIG_ERROR_REASON=""
  SHUTDOWN_REQUESTED=0
  PROC_ROOT="${MINIOPS_PROC_ROOT:-/proc}"
  CONFIG_KEYS=()
}

is_unsigned_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

config_error() {
  CONFIG_ERROR_REASON="$1"
  return 1
}

load_config_file() {
  local path="$1" line key value line_number=0

  if [[ ! -r "$path" ]]; then
    config_error "config_file_unreadable"
    return 1
  fi
  CONFIG_KEYS=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    if [[ "$line" != *=* ]]; then
      config_error "invalid_line_${line_number}"
      return 1
    fi

    key="${line%%=*}"
    value="${line#*=}"
    if [[ ! "$key" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
      config_error "invalid_key_${line_number}"
      return 1
    fi
    if [[ "$value" == *[[:space:]]* ]]; then
      config_error "whitespace_value_${line_number}"
      return 1
    fi

    case "$key" in
      INTERVAL_SECONDS | CPU_LOAD_WARN | MEMORY_WARN | DISK_WARN) ;;

      *)
        config_error "unknown_key_${key}"
        return 1
        ;;
    esac

    if [[ -n "${CONFIG_KEYS[$key]+present}" ]]; then
      config_error "duplicate_key_${key}"
      return 1
    fi
    CONFIG_KEYS["$key"]=1
    printf -v "$key" '%s' "$value"
  done <"$path"
}

validate_config() {
  if ! is_unsigned_integer "$INTERVAL_SECONDS" || ((10#$INTERVAL_SECONDS < 5 || 10#$INTERVAL_SECONDS > 86400)); then
    config_error "interval_out_of_range"
    return 1
  fi
  if ! is_unsigned_integer "$CPU_LOAD_WARN" || ((10#$CPU_LOAD_WARN > 100)); then
    config_error "cpu_load_warn_out_of_range"
    return 1
  fi
  if ! is_unsigned_integer "$MEMORY_WARN" || ((10#$MEMORY_WARN > 100)); then
    config_error "memory_warn_out_of_range"
    return 1
  fi
  if ! is_unsigned_integer "$DISK_WARN" || ((10#$DISK_WARN > 100)); then
    config_error "disk_warn_out_of_range"
    return 1
  fi
}

apply_cli_overrides() {
  [[ -z "$CLI_INTERVAL" ]] || INTERVAL_SECONDS="$CLI_INTERVAL"
  [[ -z "$CLI_CPU_LOAD_WARN" ]] || CPU_LOAD_WARN="$CLI_CPU_LOAD_WARN"
  [[ -z "$CLI_MEMORY_WARN" ]] || MEMORY_WARN="$CLI_MEMORY_WARN"
  [[ -z "$CLI_DISK_WARN" ]] || DISK_WARN="$CLI_DISK_WARN"
}

parse_args() {
  local mode_count=0

  while (($# > 0)); do
    case "$1" in
      --once | --loop | --self-test)
        mode_count=$((mode_count + 1))
        if ((mode_count > 1)); then
          printf 'CLI_ERROR: 只能指定一个运行模式。\n' >&2
          return 2
        fi
        MODE="$1"
        shift
        ;;
      --config)
        if (($# < 2)); then
          printf 'CLI_ERROR: --config 缺少路径。\n' >&2
          return 2
        fi
        CONFIG_FILE="$2"
        shift 2
        ;;
      --interval)
        if (($# < 2)); then
          printf 'CLI_ERROR: --interval 缺少数值。\n' >&2
          return 2
        fi
        CLI_INTERVAL="$2"
        shift 2
        ;;
      --cpu-load-warn)
        if (($# < 2)); then
          printf 'CLI_ERROR: --cpu-load-warn 缺少数值。\n' >&2
          return 2
        fi
        CLI_CPU_LOAD_WARN="$2"
        shift 2
        ;;
      --memory-warn)
        if (($# < 2)); then
          printf 'CLI_ERROR: --memory-warn 缺少数值。\n' >&2
          return 2
        fi
        CLI_MEMORY_WARN="$2"
        shift 2
        ;;
      --disk-warn)
        if (($# < 2)); then
          printf 'CLI_ERROR: --disk-warn 缺少数值。\n' >&2
          return 2
        fi
        CLI_DISK_WARN="$2"
        shift 2
        ;;
      --help | -h)
        HELP_REQUESTED=1
        shift
        ;;
      *)
        printf 'CLI_ERROR: 未知参数: %s\n' "$1" >&2
        return 2
        ;;
    esac
  done
}

cpu_load_ratio_from_values() {
  local load="$1" cores="$2"
  [[ "$load" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
  is_unsigned_integer "$cores" || return 1
  ((10#$cores > 0)) || return 1
  awk -v load_avg="$load" -v cpu_cores="$cores" 'BEGIN { printf "%.0f", (load_avg / cpu_cores) * 100 }'
}

memory_used_percent_from_values() {
  local total="$1" available="$2"
  is_unsigned_integer "$total" || return 1
  is_unsigned_integer "$available" || return 1
  ((10#$total > 0 && 10#$available <= 10#$total)) || return 1
  awk -v total="$total" -v available="$available" 'BEGIN { printf "%.0f", 100 - (available * 100 / total) }'
}

disk_used_percent_from_value() {
  local value="$1"
  is_unsigned_integer "$value" || return 1
  ((10#$value <= 100)) || return 1
  printf '%s\n' "$((10#$value))"
}

cpu_load_ratio() {
  local load cores
  [[ -r "$PROC_ROOT/loadavg" ]] || return 1
  if ! read -r load _ <"$PROC_ROOT/loadavg"; then
    return 1
  fi
  if ! cores=$(command nproc 2>/dev/null); then
    return 1
  fi
  cpu_load_ratio_from_values "$load" "$cores"
}

memory_used_percent() {
  local values total available
  if ! values=$(free | awk '$1 == "Mem:" { print $2, $7; found=1 } END { if (!found) exit 1 }'); then
    return 1
  fi
  read -r total available <<<"$values" || return 1
  memory_used_percent_from_values "$total" "$available"
}

disk_used_percent() {
  local value
  if ! value=$(df -P / | awk 'NR > 1 { gsub(/%/, "", $5); print $5; found=1; exit } END { if (!found) exit 1 }'); then
    return 1
  fi
  disk_used_percent_from_value "$value"
}

check_threshold() {
  local resource="$1" value="$2" threshold="$3"
  is_unsigned_integer "$value" || return 1
  is_unsigned_integer "$threshold" || return 1
  if ((10#$value >= 10#$threshold)); then
    log_event "ALERT" "threshold_exceeded" "resource=${resource} value=${value} threshold=${threshold}"
  fi
  return 0
}

sample_resources() {
  local cpu_load memory_used disk_used

  if ! cpu_load=$(cpu_load_ratio); then
    log_error "collection_failed" "cpu_load_ratio_unavailable" "resource=cpu_load_ratio"
    return 1
  fi
  if ! memory_used=$(memory_used_percent); then
    log_error "collection_failed" "memory_unavailable" "resource=memory_used"
    return 1
  fi
  if ! disk_used=$(disk_used_percent); then
    log_error "collection_failed" "disk_unavailable" "resource=disk_used"
    return 1
  fi

  log_event "INFO" "resource_sample" "cpu_load_ratio=${cpu_load} memory_used=${memory_used} disk_used=${disk_used}"
  check_threshold "cpu_load_ratio" "$cpu_load" "$CPU_LOAD_WARN" || return 1
  check_threshold "memory_used" "$memory_used" "$MEMORY_WARN" || return 1
  check_threshold "disk_used" "$disk_used" "$DISK_WARN" || return 1
}

self_test() {
  log_event "INFO" "startup" "mode=self_test"
  check_threshold "demo" 100 0 || return 1
  log_event "INFO" "shutdown" "mode=self_test"
}

request_shutdown() {
  SHUTDOWN_REQUESTED=1
}

loop_forever() {
  trap request_shutdown TERM INT
  log_event "INFO" "startup" "mode=loop"

  while ((SHUTDOWN_REQUESTED == 0)); do
    if ! sample_resources; then
      log_error "monitor_failed" "sample_failed"
      return 1
    fi
    if ! sleep "$INTERVAL_SECONDS"; then
      if ((SHUTDOWN_REQUESTED == 1)); then
        break
      fi
      log_error "monitor_failed" "sleep_failed"
      return 1
    fi
  done

  log_event "INFO" "shutdown" "mode=loop reason=signal"
  trap - TERM INT
}

main() {
  set_defaults

  if ! parse_args "$@"; then
    usage >&2
    return 2
  fi
  if ((HELP_REQUESTED == 1)); then
    usage
    return 0
  fi

  if [[ -n "$CONFIG_FILE" ]] && ! load_config_file "$CONFIG_FILE"; then
    log_error "config_invalid" "${CONFIG_ERROR_REASON:-invalid_config}"
    return 1
  fi
  apply_cli_overrides
  if ! validate_config; then
    log_error "config_invalid" "${CONFIG_ERROR_REASON:-invalid_config}"
    return 1
  fi

  case "$MODE" in
    --once)
      log_event "INFO" "startup" "mode=once"
      sample_resources || return 1
      log_event "INFO" "shutdown" "mode=once"
      ;;
    --loop)
      loop_forever
      ;;
    --self-test)
      self_test
      ;;
    *)
      printf 'CLI_ERROR: 未知运行模式。\n' >&2
      return 2
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -Eeuo pipefail
  main "$@"
fi
