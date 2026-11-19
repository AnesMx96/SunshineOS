# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="root file system full (fake package files fill the pacman cache)"
break() { vmr 'a=$(df --output=avail -B1 / | tail -1); for i in 1 2 3; do fallocate -l $((a / 3 - 30000000)) /var/cache/pacman/pkg/fake$i-1-1-any.pkg.tar.zst 2>&1; done; df --output=pcent / | tail -1'; }
expect_detect() { echo 'root disk .*% full'; }
verify() { vmr '[ "$(df --output=pcent / | tail -1 | tr -dc 0-9)" -lt 90 ]'; }
repair_alt() { vmr 'yes | sunshine-cleanup'; }
