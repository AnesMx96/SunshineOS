# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="/boot/vmlinuz-linux present but corrupt (random data)"
break() { vmr 'head -c 1048576 /dev/urandom > /boot/vmlinuz-linux'; }
expect_detect() { echo 'kernel image.*(invalid|not match|mismatch|corrupt)'; }
verify() { vmr 'cmp -s /boot/vmlinuz-linux /usr/lib/modules/$(ls /usr/lib/modules | tail -1)/vmlinuz'; }
repair_alt() { vmr 'cp --sparse=never --reflink=never /usr/lib/modules/$(ls /usr/lib/modules | tail -1)/vmlinuz /boot/vmlinuz-linux && chmod 644 /boot/vmlinuz-linux'; }
