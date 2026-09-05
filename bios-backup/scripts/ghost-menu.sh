#!/usr/bin/env bash
# Symantec Ghost 11 helper — choose where to store the .gho image.
# Shows available local disks and optional network PC storage for selection.
# Does not ship Ghost binaries (place your licensed copy in ghost/).

set -euo pipefail

TOOL_DIR="${BIOS_TOOL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib.sh
source "${TOOL_DIR}/scripts/lib.sh"

YLW=$'\033[33m'
GRN=$'\033[32m'
RED=$'\033[31m'
BLD=$'\033[1m'
CYN=$'\033[36m'
RST=$'\033[0m'

GHOST_DIR="${TOOL_DIR}/ghost"
G32="${GHOST_DIR}/Ghost32.exe"
G64="${GHOST_DIR}/Ghost64.exe"
GDOS="${GHOST_DIR}/Ghost.exe"
IMG_ROOT="${TOOL_DIR}/backups/ghost-images"
MOUNT_ROOT="${TOOL_DIR}/backups/network-mounts"
DEST_FILE="${IMG_ROOT}/SELECTED-DEST.txt"

mkdir -p "${IMG_ROOT}" "${MOUNT_ROOT}"

pause() {
  echo
  read -r -p "Press Enter to continue..." _ || true
}

# Arrays filled by build_dest_list
DEST_PATHS=()
DEST_LABELS=()

human_free() {
  local path="$1"
  df -h "${path}" 2>/dev/null | awk 'NR==2{print $4" free / "$2" total ("$5" used)"}'
}

add_dest() {
  local path="$1"
  local label="$2"
  [[ -d "${path}" ]] || return 0
  DEST_PATHS+=("${path}")
  DEST_LABELS+=("${label}")
}

