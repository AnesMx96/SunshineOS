# How EndeavourOS, Garuda and CachyOS detect/repair the break-repair scenarios (tak-7a, 2026-11-19)

Sources read (paths under `~/sunshineos-build/research/`): `g-pkgbuilds/garuda-health/garuda-health` (Python, 1559 lines), `g-pkgbuilds/garuda-hooks/garuda-hooks-runner` + `pacnew-check.hook`, `g-pkgbuilds/garuda-libs/pacdiff-merge`, `g-pkgbuilds/garuda-update/main-update`, `garuda-boot-repair/mainwindow.cpp`, `eos-iso/root/usr/bin/eos-update`, `CachyOS-Settings/usr/bin/{cachyos-bugreport.sh,sbctl-batch-sign}`. Scenario numbers are the files in `test/break/`.
Nothing here is guessed: where a tool was not found in those trees it says "not found".

## What each distro really has

**Garuda** (the most complete): `garuda-health` is a catalogue of ~25 checks with severities (NO_ISSUE, INFO, LOW, HIGH, CRITICAL) and prioritised fixers that ask for consent (`run_interactive_command(..., require_consent=True)`), run in a fixed priority order, and exclude each other (e.g. a full update fix excludes the pacman.conf fix). Checks: core packages (`base`, `chaotic-keyring`, `chaotic-mirrorlist` = CRITICAL, line 514), important packages, deprecated/optional packages, **pacman.conf must exist and contain `[garuda] [core] [extra] [chaotic-aur]`** (572), NVIDIA driver + kernel module state (616-730), btrfs root free space (732), btrfs timers, dracut in use, pipewire in use, **partial upgrade** (856, a flag file `/var/lib/garuda/partial_upgrade` set by a pacman hook: after a transaction that did not do a full `-Syu`, if `pacman -Qu` is not empty the hook touches the flag; empty -> removes it and touches `last_update`; `garuda-hooks-runner` lines 60-71), outdated system (>2 weeks), pending reboot, failed systemd services, old btrfs snapshots (fix: `snapper-tools delete-old`), CPU temperature, **time sync** (fix `timedatectl set-ntp true`, line 386), SMART, RAM, **initramfs build success flag** `/var/lib/garuda/initramfs_error` (set/removed by the hook, lines 162-171; fix `dracut-rebuild`), snapper services and config (fix = reset config), **kernels in /boot** (1220: for every kernel in `/usr/lib/modules` both `/boot/vmlinuz-<k>` and `/boot/initramfs-<k>.img` must exist, and the image must be **byte-identical** to `/usr/lib/modules/<k>/vmlinuz` (`filecmp.cmp(..., shallow=False)`); no valid kernel = CRITICAL, one missing = HIGH), EFI boot manager entry (1284: `efibootmgr` current entry must be "Garuda"), packagekit.
`garuda-hooks-runner`: after a GRUB upgrade it re-runs `grub-install --no-nvram` for the EFI binary, installs only the GRUB modules the config needs, signs with `sbsign` when Secure Boot keys exist, and **keeps the fallback copies `EFI/Boot/grubx64.efi` and `bootx64.efi` identical** (`cmp -s`, lines 96-130). It also refuses pacman operations while booted into a snapshot (line 78).
`pacnew-check.hook`: after every transaction prints `pacdiff -o`. `pacdiff-merge`: makes a snapper snapshot first, skips `/etc/pacman.d/mirrorlist` (deletes its pacnew), refuses files with `chattr +i`, merges with meld.
`garuda-update/main-update`: mirrors via `rate-mirrors --allow-root --max-delay=21600` (falls back to `reflector --latest 10 --age 2 ...`), **throws the result away if the file is empty** ("a bug in rate-mirrors creates empty files sometimes"), retries a failed transaction with `--overwrite` when the only conflicts are `__pycache__/*.pyc` files, has `--no-space-check`, AUR via paru/yay.
`garuda-boot-repair` (Qt, from live): detects LUKS (`cryptsetup isLuks` -> `luksOpen ... chrootfs`), mounts btrfs `subvol=@`, binds dev/sys/proc, reads the target's `/etc/fstab` to mount `/boot` and `/boot/efi`, `chroot ... grub-install --target=i386-pc|<arch>-efi --bootloader-id=Garuda --recheck --force` then `update-grub`, unmounts and closes LUKS. **Only GRUB** (no initramfs, kernel, fstab, fsck, password).

**EndeavourOS**: `eos-update` (`eos-iso/root/usr/bin/eos-update`): handles a dangling `db.lck` (line 645), checks free disk space before updating (`--min-free-bytes`), updates `archlinux-keyring endeavouros-keyring` first (line 161), `--keyrings-reset` (157): **moves** `/etc/pacman.d/gnupg` to `/root/pacman-key.bak.<date>` (a backup, not a delete), `pacman-key --init`, `--populate archlinux endeavouros`, `-Syy`, `-Syu`; `ClearDatabases` (167: `rm -r /var/lib/pacman/sync`), `paccache -rk 1..5` (236-250), shows archlinux.org news, wraps yay/paru, mirror list editing with reflector instructions. No health checker and no live-session repair tool found in `eos-iso/root` (the `grep` for chroot only finds translations and the ISO build script).

