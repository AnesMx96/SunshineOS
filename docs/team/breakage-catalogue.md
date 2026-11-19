# 40 ways an Arch-based desktop breaks: detect, repair, risk (by tak-7a, 2026-11-19)

Environments: **RUN** = running system as root. **LIVE** = live session; `sunshine-rescue run -- CMD` (or `arch-chroot /mnt/sunshine-rescue CMD`) after `sunshine-rescue mount`.
"Never auto" = a human must confirm. Each item is meant to become one test: break it, run the repair, verify the DETECT command now passes.

## A. Boot

1. **Missing/wrong kernel image** `/boot/vmlinuz-linux` (partial upgrade, full /boot).
   DETECT `test -s /boot/vmlinuz-linux && file -b /boot/vmlinuz-linux | grep -q 'Linux kernel'`. REPAIR RUN/LIVE `cp /usr/lib/modules/$(ls /usr/lib/modules|tail -1)/vmlinuz /boot/vmlinuz-linux` (or `pacman -S linux`). Risk low. Never auto: delete other kernels.
2. **Empty/short initramfs** (mkinitcpio killed by ENOSPC). DETECT `[ $(stat -c%s /boot/initramfs-linux.img) -gt 5000000 ] && lsinitcpio /boot/initramfs-linux.img >/dev/null`. REPAIR `mkinitcpio -P` (write to a temp file then mv; sunshine-boot-repair does). Risk low.
3. **/boot full.** DETECT `[ $(df --output=avail -B1M /boot|tail -1) -gt 100 ]`. REPAIR `paccache -rk1`, remove `*.img` of removed kernels, `pacman -Rns` unused kernels (ask). Never auto: remove the running kernel.
4. **GRUB config missing/stale** (`grub.cfg` absent or no menuentry). DETECT `grep -q menuentry /boot/grub/grub.cfg`. REPAIR `grub-mkconfig -o /boot/grub/grub.cfg`. Risk low.
5. **GRUB not installed / ESP wiped.** DETECT UEFI `ls /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/SunshineOS/grubx64.efi`; BIOS `dd if=/dev/DISK bs=512 count=1|strings|grep -q GRUB`. REPAIR LIVE/RUN `grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=SunshineOS --recheck` plus `--removable`; BIOS `grub-install --target=i386-pc /dev/DISK`. Risk medium (writes NVRAM); never auto on a disk the user did not pick.
6. **fstab UUID wrong** (cloned disk, wrong edit). DETECT per line `blkid -U UUID`; `findmnt --verify --fstab`. REPAIR rewrite the line with the UUID of the mounted device from `lsblk -f` (LIVE); keep `fstab.sunshine-backup`. Risk medium. Never auto: delete lines.
7. **fstab missing `nofail` on removable/secondary disk -> emergency mode.** DETECT `findmnt --verify`; journal `Dependency failed for`. REPAIR add `nofail,x-systemd.device-timeout=5s`. Risk low.
8. **Root device not found (initramfs hooks wrong: no `encrypt`/`btrfs`/`keyboard`).** DETECT `lsinitcpio /boot/initramfs-linux.img | grep -E 'btrfs|dm-crypt|usbhid'`; compare with `HOOKS` in /etc/mkinitcpio.conf and root fs type. REPAIR set hooks, `mkinitcpio -P`. Risk medium.
9. **LUKS: no keyfile/`cryptdevice` mismatch** (luks1 installs). DETECT `grep cryptdevice /etc/default/grub` vs `blkid -t TYPE=crypto_LUKS`. REPAIR LIVE: open, mount, fix `GRUB_CMDLINE_LINUX`, `GRUB_ENABLE_CRYPTODISK=y`, mkinitcpio, grub-install. Never auto: `luksFormat`, `luksErase`.
10. **Wrong default kernel in GRUB after removing a kernel.** DETECT `grub-editenv list; grep -c 'with Linux' /boot/grub/grub.cfg`. REPAIR `grub-set-default 0` after mkconfig. Risk low.
11. **Secure Boot on, unsigned GRUB/kernel -> "bad shim signature".** DETECT `bootctl status | grep -i 'secure boot'` or `mokutil --sb-state`. REPAIR RUN: tell the user to disable it, or `sbctl` flow. Never auto: enroll keys.
12. **Dual boot: Windows entry gone.** DETECT `os-prober` output vs grub.cfg; `GRUB_DISABLE_OS_PROBER=false`. REPAIR set it, `grub-mkconfig`. Risk low.
13. **Btrfs snapshot boot menu broken (grub-btrfs).** DETECT `systemctl is-enabled grub-btrfsd; ls /boot/grub/grub-btrfs.cfg`. REPAIR `grub-mkconfig`, enable `grub-btrfsd`. Risk low.
14. **Hibernate/resume device wrong.** DETECT `grep resume /proc/cmdline` vs swap UUID. REPAIR remove `resume=` if no swap. Low.

## B. Packages and updates

