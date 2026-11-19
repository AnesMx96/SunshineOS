# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="EFI partition not mounted at /boot/efi"
precondition() { vm 'test -d /sys/firmware/efi && mountpoint -q /boot/efi'; }
break() { vmr 'umount /boot/efi'; }
expect_detect() { echo 'EFI partition not mounted'; }
verify() { vmr 'mountpoint -q /boot/efi'; }
