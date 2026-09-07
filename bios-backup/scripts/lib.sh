#!/usr/bin/env bash
# Shared helpers for the BIOS USB kit.

dmi_field() {
  local f="/sys/class/dmi/id/$1"
  if [[ -r "${f}" ]]; then
    tr -d '\0' <"${f}" | head -c 200
  else
    echo "n/a"
  fi
}

require_flashrom() {
  if ! command -v flashrom >/dev/null 2>&1; then
    echo "flashrom is not installed in this live environment."
    echo "Install it (example on Debian/Ubuntu live):"
    echo "  sudo apt update && sudo apt install -y flashrom"
    echo "Or boot SystemRescue / a live image that already includes flashrom."
    exit 1
  fi
}

write_inventory() {
  local meta="$1"
  local json="$2"
  {
    echo "Captured: $(date -Is)"
    echo "bios_vendor: $(dmi_field bios_vendor)"
    echo "bios_version: $(dmi_field bios_version)"
    echo "bios_date: $(dmi_field bios_date)"
    echo "board_vendor: $(dmi_field board_vendor)"
    echo "board_name: $(dmi_field board_name)"
    echo "board_version: $(dmi_field board_version)"
    echo "product_name: $(dmi_field product_name)"
    echo "sys_vendor: $(dmi_field sys_vendor)"
  } | tee "${meta}"

  cat >"${json}" <<EOF
{
  "captured": "$(date -Is)",
  "bios_vendor": "$(dmi_field bios_vendor)",
  "bios_version": "$(dmi_field bios_version)",
  "bios_date": "$(dmi_field bios_date)",
  "board_vendor": "$(dmi_field board_vendor)",
  "board_name": "$(dmi_field board_name)",
  "board_version": "$(dmi_field board_version)",
  "product_name": "$(dmi_field product_name)",
  "sys_vendor": "$(dmi_field sys_vendor)"
}
EOF
}
