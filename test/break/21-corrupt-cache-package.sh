# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="corrupt package file in the pacman cache"
break() { vmr 'head -c 4096 /dev/urandom > /var/cache/pacman/pkg/broken-1-1-any.pkg.tar.zst'; }
expect_detect() { echo 'cache|corrupt'; }
verify() { vmr '! test -e /var/cache/pacman/pkg/broken-1-1-any.pkg.tar.zst'; }
repair_alt() { vmr 'sunshine-fix-pacman'; }
