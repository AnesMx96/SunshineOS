#!/usr/bin/env bash
# Real installation test in VirtualBox (window for the owner, ssh for the scripts): boot the ISO, install to a blank disk with sunshine-install
# in automatic mode, shut down, boot the installed system from the disk, wait for it to come up.
#   test/install-test.sh NAME ISO [FS] [ENCRYPT]     FS: ext4 | btrfs (default btrfs), ENCRYPT: yes|no (default no)
# Afterwards:  SSH_PORT=2223 test/dev-vm.sh ssh NAME 'command'   (user sunshine, password sunshine; sudo is passwordless)
set -uo pipefail
cd "$(dirname "$0")/.."
N=${1:?VM name}; ISO=${2:?iso}; FS=${3:-btrfs}; ENC=${4:-no}
PORT=${SSH_PORT:-2223}; export SSH_PORT=$PORT
VB=test/vbox.sh; D=test/dev-vm.sh
ts() { date +%H:%M:%S; }
wait_ssh() { local i; for i in $(seq 1 ${2:-90}); do $D ssh "$N" true 2>/dev/null && return 0; sleep 5; done; return 1; }

VBoxManage list vms | grep -q "\"$N\"" && { echo "$N exists: delete it first (VBoxManage unregistervm $N --delete)"; exit 1; }
SSHPORT=$PORT $VB create "$N" "$ISO" 24 >/dev/null || exit 1
echo "$(ts) created $N (ssh $PORT)"
$VB start "$N" >/dev/null; sleep 6; $VB key "$N" enter      # first entry: live session
echo "$(ts) booting the live session ..."
wait_ssh "$N" 120 || { echo "live session did not answer on ssh"; exit 1; }
sleep 30       # let the live setup finish before the installer takes the disk
echo "$(ts) installing ($FS, encrypt=$ENC) ..."
ENV="SUNSHINE_AUTO=1 SUNSHINE_DISK=/dev/sda SUNSHINE_USER=sunshine SUNSHINE_PASS=sunshine SUNSHINE_HOSTNAME=sunshine-test SUNSHINE_TZ=Europe/Kyiv SUNSHINE_LOCALE=en_US.UTF-8 SUNSHINE_KEYMAP=us SUNSHINE_FS=$FS"
[ "$ENC" = yes ] && ENV="$ENV SUNSHINE_ENCRYPT=yes SUNSHINE_LUKS_PASS=sunshine-luks"
lsblk_out=$($D ssh "$N" 'lsblk -dpno NAME,SIZE,TYPE | grep disk')
disk=$(printf '%s\n' "$lsblk_out" | awk '{print $1}' | while read -r d; do [ "$($D ssh "$N" "lsblk -no MOUNTPOINTS $d | grep -c .")" = 0 ] && echo "$d" && break; done)
[ -n "$disk" ] || { echo "no blank disk found: $lsblk_out"; exit 1; }
ENV=${ENV/\/dev\/sda/$disk}
$D ssh "$N" "sudo env $ENV nohup sunshine-install > /tmp/install.out 2>&1; echo INSTALL_RC=\$? >> /tmp/install.out" >/dev/null 2>&1 &
ipid=$!
for i in $(seq 1 240); do
  sleep 10
  out=$($D ssh "$N" 'tail -3 /tmp/install.out 2>/dev/null' 2>/dev/null) || continue
  printf '%s\n' "$out" | grep -q INSTALL_RC && break
done
kill $ipid 2>/dev/null
rc=$($D ssh "$N" 'grep INSTALL_RC /tmp/install.out' 2>/dev/null)
echo "$(ts) installer finished: ${rc:-no result}"
$D ssh "$N" 'tail -12 /tmp/install.out; sudo cp /var/log/sunshine-install.log /tmp/ 2>/dev/null' | tail -14
mkdir -p test/tmp; VBoxManage guestcontrol "$N" copyfrom --username root --password "" /var/log/sunshine-install.log "test/tmp/$N-install.log" >/dev/null 2>&1
echo "$rc" | grep -q 'INSTALL_RC=0' || { echo "INSTALL FAILED: see test/tmp/$N-install.log"; exit 1; }
echo "$(ts) shutting down, detaching the ISO, booting from the disk ..."
$D ssh "$N" 'sudo poweroff' >/dev/null 2>&1; sleep 20; VBoxManage controlvm "$N" poweroff >/dev/null 2>&1; sleep 3
VBoxManage storageattach "$N" --storagectl SATA --port 0 --device 0 --type dvddrive --medium emptydrive >/dev/null 2>&1
$VB start "$N" >/dev/null
if [ "$ENC" = yes ]; then   # GRUB asks for the passphrase (LUKS1 + key file in the initramfs: asked once)
  sleep 25; VBoxManage controlvm "$N" keyboardputstring "sunshine-luks"; sleep 1; $VB key "$N" enter; echo "$(ts) passphrase typed"
fi
wait_ssh "$N" 120 && echo "$(ts) installed system is up" || { echo "installed system did not answer on ssh"; exit 1; }