15. **Stale `/var/lib/pacman/db.lck`.** DETECT `[ -e db.lck ] && ! pgrep -x pacman`. REPAIR `rm`. Risk none.
16. **Interrupted upgrade (half-installed, "unable to lock", partial downloads).** DETECT `find /var/cache/pacman/pkg -name '*.part' -o -name 'download-*'`; `pacman -Qk 2>&1|grep -v '0 altered'`. REPAIR delete partials, `pacman -Syu`. Risk low. Never auto: `-Rdd`.
17. **Keyring broken ("invalid or corrupted package (PGP signature)", unknown key).** DETECT `pacman-key --list-keys` empty, `pacman -Syy` error text. REPAIR `rm -rf /etc/pacman.d/gnupg; pacman-key --init; pacman-key --populate archlinux`; then `pacman -S archlinux-keyring` first. Risk low (live: gnupg dir is a mount: empty it).
18. **Corrupt sync databases.** DETECT `for f in /var/lib/pacman/sync/*.db; do bsdtar -tf $f >/dev/null; done`. REPAIR remove, `pacman -Syy`. Low.
19. **Corrupt local db (`/var/lib/pacman/local/*/desc` missing).** DETECT `pacman -Dk`. REPAIR restore from `/var/lib/pacman` backup or `pacman -S --overwrite '*' $(pkg)`. Medium. Never auto: delete local db entries.
20. **Removed a core package (`pacman -Rdd`, `base`, `linux`, `systemd`).** DETECT `pacman -Qg base` vs `pacman -Qq base`-members: `comm -13 <(pacman -Qq|sort) <(pacman -Sgq base|sort)`; `pacman -Qk`. REPAIR `pacman -S --needed $(pacman -Sgq base) linux linux-firmware` (LIVE with chroot if pacman itself is gone: `pacman --sysroot`/`-r /mnt`). Low.
21. **Missing/overwritten files of a package.** DETECT `pacman -Qkk 2>&1|grep -v ' 0 altered'` (ignore config files). REPAIR `pacman -S --noconfirm $(pkgs)` after backing up configs. Medium (overwrites local edits of non-config files).
22. **Mirrors dead / slow (404, timeouts).** DETECT `pacman -Syy` fails; `curl -fsI --max-time 5 $(first Server)/core/os/x86_64/core.db`. REPAIR `rate-mirrors --allow-root arch` -> /etc/pacman.d/mirrorlist (keep backup); fallback `Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch`. Low.
23. **Custom repo broken/unsigned ([sunshine], [chaotic-aur]).** DETECT `pacman -Sy` error for that repo. REPAIR comment the repo out temporarily and tell the user (never leave the system unable to update). Low.
24. **pacman.conf missing core/extra or edited wrongly.** DETECT `grep -E '^\[(core|extra)\]'`; `pacman-conf --repo-list`. REPAIR restore `pacman.conf.pacnew`. Low.
25. **Unmerged .pacnew for security-critical files (mirrorlist, pacman.conf, sudoers, mkinitcpio.conf, grub, fstab).** DETECT `find /etc -name '*.pacnew'`. REPAIR `pacdiff -o` listing; auto-merge only when the user never changed the file (compare to packaged `pacman -Qo` md5). Never auto: merge sudoers/fstab.
26. **Partial upgrade / library mismatch (`libicu`, `libssl` .so.N not found).** DETECT `ldd $(command -v pacman) | grep 'not found'`; `pacman -Qk`; `checkupdates` shows major .so bumps. REPAIR full `pacman -Syu` (never `-Sy pkg`); if pacman itself is broken: LIVE chroot or static `pacman-static`. Medium.
27. **Kernel/modules mismatch after upgrade without reboot (`/usr/lib/modules/$(uname -r)` missing).** DETECT `[ -d /usr/lib/modules/$(uname -r) ]`. REPAIR tell the user to reboot; do not load modules. Pacman hook "last update" helps (`kernel-modules-hook`).
28. **DKMS module failed (nvidia/virtualbox) after kernel update.** DETECT `dkms status | grep -v installed`. REPAIR `dkms autoinstall -k $(ls /usr/lib/modules)`; install matching `*-headers`. Low.
29. **AUR helper broken after libalpm bump (paru: `libalpm.so.NN`).** DETECT `paru --version`. REPAIR `pacman -S paru` (from [chaotic]/[sunshine]) or rebuild `paru -S paru`. Low.

## C. Drivers, graphics, display

