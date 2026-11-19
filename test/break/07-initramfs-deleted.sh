# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="/boot/initramfs-linux.img deleted"
break() { vmr 'rm -f /boot/initramfs-linux.img'; }
expect_detect() { echo 'initramfs.*(missing|empty)'; }
verify() { vmr 'test "$(stat -c%s /boot/initramfs-linux.img)" -gt 5000000 && lsinitcpio /boot/initramfs-linux.img >/dev/null'; }
