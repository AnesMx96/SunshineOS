#!/usr/bin/env bash
# Rank 11 - late target cleanup after users, plus the install log.
# Wire as shellprocess@live_leftovers after users and before umount.
# Evidence: /home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/scripts/chrooted_cleaner_script.sh:249-252;
# /home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/modules/shellprocess_copyfiles.conf:13-15;
# /home/tak/sunshineos-build/research/cachyos-calamares/src/modules/shellprocess/shellprocess.conf:95-106;
# profile/airootfs/usr/local/bin/sunshine-install:239-257.
set -uo pipefail

ROOT=${1:-}
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ] || [ "$ROOT" = / ]; then
  echo "usage: $0 <target-root> (refuses /)" >&2
  exit 2
fi

rm -rf "$ROOT/etc/calamares" \
       "$ROOT/opt/extra-drivers" \
       "$ROOT/home/liveuser" \
       "$ROOT/home/sunshine" \
       "$ROOT/var/lib/NetworkManager/NetworkManager.state"

find "$ROOT/etc" -type f -name '*.pacnew' -delete 2>/dev/null || true

install -d "$ROOT/var/log/sunshine"
if [ -r /var/log/sunshine-install.log ]; then
  install -m 0600 /var/log/sunshine-install.log "$ROOT/var/log/sunshine/sunshine-install.log"
elif [ -r /var/log/calamares.log ]; then
  install -m 0600 /var/log/calamares.log "$ROOT/var/log/sunshine/calamares.log"
fi

exit 0
