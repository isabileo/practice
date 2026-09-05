#!/usr/bin/env bash
# Disk / Drives submenu: list disks, show partitions & space,
# format a disk, or wipe all partitions (empty disk).

set -euo pipefail

TOOL_DIR="${BIOS_TOOL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib.sh
source "${TOOL_DIR}/scripts/lib.sh"

YLW=$'\033[33m'
RED=$'\033[31m'
BLD=$'\033[1m'
CYN=$'\033[36m'
RST=$'\033[0m'

pause() {
  echo
  read -r -p "Press Enter to continue..." _
}

# Returns 0 if DEV looks like it holds this live kit / current root disk.
is_risky_disk() {
  local dev="$1"
  local base src root_src part
  base="$(basename "${dev}")"

  root_src="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
  root_src="${root_src%%[*}" # drop mapper annotations
  if [[ "${root_src}" == "/dev/${base}" || "${root_src}" == "/dev/${base}"p* || "${root_src}" == "/dev/${base}"[0-9]* ]]; then
    return 0
  fi

  src="$(findmnt -n -o SOURCE --target "${TOOL_DIR}" 2>/dev/null || true)"
  src="${src%%[*}"
  if [[ "${src}" == "/dev/${base}" || "${src}" == "/dev/${base}"p* || "${src}" == "/dev/${base}"[0-9]* ]]; then
    return 0
  fi

  # Any mounted partition of this disk
  while read -r part; do
    [[ -z "${part}" ]] && continue
    if findmnt "/dev/${part}" >/dev/null 2>&1; then
      local mnt
      mnt="$(findmnt -n -o TARGET "/dev/${part}" 2>/dev/null || true)"
      if [[ -n "${mnt}" ]] && { [[ "${TOOL_DIR}" == "${mnt}"* ]] || [[ "${mnt}" == "/" ]]; }; then
        return 0
      fi
    fi
  done < <(lsblk -ln -o NAME,TYPE "${dev}" 2>/dev/null | awk '$2=="part"{print $1}')

  return 1
}

list_disks() {
  echo "${BLD}Disk drives on this PC:${RST}"
  echo
  if ! command -v lsblk >/dev/null 2>&1; then
    echo "lsblk not found. Install util-linux."
    return 1
  fi
  printf "  %-12s %-10s %-8s %s\n" "NAME" "SIZE" "BUS" "MODEL"
  local name size typ tran model
  while read -r name size typ tran model; do
    [[ "${typ}" != "disk" ]] && continue
    [[ "${name}" == loop* ]] && continue
    printf "  %-12s %-10s %-8s %s\n" "${name}" "${size}" "${tran:--}" "${model:--}"
  done < <(lsblk -dn -o NAME,SIZE,TYPE,TRAN,MODEL)
  echo
  echo "Full layout (disks + partitions):"
  lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,TYPE
}

# Fill global arrays DISK_NAMES DISK_SIZES from lsblk
load_disk_list() {
  DISK_NAMES=()
  DISK_SIZES=()
  local name size typ
  while read -r name size typ; do
    [[ "${typ}" != "disk" ]] && continue
    # skip obvious loop if any slip through
    [[ "${name}" == loop* ]] && continue
    DISK_NAMES+=("${name}")
    DISK_SIZES+=("${size}")
  done < <(lsblk -dn -o NAME,SIZE,TYPE)
}

