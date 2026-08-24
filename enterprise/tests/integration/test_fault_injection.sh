#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(CDPATH="" cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(CDPATH="" cd -- "$TEST_DIR/../.." && pwd)"
MONITOR_SCRIPT="$PROJECT_DIR/src/miniops-monitor.sh"
INSTALL_SCRIPT="$PROJECT_DIR/install.sh"
TMP_DIR="$(mktemp -d)"
ORIGINAL_PATH="$PATH"
FAILURES=0

cleanup() {
  rm -rf -- "$TMP_DIR"
}
trap cleanup EXIT

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1" >&2
  FAILURES=$((FAILURES + 1))
}

assert_contains() {
  local haystack="$1" needle="$2" name="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name: missing=$needle output=$haystack"
  fi
}

assert_exists() {
  if [[ -e "$1" ]]; then
    pass "$2"
  else
    fail "$2: missing=$1"
  fi
}

assert_not_exists() {
  if [[ ! -e "$1" ]]; then
    pass "$2"
  else
    fail "$2: unexpected=$1"
  fi
}

create_monitor_fixtures() {
  local root="$1"
  local bin="$root/bin" proc="$root/proc"
  mkdir -p "$bin" "$proc"
  printf '%s\n' '0.50 0.25 0.10 1/10 1234' >"$proc/loadavg"
  printf '%s\n' 'Mem: 100 75 0 0 0 25' >"$root/free.out"
  printf '%s\n' 'Filesystem 1024-blocks Used Available Capacity Mounted on' '/dev/test 100 80 20 80% /' >"$root/df.out"

  cat >"$bin/nproc" <<'SCRIPT'
#!/usr/bin/env bash
printf '1\n'
SCRIPT
  cat >"$bin/free" <<'SCRIPT'
#!/usr/bin/env bash
cat "$MINIOPS_FIXTURE_ROOT/free.out"
SCRIPT
  cat >"$bin/df" <<'SCRIPT'
#!/usr/bin/env bash
cat "$MINIOPS_FIXTURE_ROOT/df.out"
SCRIPT
  chmod +x "$bin/nproc" "$bin/free" "$bin/df"
}

