#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(CDPATH="" cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(CDPATH="" cd -- "$TEST_DIR/../.." && pwd)"
FAILURES=0

assert_success_contains() {
  local name="$1" needle="$2" output status
  shift 2
  output="$("$@" 2>&1)"
  status=$?
  if ((status == 0)) && [[ "$output" == *"$needle"* ]]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name status=$status output=$output" >&2
    FAILURES=$((FAILURES + 1))
  fi
}

assert_success_contains "installer dry-run" "DRY-RUN: 不执行" bash "$PROJECT_DIR/install.sh" --dry-run
assert_success_contains "uninstaller dry-run" "DRY-RUN: 停止并禁用" bash "$PROJECT_DIR/uninstall.sh" --dry-run

if ((FAILURES == 0)); then
  echo "PASS: installer unit checks completed."
  exit 0
fi
echo "FAIL: $FAILURES installer unit checks failed." >&2
exit 1
