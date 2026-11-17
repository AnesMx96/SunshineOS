#!/usr/bin/env bash
# VirtualBox: kernel modules at boot, the account joins vboxusers.
# args: id user home   (runs as root)
ID=$1; U=$2; H=$3
printf 'vboxdrv\nvboxnetadp\nvboxnetflt\n' > /etc/modules-load.d/virtualbox.conf
usermod -aG vboxusers "$U"