create_systemctl_mock() {
  local path="$1"
  cat >"$path" <<'SCRIPT'
#!/usr/bin/env bash
case "${1:-}" in
  show)
    if [[ "${FAKE_SYSTEMCTL_FAIL_SHOW:-0}" == "1" || "${FAKE_SYSTEMCTL_FAIL_QUERY:-0}" == "1" ]]; then
      printf 'Failed to connect to bus: mock failure\n'
      exit 1
    fi
    if [[ "${FAKE_SYSTEMCTL_NOT_FOUND:-0}" == "1" || "${FAKE_SYSTEMCTL_SHOW_NOT_FOUND:-0}" == "1" || "${FAKE_SYSTEMCTL_LEGACY_NOT_FOUND:-0}" == "1" ]]; then
      printf 'not-found\n'
      exit 0
    fi
    if [[ "${FAKE_SYSTEMCTL_UNIT_EXISTS:-0}" == "1" || -e "${MINIOPS_TEST_ROOT:-}/etc/systemd/system/miniops-monitor-enterprise.service" || -e "${FAKE_SYSTEMCTL_STATE}.active" || -e "${FAKE_SYSTEMCTL_STATE}.enabled" ]]; then
      printf 'loaded\n'
    else
      printf 'not-found\n'
    fi
    exit 0
    ;;
  is-active)
    if [[ "${FAKE_SYSTEMCTL_FAIL_QUERY:-0}" == "1" ]]; then
      printf 'Failed to connect to bus: mock failure\n'
      exit 1
    fi
    if [[ "${FAKE_SYSTEMCTL_NOT_FOUND:-0}" == "1" ]]; then
      state=unknown
      status=4
    elif [[ -e "${FAKE_SYSTEMCTL_STATE}.active" ]]; then
      state=active
      status=0
    else
      state=inactive
      status=3
    fi
    if [[ "${2:-}" != "--quiet" ]]; then
      printf '%s\n' "$state"
    fi
    exit "$status"
    ;;
  is-enabled)
    if [[ "${FAKE_SYSTEMCTL_FAIL_QUERY:-0}" == "1" ]]; then
      printf 'Failed to connect to bus: mock failure\n'
      exit 1
    fi
    if [[ "${FAKE_SYSTEMCTL_NOT_FOUND:-0}" == "1" ]]; then
      state=not-found
      status=1
    elif [[ "${FAKE_SYSTEMCTL_LEGACY_NOT_FOUND:-0}" == "1" ]]; then
      printf 'Failed to get unit file state for miniops-monitor-enterprise.service:\nNo such file or directory\n'
      exit 1
    elif [[ "${FAKE_SYSTEMCTL_FAIL_ENABLED_QUERY:-0}" == "1" ]]; then
      printf 'Failed to connect to bus: mock enabled query failure\n'
      exit 1
    elif [[ -e "${FAKE_SYSTEMCTL_STATE}.enabled" ]]; then
      state=enabled
      status=0
    else
      state=disabled
      status=1
    fi
    if [[ "${2:-}" != "--quiet" ]]; then
      printf '%s\n' "$state"
    fi
    exit "$status"
    ;;
  restart)
    if [[ "${FAKE_SYSTEMCTL_FAIL_RESTART:-0}" == "1" ]]; then
      touch "${FAKE_SYSTEMCTL_STATE}.active"
      exit 1
    fi
    touch "${FAKE_SYSTEMCTL_STATE}.active"
    exit 0
    ;;
  enable)
    if [[ "${FAKE_SYSTEMCTL_FAIL_ENABLE:-0}" == "1" ]]; then
      exit 1
    fi
    touch "${FAKE_SYSTEMCTL_STATE}.enabled"
    exit 0
    ;;
  disable)
    if [[ "${FAKE_SYSTEMCTL_FAIL_DISABLE:-0}" == "1" ]]; then
      exit 1
    fi
    rm -f -- "${FAKE_SYSTEMCTL_STATE}.enabled"
    exit 0
    ;;
  stop)
    if [[ "${FAKE_SYSTEMCTL_FAIL_STOP:-0}" == "1" ]]; then
      exit 1
    fi
    rm -f -- "${FAKE_SYSTEMCTL_STATE}.active"
    exit 0
    ;;
  daemon-reload)
    if [[ "${FAKE_SYSTEMCTL_FAIL_DAEMON_RELOAD:-0}" == "1" ]]; then
      exit 1
    fi
    if [[ "${FAKE_SYSTEMCTL_FAIL_DAEMON_RELOAD_ONCE:-0}" == "1" && ! -e "${FAKE_SYSTEMCTL_STATE}.daemon-reload-failed" ]]; then
      touch "${FAKE_SYSTEMCTL_STATE}.daemon-reload-failed"
      exit 1
    fi
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
SCRIPT
  chmod +x "$path"
}

test_monitor_success() {
  local root="$TMP_DIR/monitor-success" output status
  create_monitor_fixtures "$root"
  output="$(MINIOPS_FIXTURE_ROOT="$root" MINIOPS_PROC_ROOT="$root/proc" PATH="$root/bin:$ORIGINAL_PATH" bash "$MONITOR_SCRIPT" --once 2>&1)"
  status=$?
  if ((status == 0)); then
    pass "normal fixture exits successfully"
  else
    fail "normal fixture exits successfully: status=$status"
  fi
  assert_contains "$output" "event=resource_sample" "normal sample event"
  assert_contains "$output" "cpu_load_ratio=50 memory_used=75 disk_used=80" "normal sample values"
}

test_missing_proc_failure() {
  local root="$TMP_DIR/missing-proc" output status
  create_monitor_fixtures "$root"
  rm -f -- "$root/proc/loadavg"
  output="$(MINIOPS_FIXTURE_ROOT="$root" MINIOPS_PROC_ROOT="$root/proc" PATH="$root/bin:$ORIGINAL_PATH" bash "$MONITOR_SCRIPT" --once 2>&1)"
  status=$?
  if ((status == 1)); then
    pass "missing proc fixture returns runtime failure"
  else
    fail "missing proc fixture returns runtime failure: status=$status"
  fi
  assert_contains "$output" "event=collection_failed" "missing proc error event"
  assert_contains "$output" "resource=cpu_load_ratio" "missing proc resource"
}

