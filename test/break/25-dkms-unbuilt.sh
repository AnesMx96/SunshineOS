# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="DKMS module not built for the installed kernel"
precondition() { vm 'command -v dkms >/dev/null && dkms status | grep -q installed'; }
break() { vmr 'l=$(dkms status | grep installed | head -1); n=${l%%/*}; v=${l#*/}; v=${v%%,*}; k=$(echo "$l" | cut -d, -f2 | tr -d " "); dkms unbuild -m "$n" -v "$v" -k "$k"; dkms status | grep -vc installed'; }
expect_detect() { echo 'DKMS'; }
verify() { vmr '! dkms status | grep -v installed | grep -q .'; }