build_dest_list() {
  DEST_PATHS=()
  DEST_LABELS=()

  # This USB kit folder
  add_dest "${IMG_ROOT}" "This USB — Ghost images folder"

  # Mounted local disks / USB / CD
  local mp src fstype
  while read -r mp; do
    [[ -z "${mp}" || "${mp}" == "/" ]] && continue
    [[ "${mp}" == /snap* ]] && continue
    [[ "${mp}" == /boot* ]] && continue
    [[ "${mp}" == /run/user* ]] && continue
    # skip duplicates of IMG_ROOT
    [[ "${mp}" == "${IMG_ROOT}" ]] && continue
    src="$(findmnt -n -o SOURCE "${mp}" 2>/dev/null || true)"
    fstype="$(findmnt -n -o FSTYPE "${mp}" 2>/dev/null || true)"
    case "${fstype}" in
      iso9660|udf)
        add_dest "${mp}" "CD/DVD — ${src:-optical} @ ${mp}"
        ;;
      *)
        add_dest "${mp}" "Local disk/USB — ${src:-?} (${fstype:-?}) @ ${mp}"
        ;;
    esac
  done < <(findmnt -ln -t ext4,ext3,ext2,xfs,btrfs,ntfs,vfat,exfat,fuseblk,iso9660,udf -o TARGET 2>/dev/null | sort -u)

  # Network shares already mounted by this kit
  local d
  for d in "${MOUNT_ROOT}"/*; do
    [[ -d "${d}" ]] || continue
    if findmnt "${d}" >/dev/null 2>&1; then
      add_dest "${d}" "Network PC — $(basename "${d}") @ ${d}"
      # also offer a ghost-images subfolder if we create it
    fi
  done
}

show_available_disks() {
  echo "${BLD}Available disks / storage on THIS PC:${RST}"
  echo
  if command -v lsblk >/dev/null 2>&1; then
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,TYPE,TRAN
  fi
  echo
  echo "${BLD}Free space on mounted volumes:${RST}"
  df -hT 2>/dev/null | awk 'NR==1 || /^\/dev/ || /media|mnt|cdrom/'
  echo
  echo "${BLD}Network mounts (other PCs):${RST}"
  local found=0 d
  for d in "${MOUNT_ROOT}"/*; do
    [[ -d "${d}" ]] || continue
    if findmnt "${d}" >/dev/null 2>&1; then
      echo "  ${d}"
      human_free "${d}" | sed 's/^/    /'
      found=1
    fi
  done
  if [[ "${found}" -eq 0 ]]; then
    echo "  (none yet — use option to connect network PC storage first)"
  fi
}

connect_network_storage() {
  local host share user pass mpoint opts
  echo "${BLD}Connect network PC storage (for Ghost .gho images)${RST}"
  echo "Enter a Windows share on the other PC (SMB)."
  echo
  read -r -p "Remote PC IP or name: " host
  [[ -z "${host}" ]] && { echo "Cancelled."; return 1; }
  read -r -p "Share name (e.g. Data Backup C$): " share
  [[ -z "${share}" ]] && { echo "Cancelled."; return 1; }
  read -r -p "Username: " user
  user="${user:-guest}"
  read -r -s -p "Password (empty if none): " pass
  echo

  if ! command -v mount.cifs >/dev/null 2>&1; then
    echo "${RED}mount.cifs not found. Install: sudo apt install -y cifs-utils${RST}"
    return 1
  fi

  mpoint="${MOUNT_ROOT}/$(echo "${host}_${share}" | tr -c 'A-Za-z0-9._-' '_')"
  mkdir -p "${mpoint}"
  if findmnt "${mpoint}" >/dev/null 2>&1; then
    echo "Already mounted: ${mpoint}"
  else
    opts="uid=0,gid=0,iocharset=utf8,file_mode=0644,dir_mode=0755"
    if [[ -n "${pass}" ]]; then
      mount -t cifs "//${host}/${share}" "${mpoint}" -o "username=${user},password=${pass},${opts}" 2>/dev/null \
        || mount -t cifs "//${host}/${share}" "${mpoint}" -o "username=${user},password=${pass},${opts},vers=3.0" 2>/dev/null \
        || mount -t cifs "//${host}/${share}" "${mpoint}" -o "username=${user},password=${pass},${opts},vers=2.0" 2>/dev/null \
        || mount -t cifs "//${host}/${share}" "${mpoint}" -o "username=${user},password=${pass},${opts},vers=1.0" 2>/dev/null \
        || {
          echo "${RED}Mount failed. Check IP, share, user/password, firewall.${RST}"
          return 1
        }
    else
      mount -t cifs "//${host}/${share}" "${mpoint}" -o "username=${user},guest,${opts},vers=1.0" 2>/dev/null \
        || mount -t cifs "//${host}/${share}" "${mpoint}" -o "username=${user},${opts}" 2>/dev/null \
        || {
          echo "${RED}Mount failed.${RST}"
          return 1
        }
    fi
    echo "${GRN}Mounted //${host}/${share} → ${mpoint}${RST}"
  fi

  mkdir -p "${mpoint}/GhostImages"
  echo
  echo "Suggested Ghost folder on that PC:"
  echo "  ${mpoint}/GhostImages"
  human_free "${mpoint}"
  echo
  echo "${mpoint}/GhostImages" >"${DEST_FILE}"
  echo "Selected destination saved:"
  echo "  ${mpoint}/GhostImages"
}

select_ghost_destination() {
  local choice i idx path sub
  build_dest_list

  clear 2>/dev/null || true
  echo "${BLD}${CYN}========================================${RST}"
  echo "${BLD}${CYN}   Select Ghost image destination${RST}"
  echo "${BLD}${CYN}========================================${RST}"
  echo
  echo "Store the Ghost .gho backup image on one of these locations."
  echo

  if [[ ${#DEST_PATHS[@]} -eq 0 ]]; then
    echo "${YLW}No mounted destinations found yet.${RST}"
    echo "Mount a disk or connect network storage first."
    return 1
  fi

  for i in "${!DEST_PATHS[@]}"; do
    idx=$((i + 1))
    path="${DEST_PATHS[$i]}"
    echo "  ${idx}) ${DEST_LABELS[$i]}"
    echo "      Path: ${path}"
    human_free "${path}" | sed 's/^/      /'
    echo
  done
  local cancel=$(( ${#DEST_PATHS[@]} + 1 ))
  echo "  ${cancel}) Cancel"
  echo
  read -r -p "Choose destination [1-${cancel}]: " choice || true

  if [[ -z "${choice}" || "${choice}" == "${cancel}" ]]; then
    echo "Cancelled."
    return 1
  fi
  if [[ ! "${choice}" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#DEST_PATHS[@]})); then
    echo "Invalid selection."
    return 1
  fi

  path="${DEST_PATHS[$((choice - 1))]}"
  # Prefer a GhostImages subfolder on the chosen volume
  if [[ "${path}" == "${IMG_ROOT}" ]]; then
    sub="${path}"
  else
    sub="${path}/GhostImages"
    mkdir -p "${sub}" 2>/dev/null || sub="${path}"
  fi

  echo "${sub}" >"${DEST_FILE}"
  echo
  echo "${GRN}Ghost image destination selected:${RST}"
  echo "  ${sub}"
  human_free "${sub}" || human_free "${path}" || true
  echo
  echo "In Ghost use: Local → Disk → To Image"
  echo "  and save the .gho file into that folder."
  echo
  echo "Saved also to: ${DEST_FILE}"
}

show_selected_dest() {
  echo "${BLD}Currently selected Ghost image destination:${RST}"
  if [[ -f "${DEST_FILE}" ]]; then
    local p
    p="$(tr -d '\r' <"${DEST_FILE}" | head -1)"
    echo "  ${p}"
    if [[ -d "${p}" ]]; then
      human_free "${p}" | sed 's/^/  /'
      echo
      echo "  Existing .gho files there:"
      find "${p}" -maxdepth 2 -type f \( -iname '*.gho' -o -iname '*.ghs' -o -iname '*.v2i' \) 2>/dev/null | sed 's/^/    /' | head -20
      if ! find "${p}" -maxdepth 2 -type f \( -iname '*.gho' -o -iname '*.ghs' \) 2>/dev/null | grep -q .; then
        echo "    (none yet)"
      fi
    else
      echo "  ${YLW}(path not accessible right now — remount network/disk if needed)${RST}"
    fi
  else
    echo "  (none — use Select destination first)"
  fi
}

show_ghost_status() {
  echo "${BLD}Symantec Ghost 11 files on this USB:${RST}"
  local found=0
  [[ -f "${G32}" ]] && { echo "  ${GRN}Ghost32.exe${RST}"; found=1; }
  [[ -f "${G64}" ]] && { echo "  ${GRN}Ghost64.exe${RST}"; found=1; }
  [[ -f "${GDOS}" ]] && { echo "  ${GRN}Ghost.exe (DOS)${RST}"; found=1; }
  if [[ "${found}" -eq 0 ]]; then
    echo "  ${RED}Not found — copy your licensed Ghost32.exe into:${RST}"
    echo "    ${GHOST_DIR}"
    echo "  See ghost/README.txt (Ghost is not redistributed with this kit)."
  fi
}

how_to_run_ghost() {
  show_ghost_status
  echo
  show_selected_dest
  echo
  echo "${BLD}How to create the Ghost image:${RST}"
  echo
  echo "  A) Windows XP / 7 / 10 still running"
  echo "       USB → bios-backup\\windows\\RUN-MENU.bat → Ghost 11"
  echo "       Local → Disk → To Image → browse to the selected folder"
  echo
  echo "  B) Boot Ghost/DOS ISO from Ventoy (if you added one)"
  echo
  echo "  C) Linux built-in clone (no Ghost): Disk / Drives → Clone disk"
  echo
  if [[ -f "${DEST_FILE}" ]]; then
    echo "Save your .gho here:"
    echo "  $(tr -d '\r' <"${DEST_FILE}" | head -1)"
  fi
}

# ---- Ghost menu loop ----
while true; do
  clear 2>/dev/null || true
  echo "${BLD}${CYN}========================================${RST}"
  echo "${BLD}${CYN}   Symantec Ghost 11 — image storage${RST}"
  echo "${BLD}${CYN}========================================${RST}"
  echo
  echo "Choose where to store the Ghost disk image (.gho),"
  echo "including disks on this PC or storage on another network PC."
  echo
  show_ghost_status
  echo
  if [[ -f "${DEST_FILE}" ]]; then
    echo "Selected dest: $(tr -d '\r' <"${DEST_FILE}" | head -1)"
  else
    echo "Selected dest: (none yet)"
  fi
  echo
  echo "  1) Show available disks / storage (this PC + network mounts)"
  echo "  2) Connect network PC storage (SMB share for .gho)"
  echo "  3) Select destination for Ghost image (list + pick)"
  echo "  4) Show selected destination + existing .gho files"
  echo "  5) How to run Ghost (Windows / Ventoy / Linux clone)"
  echo "  6) Open Network & Transfer menu (copy files too)"
  echo "  7) Back to main menu"
  echo
  read -r -p "Choose option [1-7]: " choice || true
  [[ -z "${choice}" ]] && exit 0
  case "${choice}" in
    1) clear 2>/dev/null || true; show_available_disks; pause ;;
    2) clear 2>/dev/null || true; connect_network_storage; pause ;;
    3) select_ghost_destination; pause ;;
    4) clear 2>/dev/null || true; show_selected_dest; pause ;;
    5) clear 2>/dev/null || true; how_to_run_ghost; pause ;;
    6) bash "${TOOL_DIR}/scripts/network-menu.sh" ;;
    7) exit 0 ;;
    *) echo "Invalid choice."; pause ;;
  esac
done
