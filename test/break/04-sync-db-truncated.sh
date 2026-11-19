# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="truncated sync database (core.db cut to 64 bytes)"
break() { vmr 'truncate -s 64 /var/lib/pacman/sync/core.db'; }
expect_detect() { echo 'sync (database|db)|database.*(damaged|corrupt)'; }
verify() { vmr 'bsdtar -tf /var/lib/pacman/sync/core.db >/dev/null'; }
repair_alt() { vmr 'sunshine-fix-pacman'; }
