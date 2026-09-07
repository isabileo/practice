#!/usr/bin/env bash
# Network + local storage browser / file copy for the USB recovery kit.
# Browse disks on this PC (HDD/USB/CD) and Windows shares on other PCs,
# then copy files/folders either way. Use only on networks you administer.

set -euo pipefail

TOOL_DIR="${BIOS_TOOL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib.sh
source "${TOOL_DIR}/scripts/lib.sh"

YLW=$'\033[33m'
RED=$'\033[31m'
GRN=$'\033[32m'
BLD=$'\033[1m'
CYN=$'\033[36m'
RST=$'\033[0m'

MOUNT_ROOT="${TOOL_DIR}/backups/network-mounts"
mkdir -p "${MOUNT_ROOT}" "${TOOL_DIR}/backups/transfers"

pause() {
  echo
  read -r -p "Press Enter to continue..." _ || true
}

need_cmd() {
  local c="$1"
  if ! command -v "${c}" >/dev/null 2>&1; then
    echo "${YLW}Missing tool: ${c}${RST}"
    echo "On Ubuntu/Debian live try:  sudo apt update && sudo apt install -y ${2:-$c}"
    return 1
  fi
  return 0
}

# ---- local storage ----
show_local_storage() {
  echo "${BLD}Local disks / USB / CD-DVD on THIS PC:${RST}"
  echo
  if command -v lsblk >/dev/null 2>&1; then
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,TYPE,TRAN
  else
    echo "(lsblk not available)"
  fi
  echo
  echo "${BLD}Mounted filesystems (usable paths):${RST}"
  df -hT 2>/dev/null | awk 'NR==1 || /^\/dev/ || /media|mnt|cdrom|iso9660|udf/'
  echo
  echo "${BLD}Optical drives:${RST}"
  if command -v lsblk >/dev/null 2>&1; then
    lsblk -dn -o NAME,SIZE,TYPE,TRAN,MODEL | awk '$3=="rom"{print "  /dev/"$1"  "$2"  "$4"  "$5" "$6" "$7}'
    # also show sr*
    for d in /dev/sr* /dev/cdrom; do
      [[ -b "${d}" ]] && echo "  ${d}"
    done 2>/dev/null | sort -u
  fi
  if ! ls /dev/sr* >/dev/null 2>&1 && ! ls /dev/cdrom >/dev/null 2>&1; then
    echo "  (none detected)"
  fi
}

mount_local_hint() {
  echo
  echo "Common mount paths after plugging USB / inserting CD:"
  echo "  /media/  /mnt/  /run/media/"
  echo "To mount manually:"
  echo "  sudo mkdir -p /mnt/usb && sudo mount /dev/sdX1 /mnt/usb"
  echo "  sudo mkdir -p /mnt/cd  && sudo mount /dev/sr0 /mnt/cd"
}

# ---- network discovery ----
scan_lan() {
  echo "${BLD}Scan LAN for other PCs (ping + SMB port 445)...${RST}"
  echo
  need_cmd ip "iproute2" || return 0

  local iface cidr base
  iface="$(ip route show default 2>/dev/null | awk '{print $5; exit}')"
  cidr="$(ip -4 -o addr show "${iface}" 2>/dev/null | awk '{print $4; exit}')"
  if [[ -z "${cidr}" ]]; then
    echo "No IPv4 address found. Connect Ethernet/Wi‑Fi in the live session first."
    return 0
  fi
  echo "Interface: ${iface}  Address: ${cidr}"
  base="$(echo "${cidr}" | cut -d/ -f1 | awk -F. '{print $1"."$2"."$3}')"
  echo "Scanning ${base}.1–254 for hosts that answer ping or TCP/445 (SMB)..."
  echo "(this can take a minute)"
  echo

  local i alive=0
  for i in $(seq 1 254); do
    local ip="${base}.${i}"
    if ping -c 1 -W 1 "${ip}" >/dev/null 2>&1; then
      local smb="no"
      if command -v bash >/dev/null 2>&1; then
        if timeout 1 bash -c "echo >/dev/tcp/${ip}/445" 2>/dev/null; then
          smb="SMB"
        fi
      fi
      printf "  %-16s  ping=yes  %s\n" "${ip}" "${smb}"
      alive=$((alive + 1))
    fi
  done
  echo
  echo "Found ${alive} host(s) responding to ping."
  echo "Use option 3 to connect to a Windows share (IP + share name + user/password)."
}

