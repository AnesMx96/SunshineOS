# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="[community] (removed from Arch) re-added to pacman.conf"
break() { vmr 'printf "\n[community]\nInclude = /etc/pacman.d/mirrorlist\n" >> /etc/pacman.conf'; }
expect_detect() { echo 'community|repositor(y|ies)'; }
verify() { vmr '! pacman-conf --repo-list | grep -qx community && pacman -Sy --noconfirm >/dev/null 2>&1'; }
repair_alt() { vmr 'sunshine-fix-pacman'; }
