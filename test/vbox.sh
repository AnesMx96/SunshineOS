#!/usr/bin/env bash
# VirtualBox test VM with a two-way channel: you work in its window (GUI), the scripts work through guest control and SSH at the same time.
#   test/vbox.sh create NAME ISO|USBVMDK [disk-GB]   new VM (UEFI, 4 vCPU, 4 GB, NAT with ssh on 127.0.0.1:2222, shared clipboard and drag-and-drop)
#   test/vbox.sh start NAME                          starts it WITH a window (never headless)
#   test/vbox.sh run NAME 'command'                  runs a command in the guest as root (live ISO: empty password), prints its output
#   test/vbox.sh user NAME 'command'                 same, as the user "sunshine" (password sunshine), with the Wayland session variables set
#   test/vbox.sh put NAME FILE [DEST]                copies a file into the guest (a new name each time: guest control does not overwrite)
#   test/vbox.sh shot NAME FILE.png                  screenshot of the guest screen
#   test/vbox.sh key NAME enter|down|up|esc|meta     sends a key (boot menus)
#   test/vbox.sh stop NAME | delete NAME
# Guest control needs the VirtualBox guest additions in the guest (the live ISO has them). Commands must stay under about 1 KB: use `put` for scripts.
set -uo pipefail
cmd=${1:-}; N=${2:-}; shift 2 2>/dev/null || true
G() { VBoxManage guestcontrol "$N" run --username "${GU:-root}" --password "${GP:-}" --exe /bin/bash -- -c "$1"; }
case "$cmd" in
  create)
    src=${1:?ISO or raw-disk VMDK}; gb=${2:-24}
    VBoxManage createvm --name "$N" --ostype ArchLinux_64 --register >/dev/null
    VBoxManage modifyvm "$N" --memory 4096 --cpus 4 --vram 128 --graphicscontroller vmsvga --firmware efi64 --ioapic on --nic1 nat --audio-enabled off \
      --clipboard-mode bidirectional --draganddrop bidirectional --natpf1 "ssh,tcp,127.0.0.1,2222,,22" --usbxhci off --rtcuseutc on
    VBoxManage storagectl "$N" --name SATA --add sata --controller IntelAhci --portcount 4
    case "$src" in
      *.vmdk) VBoxManage storageattach "$N" --storagectl SATA --port 0 --device 0 --type hdd --medium "$src" ;;
      *.iso)  VBoxManage storageattach "$N" --storagectl SATA --port 0 --device 0 --type dvddrive --medium "$src"
              d=$(VBoxManage showvminfo "$N" --machinereadable | sed -n 's/^CfgFile="\(.*\)\/[^/]*"$/\1/p')
              VBoxManage createmedium disk --filename "$d/$N.vdi" --size $((gb * 1024)) >/dev/null
              VBoxManage storageattach "$N" --storagectl SATA --port 1 --device 0 --type hdd --medium "$d/$N.vdi" ;;
    esac
    echo "created $N" ;;
  start) VBoxManage startvm "$N" --type gui ;;
  run) G "$1" ;;
  user) GU=sunshine GP=sunshine G "export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus WAYLAND_DISPLAY=wayland-0; $1" ;;
  put) f=${1:?file}; VBoxManage guestcontrol "$N" copyto --username root --password "" --target-directory "${2:-/tmp/}" "$f" && G "chmod a+rx /tmp/$(basename "$f")" ;;
  shot) VBoxManage controlvm "$N" screenshotpng "${1:?file.png}" ;;
  key) case "${1:?key}" in enter) c="1c 9c";; down) c="e0 50 e0 d0";; up) c="e0 48 e0 c8";; esc) c="01 81";; meta) c="e0 5b e0 db";; *) echo "unknown key"; exit 2;; esac; VBoxManage controlvm "$N" keyboardputscancode $c ;;
  stop) VBoxManage controlvm "$N" poweroff ;;
  delete) VBoxManage unregistervm "$N" --delete ;;
  *) sed -n 2,14p "$0"; exit 2 ;;
esac
