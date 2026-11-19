# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="stale pacman lock file (no pacman running)"
break() { vmr 'touch /var/lib/pacman/db.lck'; }
expect_detect() { echo 'stale lock'; }
verify() { vmr '! test -e /var/lib/pacman/db.lck'; }
