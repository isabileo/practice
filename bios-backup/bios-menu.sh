#!/usr/bin/env bash
# BIOS Backup / Restore menu for a bootable USB environment.
# Read/write firmware on a PC you own. Wrong images can brick hardware.

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

RED=$'\033[31m'
GRN=$'\033[32m'
YLW=$'\033[33m'
CYN=$'\033[36m'
BLD=$'\033[1m'
RST=$'\033[0m'

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "${YLW}Re-launching with sudo (firmware access needs root)...${RST}"
    exec sudo -E bash "$0" "$@"
  fi
}

pause() {
  echo
  read -r -p "Press Enter to continue..." _
}

show_header() {
  clear
  echo "${BLD}${CYN}========================================${RST}"
  echo "${BLD}${CYN}   BIOS Copy / Upload (USB Boot Kit)  ${RST}"
  echo "${BLD}${CYN}========================================${RST}"
  echo
  echo " Backup folder: ${BACKUP_ROOT}"
  echo
  echo "${YLW}WARNING: Uploading the wrong BIOS can permanently brick this PC.${RST}"
  echo "${YLW}Use only dumps taken from THIS machine (same board revision).${RST}"
  echo
}

show_menu() {
  show_header
  echo "  1) Copy BIOS   — save a backup of this PC's firmware"
  echo "  2) Upload BIOS — restore a previous backup to this PC"
  echo "  3) Show PC / chip info"
  echo "  4) List saved backups"
  echo "  5) Exit"
  echo
  read -r -p "Choose option [1-5]: " choice
  case "${choice}" in
    1) bash "${SCRIPT_DIR}/scripts/copy-bios.sh"; pause ;;
    2) bash "${SCRIPT_DIR}/scripts/upload-bios.sh"; pause ;;
    3) bash "${SCRIPT_DIR}/scripts/show-info.sh"; pause ;;
    4) bash "${SCRIPT_DIR}/scripts/list-backups.sh"; pause ;;
    5) echo "Bye."; exit 0 ;;
    *) echo "Invalid choice."; pause ;;
  esac
}

need_root "$@"
mkdir -p "${BACKUP_ROOT}"

while true; do
  show_menu
done
