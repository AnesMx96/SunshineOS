#!/usr/bin/env bash
# Printing: start CUPS, let the account use printers and scanners.
# args: id user home   (runs as root)
ID=$1; U=$2; H=$3
systemctl enable --now cups.socket cups.service >/dev/null 2>&1
getent group scanner >/dev/null && usermod -aG scanner "$U"; getent group lp >/dev/null && usermod -aG lp "$U"