show_disk_partitions() {
  local name="$1"
  local dev="/dev/${name}"

  echo "${BLD}Selected disk: ${dev}${RST}"
  echo

  if [[ ! -b "${dev}" ]]; then
    echo "Not a block device: ${dev}"
    return 1
  fi

  local size model tran
  size="$(lsblk -dn -o SIZE "${dev}" 2>/dev/null || echo "?")"
  model="$(lsblk -dn -o MODEL "${dev}" 2>/dev/null | sed 's/[[:space:]]*$//')"
  tran="$(lsblk -dn -o TRAN "${dev}" 2>/dev/null || echo "?")"

  echo "  Size     : ${size}"
  echo "  Model    : ${model:-n/a}"
  echo "  Bus      : ${tran:-n/a}"
  echo

  echo "${BLD}Partitions & space:${RST}"
  echo
  # Human table
  lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINT,TYPE "${dev}"
  echo

  # Free / used summary per partition if mounted or has size
  echo "${BLD}Space summary:${RST}"
  echo
  printf "  %-14s %-10s %-10s %-10s %s\n" "DEVICE" "SIZE" "USED" "AVAIL" "MOUNT/NOTE"
  local part psize used avail mnt fstype
  while read -r part psize fstype mnt; do
    [[ -z "${part}" ]] && continue
    if [[ -n "${mnt}" && "${mnt}" != "-" ]]; then
      used="$(df -h "${mnt}" 2>/dev/null | awk 'NR==2{print $3}')"
      avail="$(df -h "${mnt}" 2>/dev/null | awk 'NR==2{print $4}')"
      printf "  %-14s %-10s %-10s %-10s %s\n" "${part}" "${psize}" "${used:-?}" "${avail:-?}" "${mnt}"
    else
      printf "  %-14s %-10s %-10s %-10s %s\n" "${part}" "${psize}" "-" "-" "${fstype:-unformatted}/not mounted"
    fi
  done < <(lsblk -ln -o NAME,SIZE,FSTYPE,MOUNTPOINT "${dev}" | awk 'NR>1{print}')

  # Unallocated hint via parted if available
  if command -v parted >/dev/null 2>&1; then
    echo
    echo "${BLD}Partition table (parted):${RST}"
    parted -s "${dev}" unit GiB print free 2>/dev/null || parted -s "${dev}" print 2>/dev/null || echo "  (could not read table — disk may be empty/raw)"
  fi
}

unmount_disk() {
  local name="$1"
  local dev="/dev/${name}"
  local p
  # Unmount partitions in reverse order
  mapfile -t parts < <(lsblk -ln -o NAME,TYPE "${dev}" | awk '$2=="part"{print $1}' | tac)
  for p in "${parts[@]+"${parts[@]}"}"; do
    [[ -z "${p}" ]] && continue
    if findmnt "/dev/${p}" >/dev/null 2>&1; then
      echo "Unmounting /dev/${p}..."
      umount -R "/dev/${p}" 2>/dev/null || umount "/dev/${p}" 2>/dev/null || {
        echo "${RED}Could not unmount /dev/${p}. Close programs using it and retry.${RST}"
        return 1
      }
    fi
  done
  # swap off if any
  if command -v swapoff >/dev/null 2>&1; then
    for p in "${parts[@]+"${parts[@]}"}"; do
      swapoff "/dev/${p}" 2>/dev/null || true
    done
  fi
  return 0
}

confirm_destructive() {
  local name="$1"
  local action="$2"
  local dev="/dev/${name}"

  echo
  echo "${RED}${BLD}DANGER: ${action}${RST}"
  echo "${RED}Target: ${dev} — ALL DATA on this disk will be destroyed.${RST}"
  if is_risky_disk "${dev}"; then
    echo "${RED}${BLD}This looks like the disk holding your LIVE USB or system files!${RST}"
    echo "${RED}Formatting it can stop the session or erase this tool.${RST}"
  fi
  echo
  read -r -p "Type the disk name (${name}) to continue: " typed
  if [[ "${typed}" != "${name}" ]]; then
    echo "Cancelled (name did not match)."
    return 1
  fi
  read -r -p "Type YES to confirm ${action}: " yes
  if [[ "${yes}" != "YES" ]]; then
    echo "Cancelled."
    return 1
  fi
  return 0
}

wipe_partitions_only() {
  local name="$1"
  local dev="/dev/${name}"

  confirm_destructive "${name}" "DELETE ALL PARTITIONS (empty disk)" || return 0
  unmount_disk "${name}" || return 1

  echo "Wiping filesystem signatures on disk and partitions..."
  local p
  for p in $(lsblk -ln -o NAME,TYPE "${dev}" | awk '$2=="part"{print $1}'); do
    wipefs -a "/dev/${p}" 2>/dev/null || true
  done
  wipefs -a "${dev}" 2>/dev/null || true

  echo "Clearing partition table (disk will have no partitions)..."
  if command -v sgdisk >/dev/null 2>&1; then
    sgdisk --zap-all "${dev}"
  fi
  # Zero start (MBR/GPT) and a bit of the end (backup GPT)
  dd if=/dev/zero of="${dev}" bs=1M count=2 status=none conv=fsync 2>/dev/null || true
  if command -v blockdev >/dev/null 2>&1; then
    local sectors
    sectors="$(blockdev --getsz "${dev}" 2>/dev/null || echo 0)"
    if [[ "${sectors}" =~ ^[0-9]+$ ]] && ((sectors > 2048)); then
      dd if=/dev/zero of="${dev}" bs=512 seek=$((sectors - 2048)) count=2048 status=none conv=fsync 2>/dev/null || true
    fi
  fi

  if command -v partprobe >/dev/null 2>&1; then
    partprobe "${dev}" 2>/dev/null || true
  fi
  sleep 1
  echo
  echo "Done. Disk ${dev} has no partitions."
  show_disk_partitions "${name}"
}

