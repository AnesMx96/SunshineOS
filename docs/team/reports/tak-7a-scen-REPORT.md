# Report: break-repair test scenarios 28-34

## What I did
Created 7 new scenario files under `test/break/` (numbers 28-34), following the exact style of the existing scenarios (one-line shellcheck header, `vm`/`vmr` helpers only for remote commands, single-quoted remote commands). Each file defines `TITLE`, `break()`, `expect_detect()`, `verify()`, and (where the default doctor repair cannot fix the break) `repair_alt()` or `precondition()`/`DETECT_ONLY` as specified. All files pass `bash -n` and `shellcheck -S warning`.

## Files created
- `test/break/28-vmlinuz-corrupt.sh`
- `test/break/29-efi-fallback-stale.sh`
- `test/break/30-nvram-entry-lost.sh`
- `test/break/31-pacman-conf-no-core.sh`
- `test/break/32-base-member-removed.sh`
- `test/break/33-mirrorlist-empty.sh`
- `test/break/34-booted-snapshot-note.sh`
- `REPORT.md`

## Notes on implementation choices
- 28: corrupts `/boot/vmlinuz-linux` with 1 MB from `/dev/urandom`; `verify` uses `cmp -s` against `/usr/lib/modules/$(ls /usr/lib/modules | tail -1)/vmlinuz`; `repair_alt` restores the kernel image from the modules tree.
- 29: precondition requires UEFI + existing fallback loader; break overwrites it with random bytes; `verify` compares against `grubx64.efi` if present, otherwise checks size > 100000 and an `MZ` header; `repair_alt` runs `grub-install --removable`.
- 30: precondition requires UEFI + `efibootmgr`; break deletes every boot entry whose label contains `SunshineOS`; `verify` checks `efibootmgr` output still contains `SunshineOS`; `repair_alt` reinstalls the NVRAM entry.
- 31: removes the `[core]` section with `awk`, keeping `/etc/pacman.conf.break-backup`; `verify` checks `pacman-conf --repo-list` contains `core`; `repair_alt` restores the backup.
- 32: removes the small `base` group member `which` via `pacman -Rdd --noconfirm which`; `verify` checks `pacman -Qq which`; `repair_alt` reinstalls it.
- 33: copies then truncates `/etc/pacman.d/mirrorlist`; `verify` checks for a `^Server` line and a working `pacman -Sy`; `repair_alt` restores the backup.
- 34: `DETECT_ONLY=1`, btrfs-root precondition, creates `/run/sunshine-test-snapshot-boot`, `expect_detect` pattern `snapshot`, `verify` is `true`.

## What I could not do
- I did not run the scenarios against a VM (no VM available in this environment); only `--list`, `bash -n`, and `shellcheck` were run.
- I did not modify `sunshine-doctor` or any other file: the task restricted changes to new scenario files (plus `REPORT.md`). Scenarios that the current doctor cannot detect/repair are therefore expected to surface as `GAP`/`FAIL` in the harness rather than `PASS`.

## Decisions the senior developer must make
- The `expect_detect` regexes for the new gaps (28-33) describe messages the doctor does not yet print; if the doctor is later taught to detect them, the wording must match these patterns or the patterns must be updated.
- `repair_alt` commands were added so non-detecting scenarios classify as `GAP` instead of `FAIL`; confirm these alternative repairs are acceptable (some, such as restoring the `.break-backup` files, simply undo the break rather than exercising a Sunshine tool).
- Whether 32 should use `which` (as instructed) or `util-linux`/`sed` (noted as alternatives in the task).

## `test/break-repair.sh --list` output
```
01-stale-db-lock                   stale pacman lock file (no pacman running)
02-empty-gnupg                     empty /etc/pacman.d/gnupg (keyring gone)
03-sync-dbs-deleted                /var/lib/pacman/sync/*.db deleted
04-sync-db-truncated               truncated sync database (core.db cut to 64 bytes)
05-community-repo-readded          [community] (removed from Arch) re-added to pacman.conf
06-sunshine-repo-removed           [sunshine] repository removed from pacman.conf
07-initramfs-deleted               /boot/initramfs-linux.img deleted
08-vmlinuz-deleted                 /boot/vmlinuz-linux deleted
09-grub-cfg-empty                  /boot/grub/grub.cfg emptied (file exists, no menu entries)
10-remove-sddm                     login manager removed (pacman -Rdd sddm)
11-remove-networkmanager           NetworkManager removed (pacman -Rdd networkmanager)
12-remove-sudo                     sudo removed (pacman -Rdd sudo): no root access for the user  [live ISO]
13-fstab-bad-esp-uuid              /etc/fstab: wrong UUID for the EFI partition (boot drops to emergency mode)  [live ISO]
14-esp-unmounted                   EFI partition not mounted at /boot/efi
15-bootx64-deleted                 EFI/BOOT/BOOTX64.EFI (fallback loader) deleted
16-os-release-arch                 os-release replaced by Arch's (identity lost)
17-mkinitcpio-bad-hook             mkinitcpio.conf with a hook that does not exist (next kernel update would fail)
18-root-disk-full                  root file system full (fake package files fill the pacman cache)
19-networkmanager-stopped          NetworkManager service stopped and failed
20-sudoers-broken                  broken file in /etc/sudoers.d (sudo refuses to run for everyone)  [live ISO]
21-corrupt-cache-package           corrupt package file in the pacman cache
22-wrong-clock                     system clock wrong and NTP off (TLS and signature errors follow)
23-ucode-missing                   CPU microcode package removed
24-orphan-pacnew                   unreviewed .pacnew files for pacman.conf-adjacent and sudoers files
25-dkms-unbuilt                    DKMS module not built for the installed kernel
26-partial-upgrade                 partial upgrade: databases refreshed (pacman -Sy) without upgrading
27-snapper-config-removed          snapper config for / removed (btrfs only)
28-vmlinuz-corrupt                 /boot/vmlinuz-linux present but corrupt (random data)
29-efi-fallback-stale              EFI/BOOT/BOOTX64.EFI (fallback loader) present but stale
30-nvram-entry-lost                NVRAM boot entry for SunshineOS lost
31-pacman-conf-no-core             [core] section removed from /etc/pacman.conf
32-base-member-removed             a small member of the base group removed (which)
33-mirrorlist-empty                /etc/pacman.d/mirrorlist emptied
34-booted-snapshot-note            system booted from a read-only snapshot (note only)
```
