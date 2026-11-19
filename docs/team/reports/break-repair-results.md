# Break-and-repair results on Sol-inst (btrfs, UEFI), 2026-11-19

Harness: `test/break-repair.sh` (34 scenarios in `test/break/`). The run was stopped at 09:17 after 24 scenarios because the host disk was nearly full and the senior needed the RAM for the ISO builds; scenarios 25-34 were NOT run. The VM was rolled back to its clean snapshot and powered off. Tools under test: the senior's `team/night-run` as pushed to the VM before the run (doctor/rescue with confirm-before-write); the live ISO of 02:24 plus the tools pushed over ssh for the three LIVE scenarios.
Caveat: the host disk was 100% full from about 08:25 to 08:50 (VirtualBox pauses VMs then); scenarios 13 and 14 ran in that window, so re-run them.

## Summary (24 run: 17 PASS, 3 GAP, 4 FAIL)

| # | Scenario | Result | Why |
|---|---|---|---|
| 01 | stale pacman lock | PASS | |
| 02 | empty /etc/pacman.d/gnupg | PASS | |
| 03 | sync databases deleted | PASS | |
| 04 | truncated sync database | PASS | |
| 05 | [community] re-added | PASS | |
| 06 | [sunshine] repo removed | PASS | |
| 07 | initramfs deleted | PASS | |
| 08 | vmlinuz deleted | PASS | |
| 09 | grub.cfg emptied | PASS | |
| 10 | sddm removed | PASS | |
| 11 | NetworkManager removed | PASS | |
| 12 | sudo removed (LIVE) | FAIL | rescue listed `missing: sudo` and stopped: the new confirm-before-write needs `SUNSHINE_RESCUE_YES=1` and my non-interactive run had neither a tty nor the variable. Not a product bug as such; re-run with the variable. Suggestion: with no tty and no variable the tool should say "not repaired: needs confirmation" and exit non-zero. |
| 13 | wrong UUID of the ESP in fstab (LIVE) | FAIL | the installed system did not boot after the live repair (emergency mode): rescue reports missing UUIDs but cannot fix them. Run during the full-disk window: re-run. |
| 14 | ESP not mounted | FAIL | doctor detects it (warning) but `--fix` does not remount `/boot/efi` (it is in fstab: `mount /boot/efi`). |
| 15 | BOOTX64.EFI deleted | PASS | |
| 16 | os-release replaced by Arch's | PASS | |
| 17 | mkinitcpio.conf with a missing hook | GAP | doctor detects it (clear message) but only reports (by design). My verify was too weak (mkinitcpio only warns and still builds): fixed in the scenario. |
| 18 | root file system full | FAIL | doctor detects, `--fix` now runs the cleanup but "freed 0 MB": my fake files were three different package names, so `paccache -rk1` kept all of them. Scenario fixed (three versions of one package); re-run. |
| 19 | NetworkManager stopped | PASS | |
| 20 | broken file in /etc/sudoers.d (LIVE) | PASS | rescue + doctor inside the chroot set the file aside |
| 21 | corrupt package file in the pacman cache | GAP | doctor does not detect it; `sunshine-fix-pacman` repairs it. Add `zstd -tq` over `/var/cache/pacman/pkg/*.pkg.tar.zst` to the doctor (report, and delete with --fix). |
| 22 | wrong clock, NTP off | GAP | doctor detects; `--fix` did not get it synchronised within my 5 s wait (the alt command `timedatectl set-ntp true` with a 10 s wait did): probably only timing, make the doctor wait/verify or report "sync started". |
| 23 | CPU microcode removed | PASS | |
| 24 | orphan .pacnew files | PASS | detect only |
| 25-34 | DKMS, partial upgrade, snapper config, vmlinuz corrupt, EFI fallback stale, NVRAM entry, [core] missing, base member removed, empty mirrorlist, snapshot boot | NOT RUN | stopped for disk/RAM; scenario 32 and the others are ready |

