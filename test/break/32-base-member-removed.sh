# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="a small member of the base group removed (psmisc, a dependency of the base package)"
break() { vmr 'pacman -Rdd --noconfirm psmisc'; }
expect_detect() { echo 'required packages missing|base'; }
verify() { vmr 'pacman -Qq psmisc'; }
