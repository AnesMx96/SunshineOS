# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="snapper config for / removed (btrfs only)"
precondition() { vm 'findmnt -no FSTYPE / | grep -q btrfs && test -e /etc/snapper/configs/root'; }
break() { vmr 'rm -f /etc/snapper/configs/root; sed -i "s/^SNAPPER_CONFIGS=.*/SNAPPER_CONFIGS=\"\"/" /etc/conf.d/snapper 2>/dev/null; true'; }
expect_detect() { echo 'snapper is not configured'; }
verify() { vmr 'test -e /etc/snapper/configs/root'; }
