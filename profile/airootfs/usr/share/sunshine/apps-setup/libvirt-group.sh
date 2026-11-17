#!/usr/bin/env bash
# QEMU/libvirt: start the service, the account joins libvirt and kvm, the default network starts automatically.
# args: id user home   (runs as root)
ID=$1; U=$2; H=$3
usermod -aG libvirt,kvm "$U"
systemctl enable --now libvirtd.socket >/dev/null 2>&1
virsh net-autostart default >/dev/null 2>&1; virsh net-start default >/dev/null 2>&1; true
