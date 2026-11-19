# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="system booted from a read-only snapshot (note only)"
DETECT_ONLY=1
precondition() { vm 'findmnt -no FSTYPE / | grep -q btrfs'; }
break() { vmr 'touch /run/sunshine-test-snapshot-boot'; }
expect_detect() { echo 'snapshot'; }
verify() { true; }
