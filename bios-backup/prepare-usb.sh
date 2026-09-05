#!/usr/bin/env bash
# Copy this BIOS kit onto a USB stick (FAT32/exFAT/ext4) that you will boot from.
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
mkdir -p "${TARGET}/backups" "${TARGET}/scripts"

install -m 0755 "${SRC}/bios-menu.sh" "${TARGET}/bios-menu.sh"
install -m 0755 "${SRC}/scripts/"*.sh "${TARGET}/scripts/"
install -m 0644 "${SRC}/README.md" "${TARGET}/README.md"
install -m 0644 "${SRC}/BOOT-USB.md" "${TARGET}/BOOT-USB.md"
install -m 0644 "${SRC}/START-HERE.txt" "${TARGET}/START-HERE.txt"
touch "${TARGET}/backups/.keep"

echo
echo "Installed kit to: ${TARGET}"
echo
echo "Next:"
echo "  1. Make the USB bootable with Ventoy or Rufus (see BOOT-USB.md)."
echo "  2. Boot the target Windows 7 PC from this USB (Linux live)."
echo "  3. Open a terminal and run:"
echo "       sudo bash /path/to/usb/bios-backup/bios-menu.sh"
echo "  4. Choose 1) Copy BIOS  or  2) Upload BIOS"
