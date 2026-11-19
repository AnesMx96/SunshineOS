# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="[sunshine] repository removed from pacman.conf"
break() { vmr "awk 'BEGIN{s=0} /^\\[sunshine\\]/{s=1;next} /^\\[/{s=0} !s' /etc/pacman.conf > /tmp/pc.new && cp /tmp/pc.new /etc/pacman.conf"; }
expect_detect() { echo '\[sunshine\].*(repository|missing)'; }
verify() { vmr 'pacman-conf --repo-list | grep -qx sunshine'; }
