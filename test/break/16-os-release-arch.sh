# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="os-release replaced by Arch's (identity lost)"
break() { vmr 'cp -n /usr/lib/os-release /root/os-release.sunshine-test; printf "NAME=\"Arch Linux\"\nPRETTY_NAME=\"Arch Linux\"\nID=arch\n" > /usr/lib/os-release'; }
expect_detect() { echo 'identity was changed'; }
verify() { vmr 'sunshine-identity check --quiet'; }
