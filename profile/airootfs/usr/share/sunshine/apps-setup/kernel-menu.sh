#!/usr/bin/env bash
# After installing another kernel: rebuild the GRUB menu so it is listed.
# args: id user home   (runs as root)
ID=$1; U=$2; H=$3
command -v grub-mkconfig >/dev/null && [ -d /boot/grub ] && grub-mkconfig -o /boot/grub/grub.cfg
