#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(CDPATH="" cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(CDPATH="" cd -- "$TEST_DIR/../.." && pwd)"
PACKAGE_SCRIPT="$PROJECT_DIR/scripts/package.sh"
VERSION="$(tr -d '[:space:]' < "$PROJECT_DIR/VERSION")"
DIST_DIR="$PROJECT_DIR/build/dist"
PACKAGE_FILE="$DIST_DIR/miniops-monitor-enterprise-$VERSION.tar.gz"
CHECKSUM_FILE="$PACKAGE_FILE.sha256"
TMP_DIR="$(mktemp -d)"
FAILURES=0
PACKAGE_OUTPUT=""
PACKAGE_STATUS=0

cleanup() {
  rm -rf -- "$TMP_DIR" "$PROJECT_DIR/build/stage" "$PROJECT_DIR/build/dist"
}
trap cleanup EXIT

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1" >&2
  FAILURES=$((FAILURES + 1))
}

run_package() {
  if PACKAGE_OUTPUT="$(env -u GITHUB_REF_TYPE -u GITHUB_REF -u GITHUB_REF_NAME -u GIT_TAG "$@" bash "$PACKAGE_SCRIPT" 2>&1)"; then
    PACKAGE_STATUS=0
  else
    PACKAGE_STATUS=$?
  fi
}

assert_release_files() {
  if [[ -f "$PACKAGE_FILE" && -f "$CHECKSUM_FILE" ]]; then
    pass "$1"
  else
    fail "$1: package=$PACKAGE_FILE checksum=$CHECKSUM_FILE"
  fi
}

test_branch_package() {
  run_package \
    GITHUB_REF_TYPE=branch \
    GITHUB_REF_NAME=main \
    GITHUB_REF=refs/heads/main \
    GIT_TAG=main
  if ((PACKAGE_STATUS == 0)); then
    pass "ordinary branch package succeeds"
  else
    fail "ordinary branch package succeeds: status=$PACKAGE_STATUS output=$PACKAGE_OUTPUT"
  fi
  assert_release_files "branch package creates release files"
}

test_matching_tag_package() {
  run_package \
    GITHUB_REF_TYPE=tag \
    GITHUB_REF_NAME="enterprise-v$VERSION" \
    GITHUB_REF="refs/tags/enterprise-v$VERSION" \
    GIT_TAG="enterprise-v$VERSION"
  if ((PACKAGE_STATUS == 0)); then
    pass "matching release tag package succeeds"
  else
    fail "matching release tag package succeeds: status=$PACKAGE_STATUS output=$PACKAGE_OUTPUT"
  fi
  assert_release_files "tag package creates release files"
}

test_local_explicit_tag_package() {
  run_package GIT_TAG="enterprise-v$VERSION"
  if ((PACKAGE_STATUS == 0)); then
    pass "local explicit matching tag package succeeds"
  else
    fail "local explicit matching tag package succeeds: status=$PACKAGE_STATUS output=$PACKAGE_OUTPUT"
  fi
}

test_portable_checksum() {
  local checksum_text copied_dir output status mismatch_tag
  copied_dir="$TMP_DIR/copied-dist"
  mkdir -p "$copied_dir"
  cp -- "$PACKAGE_FILE" "$CHECKSUM_FILE" "$copied_dir/"
  checksum_text="$(<"$CHECKSUM_FILE")"
  if [[ "$checksum_text" == *"/"* ]]; then
    fail "checksum manifest has no absolute or directory path: $checksum_text"
  else
    pass "checksum manifest has no absolute or directory path"
  fi
  if output="$(cd "$copied_dir" && sha256sum --check "$(basename "$CHECKSUM_FILE")" 2>&1)"; then
    status=0
  else
    status=$?
  fi
  if ((status == 0)); then
    pass "copied package verifies from a new directory"
  else
    fail "copied package verifies from a new directory: status=$status output=$output"
  fi
}

test_mismatching_tag_package() {
  mismatch_tag="enterprise-v0.0.0"
  if [[ "$mismatch_tag" == "enterprise-v$VERSION" ]]; then
    mismatch_tag="enterprise-v999.999.999"
  fi
  run_package \
    GITHUB_REF_TYPE=tag \
    GITHUB_REF_NAME="$mismatch_tag" \
    GITHUB_REF="refs/tags/$mismatch_tag" \
    GIT_TAG="$mismatch_tag"
  if ((PACKAGE_STATUS != 0)) && [[ "$PACKAGE_OUTPUT" == *"Git tag 与 VERSION 不一致"* ]]; then
    pass "mismatching release tag is rejected"
  else
    fail "mismatching release tag is rejected: status=$PACKAGE_STATUS output=$PACKAGE_OUTPUT"
  fi
}

test_branch_package
test_matching_tag_package
test_local_explicit_tag_package
test_portable_checksum
test_mismatching_tag_package

if ((FAILURES == 0)); then
  echo "PASS: package checks completed."
  exit 0
fi
echo "FAIL: $FAILURES package checks failed." >&2
exit 1
