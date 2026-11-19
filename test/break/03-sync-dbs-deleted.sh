# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="/var/lib/pacman/sync/*.db deleted"
break() { vmr 'rm -f /var/lib/pacman/sync/*.db'; }
expect_detect() { echo 'sync (database|db)|databases? (missing|not synchron)'; }
verify() { vmr 'pacman -Syy --noconfirm >/dev/null 2>&1 && ls /var/lib/pacman/sync/*.db >/dev/null'; }
repair_alt() { vmr 'sunshine-fix-pacman'; }