test_command_failure() {
  local root="$TMP_DIR/command-failure" output status
  create_monitor_fixtures "$root"
  cat >"$root/bin/free" <<'SCRIPT'
#!/usr/bin/env bash
exit 127
SCRIPT
  chmod +x "$root/bin/free"
  output="$(MINIOPS_FIXTURE_ROOT="$root" MINIOPS_PROC_ROOT="$root/proc" PATH="$root/bin:$ORIGINAL_PATH" bash "$MONITOR_SCRIPT" --once 2>&1)"
  status=$?
  if ((status == 1)); then
    pass "failed free command returns runtime failure"
  else
    fail "failed free command returns runtime failure: status=$status"
  fi
  assert_contains "$output" "event=collection_failed" "failed command error event"
  assert_contains "$output" "resource=memory_used" "failed command resource"
}

test_install_success() {
  local root="$TMP_DIR/install-success" mock="$TMP_DIR/systemctl-success" state="$TMP_DIR/systemctl-success-state" output status
  create_systemctl_mock "$mock"
  output="$(MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$INSTALL_SCRIPT" 2>&1)"
  status=$?
  if ((status == 0)); then
    pass "staged installer succeeds"
  else
    fail "staged installer succeeds: status=$status output=$output"
  fi
  assert_exists "$root/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh" "staged monitor installed"
  assert_exists "$root/etc/systemd/system/miniops-monitor-enterprise.service" "staged unit installed"
  assert_exists "$root/etc/default/miniops-monitor-enterprise" "staged config installed"
}

test_install_systemd_249_missing_unit() {
  local root="$TMP_DIR/install-systemd-249-missing" mock="$TMP_DIR/systemctl-systemd-249-missing" state="$TMP_DIR/systemctl-systemd-249-missing-state" output status
  create_systemctl_mock "$mock"
  output="$(FAKE_SYSTEMCTL_SHOW_NOT_FOUND=1 FAKE_SYSTEMCTL_LEGACY_NOT_FOUND=1 MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$INSTALL_SCRIPT" 2>&1)"
  status=$?
  if ((status == 0)); then
    pass "systemd 249 missing unit allows first install"
  else
    fail "systemd 249 missing unit allows first install: status=$status output=$output"
  fi
  assert_exists "$root/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh" "systemd 249 install creates monitor"
  assert_exists "$root/etc/systemd/system/miniops-monitor-enterprise.service" "systemd 249 install creates unit"
}

test_install_systemd_255_missing_unit() {
  local root="$TMP_DIR/install-systemd-255-missing" mock="$TMP_DIR/systemctl-systemd-255-missing" state="$TMP_DIR/systemctl-systemd-255-missing-state" output status
  create_systemctl_mock "$mock"
  output="$(FAKE_SYSTEMCTL_SHOW_NOT_FOUND=1 MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$INSTALL_SCRIPT" 2>&1)"
  status=$?
  if ((status == 0)); then
    pass "systemd 255 missing unit allows first install"
  else
    fail "systemd 255 missing unit allows first install: status=$status output=$output"
  fi
  assert_exists "$root/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh" "systemd 255 install creates monitor"
  assert_exists "$root/etc/systemd/system/miniops-monitor-enterprise.service" "systemd 255 install creates unit"
}

test_install_show_failure_preserves() {
  local root="$TMP_DIR/install-show-failure" mock="$TMP_DIR/systemctl-show-failure" state="$TMP_DIR/systemctl-show-failure-state" output status
  create_systemctl_mock "$mock"
  output="$(FAKE_SYSTEMCTL_FAIL_SHOW=1 MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$INSTALL_SCRIPT" 2>&1)"
  status=$?
  if ((status == 1)); then
    pass "installer show failure returns failure"
  else
    fail "installer show failure returns failure: status=$status output=$output"
  fi
  assert_contains "$output" "show_status=" "installer show failure diagnosis"
  assert_not_exists "$root/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh" "show failure leaves monitor absent"
  assert_not_exists "$root/etc/systemd/system/miniops-monitor-enterprise.service" "show failure leaves unit absent"
}