format_disk() {
  local name="$1"
  local dev="/dev/${name}"
  local fstype label part

  echo "Choose filesystem for a single full-disk partition:"
  echo "  1) NTFS   (good for Windows)"
  echo "  2) FAT32  (USB / small disks, max 4GiB files)"
  echo "  3) exFAT  (large files, needs mkfs.exfat)"
  echo "  4) ext4   (Linux)"
  echo "  5) Cancel"
  echo
  read -r -p "Filesystem [1-5]: " fs_choice
  case "${fs_choice}" in
    1) fstype="ntfs" ;;
    2) fstype="fat32" ;;
    3) fstype="exfat" ;;
    4) fstype="ext4" ;;
    *) echo "Cancelled."; return 0 ;;
  esac

  read -r -p "Volume label (or Enter for none): " label
  label="${label// /_}"

  confirm_destructive "${name}" "FORMAT DISK as ${fstype}" || return 0
  unmount_disk "${name}" || return 1

  echo "Wiping old signatures and partition table..."
  wipefs -a "${dev}" 2>/dev/null || true
  if command -v sgdisk >/dev/null 2>&1; then
    sgdisk --zap-all "${dev}" >/dev/null
  else
    dd if=/dev/zero of="${dev}" bs=1M count=2 status=none conv=fsync 2>/dev/null || true
  fi

  echo "Creating new GPT + one primary partition..."
  if command -v parted >/dev/null 2>&1; then
    parted -s "${dev}" mklabel gpt
    parted -s "${dev}" mkpart primary 1MiB 100%
  elif command -v sgdisk >/dev/null 2>&1; then
    sgdisk --zap-all "${dev}" >/dev/null
    sgdisk -n 1:0:0 -t 1:0700 "${dev}"
  else
    echo "Need parted or sgdisk to create partitions."
    return 1
  fi

  if command -v partprobe >/dev/null 2>&1; then
    partprobe "${dev}" 2>/dev/null || true
  fi
  sleep 2

  # Resolve partition node (nvme uses p1, sd uses 1)
  if [[ -b "${dev}p1" ]]; then
    part="${dev}p1"
  elif [[ -b "${dev}1" ]]; then
    part="${dev}1"
  else
    # wait a bit more for udev
    sleep 2
    if [[ -b "${dev}p1" ]]; then
      part="${dev}p1"
    elif [[ -b "${dev}1" ]]; then
      part="${dev}1"
    else
      echo "Partition node not found after creating table."
      lsblk "${dev}"
      return 1
    fi
  fi

  echo "Formatting ${part} as ${fstype}..."
  case "${fstype}" in
    ntfs)
      if command -v mkfs.ntfs >/dev/null 2>&1; then
        if [[ -n "${label}" ]]; then
          mkfs.ntfs -f -L "${label}" "${part}"
        else
          mkfs.ntfs -f "${part}"
        fi
      else
        echo "mkfs.ntfs missing. Install ntfs-3g. Falling back to ext4."
        mkfs.ext4 -F ${label:+-L "${label}"} "${part}"
      fi
      ;;
    fat32)
      if [[ -n "${label}" ]]; then
        mkfs.vfat -F 32 -n "${label:0:11}" "${part}"
      else
        mkfs.vfat -F 32 "${part}"
      fi
      ;;
    exfat)
      if command -v mkfs.exfat >/dev/null 2>&1; then
        if [[ -n "${label}" ]]; then
          mkfs.exfat -n "${label}" "${part}"
        else
          mkfs.exfat "${part}"
        fi
      else
        echo "mkfs.exfat not installed."
        return 1
      fi
      ;;
    ext4)
      if [[ -n "${label}" ]]; then
        mkfs.ext4 -F -L "${label}" "${part}"
      else
        mkfs.ext4 -F "${part}"
      fi
      ;;
  esac

  echo
  echo "Format complete."
  show_disk_partitions "${name}"
}

