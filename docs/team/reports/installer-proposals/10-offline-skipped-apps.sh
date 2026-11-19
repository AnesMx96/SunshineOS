#!/usr/bin/env bash
# Rank 10 - write a visible report of apps that cannot be delivered offline.
# Wire as shellprocess@skipped_apps after packages.
# Limitation: this reads default-selected entries, not the live checkbox state.
# Evidence: profile/airootfs/etc/calamares/modules/packages.conf:3-5;
# profile/airootfs/etc/calamares/modules/netinstall.conf:2-8;
# profile/airootfs/usr/share/sunshine/netinstall.yaml:14-18,71-75.
set -uo pipefail

ROOT=${1:-}
NET=${2:-/usr/share/sunshine/netinstall.yaml}
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
  echo "usage: $0 <target-root> [netinstall.yaml]" >&2
  exit 2
fi

OUT="$ROOT/var/log/sunshine-skipped-apps.txt"
mkdir -p "${OUT%/*}"

{
  echo "Sunshine OS offline app install report"
  if command -v ip >/dev/null 2>&1 && ip route get 1.1.1.1 >/dev/null 2>&1; then
    echo "network during install: available"
  else
    echo "network during install: unavailable"
  fi
  echo
  echo "Default-selected entries in $NET (not the live checkbox state):"
  if [ -r "$NET" ]; then
    grep -n 'selected: true' "$NET" || echo "  none"
  else
    echo "  catalogue not found"
  fi
  echo
  echo "After first online boot: sunshine-apps install ID, or the Sunshine store."
} > "$OUT"

cat "$OUT"
exit 0