## Real product gaps found (for the senior)
1. **ESP unmounted** (14): `sunshine-doctor --fix` should `mount /boot/efi` when it is in fstab and not mounted.
2. **Wrong fstab UUID** (13): `sunshine-rescue` cannot repair it and the system then drops to emergency mode. Proposal: when exactly one unmounted partition matches the entry's filesystem type (vfat for /boot/efi) offer to rewrite the UUID (with a backup `fstab.sunshine-backup`).
3. **Corrupt package cache file** (21): add the check to the doctor.
4. **Clock** (22): verify after `set-ntp true` (wait up to 20 s) or say it was started.
5. **Rescue without confirmation** (12): clear message and non-zero exit when it needs a confirmation and has no tty/`SUNSHINE_RESCUE_YES`.
6. Re-run after the scenario fixes: 12, 13, 17, 18, and the not-run 25-34.

## Per-scenario log excerpts

### 01-stale-db-lock:: stale pacman lock file (no pacman running)

baseline doctor: 0 problem(s)
detect: yes (expected /stale lock/)

Doctor after the break:
```
      ✘ stale lock file /var/lib/pacman/db.lck
      ! clock is not synchronised (certificates and updates can fail)
    1 problem(s) found — run: sunshine-doctor --fix
      ✘ stale lock file /var/lib/pacman/db.lck
      ! clock is not synchronised (certificates and updates can fail)
    1 problem(s) found
```

### 02-empty-gnupg:: empty /etc/pacman.d/gnupg (keyring gone)

baseline doctor: 0 problem(s)
detect: yes (expected /keyring (missing|empty)/)

Doctor after the break:
```
      ✘ package keyring missing or empty
      ! clock is not synchronised (certificates and updates can fail)
    1 problem(s) found — run: sunshine-doctor --fix
      ✘ package keyring missing or empty
    1 problem(s) found
```

### 03-sync-dbs-deleted:: /var/lib/pacman/sync/*.db deleted

baseline doctor: 0 problem(s)
detect: yes (expected /sync (database|db)|databases? (missing|not synchron)/)

Doctor after the break:
```
      ! package databases missing or damaged: sunshine core extra multilib chaotic-aur
      ! package databases missing or damaged: sunshine core extra multilib chaotic-aur
```

### 04-sync-db-truncated:: truncated sync database (core.db cut to 64 bytes)

baseline doctor: 0 problem(s)
detect: yes (expected /sync (database|db)|database.*(damaged|corrupt)/)

Doctor after the break:
```
      ! package databases missing or damaged: core
      ! package databases missing or damaged: core
```

### 05-community-repo-readded:: [community] (removed from Arch) re-added to pacman.conf

baseline doctor: 0 problem(s)
detect: yes (expected /community|repositor(y|ies)/)

Doctor after the break:
```
      ! package databases missing or damaged: community
      ✘ pacman.conf has the obsolete or unstable repository [community]
      ! clock is not synchronised (certificates and updates can fail)
    1 problem(s) found — run: sunshine-doctor --fix
      ! package databases missing or damaged: community
      ✘ pacman.conf has the obsolete or unstable repository [community]
    1 problem(s) found
```

### 06-sunshine-repo-removed:: [sunshine] repository removed from pacman.conf

baseline doctor: 0 problem(s)
detect: yes (expected /\[sunshine\].*(repository|missing)/)

Doctor after the break:
```
      ✘ the [sunshine] package repository is missing or wrong in /etc/pacman.conf
      ! clock is not synchronised (certificates and updates can fail)
    1 problem(s) found — run: sunshine-doctor --fix
      ✘ the [sunshine] package repository is missing or wrong in /etc/pacman.conf
      ! clock is not synchronised (certificates and updates can fail)
    1 problem(s) found
```

### 07-initramfs-deleted:: /boot/initramfs-linux.img deleted

baseline doctor: 0 problem(s)
detect: yes (expected /initramfs.*(missing|empty)/)

Doctor after the break:
```
      ✘ /boot/initramfs-linux.img missing or empty
    1 problem(s) found — run: sunshine-doctor --fix
      ✘ /boot/initramfs-linux.img missing or empty
    1 problem(s) found
```

### 08-vmlinuz-deleted:: /boot/vmlinuz-linux deleted

baseline doctor: 0 problem(s)
detect: yes (expected /vmlinuz-linux missing/)

Doctor after the break:
```
      ✘ /boot/vmlinuz-linux missing
    1 problem(s) found — run: sunshine-doctor --fix
      ✘ /boot/vmlinuz-linux missing
    1 problem(s) found
```