30. **NVIDIA driver/kernel mismatch -> black screen or fallback to llvmpipe.** DETECT `nvidia-smi` fails but `lspci -k | grep -A3 NVIDIA` shows nvidia; `glxinfo -B | grep llvmpipe`. REPAIR `nvidia-open-dkms` (Turing+) or `nvidia-dkms`, `nvidia-utils`, `nvidia_drm.modeset=1 fbdev=1`, `mkinitcpio -P`. Medium. Never auto on hybrid laptops without PRIME check.
31. **Hybrid graphics: wrong GPU renders / external monitor dead.** DETECT `lspci | grep -E 'VGA|3D'` count 2; `prime-run glxinfo -B`. REPAIR `nvidia-prime`/`switcheroo-control`, `__NV_PRIME_RENDER_OFFLOAD=1`; Wayland: `KWIN_DRM_DEVICES`. Medium.
32. **SDDM does not start (black screen / loops).** DETECT `systemctl --failed`; `journalctl -b -u sddm -p err`. REPAIR `systemctl reset-failed sddm`; move `/etc/sddm.conf.d/*` away one by one; set session to plasma-x11 as fallback; `pacman -S sddm`. Low.
33. **Broken user session config (Plasma panel gone, wrong theme, crash loop).** DETECT `journalctl --user -b | grep -c 'plasmashell.*segfault'`; `~/.config/plasma-org.kde.plasma.desktop-appletsrc` missing applets. REPAIR rename `~/.config/plasma*` and `~/.cache/plasmashell` to `.bak`, re-run `sunshine-plasma-setup --reapply` (keep the backup). Low; never auto-delete user files.
34. **No Wayland session file / wrong `Session=` in sddm state.** DETECT `ls /usr/share/wayland-sessions/plasma.desktop`; `/var/lib/sddm/state.conf`. REPAIR reinstall `plasma-workspace`, write the state file. Low.
35. **Missing firmware (Wi-Fi/GPU) after minimal install.** DETECT `dmesg | grep -i 'firmware.*failed'`. REPAIR `pacman -S linux-firmware` (+ `linux-firmware-nvidia`, `sof-firmware`, `alsa-firmware`). Low.

## D. Disk and filesystem

36. **Root filesystem full (ENOSPC), includes btrfs metadata full.** DETECT `df -h /`; `btrfs fi usage /` (Free (estimated) vs metadata). REPAIR `paccache -rk1`, `journalctl --vacuum-size=200M`, `snapper delete` old, `btrfs balance start -dusage=5 /`. Medium. Never auto: delete user files.
37. **Filesystem errors (ext4 needs fsck, btrfs csum errors).** DETECT `journalctl -b -k | grep -E 'EXT4-fs error|BTRFS error|I/O error'`; `btrfs device stats /`; `smartctl -H`. REPAIR LIVE unmounted `e2fsck -fy`; btrfs: `btrfs scrub start -B`, `btrfs check --readonly` first. Never auto: `btrfs check --repair`, `-fy` on a mounted fs.
38. **Snapshots eat the disk / snapper timeline huge.** DETECT `snapper list|wc -l`; `btrfs qgroup show`. REPAIR `snapper cleanup number; snapper cleanup timeline`. Low.
39. **Swap/zram misconfigured -> freezes under load.** DETECT `swapon --show`; `zramctl`; `free -m`. REPAIR `/etc/systemd/zram-generator.conf`, `earlyoom`. Low.

## E. Network, users, time

40. **No network after update (NetworkManager disabled / iwd conflict / DNS).** DETECT `systemctl is-active NetworkManager`; `nmcli g`; `resolvectl status`; `getent hosts archlinux.org`. REPAIR `systemctl enable --now NetworkManager`; disable duplicate (dhcpcd, iwd standalone); `ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf`. Low.
41. **User locked out (sudoers broken, wheel missing, password lost, faillock).** DETECT `visudo -c`; `id USER | grep wheel`; `faillock --user USER`. REPAIR LIVE `sunshine-rescue passwd USER`, `visudo` fix via chroot, `faillock --user USER --reset`. Never auto: change sudoers content, only restore the packaged `/etc/sudoers` if `visudo -c` fails.
42. **Home directory permissions/ownership wrong, `~/.local` unwritable (login loops).** DETECT `find ~ -maxdepth 2 ! -user $USER`. REPAIR `chown -R USER: ~` only for the dotfiles that are root-owned. Medium.
43. **Clock wrong -> TLS/pacman signature errors.** DETECT `timedatectl show -p NTPSynchronized`. REPAIR `timedatectl set-ntp true`; `hwclock --systohc`. Low.
44. **Locale/keymap broken (`locale: Cannot set`).** DETECT `locale 2>&1|grep -i cannot`; `/etc/locale.gen` lines. REPAIR `locale-gen`, write `/etc/locale.conf`. Low.
45. **Identity overwritten by filesystem update (os-release).** DETECT `sunshine-identity check`. REPAIR `sunshine-identity apply` (pacman hook). Low.

## What must never be done automatically (summary)
`pacman -Rdd` or removing kernels/base; `btrfs check --repair`; `fsck -y` on a mounted filesystem; `luks*` format/erase; `grub-install` to a disk the user did not choose; merging sudoers/fstab pacnews; deleting anything in the user's home; enrolling Secure Boot keys; changing partition tables; writing NVRAM on a machine other than the one being repaired.

## Suggested test harness shape (for test/break-repair.sh)
For each numbered item a tiny function `break_N` (runs in the VM over ssh/guestcontrol) and `verify_N` (the DETECT command must succeed), driven in a loop: snapshot the VM (VBoxManage snapshot), break, run `sunshine-doctor --fix` (RUN items) or reboot into live + `sunshine-rescue repair` (LIVE items), verify, restore the snapshot. Items 1-5, 15-18, 20, 22, 24, 36, 40 are cheapest and cover most real-world failures.
