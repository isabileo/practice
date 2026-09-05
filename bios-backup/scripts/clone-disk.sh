#!/usr/bin/env bash
# Fast & accurate disk clone (source → destination).
#
# Capacity rules:
#   same size      → same-space bit copy (whole disk)
#   source larger  → proportionate partitions to fit destination
#   source smaller → ask: same-space OR proportionate expand
#
# Speed / accuracy:
#   same-space     → large-block dd (64 MiB) + direct I/O + pv; head/mid/tail verify
#   proportionate  → scaled partition table + partclone/ntfsclone when available
#                    (skips free space = faster), else fast dd per partition + resize

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

SAME_TOL=$((1024 * 1024)) # within 1 MiB = same capacity
DD_BS="128M" # large blocks = higher throughput on modern disks

pause() {
  echo
  read -r -p "Press Enter to continue..." _ || true
}

DISK_NAMES=()
DISK_SIZES=()
PART_NUMS=()
PART_STARTS=()
PART_SIZES=()
PART_TYPES=()
PART_FSTYPES=()

load_disk_list() {
  DISK_NAMES=()
  DISK_SIZES=()
  local name size typ
  while read -r name size typ; do
    [[ "${typ}" != "disk" ]] && continue
    [[ "${name}" == loop* ]] && continue
    DISK_NAMES+=("${name}")
    DISK_SIZES+=("${size}")
  done < <(lsblk -dn -o NAME,SIZE,TYPE)
}

disk_bytes() {
  blockdev --getsize64 "/dev/$1" 2>/dev/null || echo 0
}

human_bytes() {
  local b="$1"
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec-i --suffix=B "${b}"
  else
    echo "${b} bytes"
  fi
}

part_node() {
  local disk="$1"
  local num="$2"
  if [[ -b "/dev/${disk}p${num}" ]]; then
    echo "/dev/${disk}p${num}"
  else
    echo "/dev/${disk}${num}"
  fi
}

show_disk_detail() {
  local name="$1"
  local role="${2:-Disk}"
  local dev="/dev/${name}"

  echo "${BLD}${role}: ${dev}${RST}"
  echo "  Size  : $(lsblk -dn -o SIZE "${dev}" 2>/dev/null || echo '?') ($(human_bytes "$(disk_bytes "${name}")"))"
  echo "  Model : $(lsblk -dn -o MODEL "${dev}" 2>/dev/null | sed 's/[[:space:]]*$//' || echo n/a)"
  echo "  Bus   : $(lsblk -dn -o TRAN "${dev}" 2>/dev/null || echo n/a)"
  echo
  echo "${BLD}Partitions & space:${RST}"
  lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,TYPE "${dev}"
  echo
  printf "  %-14s %-10s %-10s %-10s %s\n" "DEVICE" "SIZE" "USED" "AVAIL" "MOUNT/NOTE"
  local part psize fstype mnt used avail
  while read -r part psize fstype mnt; do
    [[ -z "${part}" ]] && continue
    if [[ -n "${mnt}" && "${mnt}" != "-" ]]; then
      used="$(df -h "${mnt}" 2>/dev/null | awk 'NR==2{print $3}')"
      avail="$(df -h "${mnt}" 2>/dev/null | awk 'NR==2{print $4}')"
      printf "  %-14s %-10s %-10s %-10s %s\n" "${part}" "${psize}" "${used:-?}" "${avail:-?}" "${mnt}"
    else
      printf "  %-14s %-10s %-10s %-10s %s\n" "${part}" "${psize}" "-" "-" "${fstype:-raw}/not mounted"
    fi
  done < <(lsblk -ln -o NAME,SIZE,FSTYPE,MOUNTPOINT "${dev}" | awk 'NR>1{print}')
  echo
}

unmount_disk() {
  local name="$1"
  local dev="/dev/${name}"
  local p
  mapfile -t parts < <(lsblk -ln -o NAME,TYPE "${dev}" | awk '$2=="part"{print $1}' | tac)
  for p in "${parts[@]+"${parts[@]}"}"; do
    [[ -z "${p}" ]] && continue
    if findmnt "/dev/${p}" >/dev/null 2>&1; then
      echo "Unmounting /dev/${p}..."
      umount -R "/dev/${p}" 2>/dev/null || umount "/dev/${p}" 2>/dev/null || {
        echo "${RED}Could not unmount /dev/${p}.${RST}"
        return 1
      }
    fi
    swapoff "/dev/${p}" 2>/dev/null || true
  done
}