### 09-grub-cfg-empty:: /boot/grub/grub.cfg emptied (file exists, no menu entries)

baseline doctor: 0 problem(s)
detect: yes (expected /grub\.cfg|GRUB menu/)

Doctor after the break:
```
      ✘ /boot/grub/grub.cfg is missing or has no boot entries
      ! clock is not synchronised (certificates and updates can fail)
      ! no snapshot entries in the GRUB menu yet
    1 problem(s) found — run: sunshine-doctor --fix
      ✘ /boot/grub/grub.cfg is missing or has no boot entries
    1 problem(s) found
```

### 10-remove-sddm:: login manager removed (pacman -Rdd sddm)

baseline doctor: 0 problem(s)
detect: yes (expected /sddm/)

Doctor after the break:
```
      ✘ package database problem: error: missing 'sddm' dependency for 'sddm-kcm' 
      ✘ core packages missing: sddm
      ! expected package not installed: sddm
      ! an update was applied since the last restart: restart to use it
    2 problem(s) found — run: sunshine-doctor --fix
      ✘ package database problem: error: missing 'sddm' dependency for 'sddm-kcm' 
      ✘ core packages missing: sddm
      ! an update was applied since the last restart: restart to use it
    2 problem(s) found
```

### 11-remove-networkmanager:: NetworkManager removed (pacman -Rdd networkmanager)

baseline doctor: 0 problem(s)
detect: yes (expected /NetworkManager|network service/)

Doctor after the break:
```
      ✘ package database problem: error: missing 'networkmanager' dependency for 'network-manager-applet' error: missing 'networkmanager' dependency for 'networkmanager-qt' 
      ✘ core packages missing: networkmanager
      ! an update was applied since the last restart: restart to use it
    2 problem(s) found — run: sunshine-doctor --fix
      ✘ package database problem: error: missing 'networkmanager' dependency for 'network-manager-applet' error: missing 'networkmanager' dependency for 'networkmanager-qt' 
      ✘ core packages missing: networkmanager
      ! an update was applied since the last restart: restart to use it
    2 problem(s) found
```

### 12-remove-sudo:: sudo removed (pacman -Rdd sudo): no root access for the user

baseline doctor: 0 problem(s)
detect: yes (expected /sudo/)

Live repair:
```
    ✘ 🫖 the package database is damaged
```

### 13-fstab-bad-esp-uuid:: /etc/fstab: wrong UUID for the EFI partition (boot drops to emergency mode)

baseline doctor: 0 problem(s)
detect: yes (expected /fstab/)

Doctor after the break:
```
      ! /etc/fstab has problems (run: findmnt --verify)
```

### 14-esp-unmounted:: EFI partition not mounted at /boot/efi

baseline doctor: 0 problem(s)
detect: yes (expected /EFI partition not mounted/)

Doctor after the break:
```
      ✘ EFI fallback boot file (EFI/BOOT/BOOTX64.EFI) is missing: some firmwares will not find the system
      ! EFI partition not mounted at /boot/efi (kernel/GRUB updates may not reach it)
    1 problem(s) found — run: sunshine-doctor --fix
      ✘ EFI fallback boot file (EFI/BOOT/BOOTX64.EFI) is missing: some firmwares will not find the system
      ! EFI partition not mounted at /boot/efi (kernel/GRUB updates may not reach it)
    1 problem(s) found
```

Doctor after the repair:
```
      ✘ EFI fallback boot file (EFI/BOOT/BOOTX64.EFI) is missing: some firmwares will not find the system
    1 problem(s) found — run: sunshine-doctor --fix
```

### 15-bootx64-deleted:: EFI/BOOT/BOOTX64.EFI (fallback loader) deleted

baseline doctor: 0 problem(s)
detect: yes (expected /EFI fallback boot file/)

Doctor after the break:
```
      ✘ EFI fallback boot file (EFI/BOOT/BOOTX64.EFI) is missing: some firmwares will not find the system
      ! clock is not synchronised (certificates and updates can fail)
    1 problem(s) found — run: sunshine-doctor --fix
      ✘ EFI fallback boot file (EFI/BOOT/BOOTX64.EFI) is missing: some firmwares will not find the system
    1 problem(s) found
```