# ---- SMB mount / browse ----
list_smb_shares() {
  local host="$1"
  local user="$2"
  local pass="$3"
  need_cmd smbclient "smbclient" || return 1
  echo "${BLD}Shares on ${host}:${RST}"
  if [[ -n "${pass}" ]]; then
    smbclient -L "//${host}" -U "${user}%${pass}" 2>/dev/null || smbclient -L "//${host}" -U "${user}" --password="${pass}" 2>/dev/null || {
      echo "${RED}Could not list shares. Check IP, username, password, firewall.${RST}"
      return 1
    }
  else
    smbclient -L "//${host}" -U "${user}" -N 2>/dev/null || smbclient -L "//${host}" -U "${user}" 2>/dev/null || {
      echo "${RED}Could not list shares.${RST}"
      return 1
    }
  fi
}

mount_smb_share() {
  local host="$1"
  local share="$2"
  local user="$3"
  local pass="$4"
  local mpoint="${MOUNT_ROOT}/${host}_${share}"
  mpoint="$(echo "${mpoint}" | tr -c 'A-Za-z0-9._/-' '_')"

  need_cmd mount.cifs "cifs-utils" || return 1
  mkdir -p "${mpoint}"

  if findmnt "${mpoint}" >/dev/null 2>&1; then
    echo "Already mounted at ${mpoint}"
    echo "${mpoint}"
    return 0
  fi

  local opts="uid=0,gid=0,iocharset=utf8,file_mode=0644,dir_mode=0755"
  # Windows XP often needs NT1; Win7/10 prefer SMB2/3 — try vers=default first then fallbacks
  if [[ -n "${pass}" ]]; then
    if mount -t cifs "//${host}/${share}" "${mpoint}" -o "username=${user},password=${pass},${opts}" 2>/dev/null \
      || mount -t cifs "//${host}/${share}" "${mpoint}" -o "username=${user},password=${pass},${opts},vers=3.0" 2>/dev/null \
      || mount -t cifs "//${host}/${share}" "${mpoint}" -o "username=${user},password=${pass},${opts},vers=2.0" 2>/dev/null \
      || mount -t cifs "//${host}/${share}" "${mpoint}" -o "username=${user},password=${pass},${opts},vers=1.0" 2>/dev/null; then
      echo "${GRN}Mounted //${host}/${share} → ${mpoint}${RST}"
      echo "${mpoint}"
      return 0
    fi
  else
    if mount -t cifs "//${host}/${share}" "${mpoint}" -o "username=${user},guest,${opts}" 2>/dev/null \
      || mount -t cifs "//${host}/${share}" "${mpoint}" -o "username=${user},${opts},vers=1.0" 2>/dev/null; then
      echo "${GRN}Mounted //${host}/${share} → ${mpoint}${RST}"
      echo "${mpoint}"
      return 0
    fi
  fi
  echo "${RED}Mount failed for //${host}/${share}${RST}"
  return 1
}

connect_remote_flow() {
  local host share user pass mpoint
  echo "${BLD}Connect to another PC (Windows file share / SMB)${RST}"
  echo "Use an IP or computer name on your LAN (e.g. 192.168.1.50)."
  echo "You need a username/password that is allowed to access that PC's shares."
  echo
  read -r -p "Remote PC IP or name: " host
  [[ -z "${host}" ]] && { echo "Cancelled."; return 0; }
  read -r -p "Username (e.g. Administrator): " user
  user="${user:-guest}"
  read -r -s -p "Password (empty for guest/none): " pass
  echo

  echo
  list_smb_shares "${host}" "${user}" "${pass}" || true
  echo
  read -r -p "Share name to mount (e.g. C$ SharedDocs Data): " share
  [[ -z "${share}" ]] && { echo "Cancelled."; return 0; }

  # Capture only last line as path if mount prints messages
  if mpoint="$(mount_smb_share "${host}" "${share}" "${user}" "${pass}" | tee /dev/stderr | tail -1)"; then
    if [[ -d "${mpoint}" ]]; then
      echo
      echo "${BLD}Contents of ${mpoint}:${RST}"
      ls -lah "${mpoint}" | head -50
      echo
      echo "Use copy option with this path as source or destination."
    fi
  fi
}

