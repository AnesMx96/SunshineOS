# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="a small member of the base group removed (which)"
break() { vmr 'pacman -Rdd --noconfirm which'; }
expect_detect() { echo 'base (group|member)|core packages missing'; }
verify() { vmr 'pacman -Qq which'; }
repair_alt() { vmr 'pacman -S --noconfirm --needed which'; }
