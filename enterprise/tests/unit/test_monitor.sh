#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(CDPATH="" cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(CDPATH="" cd -- "$TEST_DIR/../.." && pwd)"
# shellcheck disable=SC1091
source "$PROJECT_DIR/src/miniops-monitor.sh"

FAILURES=0

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1" >&2
  FAILURES=$((FAILURES + 1))
}

assert_equals() {
  local expected="$1" actual="$2" name="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$name"
  else
    fail "$name: expected=$expected actual=$actual"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" name="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name: missing=$needle"
  fi
}

test_metric_calculations() {
  assert_equals "50" "$(cpu_load_ratio_from_values 0.5 1)" "CPU load ratio calculation"
  assert_equals "75" "$(memory_used_percent_from_values 100 25)" "memory percentage calculation"
  assert_equals "80" "$(disk_used_percent_from_value 80)" "disk percentage calculation"
}

test_threshold_output() {
  local output
  output="$(check_threshold demo 100 0)"
  assert_contains "$output" "event=threshold_exceeded" "threshold event"
  assert_contains "$output" "resource=demo value=100 threshold=0" "threshold fields"
}

test_log_contract() {
  local output
  output="$(log_event INFO resource_sample "cpu_load_ratio=50")"
  assert_contains "$output" "timestamp=" "log timestamp field"
  assert_contains "$output" "schema_version=1" "log schema field"
  assert_contains "$output" "level=INFO" "log level field"
  assert_contains "$output" "event=resource_sample" "log event field"
}

test_config_parser() {
  local temp_dir valid_file invalid_file
  temp_dir="$(mktemp -d)"
  valid_file="$temp_dir/valid.env"
  invalid_file="$temp_dir/invalid.env"
  printf '%s\n' 'INTERVAL_SECONDS=30' 'CPU_LOAD_WARN=75' 'MEMORY_WARN=80' 'DISK_WARN=70' > "$valid_file"
  printf '%s\n' 'INTERVAL_SECONDS=1' > "$invalid_file"

  set_defaults
  if load_config_file "$valid_file" && validate_config; then
    pass "valid configuration"
  else
    fail "valid configuration"
  fi
  assert_equals "30" "$INTERVAL_SECONDS" "configuration value loaded"

  set_defaults
  if load_config_file "$invalid_file" && validate_config; then
    fail "invalid configuration rejected"
  else
    pass "invalid configuration rejected"
  fi
  rm -rf -- "$temp_dir"
}

test_cli_contract() {
  set_defaults
  if parse_args --loop --interval 10; then
    assert_equals "--loop" "$MODE" "CLI mode"
    assert_equals "10" "$CLI_INTERVAL" "CLI override"
  else
    fail "valid CLI arguments"
  fi

  set_defaults
  if parse_args --loop --once; then
    fail "duplicate modes rejected"
  else
    pass "duplicate modes rejected"
  fi
}

test_metric_calculations
test_threshold_output
test_log_contract
test_config_parser
test_cli_contract

if ((FAILURES == 0)); then
  echo "PASS: monitor unit checks completed."
  exit 0
fi
echo "FAIL: $FAILURES monitor unit checks failed." >&2
exit 1
