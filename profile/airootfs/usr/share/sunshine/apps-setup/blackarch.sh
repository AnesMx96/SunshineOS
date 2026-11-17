#!/usr/bin/env bash
# Adds the BlackArch repository by hand (no strap script). The key is fetched by its fingerprint and checked to belong to BlackArch before it is trusted.
# args: id user home   (runs as root)
ID=$1; U=$2; H=$3
FPR=4345771566D76038C7FEB43863EC0ADBEA87E4E3
grep -q '^\[blackarch\]' /etc/pacman.conf && exit 0
pacman-key --recv-keys "$FPR" --keyserver keyserver.ubuntu.com || exit 1
pacman-key --finger "$FPR" | grep -qi blackarch || { echo "the key $FPR is not a BlackArch key: not trusted"; pacman-key --delete "$FPR" 2>/dev/null; exit 1; }
pacman-key --lsign-key "$FPR"
printf '\n[blackarch]\nServer = https://ftp.halifax.rwth-aachen.de/blackarch/$repo/os/$arch\n' >> /etc/pacman.conf
pacman -Sy --noconfirm
