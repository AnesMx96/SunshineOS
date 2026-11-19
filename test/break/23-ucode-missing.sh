# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="CPU microcode package removed"
precondition() { vm 'pacman -Qq intel-ucode amd-ucode 2>/dev/null | grep -q .'; }
break() { vmr 'pacman -Rdd --noconfirm intel-ucode amd-ucode >/dev/null 2>&1; ! pacman -Qq intel-ucode amd-ucode 2>/dev/null | grep -q .'; }
expect_detect() { echo 'ucode|microcode'; }
verify() { vmr 'pacman -Qq intel-ucode amd-ucode 2>/dev/null | grep -q .'; }
