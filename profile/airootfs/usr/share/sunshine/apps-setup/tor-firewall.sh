#!/usr/bin/env bash
# A low-level firewall for Tor Browser users: deny all incoming connections, allow outgoing (ufw).
# args: id user home   (runs as root)
ID=$1; U=$2; H=$3
command -v ufw >/dev/null || exit 1
ufw --force reset >/dev/null
ufw default deny incoming; ufw default allow outgoing
ufw --force enable; systemctl enable ufw.service >/dev/null 2>&1
# torbrowser-launcher downloads and verifies Tor Browser on its first start; nothing else to prepare