test_install_enabled_query_failure_preserves() {
  local root="$TMP_DIR/install-enabled-query-failure" mock="$TMP_DIR/systemctl-enabled-query-failure" state="$TMP_DIR/systemctl-enabled-query-failure-state" output status
  create_systemctl_mock "$mock"
  create_staged_install "$root"
  output="$(FAKE_SYSTEMCTL_FAIL_ENABLED_QUERY=1 MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$INSTALL_SCRIPT" 2>&1)"
  status=$?
  if ((status == 1)); then
    pass "installer enabled query failure returns failure"
  else
    fail "installer enabled query failure returns failure: status=$status output=$output"
  fi
  assert_contains "$output" "无法查询服务启用状态" "installer enabled query failure diagnosis"
  assert_exists "$root/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh" "enabled query failure preserves monitor"
  assert_exists "$root/etc/systemd/system/miniops-monitor-enterprise.service" "enabled query failure preserves unit"
  assert_exists "$root/etc/default/miniops-monitor-enterprise" "enabled query failure preserves config"
}

test_install_failure_cleanup() {
  local root="$TMP_DIR/install-failure" mock="$TMP_DIR/systemctl-failure" state="$TMP_DIR/systemctl-failure-state" output status
  create_systemctl_mock "$mock"
  output="$(FAKE_SYSTEMCTL_FAIL_RESTART=1 MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$INSTALL_SCRIPT" 2>&1)"
  status=$?
  if ((status == 1)); then
    pass "failed staged installer returns failure"
  else
    fail "failed staged installer returns failure: status=$status output=$output"
  fi
  assert_not_exists "$root/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh" "failed install removes monitor"
  assert_not_exists "$root/etc/systemd/system/miniops-monitor-enterprise.service" "failed install removes unit"
  assert_not_exists "$root/etc/default/miniops-monitor-enterprise" "failed install removes new config"
}

test_install_failure_stop_preserves() {
  local root="$TMP_DIR/install-stop-failure" mock="$TMP_DIR/systemctl-stop-failure" state="$TMP_DIR/systemctl-stop-failure-state" output status
  create_systemctl_mock "$mock"
  output="$(FAKE_SYSTEMCTL_FAIL_RESTART=1 FAKE_SYSTEMCTL_FAIL_STOP=1 MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$INSTALL_SCRIPT" 2>&1)"
  status=$?
  if ((status == 1)); then
    pass "installer stop failure returns failure"
  else
    fail "installer stop failure returns failure: status=$status output=$output"
  fi
  assert_contains "$output" "无法确认服务已停止" "installer stop failure diagnosis"
  assert_exists "$root/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh" "stop failure preserves monitor"
  assert_exists "$root/etc/systemd/system/miniops-monitor-enterprise.service" "stop failure preserves unit"
  assert_exists "$root/etc/default/miniops-monitor-enterprise" "stop failure preserves config"
}

test_install_failure_disable_preserves() {
  local root="$TMP_DIR/install-disable-failure" mock="$TMP_DIR/systemctl-disable-failure" state="$TMP_DIR/systemctl-disable-failure-state" output status
  create_systemctl_mock "$mock"
  output="$(FAKE_SYSTEMCTL_FAIL_RESTART=1 FAKE_SYSTEMCTL_FAIL_DISABLE=1 MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$INSTALL_SCRIPT" 2>&1)"
  status=$?
  if ((status == 1)); then
    pass "installer disable failure returns failure"
  else
    fail "installer disable failure returns failure: status=$status output=$output"
  fi
  assert_contains "$output" "回滚前禁用服务失败" "installer disable failure diagnosis"
  assert_exists "$root/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh" "installer disable failure preserves monitor"
  assert_exists "$root/etc/systemd/system/miniops-monitor-enterprise.service" "installer disable failure preserves unit"
  assert_exists "$root/etc/default/miniops-monitor-enterprise" "installer disable failure preserves config"
}

