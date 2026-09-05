#!/usr/bin/env bash
# Upload (flash) a previously copied BIOS image with flashrom.

set -euo pipefail

TOOL_DIR="${BIOS_TOOL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BACKUP_ROOT="${BIOS_BACKUP_ROOT:-${TOOL_DIR}/backups}"
# shellcheck source=lib.sh
source "${TOOL_DIR}/scripts/lib.sh"

require_flashrom
mkdir -p "${BACKUP_ROOT}"

echo "WARNING: This will WRITE firmware to the motherboard flash chip."
echo "Only upload a dump taken from THIS exact PC."
echo "Power must not be lost during the write."
echo

mapfile -t IMAGES < <(find "${BACKUP_ROOT}" -type f -name 'bios.bin' 2>/dev/null | sort)

if [[ ${#IMAGES[@]} -eq 0 ]]; then
  echo "No bios.bin backups found in ${BACKUP_ROOT}"
  echo "Use option 1 (Copy BIOS) first, or copy a known-good bios.bin onto this USB."
  exit 1
fi

echo "Available backups:"
echo
i=1
for img in "${IMAGES[@]}"; do
  size="$(du -h "${img}" | awk '{print $1}')"
  sum="$(sha256sum "${img}" | awk '{print $1}')"
  echo "  ${i}) ${img}"
  echo "      size=${size}  sha256=${sum:0:16}..."
  ((i++)) || true
done
echo "  ${i}) Enter a custom path"
echo

read -r -p "Select image to upload: " pick

if [[ "${pick}" == "${i}" ]]; then
  read -r -p "Full path to bios.bin: " ROM
elif [[ "${pick}" =~ ^[0-9]+$ ]] && (( pick >= 1 && pick < i )); then
  ROM="${IMAGES[$((pick - 1))]}"
else
  echo "Invalid selection."
  exit 1
fi

if [[ ! -f "${ROM}" ]]; then
  echo "File not found: ${ROM}"
  exit 1
fi

echo
echo "Selected: ${ROM}"
sha256sum "${ROM}"
echo
read -r -p "Type YES to upload this BIOS to the chip: " confirm
if [[ "${confirm}" != "YES" ]]; then
  echo "Cancelled."
  exit 0
fi

LOG_DIR="${BACKUP_ROOT}/upload-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${LOG_DIR}"

echo
echo "Uploading... do not power off."
if flashrom -p internal -w "${ROM}" 2>&1 | tee "${LOG_DIR}/upload.log"; then
  echo
  echo "SUCCESS: BIOS uploaded."
  echo "Reboot the PC now. If it fails to POST, use Dual-BIOS / USB recovery / SPI programmer."
else
  echo
  echo "FAILED: flashrom could not write the chip."
  echo "Log: ${LOG_DIR}/upload.log"
  echo "Do not reboot repeatedly if the chip may be half-written — seek hardware recovery."
  exit 1
fi
