#!/usr/bin/env bash
# Self-test / simulation for the USB kit options (no destructive disk writes).
# Run: sudo bash scripts/self-test.sh
# Verifies menus open, list paths work, clone engine settings, Ghost dest select.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"
export BIOS_TOOL_DIR="${ROOT}"

PASS=0
FAIL=0
skip_destructive=1

ok() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }

echo "========================================"
echo " USB kit self-test (precision + speed checks)"
echo "========================================"
echo "Root: ${ROOT}"
echo

echo "[1] Syntax"
for f in bios-menu.sh prepare-usb.sh scripts/*.sh; do
  if bash -n "${f}"; then ok "bash -n ${f}"
  else bad "bash -n ${f}"; fi
done

echo
echo "[2] Required files present"
for f in \
  bios-menu.sh prepare-usb.sh START-HERE.txt BOOT-USB.md OS-COMPAT.txt README.md \
  scripts/copy-bios.sh scripts/upload-bios.sh scripts/show-info.sh scripts/list-backups.sh \
  scripts/disk-menu.sh scripts/clone-disk.sh scripts/ghost-menu.sh scripts/network-menu.sh \
  scripts/lib.sh \
  windows/RUN-MENU.bat windows/run-ghost.bat windows/choose-ghost-dest.bat \
  ghost/README.txt
 do
  if [[ -e "${f}" ]]; then ok "exists ${f}"
  else bad "missing ${f}"; fi
done

echo
echo "[3] Speed / precision settings in clone-disk.sh"
if grep -q 'DD_BS="128M"' scripts/clone-disk.sh; then ok "clone block size 128M (fast)"
else bad "clone DD_BS not 128M"; fi
if grep -q 'oflag=direct' scripts/clone-disk.sh; then ok "direct I/O enabled"
else bad "direct I/O missing"; fi
if grep -q 'count_bytes' scripts/clone-disk.sh; then ok "exact byte count (precision)"
else bad "count_bytes missing"; fi
if grep -q 'verify_' scripts/clone-disk.sh; then ok "head/mid/tail verify present"
else bad "verify missing"; fi
if grep -qE 'partclone|ntfsclone' scripts/clone-disk.sh; then ok "FS-aware fast clone helpers"
else bad "partclone/ntfsclone path missing"; fi

echo
echo "[4] Menu option simulations (non-destructive)"
run_menu() {
  local name="$1"; shift
  local script="$1"; shift
  local out ec
  set +e
  out="$(printf '%s\n' "$@" | timeout 25 bash "${script}" 2>&1)"
  ec=$?
  set -e
  if echo "${out}" | grep -qiE 'BIOS|Disk /|Ghost|Network|Clone|Choose option|Bye\.|Back to main|Copy BIOS|Upload BIOS|Available disks|Local disks|Symantec|Transfer|WARNING'; then
    ok "${name}"
    return 0
  fi
  bad "${name} (exit=${ec})"
  echo "${out}" | tail -12 | sed 's/^/    /'
}

run_menu "main exit(8)" ./bios-menu.sh '8'
run_menu "main show-info(3)" ./bios-menu.sh '3' '' '8'
run_menu "main list-backups(4)" ./bios-menu.sh '4' '' '8'
run_menu "main copy-bios(1)" ./bios-menu.sh '1' '' '8'
run_menu "main upload-bios(2)" ./bios-menu.sh '2' '' '8'
run_menu "main ghost(6)->back" ./bios-menu.sh '6' '7' '8'
run_menu "main network(7)->back" ./bios-menu.sh '7' '7' '8'
run_menu "disk menu back" ./scripts/disk-menu.sh '5' '4' '5' '3'
run_menu "ghost show disks" ./scripts/ghost-menu.sh '1' '' '7'
run_menu "ghost select dest#1" ./scripts/ghost-menu.sh '3' '1' '' '4' '' '7'
run_menu "network local storage" ./scripts/network-menu.sh '1' '' '7'
run_menu "network mounts list" ./scripts/network-menu.sh '4' '' '7'

echo
echo "[5] Ghost destination selection precision"
if [[ -f backups/ghost-images/SELECTED-DEST.txt ]]; then
  dest="$(tr -d '\r' <backups/ghost-images/SELECTED-DEST.txt | head -1)"
  if [[ -d "${dest}" ]]; then ok "selected dest exists: ${dest}"
  else bad "selected dest missing: ${dest}"; fi
else
  bad "SELECTED-DEST.txt not created"
fi

echo
echo "[6] prepare-usb install simulation"
tmp="$(mktemp -d)"
bash prepare-usb.sh "${tmp}" >/tmp/prep.out
if [[ -x "${tmp}/bios-backup/bios-menu.sh" && -f "${tmp}/bios-backup/scripts/network-menu.sh" && -f "${tmp}/bios-backup/windows/choose-ghost-dest.bat" ]]; then
  ok "prepare-usb installs full kit"
else
  bad "prepare-usb incomplete"
  tail -10 /tmp/prep.out
fi
rm -rf "${tmp}"

echo
echo "[7] show-info / list-backups direct"
bash scripts/show-info.sh >/tmp/info.out 2>&1 || true
grep -q 'BIOS vendor' /tmp/info.out && ok "show-info runs" || bad "show-info"
bash scripts/list-backups.sh >/tmp/lb.out 2>&1 || true
grep -qE 'Backups|none yet' /tmp/lb.out && ok "list-backups runs" || bad "list-backups"

echo
echo "========================================"
echo " RESULT: ${PASS} passed, ${FAIL} failed"
echo "========================================"
if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi
exit 0