test_install_failure_daemon_reload_preserves() {
  local root="$TMP_DIR/install-daemon-reload-failure" mock="$TMP_DIR/systemctl-daemon-reload-failure" state="$TMP_DIR/systemctl-daemon-reload-failure-state" output status
  create_systemctl_mock "$mock"
  output="$(FAKE_SYSTEMCTL_FAIL_DAEMON_RELOAD=1 MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$INSTALL_SCRIPT" 2>&1)"
  status=$?
  if ((status == 1)); then
    pass "installer daemon-reload failure returns failure"
  else
    fail "installer daemon-reload failure returns failure: status=$status output=$output"
  fi
  assert_contains "$output" "回滚前 daemon-reload 失败" "installer daemon-reload failure diagnosis"
  assert_exists "$root/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh" "daemon-reload failure preserves monitor"
  assert_exists "$root/etc/systemd/system/miniops-monitor-enterprise.service" "daemon-reload failure preserves unit"
  assert_exists "$root/etc/default/miniops-monitor-enterprise" "daemon-reload failure preserves config"
}

create_staged_install() {
  local root="$1"
  mkdir -p \
    "$root/usr/local/lib/miniops-monitor-enterprise" \
    "$root/etc/systemd/system" \
    "$root/etc/default"
  touch \
    "$root/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh" \
    "$root/etc/systemd/system/miniops-monitor-enterprise.service" \
    "$root/etc/default/miniops-monitor-enterprise"
}

test_uninstall_success() {
  local root="$TMP_DIR/uninstall-success" mock="$TMP_DIR/systemctl-uninstall-success" state="$TMP_DIR/systemctl-uninstall-success-state" output status
  create_systemctl_mock "$mock"
  create_staged_install "$root"
  touch "$state.active" "$state.enabled"
  output="$(MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$PROJECT_DIR/uninstall.sh" --purge-config 2>&1)"
  status=$?
  if ((status == 0)); then
    pass "staged uninstaller succeeds"
  else
    fail "staged uninstaller succeeds: status=$status output=$output"
  fi
  assert_not_exists "$root/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh" "uninstaller removes monitor"
  assert_not_exists "$root/etc/systemd/system/miniops-monitor-enterprise.service" "uninstaller removes unit"
  assert_not_exists "$root/etc/default/miniops-monitor-enterprise" "uninstaller purges config"
}

test_uninstall_service_absent() {
  local root="$TMP_DIR/uninstall-absent" mock="$TMP_DIR/systemctl-uninstall-absent" state="$TMP_DIR/systemctl-uninstall-absent-state" output status
  create_systemctl_mock "$mock"
  output="$(FAKE_SYSTEMCTL_NOT_FOUND=1 MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$PROJECT_DIR/uninstall.sh" 2>&1)"
  status=$?
  if ((status == 0)); then
    pass "absent service uninstall is idempotent"
  else
    fail "absent service uninstall is idempotent: status=$status output=$output"
  fi
}

test_uninstall_service_absent_systemd_249() {
  local root="${TMP_DIR}/uninstall-absent-systemd-249" mock="${TMP_DIR}/systemctl-uninstall-absent-systemd-249" state="${TMP_DIR}/systemctl-uninstall-absent-systemd-249-state" output status
  create_systemctl_mock "$mock"
  output="$(FAKE_SYSTEMCTL_SHOW_NOT_FOUND=1 FAKE_SYSTEMCTL_LEGACY_NOT_FOUND=1 MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$PROJECT_DIR/uninstall.sh" 2>&1)"
  status=$?
  if ((status == 0)); then
    pass "systemd 249 absent service uninstall is idempotent"
  else
    fail "systemd 249 absent service uninstall is idempotent: status=$status output=$output"
  fi
}

