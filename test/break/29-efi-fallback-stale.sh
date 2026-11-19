# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="EFI/BOOT/BOOTX64.EFI (fallback loader) present but stale"
precondition() { vm 'test -d /sys/firmware/efi && test -f /boot/efi/EFI/BOOT/BOOTX64.EFI'; }
break() { vmr 'head -c 1048576 /dev/urandom > /boot/efi/EFI/BOOT/BOOTX64.EFI'; }
expect_detect() { echo 'EFI fallback.*(invalid|stale|not match|mismatch|corrupt)'; }
verify() { vmr 'if [ -f /boot/efi/EFI/SunshineOS/grubx64.efi ]; then cmp -s /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/SunshineOS/grubx64.efi; else [ "$(stat -c%s /boot/efi/EFI/BOOT/BOOTX64.EFI)" -gt 100000 ] && [ "$(head -c 2 /boot/efi/EFI/BOOT/BOOTX64.EFI)" = MZ ]; fi'; }
repair_alt() { vmr 'grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --recheck >/dev/null 2>&1'; }
