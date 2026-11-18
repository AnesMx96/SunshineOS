#!/usr/bin/env bash
# Copy the live-session fixes into the installed system before first boot.
# The installer copies from /run/archiso/airootfs (squashfs), so overlay fixes are lost.
# Run from the live ISO with: bash /tmp/sunshine-fixes/inject-into-target.sh
set -u
T=/mnt/sunshine-target
D=/dev/sdb2
F=/tmp/sunshine-fixes
exec > >(tee -a /tmp/suos-inject.log) 2>&1
echo "=== inject fixes into installed system @ $(date -Is) ==="

sudo mkdir -p "$T"
sudo mount -o noatime,subvol=@ "$D" "$T" || { echo MOUNT_ROOT_FAILED; exit 1; }
sudo mkdir -p "$T/home" "$T/var/cache" "$T/var/log"
sudo mount -o noatime,subvol=@home "$D" "$T/home" || { echo MOUNT_HOME_FAILED; exit 1; }

# Fixed first-party tools (the squashfs originals crash / misreport).
for tool in sunshine-welcome sunshine-toolbox sunshine-doctor sunshine-install sunshine-register-base; do
  sudo install -m 755 "$F/$tool" "$T/usr/local/bin/$tool" || echo "FAILED tool $tool"
done

# Calamares config and its helper script (GUI install would otherwise fail again).
sudo install -m 644 "$F/shellprocess-ownbase.conf" "$T/etc/calamares/modules/shellprocess-ownbase.conf" || echo FAILED_CALAMARES_CONF

# The installer excludes /etc/pacman.d/gnupg; copy the working keyring so the
# [sunshine] repository is trusted in the installed system.
sudo rm -rf "$T/etc/pacman.d/gnupg"
sudo cp -a /etc/pacman.d/gnupg "$T/etc/pacman.d/gnupg" || echo FAILED_KEYRING

# The installer removes the vboxservice wants-link; restore it (and sshd) so
# the VM remains controllable after reboot.
sudo mkdir -p "$T/etc/systemd/system/multi-user.target.wants"
sudo ln -sf /usr/lib/systemd/system/vboxservice.service "$T/etc/systemd/system/multi-user.target.wants/vboxservice.service"
sudo ln -sf /usr/lib/systemd/system/sshd.service "$T/etc/systemd/system/multi-user.target.wants/sshd.service"

# Theme defaults for future users (skel) and for the already-created user.
sudo install -d "$T/etc/skel/.config/gtk-3.0" "$T/etc/skel/.config/gtk-4.0" "$T/etc/skel/.config/Kvantum"
sudo install -m 644 "$F/gtk-settings.ini" "$T/etc/skel/.config/gtk-3.0/settings.ini"
sudo install -m 644 "$F/gtk-settings.ini" "$T/etc/skel/.config/gtk-4.0/settings.ini"
sudo install -m 644 "$F/kvantum.kvconfig" "$T/etc/skel/.config/Kvantum/kvantum.kvconfig"
sudo cp -a "$T/usr/share/Kvantum/Sunshine" "$T/etc/skel/.config/Kvantum/" 2>/dev/null || true

U="$T/home/sunshine"
if [ -d "$U" ]; then
  sudo install -d -o sunshine -g sunshine "$U/.config/gtk-3.0" "$U/.config/gtk-4.0" "$U/.config/Kvantum"
  sudo install -o sunshine -g sunshine -m 644 "$F/gtk-settings.ini" "$U/.config/gtk-3.0/settings.ini"
  sudo install -o sunshine -g sunshine -m 644 "$F/gtk-settings.ini" "$U/.config/gtk-4.0/settings.ini"
  sudo install -o sunshine -g sunshine -m 644 "$F/kvantum.kvconfig" "$U/.config/Kvantum/kvantum.kvconfig"
  sudo cp -a "$T/usr/share/Kvantum/Sunshine" "$U/.config/Kvantum/" 2>/dev/null || true
  sudo chown -R sunshine:sunshine "$U/.config/Kvantum" 2>/dev/null || true
else
  echo USER_HOME_MISSING
fi

echo "=== verification ==="
ls -l "$T/usr/local/bin/sunshine-welcome" "$T/usr/local/bin/sunshine-toolbox" "$T/usr/local/bin/sunshine-doctor"
grep -n 'rsync -aHAXx' "$T/usr/local/bin/sunshine-install"
grep gtk-theme-name "$T/etc/skel/.config/gtk-3.0/settings.ini"
cat "$T/etc/skel/.config/Kvantum/kvantum.kvconfig"
ls -ld "$T/etc/pacman.d/gnupg"; ls -l "$T/etc/systemd/system/multi-user.target.wants/"{vboxservice,sshd}.service
echo INJECT_OK
