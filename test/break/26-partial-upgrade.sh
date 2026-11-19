# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="partial upgrade: databases refreshed (pacman -Sy) without upgrading"
DETECT_ONLY=1
break() { vmr 'pacman -Sy --noconfirm >/dev/null 2>&1; pacman -Qu | wc -l'; }
expect_detect() { echo 'partial upgrade|(database|databases).*newer'; }
verify() { true; }