**CachyOS** (`CachyOS-Settings`): no doctor/repair tool found there. What exists: `cachyos-bugreport.sh` (root, writes `cachyos-bugreport.log`, asks before including sensitive parts), `paste-cachyos` (upload), `sbctl-batch-sign` (signs many EFI files for Secure Boot, important when dual booting Windows; refuses on Limine), `game-performance`, `kerver`, `topmem`, `pci-latency`, `eac-setup`, `dlss-swapper`, sysctl (`70-cachyos-settings.conf`), `zram-generator.conf`, `thp-shrinker`, `coredump` tmpfiles, modprobe files. Hardware: `chwd` profiles (`research/chwd/profiles/pci/graphic_drivers/profiles.toml`) which run `mkinitcpio -P` after driver changes.

## Per scenario

| # | Scenario | Garuda | EndeavourOS | CachyOS | Sunshine today (doctor 181 lines + tools) |
|---|---|---|---|---|---|
| 01 | stale db.lck | `garuda-bash-config`/`garuda-fish-config` and `garuda-assistant` (`garudaassistant.cpp`) reference `db.lck` (shell helper / assistant action; not read in detail) | `eos-update` (645) removes it when pacman is not running | not found | doctor `--fix` removes it |
| 02 | empty gnupg | `garuda-assistant` (`garudaassistant.cpp`) calls `pacman-key` (not read in detail) | `--keyrings-reset` (moves the dir to a **backup**, init, populate, `-Syy`, `-Syu`) | not found | doctor `--fix` and `sunshine-fix-pacman` (deletes, no backup: adopt EOS backup) |
| 03 | sync dbs deleted | `main-update` uses `-yy` when `DATABASE_UPDATED=force` | `ClearDatabases` + normal update re-downloads | not found | `sunshine-fix-pacman` only repairs damaged ones; doctor does not look: **gap** |
| 04 | truncated sync db | as 03 | as 03 | not found | `sunshine-fix-pacman` (`bsdtar -tf`) yes, doctor no |
| 05 | [community] re-added | health checks required repos only (missing, not extra) | not found | not found | neither; **our doctor should compare `pacman-conf --repo-list` with a known good list and flag unknown repos that return 404** |
| 06 | [sunshine] removed | `check_pacman_conf` CRITICAL, fix = remote pacman.conf replacement (295-310) | not found | not found | doctor + `sunshine-repo ensure` (good) |
| 07 | initramfs deleted | `check_kernels_in_boot` + `/var/lib/garuda/initramfs_error` flag | not found | `chwd` runs `mkinitcpio -P` after driver changes | doctor per kernel (good) |
| 08 | vmlinuz deleted | as 07 (and **content comparison**) | not found | not found | doctor restores a missing one; **does not detect a present but wrong/corrupt image: adopt Garuda's `cmp` against `/usr/lib/modules/<k>/vmlinuz`** |
| 09 | grub.cfg empty | grub hook runs `update-grub` after GRUB upgrades | not found | not found | doctor only tests that the file exists: **gap** (test `grep -q menuentry`) |
| 10 | sddm removed | core/important packages check -> `pacman -S` | not found | not found | doctor warns only: **gap** (no fix) |
| 11 | networkmanager removed | `networkmanager-support` package; health enables services (`fix_enable_services`, line 275) | not found | not found | doctor warns only |
| 12 | sudo removed | not found | not found | not found | not covered anywhere; live `sunshine-rescue run -- pacman -S sudo` would work; **add to rescue repair: reinstall `base sudo` members missing** |
| 13 | fstab wrong ESP UUID | boot-repair reads the target's fstab only to mount | not found | not found | `sunshine-rescue` reports missing UUIDs but does not fix: **gap** (could rewrite with `blkid`/`lsblk -f` after asking) |
| 14 | ESP unmounted | not found | not found | not found | doctor warns |
| 15 | BOOTX64.EFI deleted | hooks keep the fallback `EFI/Boot/*.efi` identical to the main binary | not found | not found | doctor restores via `grub-install --removable` (good; Garuda's cmp check would also catch a *stale* fallback) |
| 16 | os-release replaced | `garuda-hooks-runner` line 8 rewrites `/usr/lib/os-release` after filesystem updates | not found | not found | `sunshine-identity` + hook (good) |
| 17 | bad mkinitcpio hook | uses dracut; `initramfs_error` flag after failed build | not found | `chwd` calls `mkinitcpio -P` | our hook records `initramfs_error`; nothing validates HOOKS before: **add `mkinitcpio -k <ver> -g /tmp/x` dry build to doctor** |
| 18 | root full | `check_btrfs_root_storage` (732), old-snapshot cleanup | space check before update (`--min-free-bytes`), `paccache -rkN` | not found | `sunshine-update` got a space check; doctor flags >=95% but does not free space |
| 19 | NetworkManager stopped | `fix_enable_services` | not found | not found | doctor warns only |
| 20 | broken sudoers.d | not found | not found | not found | nobody; **needs live rescue (`visudo -c`, move bad file to /root)** |
| 21 | corrupt cache package | `garuda-assistant` references `paccache` (not read in detail) | `paccache` | not found | `sunshine-fix-pacman` (`zstd -t`) yes |
| 22 | wrong clock | `check_time_sync` + fix `timedatectl set-ntp true` (consent) | not found | not found | doctor warns only: **gap** |
| 23 | ucode missing | not found | `shellprocess_removeucode.conf` (installer removes the other vendor's ucode) | not found | doctor installs (good) |
| 24 | orphan pacnew | `pacnew-check.hook` after every transaction + `pacdiff-merge` with snapshot, skip list, `chattr +i` check | `--pacdiff` (deprecated option) | not found | doctor counts them; no hook, no merge helper: **gap** |
| 25 | DKMS unbuilt | `fix_dkms_rebuild` (441) | not found | not found | doctor `dkms autoinstall` (good) |
| 26 | partial upgrade | flag-file approach (856 + hook 60-71): **the cleanest design** | `eos-update` always runs `-Syu` | not found | not detected: **adopt the hook flag** (PostTransaction: `pacman -Qu` non-empty after a non-full transaction -> `/var/lib/sunshine/partial_upgrade`; doctor fix = `pacman -Syu`) |
| 27 | snapper config removed | `check_snapper_config` + `fix_snapper_reset_config` | not found | not found | doctor + `sunshine-snapshots-setup` (good) |

## Things their tools handle that ours does not (adopt, in priority order)

1. **Partial-upgrade flag via pacman hook** (Garuda `garuda-hooks-runner` 60-71; check 856). Real and common cause of unbootable systems.
2. **Kernel integrity by content**, not presence (Garuda check at 1220: `filecmp` `/boot/vmlinuz-<k>` vs `/usr/lib/modules/<k>/vmlinuz`).
3. **Required-repos check with a CRITICAL level for core/extra and unknown-repo detection** (Garuda 572).
4. **Core package set check** (Garuda 514: `base` + distro keyrings) as a CRITICAL with a fix that reinstalls `pacman -Sgq base` members.
5. **Keyring reset that keeps a backup** (EOS `ResetKeyrings`, line 157) and **update keyrings first** (EOS line 161); we already do keyring first in `sunshine-update`.
6. **Empty mirrorlist guard** (Garuda `main-update` 62-80: discard the rate-mirrors result if empty). Ours checks `grep '^Server'`: fine.
7. **EFI fallback copies kept identical to the main loader** after a GRUB update (Garuda hook 96-130) instead of only checking the file exists.
8. **`efibootmgr` check** that our entry is the current/first boot entry (Garuda 1284), plus a repair `efibootmgr -c`.
9. **pacnew workflow**: PostTransaction hook listing `.pacnew` (Garuda `pacnew-check.hook`), merge helper with pre-merge snapshot, skip list (mirrorlist), `lsattr` immutability check (`pacdiff-merge`).
10. **Consent + priority + exclusion model for fixers** (Garuda `Fixer(priority, excludes, actions)`): our doctor repairs in file order; it never asks.
11. **Refuse package operations while booted into a read-only snapshot** (Garuda hook line 78) with a clear message.
12. **Secure Boot helper** (CachyOS `sbctl-batch-sign`) and a doctor check `mokutil --sb-state` / `bootctl status`.
13. **Bug report collector** (CachyOS `cachyos-bugreport.sh`: root-only dmesg, ask before including sensitive parts, `.old` rotation) vs our `sunshine-diagnose`: compare the content list.
14. **Retry with `--overwrite` for known harmless conflicts** (Garuda `main-update` 44-47: only `__pycache__/*.pyc`).

## What ours does that they do not (keep, advertise)
Live rescue of the whole system, not only GRUB (`sunshine-rescue`: fsck, package db/keyring, kernel, initramfs, fstab check, GRUB UEFI+BIOS, password reset, chroot, LUKS and btrfs subvolumes); identity protection hook; one tool per concern but one doctor (`--fix` is non-interactive); signed tool updates independent of the ISO.

## Scenarios to add to the harness (their tools have checks for them)
28 vmlinuz present but corrupt (truncate to 1 MB; Garuda detects, ours does not); 29 EFI fallback loader present but stale (copy a random file over BOOTX64.EFI); 30 NVRAM entry lost (`efibootmgr -B`); 31 booted into a read-only btrfs snapshot then update; 32 `pacman.conf` without `[core]`; 33 required package `base` member removed (`pacman -Rdd coreutils` is too destructive for a VM test: use `util-linux`); 34 empty mirrorlist.
