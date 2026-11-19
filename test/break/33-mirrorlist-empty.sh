# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="/etc/pacman.d/mirrorlist emptied"
break() { vmr 'cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.break-backup && : > /etc/pacman.d/mirrorlist'; }
expect_detect() { echo 'mirror'; }
verify() { vmr 'grep -q ^Server /etc/pacman.d/mirrorlist && pacman -Sy --noconfirm >/dev/null 2>&1'; }
repair_alt() { vmr 'cp /etc/pacman.d/mirrorlist.break-backup /etc/pacman.d/mirrorlist'; }
