#!/usr/bin/env bash
# BIOS Backup / Restore + Disk tools menu for a bootable USB environment.
# Read/write firmware on a PC you own. Wrong images can brick hardware.
# Disk format / wipe destroys all data on the chosen drive.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Prefer a backups folder on the USB stick (parent of this kit) when present.
if [[ -d "${SCRIPT_DIR}/../backups" ]]; then
  BACKUP_ROOT="${SCRIPT_DIR}/../backups"
elif [[ -d "${SCRIPT_DIR}/backups" ]]; then
  BACKUP_ROOT="${SCRIPT_DIR}/backups"
else
  BACKUP_ROOT="${SCRIPT_DIR}/backups"
  mkdir -p "${BACKUP_ROOT}"
fi

export BIOS_BACKUP_ROOT="${BACKUP_ROOT}"
export BIOS_TOOL_DIR="${SCRIPT_DIR}"

YLW=$'\033[33m'
CYN=$'\033[36m'
BLD=$'\033[1m'
RST=$'\033[0m'

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "${YLW}Re-launching with sudo (firmware / disk access needs root)...${RST}"
    exec sudo -E bash "$0" "$@"
  fi
}

pause() {
  echo
  read -r -p "Press Enter to continue..." _ || true
}

show_header() {
  clear 2>/dev/null || true
  echo "${BLD}${CYN}========================================${RST}"
  echo "${BLD}${CYN}   BIOS + Disk USB Boot Kit${RST}"
  echo "${BLD}${CYN}========================================${RST}"
  echo
  echo " Backup folder: ${BACKUP_ROOT}"
  echo
  echo "${YLW}WARNING: Wrong BIOS upload can brick this PC.${RST}"
  echo "${YLW}WARNING: Format / wipe erases the selected disk completely.${RST}"
  echo
}

show_menu() {
  show_header
  echo "  1) Copy BIOS            — save a backup of this PC's firmware"
  echo "  2) Upload BIOS          — restore a previous backup to this PC"
  echo "  3) Show PC / chip info"
  echo "  4) List saved backups"
  echo "  5) Disk / Drives        — list, format, wipe, clone disks"
  echo "  6) Symantec Ghost 11    — .gho to USB / disk / network PC"
  echo "  7) Network & Transfer   — other PCs, copy to/from shares / CD / USB"
  echo "  8) Exit"
  echo
  echo "Note: This kit does not bypass or remove BIOS passwords."
  echo
  read -r -p "Choose option [1-8]: " choice || true
  [[ -z "${choice}" ]] && exit 0
  case "${choice}" in
    1) bash "${SCRIPT_DIR}/scripts/copy-bios.sh"; pause ;;
    2) bash "${SCRIPT_DIR}/scripts/upload-bios.sh"; pause ;;
    3) bash "${SCRIPT_DIR}/scripts/show-info.sh"; pause ;;
    4) bash "${SCRIPT_DIR}/scripts/list-backups.sh"; pause ;;
    5) bash "${SCRIPT_DIR}/scripts/disk-menu.sh" ;;
    6) bash "${SCRIPT_DIR}/scripts/ghost-menu.sh" ;;
    7) bash "${SCRIPT_DIR}/scripts/network-menu.sh" ;;
    8) echo "Bye."; exit 0 ;;
    *) echo "Invalid choice."; pause ;;
  esac
}

need_root "$@"
mkdir -p "${BACKUP_ROOT}"

while true; do
  show_menu
done
