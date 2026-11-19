#!/usr/bin/env bash
# Rank 06 - offline hardware survey for the target; never installs or fails the install.
# Wire as shellprocess@driver_detect before packages.
# Evidence: /home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/scripts/cleaner_script.sh:35-51;
# /home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/scripts/chrooted_cleaner_script.sh:128-172;
# /home/tak/sunshineos-build/research/cachyos-calamares/settings.conf:67.
set -uo pipefail

ROOT=${1:-}
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
  echo "usage: $0 <target-root>" >&2
  exit 2
fi

OUT="$ROOT/var/log/sunshine-hardware.txt"
mkdir -p "${OUT%/*}"

{
  echo "Sunshine OS hardware survey"
  if command -v lspci >/dev/null 2>&1; then
    lspci -nn 2>/dev/null || echo "lspci failed"
    echo
    printf 'NVIDIA devices: %s\n' "$(lspci -nn 2>/dev/null | grep -Eic 'vga.*nvidia|3d.*nvidia' || true)"
    printf 'Broadcom devices: %s\n' "$(lspci -nn 2>/dev/null | grep -Eic '14e4:' || true)"
    printf 'Wireless devices: %s\n' "$(lspci -nn 2>/dev/null | grep -Eic 'network controller.*wireless|802\.11' || true)"
    printf 'VirtualBox devices: %s\n' "$(lspci -nn 2>/dev/null | grep -Eic 'virtualbox' || true)"
  else
    echo "lspci not available; no hardware details collected"
  fi

  if [ -d /usr/share/sunshine/drivers/repo ]; then
    echo "offline driver repo present; installation left to the driver tool after first boot"
  else
    echo "no offline driver repo; no packages installed"
  fi
} > "$OUT"

cat "$OUT"
exit 0
