# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="NetworkManager removed (pacman -Rdd networkmanager)"
break() { vmr 'pacman -Rdd --noconfirm networkmanager >/dev/null 2>&1; ! pacman -Qq networkmanager'; }
expect_detect() { echo 'NetworkManager|network service'; }
verify() { vmr 'pacman -Qq networkmanager >/dev/null && systemctl is-enabled NetworkManager >/dev/null'; }