disk_actions_menu() {
  local name="$1"
  local only_one="${2:-0}"
  local choice

  while true; do
    clear
    echo "${BLD}${CYN}========================================${RST}"
    if [[ "${only_one}" == "1" ]]; then
      echo "${BLD}${CYN}   Only disk: /dev/${name}${RST}"
    else
      echo "${BLD}${CYN}   Disk selected: /dev/${name}${RST}"
    fi
    echo "${BLD}${CYN}========================================${RST}"
    echo
    show_disk_partitions "${name}" || true
    echo
    echo "  1) Refresh — show partitions & space again"
    echo "  2) Format this disk (wipe + one new partition)"
    echo "  3) Delete all partitions (make disk with no partitions)"
    if [[ "${only_one}" == "1" ]]; then
      echo "  4) Back to main menu"
      echo
      read -r -p "Choose option [1-4]: " choice
      case "${choice}" in
        1) pause ;;
        2) format_disk "${name}"; pause ;;
        3) wipe_partitions_only "${name}"; pause ;;
        4) exit 0 ;;
        *) echo "Invalid choice."; pause ;;
      esac
    else
      echo "  4) Select another disk"
      echo "  5) Back to main menu"
      echo
      read -r -p "Choose option [1-5]: " choice
      case "${choice}" in
        1) pause ;;
        2) format_disk "${name}"; pause ;;
        3) wipe_partitions_only "${name}"; pause ;;
        4) return 0 ;;
        5) exit 0 ;;
        *) echo "Invalid choice."; pause ;;
      esac
    fi
  done
}

select_disk_flow() {
  local choice idx
  load_disk_list

  if [[ ${#DISK_NAMES[@]} -eq 0 ]]; then
    echo "No disks found."
    pause
    return 0
  fi

  # Only one disk: skip selection and operate on it directly.
  if [[ ${#DISK_NAMES[@]} -eq 1 ]]; then
    echo "Only one disk found: /dev/${DISK_NAMES[0]} (${DISK_SIZES[0]})"
    echo "Opening disk operations (no selection needed)..."
    sleep 1
    disk_actions_menu "${DISK_NAMES[0]}" 1
    return 0
  fi

  clear
  echo "${BLD}${CYN}========================================${RST}"
  echo "${BLD}${CYN}   Select a disk drive${RST}"
  echo "${BLD}${CYN}========================================${RST}"
  echo
  list_disks
  echo
  echo "Select disk:"
  local i=1
  for ((i = 1; i <= ${#DISK_NAMES[@]}; i++)); do
    idx=$((i - 1))
    echo "  ${i}) /dev/${DISK_NAMES[$idx]}  (${DISK_SIZES[$idx]})"
  done
  echo "  ${i}) Back"
  echo
  read -r -p "Choose disk: " choice

  if [[ "${choice}" == "${i}" ]]; then
    return 0
  fi
  if [[ ! "${choice}" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#DISK_NAMES[@]})); then
    echo "Invalid selection."
    pause
    return 0
  fi

  idx=$((choice - 1))
  disk_actions_menu "${DISK_NAMES[$idx]}" 0
}

# ---- submenu entry ----
while true; do
  load_disk_list
  clear
  echo "${BLD}${CYN}========================================${RST}"
  echo "${BLD}${CYN}   Disk / Drives${RST}"
  echo "${BLD}${CYN}========================================${RST}"
  echo
  echo "${YLW}WARNING: Format / delete partitions erases all data on that disk.${RST}"
  echo "${YLW}Do NOT choose the USB stick you booted from unless you mean to.${RST}"
  echo

  # Single disk: go straight to operations (show / format / wipe).
  if [[ ${#DISK_NAMES[@]} -eq 1 ]]; then
    echo "Only one disk detected: /dev/${DISK_NAMES[0]} (${DISK_SIZES[0]})"
    echo "Skipping disk selection — opening operations on this disk."
    echo
    sleep 1
    disk_actions_menu "${DISK_NAMES[0]}" 1
    exit 0
  fi

  if [[ ${#DISK_NAMES[@]} -eq 0 ]]; then
    echo "No disks found."
    echo
    echo "  1) Refresh"
    echo "  2) Back to main menu"
    echo
    read -r -p "Choose option [1-2]: " main_choice
    case "${main_choice}" in
      1) continue ;;
      2) exit 0 ;;
      *) echo "Invalid choice."; pause ;;
    esac
    continue
  fi

  echo "  1) Show all disk drives (${#DISK_NAMES[@]} found)"
  echo "  2) Select a disk (partitions, format, wipe)"
  echo "  3) Back to main menu"
  echo
  read -r -p "Choose option [1-3]: " main_choice
  case "${main_choice}" in
    1) clear; list_disks; pause ;;
    2) select_disk_flow ;;
    3) exit 0 ;;
    *) echo "Invalid choice."; pause ;;
  esac
done
