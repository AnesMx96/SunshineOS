# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="NVRAM boot entry for SunshineOS lost"
precondition() { vm 'test -d /sys/firmware/efi && command -v efibootmgr >/dev/null'; }
break() { vmr 'efibootmgr | grep -i SunshineOS | grep -oE "^Boot[0-9A-Fa-f]+" | sed "s/^Boot//" | while read -r b; do [ -n "$b" ] && efibootmgr -B -b "$b"; done'; }
expect_detect() { echo 'NVRAM|boot entry|SunshineOS'; }
verify() { vmr 'efibootmgr | grep -qi SunshineOS'; }
