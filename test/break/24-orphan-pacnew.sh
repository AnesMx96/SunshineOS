# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="unreviewed .pacnew files for pacman.conf-adjacent and sudoers files"
DETECT_ONLY=1
break() { vmr 'touch /etc/pacman.d/mirrorlist.pacnew /etc/sudoers.pacnew; ls /etc/*.pacnew /etc/pacman.d/*.pacnew'; }
expect_detect() { echo '\.pacnew'; }
verify() { true; }
