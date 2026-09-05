#!/usr/bin/env bash
# Build a single self-extracting file: BIOS-USB-KIT.sh
# Copy that one file onto any Ventoy / Rufus USB, then run it once.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="${ROOT}/dist"
OUT="${DIST}/BIOS-USB-KIT.sh"
STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT

mkdir -p "${DIST}" "${STAGE}/bios-backup"

# Copy kit (skip build artifacts / runtime mounts)
mkdir -p "${STAGE}/bios-backup"
tar -C "${ROOT}" \
  --exclude='dist' \
  --exclude='backups/network-mounts' \
  --exclude='backups/ghost-images/SELECTED-DEST.txt' \
  --exclude='backups/transfers' \
  --exclude='build-single-file.sh' \
  -cf - . | tar -C "${STAGE}/bios-backup" -xf -

# Ensure empty dirs exist in the package
mkdir -p \
  "${STAGE}/bios-backup/backups/ghost-images" \
  "${STAGE}/bios-backup/ghost" \
  "${STAGE}/bios-backup/windows" \
  "${STAGE}/bios-backup/scripts"
touch "${STAGE}/bios-backup/backups/.keep"
touch "${STAGE}/bios-backup/backups/ghost-images/.keep"

ARCHIVE="${STAGE}/payload.tar.gz"
tar -C "${STAGE}" -czf "${ARCHIVE}" bios-backup

{
  cat <<'HEADER'
#!/usr/bin/env bash
# BIOS-USB-KIT — single-file installer for Ventoy / Rufus USB sticks
# --------------------------------------------------------------------
# 1. Copy THIS file onto your bootable USB (Ventoy data partition or
#    any FAT32/exFAT volume Rufus left writable).
# 2. Boot Linux from the USB (or open a terminal on a Linux PC).
# 3. Run:
#      bash BIOS-USB-KIT.sh
#    or:
#      bash BIOS-USB-KIT.sh /path/to/usb
# 4. Then start the menu:
#      sudo bash bios-backup/bios-menu.sh
#
# Contains: BIOS copy/upload, disk tools, clone, Ghost helpers,
# network transfer. Does NOT bypass BIOS passwords.
# --------------------------------------------------------------------
set -euo pipefail

DEST="${1:-.}"
if [[ ! -d "${DEST}" ]]; then
  echo "Not a directory: ${DEST}"
  echo "Usage: bash BIOS-USB-KIT.sh [destination-folder]"
  exit 1
fi

DEST="$(cd "${DEST}" && pwd)"
echo "Extracting BIOS USB kit into: ${DEST}"

# Locate payload after marker
PAYLOAD_LINE="$(awk '/^__BIOS_USB_KIT_PAYLOAD__$/ {print NR + 1; exit 0}' "$0")"
if [[ -z "${PAYLOAD_LINE}" ]]; then
  echo "ERROR: payload marker not found in $0"
  exit 1
fi

tail -n "+${PAYLOAD_LINE}" "$0" | tar -xzf - -C "${DEST}"

chmod +x "${DEST}/bios-backup/bios-menu.sh" \
         "${DEST}/bios-backup/prepare-usb.sh" \
         "${DEST}/bios-backup/scripts/"*.sh 2>/dev/null || true

echo
echo "Done. Kit folder: ${DEST}/bios-backup"
echo
echo "Next:"
echo "  sudo bash ${DEST}/bios-backup/bios-menu.sh"
echo
echo "Windows (XP/7/10): open bios-backup\\windows\\RUN-MENU.bat"
echo "Optional Ghost: put licensed Ghost32.exe in bios-backup\\ghost\\"
echo "Docs: bios-backup/START-HERE.txt  bios-backup/OS-COMPAT.txt"
exit 0

__BIOS_USB_KIT_PAYLOAD__
HEADER
  cat "${ARCHIVE}"
} >"${OUT}"

chmod +x "${OUT}"

# Also build a plain zip for Windows Explorer extract
ZIP_OUT="${DIST}/BIOS-USB-KIT.zip"
rm -f "${ZIP_OUT}"
(cd "${STAGE}" && zip -qr "${ZIP_OUT}" bios-backup)

BYTES="$(wc -c <"${OUT}" | tr -d ' ')"
echo "Built:"
echo "  ${OUT}  (${BYTES} bytes)  ← single file for Ventoy/Rufus"
echo "  ${ZIP_OUT}"
echo
echo "Copy BIOS-USB-KIT.sh to the USB, then:  bash BIOS-USB-KIT.sh"
