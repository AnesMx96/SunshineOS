# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="sudo removed (pacman -Rdd sudo): no root access for the user"
LIVE=1
break() { vmr 'pacman -Rdd --noconfirm sudo >/dev/null 2>&1; true'; }
expect_detect() { echo 'sudo'; }
verify() { vm 'command -v sudo >/dev/null && test -f /etc/sudoers'; }
