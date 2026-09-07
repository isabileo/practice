#!/usr/bin/env bash
# Copy this kit onto a USB stick for XP / Win7 / Win10 PCs.
# Prefer FAT32 data partition so Windows XP can open the USB in Explorer.
# Usage: sudo ./prepare-usb.sh /media/you/MYUSB

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -ne 1 ]]; then
  echo "Usage: sudo $0 /path/to/mounted/usb"
  echo "Example: sudo $0 /media/$USER/VENTOY"
  exit 1
fi

DEST="$1"
if [[ ! -d "${DEST}" ]]; then
  echo "Not a directory: ${DEST}"
  exit 1
fi

TARGET="${DEST}/bios-backup"
mkdir -p \
  "${TARGET}/backups/ghost-images" \
  "${TARGET}/backups/network-mounts" \
  "${TARGET}/backups/transfers" \
  "${TARGET}/scripts" \
  "${TARGET}/ghost" \
  "${TARGET}/windows"

install -m 0755 "${SRC}/bios-menu.sh" "${TARGET}/bios-menu.sh"
install -m 0755 "${SRC}/scripts/"*.sh "${TARGET}/scripts/"
install -m 0644 "${SRC}/README.md" "${TARGET}/README.md"
install -m 0644 "${SRC}/BOOT-USB.md" "${TARGET}/BOOT-USB.md"
install -m 0644 "${SRC}/START-HERE.txt" "${TARGET}/START-HERE.txt"
install -m 0644 "${SRC}/OS-COMPAT.txt" "${TARGET}/OS-COMPAT.txt"
install -m 0644 "${SRC}/ghost/"* "${TARGET}/ghost/" 2>/dev/null || true
install -m 0644 "${SRC}/windows/"* "${TARGET}/windows/"
chmod 0644 "${TARGET}/windows/"*.bat 2>/dev/null || true
touch "${TARGET}/backups/.keep"
touch "${TARGET}/backups/ghost-images/.keep"

echo
echo "Installed kit to: ${TARGET}"
echo
echo "XP / Win7 / Win10:"
echo "  • Boot Linux from USB → sudo bash .../bios-menu.sh"
echo "  • Or in Windows → bios-backup\\windows\\RUN-MENU.bat"
echo "      Choose Ghost destination (local disk / network PC),"
echo "      then run Ghost 11 (place licensed Ghost32.exe in ghost\\)"
echo
echo "Use FAT32 Ventoy data partition if Windows XP must open the stick."
echo "See OS-COMPAT.txt and ghost/README.txt."
