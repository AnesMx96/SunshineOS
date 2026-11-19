# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="broken file in /etc/sudoers.d (sudo refuses to run for everyone)"
LIVE=1
break() { vmr 'printf "this is not valid sudoers syntax\n" > /etc/sudoers.d/99-broken; chmod 440 /etc/sudoers.d/99-broken; true'; }
expect_detect() { echo 'sudoers'; }
verify() { vmr 'visudo -c >/dev/null 2>&1'; }
