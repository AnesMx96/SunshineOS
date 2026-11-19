#!/usr/bin/env bash
# Rank 07 - fail the install when the target cannot plausibly boot.
# Wire as shellprocess@verify with no ignoreErrors, after bootloader and before umount.
# Evidence: profile/airootfs/usr/local/bin/sunshine-install:334-337;
# /home/tak/sunshineos-build/research/g-pkgbuilds/calamares-garuda/0004-bootloader-install-systemd-boot-in-the-target.patch:3-8,64-69.
set -uo pipefail

ROOT=${1:-}
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
  echo "usage: $0 <target-root>" >&2
  exit 2
fi

fail=0
check_file() {
  if [ ! -s "$ROOT$1" ]; then
    echo "FAIL: missing or empty $1" >&2
    fail=1
  fi
}

check_file /boot/vmlinuz-linux
check_file /boot/initramfs-linux.img
check_file /boot/grub/grub.cfg

if ! grep -q 'menuentry' "$ROOT/boot/grub/grub.cfg" 2>/dev/null; then
  echo "FAIL: grub.cfg has no menuentry" >&2
  fail=1
fi

check_file /etc/fstab
root_uuid=$(findmnt -no UUID --target "$ROOT" 2>/dev/null || true)
if [ -n "$root_uuid" ] && ! grep -q "$root_uuid" "$ROOT/etc/fstab" 2>/dev/null; then
  echo "FAIL: fstab does not contain root UUID $root_uuid" >&2
  fail=1
fi

if [ -d "$ROOT/boot/efi/EFI" ]; then
  check_file /boot/efi/EFI/BOOT/BOOTX64.EFI
fi

if [ -e "$ROOT/crypto_keyfile.bin" ]; then
  if ! grep -q 'GRUB_ENABLE_CRYPTODISK=y' "$ROOT/etc/default/grub" 2>/dev/null; then
    echo "FAIL: encrypted target has no GRUB_ENABLE_CRYPTODISK=y" >&2
    fail=1
  fi
fi

exit "$fail"