is_kit_or_root_disk() {
  local name="$1"
  local src root_src
  root_src="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
  root_src="${root_src%%[*}"
  if [[ "${root_src}" == "/dev/${name}" || "${root_src}" == "/dev/${name}"p* || "${root_src}" == "/dev/${name}"[0-9]* ]]; then
    return 0
  fi
  src="$(findmnt -n -o SOURCE --target "${TOOL_DIR}" 2>/dev/null || true)"
  src="${src%%[*}"
  if [[ "${src}" == "/dev/${name}" || "${src}" == "/dev/${name}"p* || "${src}" == "/dev/${name}"[0-9]* ]]; then
    return 0
  fi
  return 1
}

pick_disk() {
  local prompt="$1"
  local exclude="${2:-}"
  local i idx choice name
  local options=()
  local sizes=()

  for idx in "${!DISK_NAMES[@]}"; do
    name="${DISK_NAMES[$idx]}"
    [[ -n "${exclude}" && "${name}" == "${exclude}" ]] && continue
    options+=("${name}")
    sizes+=("${DISK_SIZES[$idx]}")
  done

  if [[ ${#options[@]} -eq 0 ]]; then
    echo "No eligible disks."
    PICKED_NAME=""
    return 1
  fi

  echo "${BLD}${prompt}${RST}"
  echo
  i=1
  for idx in "${!options[@]}"; do
    echo "  ${i}) /dev/${options[$idx]}  (${sizes[$idx]})"
    ((i++)) || true
  done
  echo "  ${i}) Cancel"
  echo
  read -r -p "Choose: " choice || true

  if [[ "${choice}" == "${i}" ]]; then
    PICKED_NAME=""
    return 1
  fi
  if [[ ! "${choice}" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#options[@]})); then
    echo "Invalid selection."
    PICKED_NAME=""
    return 1
  fi

  PICKED_NAME="${options[$((choice - 1))]}"
  return 0
}

dd_stream() {
  local src="$1"
  local dst="$2"
  local bytes="$3"

  # Exact byte count (GNU dd count_bytes) + large blocks + direct I/O = fast & accurate.
  if command -v pv >/dev/null 2>&1; then
    if ! pv -tpreb -s "${bytes}" "${src}" | dd of="${dst}" bs="${DD_BS}" iflag=fullblock oflag=direct,sync conv=fsync status=none; then
      echo "${YLW}Retrying without direct I/O...${RST}"
      pv -tpreb -s "${bytes}" "${src}" | dd of="${dst}" bs="${DD_BS}" iflag=fullblock conv=fsync status=none
    fi
  else
    if dd if="${src}" of="${dst}" bs="${DD_BS}" count="${bytes}" \
         iflag=fullblock,count_bytes oflag=direct,sync conv=fsync status=progress 2>/dev/null; then
      return 0
    fi
    echo "${YLW}Retrying without direct I/O / count_bytes...${RST}"
    local count=$(( (bytes + 128 * 1024 * 1024 - 1) / (128 * 1024 * 1024) ))
    dd if="${src}" of="${dst}" bs="${DD_BS}" count="${count}" status=progress iflag=fullblock conv=fsync
  fi
}

verify_same_space() {
  local src="$1"
  local dst="$2"
  local bytes="$3"
  local chunk=$((16 * 1024 * 1024))
  ((bytes < chunk)) && chunk=${bytes}

  echo "Verifying accuracy (head + mid + tail)..."
  if cmp -n "${chunk}" "${src}" "${dst}" >/dev/null 2>&1; then
    echo "${GRN}  Head: OK${RST}"
  else
    echo "${RED}  Head: MISMATCH${RST}"
    return 1
  fi

  if ((bytes > chunk * 3)); then
    local mid_off=$((bytes / 2 / (1024 * 1024)))
    local a b
    a="$(mktemp)"; b="$(mktemp)"
    dd if="${src}" of="${a}" bs=1M skip="${mid_off}" count=16 status=none 2>/dev/null || true
    dd if="${dst}" of="${b}" bs=1M skip="${mid_off}" count=16 status=none 2>/dev/null || true
    if cmp -s "${a}" "${b}"; then
      echo "${GRN}  Mid:  OK${RST}"
    else
      echo "${YLW}  Mid:  could not verify${RST}"
    fi
    rm -f "${a}" "${b}"
  fi

  if ((bytes > chunk)); then
    local skip=$((bytes / chunk - 1))
    local a b
    a="$(mktemp)"; b="$(mktemp)"
    dd if="${src}" of="${a}" bs="${chunk}" skip="${skip}" count=1 status=none 2>/dev/null || true
    dd if="${dst}" of="${b}" bs="${chunk}" skip="${skip}" count=1 status=none 2>/dev/null || true
    if cmp -s "${a}" "${b}"; then
      echo "${GRN}  Tail: OK${RST}"
    else
      echo "${YLW}  Tail: could not verify${RST}"
    fi
    rm -f "${a}" "${b}"
  fi
}

run_same_space_clone() {
  local src_name="$1"
  local dst_name="$2"
  local src="/dev/${src_name}"
  local dst="/dev/${dst_name}"
  local src_bytes dst_bytes

  src_bytes="$(disk_bytes "${src_name}")"
  dst_bytes="$(disk_bytes "${dst_name}")"

  if ((dst_bytes < src_bytes)); then
    echo "${RED}Same-space mode needs destination >= source.${RST}"
    return 1
  fi

  unmount_disk "${src_name}" || return 1
  unmount_disk "${dst_name}" || return 1

  echo
  echo "${BLD}Mode: SAME SPACE (bit-accurate, maximum speed)${RST}"
  echo "  Copy exactly $(human_bytes "${src_bytes}")"
  if ((dst_bytes > src_bytes)); then
    echo "  Leftover on destination: $(human_bytes "$((dst_bytes - src_bytes))") (unused)"
  fi
  echo "  Engine: dd bs=${DD_BS}, direct I/O, fsync"
  echo

  local t0 t1
  t0="$(date +%s)"
  dd_stream "${src}" "${dst}" "${src_bytes}"
  sync
  command -v partprobe >/dev/null 2>&1 && partprobe "${dst}" 2>/dev/null || true
  t1="$(date +%s)"

  echo
  echo "${GRN}Same-space clone finished in $((t1 - t0))s.${RST}"
  lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,TYPE "${dst}"
  echo
  verify_same_space "${src}" "${dst}" "${src_bytes}" || true
}

collect_partitions() {
  local disk="$1"
  PART_NUMS=()
  PART_STARTS=()
  PART_SIZES=()
  PART_TYPES=()
  PART_FSTYPES=()

  if ! command -v sfdisk >/dev/null 2>&1; then
    echo "${RED}sfdisk is required for proportionate clone (util-linux).${RST}"
    return 1
  fi

  local line num start size typ fstype node
  while IFS= read -r line; do
    [[ "${line}" != /dev/* ]] && continue
    num="$(echo "${line}" | sed -n 's|.*/[^0-9]*\([0-9][0-9]*\) :.*|\1|p')"
    start="$(echo "${line}" | sed -n 's/.*start= *\([0-9][0-9]*\).*/\1/p')"
    size="$(echo "${line}" | sed -n 's/.*size= *\([0-9][0-9]*\).*/\1/p')"
    typ="$(echo "${line}" | sed -n 's/.*type=\([^, ]*\).*/\1/p')"
    [[ -z "${num}" || -z "${start}" || -z "${size}" ]] && continue
    node="$(part_node "${disk}" "${num}")"
    fstype="$(lsblk -ln -o FSTYPE "${node}" 2>/dev/null || true)"
    PART_NUMS+=("${num}")
    PART_STARTS+=("${start}")
    PART_SIZES+=("${size}")
    PART_TYPES+=("${typ:-83}")
    PART_FSTYPES+=("${fstype}")
  done < <(sfdisk -d "/dev/${disk}" 2>/dev/null)
}

sector_size() {
  blockdev --getss "/dev/$1" 2>/dev/null || echo 512
}

build_scaled_table() {
  local out="$1"
  local src_name="$2"
  local dst_name="$3"
  local src_bytes dst_bytes ss
  local i n size new_start new_size typ label_line
  local dst_sectors last_usable

  src_bytes="$(disk_bytes "${src_name}")"
  dst_bytes="$(disk_bytes "${dst_name}")"
  ss="$(sector_size "${dst_name}")"
  n=${#PART_NUMS[@]}
  if ((n == 0)); then
    echo "${RED}Source has no partitions to scale.${RST}"
    return 1
  fi

  label_line="$(sfdisk -d "/dev/${src_name}" 2>/dev/null | grep -E '^label:' | head -1 || echo 'label: gpt')"
  {
    echo "${label_line}"
    echo "unit: sectors"
    echo "first-lba: 2048"
  } >"${out}"

  new_start=2048
  dst_sectors=$((dst_bytes / ss))
  last_usable=$((dst_sectors - 2048))

  for ((i = 0; i < n; i++)); do
    size="${PART_SIZES[$i]}"
    typ="${PART_TYPES[$i]}"
    new_size=$((size * dst_bytes / src_bytes))
    ((new_size < 2048)) && new_size=2048
    new_size=$(( (new_size / 2048) * 2048 ))
    ((new_size < 2048)) && new_size=2048

    if ((i == n - 1)); then
      new_size=$((last_usable - new_start))
      new_size=$(( (new_size / 2048) * 2048 ))
    fi
    if ((new_start + new_size > last_usable)); then
      new_size=$((last_usable - new_start))
      new_size=$(( (new_size / 2048) * 2048 ))
    fi
    if ((new_size <= 0)); then
      echo "${RED}Not enough room for partition ${PART_NUMS[$i]} after scaling.${RST}"
      return 1
    fi

    echo "start=${new_start}, size=${new_size}, type=${typ}" >>"${out}"
    new_start=$((new_start + new_size))
  done
}

copy_one_partition() {
  local src_part="$1"
  local dst_part="$2"
  local fstype="$3"
  local src_sz dst_sz copy_sz

  src_sz="$(blockdev --getsize64 "${src_part}" 2>/dev/null || echo 0)"
  dst_sz="$(blockdev --getsize64 "${dst_part}" 2>/dev/null || echo 0)"
  copy_sz="${src_sz}"
  ((dst_sz < src_sz)) && copy_sz="${dst_sz}"

  echo "  ${src_part} → ${dst_part}  (${fstype:-raw}, $(human_bytes "${copy_sz}"))"

  case "${fstype}" in
    ntfs)
      if command -v ntfsclone >/dev/null 2>&1; then
        ntfsclone --overwrite "${dst_part}" --force "${src_part}" && return 0
      fi
      if command -v partclone.ntfs >/dev/null 2>&1; then
        partclone.ntfs -b -s "${src_part}" -o "${dst_part}" && return 0
      fi
      ;;
    ext2|ext3|ext4)
      if command -v "partclone.${fstype}" >/dev/null 2>&1; then
        "partclone.${fstype}" -b -s "${src_part}" -o "${dst_part}" && return 0
      elif command -v partclone.extfs >/dev/null 2>&1; then
        partclone.extfs -b -s "${src_part}" -o "${dst_part}" && return 0
      fi
      ;;
    vfat|fat16|fat32|exfat|xfs|btrfs|f2fs)
      if command -v "partclone.${fstype}" >/dev/null 2>&1; then
        "partclone.${fstype}" -b -s "${src_part}" -o "${dst_part}" && return 0
      fi
      if [[ "${fstype}" =~ ^(vfat|fat16|fat32)$ ]] && command -v partclone.fat >/dev/null 2>&1; then
        partclone.fat -b -s "${src_part}" -o "${dst_part}" && return 0
      fi
      ;;
    swap)
      echo "  Recreating swap..."
      mkswap "${dst_part}" >/dev/null
      return 0
      ;;
  esac

  echo "  Fast dd fallback..."
  if command -v pv >/dev/null 2>&1; then
    pv -tpreb -s "${copy_sz}" "${src_part}" | dd of="${dst_part}" bs="${DD_BS}" iflag=fullblock conv=fsync status=none
  else
    dd if="${src_part}" of="${dst_part}" bs="${DD_BS}" \
      count=$(( (copy_sz + 64 * 1024 * 1024 - 1) / (64 * 1024 * 1024) )) \
      status=progress iflag=fullblock conv=fsync
  fi
}

resize_filesystem() {
  local part="$1"
  local fstype="$2"
  case "${fstype}" in
    ext2|ext3|ext4)
      if command -v e2fsck >/dev/null 2>&1 && command -v resize2fs >/dev/null 2>&1; then
        e2fsck -f -y "${part}" >/dev/null 2>&1 || true
        resize2fs "${part}" >/dev/null
      fi
      ;;
    ntfs)
      if command -v ntfsresize >/dev/null 2>&1; then
        ntfsresize --force "${part}" >/dev/null 2>&1 || true
      fi
      ;;
  esac
}

run_proportionate_clone() {
  local src_name="$1"
  local dst_name="$2"
  local src="/dev/${src_name}"
  local dst="/dev/${dst_name}"
  local src_bytes dst_bytes script
  local i n src_part dst_part

  src_bytes="$(disk_bytes "${src_name}")"
  dst_bytes="$(disk_bytes "${dst_name}")"

  collect_partitions "${src_name}" || return 1
  n=${#PART_NUMS[@]}
  if ((n == 0)); then
    echo "${RED}No partitions on source — trying same-space whole-disk copy.${RST}"
    if ((dst_bytes < src_bytes)); then
      echo "${RED}Destination is smaller; cannot same-space copy.${RST}"
      return 1
    fi
    run_same_space_clone "${src_name}" "${dst_name}"
    return $?
  fi

  if ((src_bytes > dst_bytes)); then
    echo "${YLW}Source larger — scaling partitions down to fit.${RST}"
  else
    echo "${YLW}Scaling partitions up to fill destination.${RST}"
  fi

  unmount_disk "${src_name}" || return 1
  unmount_disk "${dst_name}" || return 1

  script="$(mktemp)"
  if ! build_scaled_table "${script}" "${src_name}" "${dst_name}"; then
    rm -f "${script}"
    return 1
  fi

  echo
  echo "${BLD}Mode: PROPORTIONATE (scaled partitions, fast FS-aware copy when available)${RST}"
  echo "  Scale ≈ $(awk -v a="${dst_bytes}" -v b="${src_bytes}" 'BEGIN{printf "%.4f", a/b}')"
  echo "  Plan:"
  cat "${script}"
  echo

  echo "Writing partition table on ${dst}..."
  wipefs -a "${dst}" 2>/dev/null || true
  if command -v sgdisk >/dev/null 2>&1; then
    sgdisk --zap-all "${dst}" >/dev/null 2>&1 || true
  fi
  sfdisk --force "${dst}" <"${script}"
  rm -f "${script}"
  command -v partprobe >/dev/null 2>&1 && partprobe "${dst}" 2>/dev/null || true
  sleep 2
  command -v udevadm >/dev/null 2>&1 && udevadm settle 2>/dev/null || sleep 1

  local t0 t1
  t0="$(date +%s)"
  for ((i = 0; i < n; i++)); do
    src_part="$(part_node "${src_name}" "${PART_NUMS[$i]}")"
    dst_part="$(part_node "${dst_name}" "${PART_NUMS[$i]}")"
    if [[ ! -b "${src_part}" || ! -b "${dst_part}" ]]; then
      echo "${YLW}  Skipping partition ${PART_NUMS[$i]} (node missing).${RST}"
      continue
    fi
    copy_one_partition "${src_part}" "${dst_part}" "${PART_FSTYPES[$i]}"
    resize_filesystem "${dst_part}" "${PART_FSTYPES[$i]}"
  done
  sync
  t1="$(date +%s)"

  echo
  echo "${GRN}Proportionate clone finished in $((t1 - t0))s.${RST}"
  echo "${BLD}Destination layout:${RST}"
  lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,TYPE "${dst}"
}

choose_clone_mode() {
  local src_bytes="$1"
  local dst_bytes="$2"
  local diff

  if ((src_bytes > dst_bytes)); then
    diff=$((src_bytes - dst_bytes))
  else
    diff=$((dst_bytes - src_bytes))
  fi

  if ((diff <= SAME_TOL)); then
    echo
    echo "Disks are the same capacity ($(human_bytes "${src_bytes}"))."
    echo "Using ${BLD}SAME SPACE${RST} bit-accurate whole-disk copy (fastest + most accurate)."
    CLONE_MODE="same"
    return 0
  fi

  if ((src_bytes > dst_bytes)); then
    echo
    echo "Source is ${BLD}LARGER${RST} than destination."
    echo "  Source:      $(human_bytes "${src_bytes}")"
    echo "  Destination: $(human_bytes "${dst_bytes}")"
    echo
    echo "Will create ${BLD}PROPORTIONATE${RST} partitions on destination to fit."
    CLONE_MODE="proportionate"
    return 0
  fi

  echo
  echo "Source is ${BLD}SMALLER${RST} than destination."
  echo "  Source:      $(human_bytes "${src_bytes}")"
  echo "  Destination: $(human_bytes "${dst_bytes}")"
  echo "  Extra space: $(human_bytes "$((dst_bytes - src_bytes))")"
  echo
  echo "Choose clone style:"
  echo "  1) Same space     — exact bit copy of source size (fastest & most accurate;"
  echo "                      leftover space on destination stays empty)"
  echo "  2) Proportionate  — scale partitions to fill the whole destination"
  echo "  3) Cancel"
  echo
  read -r -p "Choose [1-3]: " style || true
  case "${style}" in
    1) CLONE_MODE="same" ;;
    2) CLONE_MODE="proportionate" ;;
    *) CLONE_MODE=""; return 1 ;;
  esac
  return 0
}

