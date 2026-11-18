#!/usr/bin/env bash
# Development loop on the live image BEFORE it is compressed into the final ISO: boot the live system with persistent changes, fix things in the
# running system (by command through guest control, or in the VM window), keep what works, harvest it into the sources.
#   test/dev-vm.sh create NAME ISO [GB]    new VirtualBox VM (window, shared clipboard) + a persistent ext4 disk labelled "sunpersist"; boots the ISO
#   test/dev-vm.sh start NAME              start it; in the GRUB menu choose "live session with persistent changes" (the script presses it for you)
#   test/dev-vm.sh ssh NAME [command]     terminal tunnel for Claude: ssh sunshine@127.0.0.1:2222 (NAT forward to the guest sshd; sudo is passwordless in the live session)
#   test/dev-vm.sh push NAME               copy the working tree (overlay/system, overlay/skel, profile files that matter) into the running VM
#   test/dev-vm.sh changed NAME            list what differs from the ISO image in the VM (the overlay's upper directory), noise left out
#   test/dev-vm.sh harvest NAME OUTDIR     copy those changed files out, ready to be merged into overlay/system or overlay/skel
#   test/dev-vm.sh reset NAME              forget all persistent changes (fresh persistent disk)
# The persistent disk is a plain file: test/tmp/NAME-persist.img (sparse). The ISO is never modified.
set -uo pipefail
cd "$(dirname "$0")/.."
cmd=${1:-}; N=${2:-}; shift 2 2>/dev/null || true
VB=test/vbox.sh
UP='/run/archiso/cowspace/persistent_*/x86_64/upperdir'
noise='^(\./)?(var/(log|cache|lib/(systemd|pacman/sync)|tmp)|tmp|run|home/[^/]+/\.(cache|local/state|local/share/(Trash|recently-used)|config/(session|kdedefaults|pulse)|xsession-errors)|root/\.(cache|bash_history)|etc/(machine-id|hostname)|usr/share/mime|usr/lib/(locale|modules)|etc/ld\.so\.cache)'
case "$cmd" in
  create)
    iso=${1:?iso}; gb=${2:-16}; mkdir -p test/tmp
    img=test/tmp/$N-persist.img; rm -f "$img"; truncate -s ${gb}G "$img"; mkfs.ext4 -q -F -L sunpersist "$img"
    $VB create "$N" "$iso" 4 >/dev/null
    vdi=test/tmp/$N-persist.vdi; rm -f "$vdi"; VBoxManage convertfromraw "$img" "$vdi" --format VDI >/dev/null 2>&1
    VBoxManage storageattach "$N" --storagectl SATA --port 2 --device 0 --type hdd --medium "$PWD/$vdi"
    VBoxManage modifyvm "$N" --boot1 dvd --boot2 none
    echo "created $N with the persistent disk $vdi" ;;
  start)   # GUI window for the user, plus the terminal tunnel (ssh via NAT forward 2222 and VBox guest control) for Claude
    $VB start "$N"; sleep 6; $VB key "$N" down; sleep 1; $VB key "$N" enter
    echo "waiting for the guest's sshd on 127.0.0.1:2222 ..."
    for i in $(seq 1 60); do "$0" ssh "$N" true 2>/dev/null && { echo "tunnel up: test/dev-vm.sh ssh $N '<command>'"; exit 0; }; sleep 5; done
    echo "ssh did not come up (guest control still works: test/vbox.sh run $N '<command>')"; exit 1 ;;
  ssh)
    O="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5 -p 2222"
    if command -v sshpass >/dev/null; then if [ $# -gt 0 ]; then exec sshpass -p sunshine ssh $O sunshine@127.0.0.1 bash -s <<<"$*"; else exec sshpass -p sunshine ssh $O sunshine@127.0.0.1; fi; fi
    echo "sshpass is needed for the tunnel (pacman -S sshpass)"; exit 1 ;;
  push)
    t=$(mktemp -d); tar -C overlay/system -cf "$t/system.tar" .; tar -C overlay/skel -cf "$t/skel.tar" .
    $VB put "$N" "$t/system.tar" >/dev/null; $VB put "$N" "$t/skel.tar" >/dev/null
    $VB run "$N" 'tar -C / -xf /tmp/system.tar --no-same-owner  --no-overwrite-dir; mkdir -p /etc/skel; tar -C /etc/skel -xf /tmp/skel.tar --no-same-owner  --no-overwrite-dir; for u in /home/*; do [ -d $u ] || continue; tar -C $u -xf /tmp/skel.tar --no-same-owner  --no-overwrite-dir --keep-old-files 2>/dev/null; chown -R $(basename $u):$(basename $u) $u/.config 2>/dev/null; done; tar -tf /tmp/system.tar | sed "s|^\\./|/|" | grep -v "^/$" | tr "\\n" "\\0" | xargs -0 -r chmod go+rX,go-w 2>/dev/null; find /usr /etc /home /opt -xdev -type d -perm -2000 -exec chmod g-s {} + 2>/dev/null; chmod 755 / 2>/dev/null; echo pushed'
    rm -rf "$t" ;;
  changed) $VB run "$N" "cd $UP 2>/dev/null && find . -type f | sed 's|^\./||' | grep -v -E '$noise' | sort" ;;
  harvest)
    out=${1:?outdir}; mkdir -p "$out"
    $VB run "$N" "cd $UP && find . -type f | sed 's|^\./||' | grep -v -E '$noise' | tar -czf /tmp/harvest.tgz -T - --no-recursion" >/dev/null
    VBoxManage guestcontrol "$N" copyfrom --username root --password "" /tmp/harvest.tgz "$out/harvest.tgz" && tar -C "$out" -xzf "$out/harvest.tgz" && echo "harvested into $out" ;;
  reset) $VB stop "$N" 2>/dev/null; img=test/tmp/$N-persist.img; mkfs.ext4 -q -F -L sunpersist "$img"; echo "persistent disk emptied (re-create the VDI with: create)";;
  *) sed -n 2,13p "$0"; exit 2 ;;
esac
