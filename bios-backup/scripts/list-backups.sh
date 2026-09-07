#!/usr/bin/env bash
set -euo pipefail

TOOL_DIR="${BIOS_TOOL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BACKUP_ROOT="${BIOS_BACKUP_ROOT:-${TOOL_DIR}/backups}"

echo "Backups in: ${BACKUP_ROOT}"
echo

if [[ ! -d "${BACKUP_ROOT}" ]] || [[ -z "$(find "${BACKUP_ROOT}" -name 'bios.bin' 2>/dev/null | head -1)" ]]; then
  echo "(none yet — use Copy BIOS first)"
  exit 0
fi

find "${BACKUP_ROOT}" -type f -name 'bios.bin' -printf '%TY-%Tm-%Td %TH:%TM  %p  (%s bytes)\n' 2>/dev/null | sort
echo
if [[ -L "${BACKUP_ROOT}/latest" || -d "${BACKUP_ROOT}/latest" ]]; then
  echo "latest -> $(readlink -f "${BACKUP_ROOT}/latest" 2>/dev/null || echo "${BACKUP_ROOT}/latest")"
fi
