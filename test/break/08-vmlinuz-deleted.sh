# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="/boot/vmlinuz-linux deleted"
break() { vmr 'rm -f /boot/vmlinuz-linux'; }
expect_detect() { echo 'vmlinuz-linux missing'; }
verify() { vmr 'test -s /boot/vmlinuz-linux && file -b /boot/vmlinuz-linux | grep -q "Linux kernel"'; }
