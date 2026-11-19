# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="mkinitcpio.conf with a hook that does not exist (next kernel update would fail)"
break() { vmr "sed -i 's/^HOOKS=(/HOOKS=(nonexistenthook /' /etc/mkinitcpio.conf; grep -c nonexistenthook /etc/mkinitcpio.conf"; }
expect_detect() { echo 'mkinitcpio|hook'; }
verify() { vmr '! grep -q nonexistenthook /etc/mkinitcpio.conf'; }   # mkinitcpio itself only warns about a missing hook and still builds, so look at the config
