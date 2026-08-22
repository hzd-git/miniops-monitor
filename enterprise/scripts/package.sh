#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR="$(CDPATH="" cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$PROJECT_DIR/VERSION"
BUILD_DIR="$PROJECT_DIR/build"
STAGE_DIR="$BUILD_DIR/stage"
DIST_DIR="$BUILD_DIR/dist"
VERSION=""
TAG=""

detect_release_tag() {
  if [[ "${GITHUB_REF_TYPE:-}" == "tag" ]]; then
    TAG="${GITHUB_REF_NAME:-}"
  elif [[ -z "${GITHUB_REF_TYPE:-}" && -z "${GITHUB_REF:-}" ]]; then
    # 保留本地显式 GIT_TAG 校验能力；CI branch 环境不会进入此分支。
    TAG="${GIT_TAG:-}"
  elif [[ "${GITHUB_REF:-}" == refs/tags/* ]]; then
    TAG="${GITHUB_REF#refs/tags/}"
  else
    TAG=""
  fi
}

fail() {
  echo "打包失败: $*" >&2
  exit 1
}

read_version() {
  VERSION="$(tr -d '[:space:]' <"$VERSION_FILE")"
  [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "VERSION 必须是 X.Y.Z：$VERSION"
  detect_release_tag
  if [[ -n "$TAG" && "$TAG" != "enterprise-v${VERSION}" ]]; then
    fail "Git tag 与 VERSION 不一致：tag=$TAG version=$VERSION"
  fi
  grep -q "^## \[${VERSION}\]" "$PROJECT_DIR/CHANGELOG.md" || fail "CHANGELOG 缺少版本 ${VERSION}。"
}

copy_path() {
  local relative="$1" source="$PROJECT_DIR/$1" destination="$STAGE_ROOT/$1"
  [[ -e "$source" ]] || fail "发布白名单路径不存在：$relative"
  mkdir -p "$(dirname "$destination")"
  cp -a "$source" "$destination"
}

check_manifest() {
  local relative mode
  local required_paths=(
    README.md
    VERSION
    CHANGELOG.md
    Makefile
    .editorconfig
    .gitattributes
    .gitignore
    install.sh
    uninstall.sh
    src/miniops-monitor.sh
    config/miniops-monitor.env.example
    systemd/miniops-monitor-enterprise.service
  )

  for relative in "${required_paths[@]}"; do
    [[ -e "$STAGE_ROOT/$relative" ]] || fail "发布物缺少文件：$relative"
  done

  if find "$STAGE_ROOT" -type f \( -name '*.key' -o -name '*.pem' -o -name '*.secret' -o -name '.env' \) -print -quit | grep -q .; then
    fail "发布物包含敏感文件。"
  fi
  if find "$STAGE_ROOT" -type f \( -name '*.tmp' -o -name '*.log' \) -print -quit | grep -q .; then
    fail "发布物包含临时文件或日志。"
  fi

  for relative in install.sh uninstall.sh src/miniops-monitor.sh; do
    mode="$(stat -c '%a' "$STAGE_ROOT/$relative")"
    [[ "$mode" == "755" ]] || fail "可执行文件权限错误：$relative mode=$mode"
  done
  mode="$(stat -c '%a' "$STAGE_ROOT/config/miniops-monitor.env.example")"
  [[ "$mode" == "644" ]] || fail "配置示例权限错误：mode=$mode"
}

check_archive() {
  local archive="$1" entry
  while IFS= read -r entry; do
    [[ "$entry" != /* ]] || fail "归档包含绝对路径：$entry"
    [[ "$entry" != *'../'* ]] || fail "归档包含路径穿越：$entry"
    [[ "$entry" != *'/.git/'* ]] || fail "归档包含 Git 数据：$entry"
    [[ "$entry" != *'/build/'* ]] || fail "归档包含构建目录：$entry"
  done < <(tar -tzf "$archive")
}

main() {
  local package_root package_file checksum_file archive_file
  read_version
  package_root="miniops-monitor-enterprise-${VERSION}"
  package_file="$DIST_DIR/${package_root}.tar.gz"
  checksum_file="${package_file}.sha256"
  STAGE_ROOT="$STAGE_DIR/$package_root"

  rm -rf -- "$STAGE_DIR" "$DIST_DIR"
  mkdir -p "$STAGE_ROOT" "$DIST_DIR"

  for path in README.md VERSION CHANGELOG.md Makefile .editorconfig .gitattributes .gitignore install.sh uninstall.sh scripts src config systemd tests docs; do
    copy_path "$path"
  done

  chmod 755 "$STAGE_ROOT/install.sh" "$STAGE_ROOT/uninstall.sh" "$STAGE_ROOT/src/miniops-monitor.sh"
  while IFS= read -r relative; do
    chmod 755 "$STAGE_ROOT/$relative"
  done < <(cd "$STAGE_ROOT" && find tests -type f -name '*.sh' -printf 'tests/%P\n')

  check_manifest
  archive_file="${package_file%.gz}"
  tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner \
    -C "$STAGE_DIR" -cf "$archive_file" "$package_root"
  gzip -n -f "$archive_file"
  check_archive "$package_file"
  (
    cd "$DIST_DIR"
    sha256sum "$(basename "$package_file")" >"$(basename "$checksum_file")"
    sha256sum --check "$(basename "$checksum_file")"
  )

  echo "PACKAGE=$package_file"
  echo "CHECKSUM=$checksum_file"
}

main "$@"