### 16-os-release-arch:: os-release replaced by Arch's (identity lost)

baseline doctor: 0 problem(s)
detect: yes (expected /identity was changed/)

Doctor after the break:
```
      ✘ system identity was changed (an update replaced os-release/issue)
    1 problem(s) found — run: sunshine-doctor --fix
      ✘ system identity was changed (an update replaced os-release/issue)
    1 problem(s) found
```

### 17-mkinitcpio-bad-hook:: mkinitcpio.conf with a hook that does not exist (next kernel update would fail)

baseline doctor: 0 problem(s)
detect: yes (expected /mkinitcpio|hook/)

Doctor after the break:
```
      ✘ mkinitcpio.conf names hooks that do not exist: nonexistenthook  (the next kernel update would fail to build an initramfs)
    1 problem(s) found — run: sunshine-doctor --fix
      ✘ mkinitcpio.conf names hooks that do not exist: nonexistenthook  (the next kernel update would fail to build an initramfs)
    1 problem(s) found
```

Doctor after the repair:
```
      ✘ mkinitcpio.conf names hooks that do not exist: nonexistenthook  (the next kernel update would fail to build an initramfs)
    1 problem(s) found — run: sunshine-doctor --fix
```

### 18-root-disk-full:: root file system full (fake package files fill the pacman cache)

baseline doctor: 0 problem(s)
detect: yes (expected /root disk .*% full/)

Doctor after the break:
```
      ! /boot has only 78 MB free (kernel updates may fail: remove old kernels with sunshine-kernel remove)
      ! clock is not synchronised (certificates and updates can fail)
      ✘ root disk 100% full
    1 problem(s) found — run: sunshine-doctor --fix
      ! /boot has only 78 MB free (kernel updates may fail: remove old kernels with sunshine-kernel remove)
      ✘ root disk 100% full
    1 problem(s) found
```

Doctor after the repair:
```
      ✘ root disk 100% full
    1 problem(s) found — run: sunshine-doctor --fix
```

### 19-networkmanager-stopped:: NetworkManager service stopped and failed

baseline doctor: 0 problem(s)
detect: yes (expected /NetworkManager is not running|failed services/)

Doctor after the break:
```
      ! NetworkManager is not running
      ! NetworkManager is not running
      ! NetworkManager is not running
      ! NetworkManager is not running
```

### 20-sudoers-broken:: broken file in /etc/sudoers.d (sudo refuses to run for everyone)

baseline doctor: 0 problem(s)
detect: yes (expected /sudo configuration has a syntax error/)

Doctor after the break:
```
      ✘ sudo configuration has a syntax error (sudo would refuse to work)
    1 problem(s) found — run: sunshine-doctor --fix
```

Live repair:
```
    Repair finished. Restart and remove the live medium.
```

### 21-corrupt-cache-package:: corrupt package file in the pacman cache

baseline doctor: 0 problem(s)
detect: no (expected /cache|corrupt/)

Doctor after the break:
```
      ! clock is not synchronised (certificates and updates can fail)
      ! clock is not synchronised (certificates and updates can fail)
```

### 22-wrong-clock:: system clock wrong and NTP off (TLS and signature errors follow)

baseline doctor: 0 problem(s)
detect: yes (expected /clock is not synchronised/)

Doctor after the break:
```
      ! clock is not synchronised (certificates and updates can fail)
      ! failed services: shadow.service 
      ! clock is not synchronised (certificates and updates can fail)
      ! failed services: shadow.service 
```

### 23-ucode-missing:: CPU microcode package removed

baseline doctor: 0 problem(s)
detect: yes (expected /ucode|microcode/)

Doctor after the break:
```
      ! an update was applied since the last restart: restart to use it
      ! intel-ucode is not installed (CPU security fixes)
      ! an update was applied since the last restart: restart to use it
      ! intel-ucode is not installed (CPU security fixes)
```

### 24-orphan-pacnew:: unreviewed .pacnew files for pacman.conf-adjacent and sudoers files

baseline doctor: 0 problem(s)
detect: yes (expected /\.pacnew/)

Doctor after the break:
```
      ! 2 config update(s) waiting for review (*.pacnew)
```
