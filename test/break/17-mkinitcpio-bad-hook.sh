# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="mkinitcpio.conf with a hook that does not exist (next kernel update would fail)"
break() { vmr "sed -i 's/^HOOKS=(/HOOKS=(nonexistenthook /' /etc/mkinitcpio.conf; grep -c nonexistenthook /etc/mkinitcpio.conf"; }
expect_detect() { echo 'mkinitcpio|hook'; }
verify() { vmr 'mkinitcpio -k "$(ls /usr/lib/modules | tail -1)" -g /tmp/break-test.img >/dev/null 2>&1; rc=$?; rm -f /tmp/break-test.img; exit $rc'; }