test_uninstall_disabled_service() {
  local root="${TMP_DIR}/uninstall-disabled" mock="${TMP_DIR}/systemctl-uninstall-disabled" state="${TMP_DIR}/systemctl-uninstall-disabled-state" output status
  create_systemctl_mock "$mock"
  create_staged_install "$root"
  output="$(MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$PROJECT_DIR/uninstall.sh" 2>&1)"
  status=$?
  if ((status == 0)); then
    pass "disabled service uninstall succeeds"
  else
    fail "disabled service uninstall succeeds: status=$status output=$output"
  fi
  assert_not_exists "$root/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh" "disabled uninstall removes monitor"
  assert_not_exists "$root/etc/systemd/system/miniops-monitor-enterprise.service" "disabled uninstall removes unit"
  assert_exists "$root/etc/default/miniops-monitor-enterprise" "disabled uninstall retains config"
}

test_uninstall_show_failure_preserves() {
  local root="${TMP_DIR}/uninstall-show-failure" mock="${TMP_DIR}/systemctl-uninstall-show-failure" state="${TMP_DIR}/systemctl-uninstall-show-failure-state" output status
  create_systemctl_mock "$mock"
  create_staged_install "$root"
  output="$(FAKE_SYSTEMCTL_FAIL_SHOW=1 MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$PROJECT_DIR/uninstall.sh" --purge-config 2>&1)"
  status=$?
  if ((status == 1)); then
    pass "uninstaller show failure returns failure"
  else
    fail "uninstaller show failure returns failure: status=$status output=$output"
  fi
  assert_exists "$root/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh" "show failure preserves monitor"
  assert_exists "$root/etc/systemd/system/miniops-monitor-enterprise.service" "show failure preserves unit"
  assert_exists "$root/etc/default/miniops-monitor-enterprise" "show failure preserves config"
}

test_uninstall_enabled_query_failure() {
  local root="${TMP_DIR}/uninstall-enabled-query-failure" mock="${TMP_DIR}/systemctl-uninstall-enabled-query-failure" state="${TMP_DIR}/systemctl-uninstall-enabled-query-failure-state" output status
  create_systemctl_mock "$mock"
  create_staged_install "$root"
  output="$(FAKE_SYSTEMCTL_FAIL_ENABLED_QUERY=1 MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$PROJECT_DIR/uninstall.sh" --purge-config 2>&1)"
  status=$?
  if ((status == 1)); then
    pass "uninstaller enabled query failure returns failure"
  else
    fail "uninstaller enabled query failure returns failure: status=$status output=$output"
  fi
  assert_exists "$root/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh" "enabled query failure preserves monitor"
  assert_exists "$root/etc/systemd/system/miniops-monitor-enterprise.service" "enabled query failure preserves unit"
  assert_exists "$root/etc/default/miniops-monitor-enterprise" "enabled query failure preserves config"
}

test_uninstall_stop_failure() {
  local root="$TMP_DIR/uninstall-stop-failure" mock="$TMP_DIR/systemctl-uninstall-stop-failure" state="$TMP_DIR/systemctl-uninstall-stop-failure-state" output status
  create_systemctl_mock "$mock"
  create_staged_install "$root"
  touch "$state.active" "$state.enabled"
  output="$(FAKE_SYSTEMCTL_FAIL_STOP=1 MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$PROJECT_DIR/uninstall.sh" --purge-config 2>&1)"
  status=$?
  if ((status == 1)); then
    pass "uninstaller stop failure returns failure"
  else
    fail "uninstaller stop failure returns failure: status=$status output=$output"
  fi
  assert_exists "$root/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh" "stop failure preserves monitor"
  assert_exists "$root/etc/systemd/system/miniops-monitor-enterprise.service" "stop failure preserves unit"
  assert_exists "$root/etc/default/miniops-monitor-enterprise" "stop failure preserves config"
}

