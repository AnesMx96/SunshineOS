# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="/etc/fstab: wrong UUID for the EFI partition (boot drops to emergency mode)"
LIVE=1
precondition() { vm 'test -d /sys/firmware/efi && grep -q /boot/efi /etc/fstab'; }
break() { vmr "sed -i 's#^UUID=[A-Fa-f0-9-]*\\([[:space:]]\\+/boot/efi\\)#UUID=DEAD-BEEF\\1#' /etc/fstab; grep -c DEAD-BEEF /etc/fstab"; }
expect_detect() { echo 'fstab'; }
verify() { vmr 'findmnt --verify >/dev/null 2>&1 && mountpoint -q /boot/efi'; }
