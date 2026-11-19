# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="login manager removed (pacman -Rdd sddm)"
break() { vmr 'pacman -Rdd --noconfirm sddm >/dev/null 2>&1; ! pacman -Qq sddm'; }
expect_detect() { echo 'sddm'; }
verify() { vmr 'pacman -Qq sddm >/dev/null && systemctl is-enabled sddm >/dev/null'; }
