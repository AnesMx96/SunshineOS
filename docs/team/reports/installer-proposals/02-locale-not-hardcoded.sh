#!/usr/bin/env bash
# Rank 02 - print replacement locale.conf lines derived from the live system.
# Usage: ./02-locale-not-hardcoded.sh > profile/airootfs/etc/calamares/modules/locale.conf
# Evidence: profile/airootfs/etc/calamares/modules/locale.conf:2-3;
# /home/tak/sunshineos-build/research/calamares/src/modules/locale/locale.conf:23-30;
# profile/airootfs/usr/local/bin/sunshine-install:92.
set -euo pipefail

zone=$(readlink -f /etc/localtime 2>/dev/null | sed -n 's#.*/zoneinfo/##p' || true)
[ -n "$zone" ] || zone=UTC
[ -e "/usr/share/zoneinfo/$zone" ] || zone=UTC

if [[ "$zone" == */* ]]; then
  region=${zone%%/*}
  city=${zone#*/}
else
  region=UTC
  city=$zone
fi

printf 'region: "%s"\nzone: "%s"\nuseSystemTimezone: true\n' "$region" "$city"
exit 0