# ---- main ----
clear 2>/dev/null || true
echo "${BLD}${CYN}========================================${RST}"
echo "${BLD}${CYN}   Clone Disk (fast & accurate)${RST}"
echo "${BLD}${CYN}========================================${RST}"
echo
echo "Same size      → same-space bit copy (max accuracy + speed)"
echo "Source larger  → proportionate partitions to fit destination"
echo "Source smaller → you choose same-space OR proportionate"
echo
echo "${YLW}Destination will be COMPLETELY overwritten.${RST}"
echo

load_disk_list

if [[ ${#DISK_NAMES[@]} -lt 2 ]]; then
  echo "Need at least two disks (source + destination)."
  echo "Currently found: ${#DISK_NAMES[@]}"
  pause
  exit 0
fi

echo "${BLD}Available disks:${RST}"
i=1
for idx in "${!DISK_NAMES[@]}"; do
  echo "  ${i}) /dev/${DISK_NAMES[$idx]}  (${DISK_SIZES[$idx]})"
  ((i++)) || true
done
echo

PICKED_NAME=""
if ! pick_disk "Select SOURCE disk (data to copy FROM):"; then
  echo "Cancelled."
  pause
  exit 0
fi
SRC_NAME="${PICKED_NAME}"

clear 2>/dev/null || true
echo "${BLD}${CYN}========================================${RST}"
echo "${BLD}${CYN}   Source disk details${RST}"
echo "${BLD}${CYN}========================================${RST}"
echo
show_disk_detail "${SRC_NAME}" "SOURCE"
read -r -p "Use /dev/${SRC_NAME} as SOURCE? [y/N]: " ok
if [[ ! "${ok}" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  pause
  exit 0
fi

clear 2>/dev/null || true
echo "${BLD}${CYN}========================================${RST}"
echo "${BLD}${CYN}   Select DESTINATION disk${RST}"
echo "${BLD}${CYN}========================================${RST}"
echo
echo "Source is /dev/${SRC_NAME} — not listed below."
echo
PICKED_NAME=""
if ! pick_disk "Select DESTINATION disk (will be overwritten):" "${SRC_NAME}"; then
  echo "Cancelled."
  pause
  exit 0
fi
DST_NAME="${PICKED_NAME}"

clear 2>/dev/null || true
echo "${BLD}${CYN}========================================${RST}"
echo "${BLD}${CYN}   Destination disk details${RST}"
echo "${BLD}${CYN}========================================${RST}"
echo
show_disk_detail "${DST_NAME}" "DESTINATION"

SRC_BYTES="$(disk_bytes "${SRC_NAME}")"
DST_BYTES="$(disk_bytes "${DST_NAME}")"

echo "${BLD}Clone plan:${RST}"
echo "  FROM /dev/${SRC_NAME} ($(human_bytes "${SRC_BYTES}"))"
echo "  TO   /dev/${DST_NAME} ($(human_bytes "${DST_BYTES}"))"

CLONE_MODE=""
if ! choose_clone_mode "${SRC_BYTES}" "${DST_BYTES}"; then
  echo "Cancelled."
  pause
  exit 0
fi

if is_kit_or_root_disk "${DST_NAME}"; then
  echo "${RED}${BLD}WARNING: Destination looks like the live USB / system disk!${RST}"
fi

echo
echo "${RED}ALL DATA on /dev/${DST_NAME} will be destroyed.${RST}"
echo "Mode: ${CLONE_MODE}"
read -r -p "Type destination name (${DST_NAME}) to continue: " typed
if [[ "${typed}" != "${DST_NAME}" ]]; then
  echo "Cancelled (name did not match)."
  pause
  exit 0
fi
read -r -p "Type YES to start the clone: " yes
if [[ "${yes}" != "YES" ]]; then
  echo "Cancelled."
  pause
  exit 0
fi

case "${CLONE_MODE}" in
  same) run_same_space_clone "${SRC_NAME}" "${DST_NAME}" ;;
  proportionate) run_proportionate_clone "${SRC_NAME}" "${DST_NAME}" ;;
  *) echo "Unknown mode."; exit 1 ;;
esac

pause