list_active_mounts() {
  echo "${BLD}Network shares mounted by this kit:${RST}"
  echo
  local found=0
  local d
  for d in "${MOUNT_ROOT}"/*; do
    [[ -d "${d}" ]] || continue
    if findmnt "${d}" >/dev/null 2>&1; then
      echo "  ${d}"
      findmnt -n -o SOURCE,FSTYPE,OPTIONS "${d}" 2>/dev/null | sed 's/^/    /'
      found=1
    fi
  done
  if [[ "${found}" -eq 0 ]]; then
    echo "  (none — use Connect to remote PC first)"
  fi
  echo
  echo "${BLD}Other useful mounts:${RST}"
  findmnt -t cifs,smb3,iso9660,udf,vfat,ntfs,exfat -o TARGET,SOURCE,FSTYPE,SIZE,AVAIL 2>/dev/null || true
}

unmount_all_network() {
  local d
  for d in "${MOUNT_ROOT}"/*; do
    [[ -d "${d}" ]] || continue
    if findmnt "${d}" >/dev/null 2>&1; then
      echo "Unmounting ${d}..."
      umount "${d}" 2>/dev/null || umount -l "${d}" 2>/dev/null || echo "  failed: ${d}"
    fi
  done
  echo "Done."
}

# ---- copy ----
browse_path() {
  local path="$1"
  if [[ ! -e "${path}" ]]; then
    echo "Path not found: ${path}"
    return 1
  fi
  echo "${BLD}${path}${RST}"
  if [[ -d "${path}" ]]; then
    df -h "${path}" 2>/dev/null | tail -1 | awk '{print "  Free: "$4" / Size: "$2"  ("$5" used)"}'
    echo
    ls -lah "${path}" | head -60
  else
    ls -lah "${path}"
  fi
}

copy_flow() {
  local src dst
  echo "${BLD}Copy files / folders${RST}"
  echo
  echo "Examples of sources / destinations:"
  echo "  Local disk:   /mnt/data   /media/ubuntu/Data"
  echo "  USB stick:    /media/.../VENTOY"
  echo "  CD/DVD:       /mnt/cd     /media/.../CDROM"
  echo "  Network:      ${MOUNT_ROOT}/<host>_<share>/..."
  echo "  Kit folder:   ${TOOL_DIR}/backups/transfers/"
  echo
  list_active_mounts
  echo
  read -r -p "SOURCE path (file or folder): " src
  [[ -z "${src}" ]] && { echo "Cancelled."; return 0; }
  if [[ ! -e "${src}" ]]; then
    echo "${RED}Source does not exist: ${src}${RST}"
    return 1
  fi
  echo
  browse_path "${src}" || true
  echo
  read -r -p "DESTINATION folder: " dst
  [[ -z "${dst}" ]] && { echo "Cancelled."; return 0; }
  mkdir -p "${dst}" 2>/dev/null || {
    echo "${RED}Cannot create/use destination: ${dst}${RST}"
    return 1
  }

  echo
  echo "Will copy:"
  echo "  FROM: ${src}"
  echo "  TO:   ${dst}/"
  read -r -p "Type YES to copy: " ok
  [[ "${ok}" != "YES" ]] && { echo "Cancelled."; return 0; }

  echo
  echo "Copying (preserving times; shows progress if possible)..."
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --info=progress2 "${src}" "${dst}/" || rsync -a --progress "${src}" "${dst}/"
  elif [[ -d "${src}" ]]; then
    cp -a "${src}" "${dst}/"
  else
    cp -a "${src}" "${dst}/"
  fi
  sync
  echo
  echo "${GRN}Copy finished.${RST}"
  echo "Destination listing:"
  ls -lah "${dst}" | head -40
}

# ---- submenu ----
while true; do
  clear 2>/dev/null || true
  echo "${BLD}${CYN}========================================${RST}"
  echo "${BLD}${CYN}   Network & Storage Transfer${RST}"
  echo "${BLD}${CYN}========================================${RST}"
  echo
  echo "Browse disks on this PC and shares on other PCs, then copy either way."
  echo "${YLW}Only access PCs/shares you are allowed to use.${RST}"
  echo
  echo "  1) Show local disks / USB / CD on this PC"
  echo "  2) Scan network for other PCs"
  echo "  3) Connect to remote PC share (SMB) + list files"
  echo "  4) Show mounted network / media paths"
  echo "  5) Copy file/folder (local ↔ network ↔ CD ↔ USB)"
  echo "  6) Unmount all kit network shares"
  echo "  7) Back to main menu"
  echo
  read -r -p "Choose option [1-7]: " choice || true
  [[ -z "${choice}" ]] && exit 0
  case "${choice}" in
    1) clear 2>/dev/null || true; show_local_storage; mount_local_hint; pause ;;
    2) clear 2>/dev/null || true; scan_lan; pause ;;
    3) clear 2>/dev/null || true; connect_remote_flow; pause ;;
    4) clear 2>/dev/null || true; list_active_mounts; pause ;;
    5) clear 2>/dev/null || true; copy_flow; pause ;;
    6) clear 2>/dev/null || true; unmount_all_network; pause ;;
    7) exit 0 ;;
    *) echo "Invalid choice."; pause ;;
  esac
done
