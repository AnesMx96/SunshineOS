# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="EFI/BOOT/BOOTX64.EFI (fallback loader) deleted"
precondition() { vm 'test -d /sys/firmware/efi && test -f /boot/efi/EFI/BOOT/BOOTX64.EFI'; }
break() { vmr 'rm -f /boot/efi/EFI/BOOT/BOOTX64.EFI'; }
expect_detect() { echo 'EFI fallback boot file'; }
verify() { vmr 'test -f /boot/efi/EFI/BOOT/BOOTX64.EFI'; }
