#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVICE_NAME="miniops-monitor-enterprise.service"
INSTALL_SCRIPT="$PROJECT_DIR/install.sh"
UNINSTALL_SCRIPT="$PROJECT_DIR/uninstall.sh"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
INSTALL_FILE="/usr/local/lib/miniops-monitor-enterprise/miniops-monitor.sh"
CONFIG_FILE="/etc/default/miniops-monitor-enterprise"
ATTEMPTED=0

diagnose() {
  systemctl status "$SERVICE_NAME" --no-pager || true
  journalctl -u "$SERVICE_NAME" -n 50 --no-pager || true
}

cleanup() {
  if ((ATTEMPTED == 1)) && { [[ -e "$SERVICE_FILE" ]] || [[ -e "$INSTALL_FILE" ]] || [[ -e "$CONFIG_FILE" ]]; }; then
    bash "$UNINSTALL_SCRIPT" --purge-config >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [[ "${MINIOPS_ALLOW_SYSTEMD_TEST:-0}" != "1" ]]; then
  echo "SKIP: set MINIOPS_ALLOW_SYSTEMD_TEST=1 in a disposable Linux host to run this test." >&2
  exit 2
fi
[[ "$(uname -s)" == "Linux" ]] || { echo "FAIL: Linux is required." >&2; exit 1; }
((EUID == 0)) || { echo "FAIL: root is required." >&2; exit 1; }
[[ "$(</proc/1/comm)" == "systemd" ]] || { echo "FAIL: systemd must be PID 1." >&2; exit 1; }

if systemctl is-active --quiet "$SERVICE_NAME" || systemctl is-enabled --quiet "$SERVICE_NAME" || [[ -e "$SERVICE_FILE" || -e "$INSTALL_FILE" || -e "$CONFIG_FILE" ]]; then
  echo "FAIL: refusing to overwrite an existing enterprise installation." >&2
  exit 1
fi

ATTEMPTED=1
if ! bash "$INSTALL_SCRIPT"; then
  echo "FAIL: installer failed." >&2
  diagnose
  exit 1
fi

systemctl is-enabled --quiet "$SERVICE_NAME" || { echo "FAIL: service is not enabled." >&2; diagnose; exit 1; }
systemctl is-active --quiet "$SERVICE_NAME" || { echo "FAIL: service is not active." >&2; diagnose; exit 1; }

found_log=0
for _ in {1..10}; do
  if journalctl -u "$SERVICE_NAME" --since '2 minutes ago' --no-pager 2>/dev/null | grep -q 'event=resource_sample'; then
    found_log=1
    break
  fi
  sleep 1
done
if ((found_log == 0)); then
  echo "FAIL: no resource sample was found in journal." >&2
  diagnose
  exit 1
fi

if ! bash "$UNINSTALL_SCRIPT" --purge-config; then
  echo "FAIL: uninstaller failed." >&2
  diagnose
  exit 1
fi

ATTEMPTED=0
[[ ! -e "$SERVICE_FILE" && ! -e "$INSTALL_FILE" && ! -e "$CONFIG_FILE" ]] || { echo "FAIL: uninstall left files behind." >&2; exit 1; }
echo "PASS: systemd install, journal, and uninstall checks completed."