test_uninstall_disable_failure() {
  local root="$TMP_DIR/uninstall-disable-failure" mock="$TMP_DIR/systemctl-uninstall-disable-failure" state="$TMP_DIR/systemctl-uninstall-disable-failure-state" output status
  create_systemctl_mock "$mock"
  create_staged_install "$root"
  touch "$state.enabled"
  output="$(FAKE_SYSTEMCTL_FAIL_DISABLE=1 MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$PROJECT_DIR/uninstall.sh" --purge-config 2>&1)"
  status=$?
  if ((status == 1)); then
    pass "uninstaller disable failure returns failure"
  else
    fail "uninstaller disable failure returns failure: status=$status output=$output"
  fi
  assert_exists "$root/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh" "disable failure preserves monitor"
  assert_exists "$root/etc/systemd/system/miniops-monitor-enterprise.service" "disable failure preserves unit"
  assert_exists "$root/etc/default/miniops-monitor-enterprise" "disable failure preserves config"
}

test_uninstall_query_failure() {
  local root="$TMP_DIR/uninstall-query-failure" mock="$TMP_DIR/systemctl-uninstall-query-failure" state="$TMP_DIR/systemctl-uninstall-query-failure-state" output status
  create_systemctl_mock "$mock"
  create_staged_install "$root"
  output="$(FAKE_SYSTEMCTL_FAIL_QUERY=1 MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$PROJECT_DIR/uninstall.sh" --purge-config 2>&1)"
  status=$?
  if ((status == 1)); then
    pass "uninstaller query failure returns failure"
  else
    fail "uninstaller query failure returns failure: status=$status output=$output"
  fi
  assert_exists "$root/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh" "query failure preserves monitor"
  assert_exists "$root/etc/systemd/system/miniops-monitor-enterprise.service" "query failure preserves unit"
  assert_exists "$root/etc/default/miniops-monitor-enterprise" "query failure preserves config"
}

test_uninstall_daemon_reload_failure() {
  local root="$TMP_DIR/uninstall-daemon-reload-failure" mock="$TMP_DIR/systemctl-uninstall-daemon-reload-failure" state="$TMP_DIR/systemctl-uninstall-daemon-reload-failure-state" output status
  create_systemctl_mock "$mock"
  create_staged_install "$root"
  touch "$state.active" "$state.enabled"
  output="$(FAKE_SYSTEMCTL_FAIL_DAEMON_RELOAD_ONCE=1 MINIOPS_TEST_MODE=1 MINIOPS_TEST_ROOT="$root" MINIOPS_SYSTEMCTL="$mock" FAKE_SYSTEMCTL_STATE="$state" bash "$PROJECT_DIR/uninstall.sh" --purge-config 2>&1)"
  status=$?
  if ((status == 1)); then
    pass "uninstaller daemon-reload failure returns failure"
  else
    fail "uninstaller daemon-reload failure returns failure: status=$status output=$output"
  fi
  assert_contains "$output" "daemon-reload" "uninstaller daemon-reload failure diagnosis"
  assert_exists "$root/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh" "daemon-reload failure restores monitor"
  assert_exists "$root/etc/systemd/system/miniops-monitor-enterprise.service" "daemon-reload failure restores unit"
  assert_exists "$root/etc/default/miniops-monitor-enterprise" "daemon-reload failure restores config"
  assert_exists "$state.enabled" "daemon-reload failure restores enabled state"
  assert_exists "$state.active" "daemon-reload failure restores active state"
}

test_monitor_success
test_missing_proc_failure
test_command_failure
test_install_success
test_install_systemd_249_missing_unit
test_install_systemd_255_missing_unit
test_install_show_failure_preserves
test_install_enabled_query_failure_preserves
test_install_failure_cleanup
test_install_failure_stop_preserves
test_install_failure_disable_preserves
test_install_failure_daemon_reload_preserves
test_uninstall_success
test_uninstall_service_absent
test_uninstall_service_absent_systemd_249
test_uninstall_disabled_service
test_uninstall_show_failure_preserves
test_uninstall_enabled_query_failure
test_uninstall_stop_failure
test_uninstall_disable_failure
test_uninstall_query_failure
test_uninstall_daemon_reload_failure

if ((FAILURES == 0)); then
  echo "PASS: fault injection checks completed."
  exit 0
fi
echo "FAIL: $FAILURES fault injection checks failed." >&2
exit 1
