# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="empty /etc/pacman.d/gnupg (keyring gone)"
break() { vmr 'rm -rf /etc/pacman.d/gnupg/* 2>/dev/null; ls -A /etc/pacman.d/gnupg | wc -l'; }
expect_detect() { echo 'keyring (missing|empty)'; }
verify() { vmr 'pacman-key --list-keys 2>/dev/null | grep -qi "Arch Linux"'; }
repair_alt() { vmr 'sunshine-fix-pacman'; }
