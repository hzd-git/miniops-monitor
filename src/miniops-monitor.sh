#!/usr/bin/env bash
# MiniOps Monitor: Ubuntu 22.04 单机资源监控教学脚本。
# 本项目参考 nuver-labs/vps-audit 的资源检查思路后以极简方式重写。
# Copyright (c) 2024 Israel Abebe Kokiso. Licensed under the MIT License.

set -euo pipefail

# 固定基础命令的英文输出，避免中文系统中 free 的内存行名称变化。
export LC_ALL=C

# 固定默认值让初学者无需编辑配置即可完成部署。
INTERVAL_SECONDS=60
CPU_LOAD_WARN=90
MEMORY_WARN=85
DISK_WARN=80

usage() {
  echo "用法: $0 [--once|--loop|--self-test]"
}

timestamp() {
  date '+%Y-%m-%dT%H:%M:%S%z'
}

# 负载除以 CPU 核数，得到适合不同规格主机比较的负载比。
cpu_load_ratio() {
  local load cores
  read -r load _ < /proc/loadavg
  cores=$(nproc)
  awk -v load="$load" -v cores="$cores" 'BEGIN { printf "%.0f", (load / cores) * 100 }'
}

# MemAvailable 更接近系统真正可继续分配的内存，而非简单的已使用列。
memory_used_percent() {
  free | awk '/^Mem:/ { printf "%.0f", 100 - ($7 * 100 / $2) }'
}

disk_used_percent() {
  df -P / | awk 'NR == 2 { gsub(/%/, "", $5); print $5 }'
}

emit() {
  local level="$1" event="$2" details="$3"
  printf '%s level=%s event=%s %s\n' "$(timestamp)" "$level" "$event" "$details"
}

check_threshold() {
  local resource="$1" value="$2" threshold="$3"

  if (( value >= threshold )); then
    emit "ALERT" "threshold_exceeded" "resource=${resource} value=${value} threshold=${threshold}"
  fi
}

sample_resources() {
  local cpu_load memory_used disk_used
  cpu_load=$(cpu_load_ratio)
  memory_used=$(memory_used_percent)
  disk_used=$(disk_used_percent)

  emit "INFO" "resource_sample" "cpu_load_ratio=${cpu_load} memory_used=${memory_used} disk_used=${disk_used}"
  check_threshold "cpu_load_ratio" "$cpu_load" "$CPU_LOAD_WARN"
  check_threshold "memory_used" "$memory_used" "$MEMORY_WARN"
  check_threshold "disk_used" "$disk_used" "$DISK_WARN"
}

self_test() {
  # 自检不施加真实负载，但会走真实阈值判断链路。
  check_threshold "demo" 100 0
}

loop_forever() {
  while true; do
    sample_resources
    sleep "$INTERVAL_SECONDS"
  done
}

case "${1:---once}" in
  --once)
    sample_resources
    ;;
  --loop)
    loop_forever
    ;;
  --self-test)
    self_test
    ;;
  --help|-h)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
