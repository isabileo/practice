#!/usr/bin/env bash
# Copy (dump) SPI/BIOS firmware with flashrom into a timestamped backup.

set -euo pipefail

TOOL_DIR="${BIOS_TOOL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BACKUP_ROOT="${BIOS_BACKUP_ROOT:-${TOOL_DIR}/backups}"
# shellcheck source=lib.sh
source "${TOOL_DIR}/scripts/lib.sh"

require_flashrom
mkdir -p "${BACKUP_ROOT}"

STAMP="$(date +%Y%m%d-%H%M%S)"
VENDOR="$(dmi_field board_vendor | tr ' /' '__' | tr -cd 'A-Za-z0-9._-')"
BOARD="$(dmi_field board_name | tr ' /' '__' | tr -cd 'A-Za-z0-9._-')"
[[ -z "${VENDOR}" ]] && VENDOR="unknown"
[[ -z "${BOARD}" ]] && BOARD="board"

OUT_DIR="${BACKUP_ROOT}/${STAMP}_${VENDOR}_${BOARD}"
mkdir -p "${OUT_DIR}"

ROM="${OUT_DIR}/bios.bin"
META="${OUT_DIR}/inventory.txt"
JSON="${OUT_DIR}/inventory.json"

echo "Collecting board info..."
write_inventory "${META}" "${JSON}"

echo
echo "Probing flash chip (flashrom)..."
if ! flashrom -p internal -o "${OUT_DIR}/probe.log" 2>&1 | tee "${OUT_DIR}/probe-console.log"; then
  echo
  echo "Probe reported errors. Some boards still dump successfully — continuing to read..."
fi

echo
echo "Copying BIOS to:"
echo "  ${ROM}"
echo

if flashrom -p internal -r "${ROM}" 2>&1 | tee "${OUT_DIR}/copy.log"; then
  sha256sum "${ROM}" | tee "${OUT_DIR}/bios.sha256"
  # Keep a simple "latest" pointer for easy restore from the menu.
  ln -sfn "${OUT_DIR}" "${BACKUP_ROOT}/latest"
  echo
  echo "SUCCESS: BIOS copied."
  echo "Saved under: ${OUT_DIR}"
  echo "Keep this USB safe — you will need this file to upload if BIOS crashes."
else
  echo
  echo "FAILED: Could not read the BIOS chip."
  echo "Common causes: chip locked by vendor, laptop EC lock, or unsupported board."
  echo "See ${OUT_DIR}/copy.log"
  echo "For a hard brick with no POST, you may need a hardware SPI programmer."
  exit 1
fi
