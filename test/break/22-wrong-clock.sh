# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="system clock wrong and NTP off (TLS and signature errors follow)"
break() { vmr 'timedatectl set-ntp false; date -s "2020-01-01 00:00:00" >/dev/null; date +%Y'; }
expect_detect() { echo 'clock is not synchronised'; }
verify() { vmr 'sleep 5; [ "$(timedatectl show -p NTPSynchronized --value)" = yes ]'; }
repair_alt() { vmr 'timedatectl set-ntp true; sleep 10'; }
