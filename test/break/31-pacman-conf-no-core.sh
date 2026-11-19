# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="[core] section removed from /etc/pacman.conf"
break() { vmr "cp /etc/pacman.conf /etc/pacman.conf.break-backup && awk 'BEGIN{s=0} /^\\[core\\]/{s=1;next} /^\\[/{s=0} !s' /etc/pacman.conf.break-backup > /tmp/pc.new && cp /tmp/pc.new /etc/pacman.conf"; }
expect_detect() { echo '\[core\].*(repository|missing)|core.*repository'; }
verify() { vmr 'pacman-conf --repo-list | grep -qx core'; }
repair_alt() { vmr 'cp /etc/pacman.conf.break-backup /etc/pacman.conf'; }
