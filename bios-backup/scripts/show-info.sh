#!/usr/bin/env bash
set -euo pipefail

TOOL_DIR="${BIOS_TOOL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib.sh
source "${TOOL_DIR}/scripts/lib.sh"

echo "=== SMBIOS / board ==="
echo "BIOS vendor : $(dmi_field bios_vendor)"
echo "BIOS version: $(dmi_field bios_version)"
echo "BIOS date   : $(dmi_field bios_date)"
echo "Board       : $(dmi_field board_vendor) $(dmi_field board_name) $(dmi_field board_version)"
echo "Product     : $(dmi_field sys_vendor) $(dmi_field product_name)"
echo

if command -v flashrom >/dev/null 2>&1; then
  echo "=== flashrom probe (internal) ==="
  flashrom -p internal 2>&1 || true
else
  echo "flashrom not found — install it to copy/upload firmware."
fi
