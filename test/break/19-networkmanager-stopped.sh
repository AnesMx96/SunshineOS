# shellcheck shell=bash disable=SC2034,SC2148
# Scenario for test/break-repair.sh (see the header of that script for the functions a scenario defines).
TITLE="NetworkManager service stopped and failed"
break() { vmr 'systemctl kill -s KILL NetworkManager; systemctl stop NetworkManager; systemctl is-active NetworkManager; true'; }
expect_detect() { echo 'NetworkManager is not running|failed services'; }
verify() { vmr 'systemctl is-active --quiet NetworkManager'; }
