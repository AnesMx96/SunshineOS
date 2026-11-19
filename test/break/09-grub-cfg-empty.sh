# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="/boot/grub/grub.cfg emptied (file exists, no menu entries)"
break() { vmr ': > /boot/grub/grub.cfg'; }
expect_detect() { echo 'grub\.cfg|GRUB menu'; }
verify() { vmr 'grep -q menuentry /boot/grub/grub.cfg'; }
repair_alt() { vmr 'yes y | sunshine-boot-repair'; }
