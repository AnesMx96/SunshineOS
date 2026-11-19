# REPORT — tak-7a installer comparison (2026-11-19)

## What I did

I completed the local research and proposal task on branch `agent/tak-7a-calam` in worktree `agents/wt-tak7a-calam`. I re-read the full Sunshine Calamares configuration (`profile/airootfs/etc/calamares/settings.conf`, all 22 files in `profile/airootfs/etc/calamares/modules/`, `branding/sunshine/branding.desc`, `profile/airootfs/usr/share/sunshine/netinstall.yaml`, the first 80 lines of `profile/airootfs/usr/share/sunshine/catalogue.toml`, and `profile/airootfs/usr/local/bin/sunshine-install`) and the scripts those modules call. I read the read-only comparison trees under `/home/tak/sunshineos-build/research/` (EndeavourOS, CachyOS, upstream Calamares, Garuda) and produced:

- one research report with the requested side-by-side module sequence table, a purpose+problem row for every Sunshine module, other-installer features with path/line evidence, tester failure points, and 12 ranked changes;
- 12 standalone proposal snippets (seven `.conf`, five `.sh`), one per proposal;
- this `REPORT.md`;
- one append-only log entry in `docs/team/log/tak-7a.md` as required by `docs/team/TASKS.md:3-5`.

No existing source file was changed. No push, Docker, VirtualBox/VBoxManage, `pacman`, `sudo`, `systemctl`, `mount`, network install/download or VM start was performed.

## Evidence quoted from source files

| Claim | Path and line quote |
|---|---|
| Sunshine has no confirmation and disables cancel during execution | `profile/airootfs/etc/calamares/settings.conf:72` — `prompt-install: false`; `:76` — `disable-cancel-during-exec: true` |
| Sunshine’s show phase has no chooser except apps | `profile/airootfs/etc/calamares/settings.conf:33-40` — `welcome, locale, keyboard, partition, users, netinstall, summary` |
| Locale default is hard-coded | `profile/airootfs/etc/calamares/modules/locale.conf:2-3` — `region: "Europe"`, `zone: "Madrid"` |
| Bootloader is GRUB-only with fixed kernel paths | `profile/airootfs/etc/calamares/modules/bootloader.conf:2-5` — `efiBootLoader: "grub"`, `kernel: "/vmlinuz-linux"`, `img: "/initramfs-linux.img"`, `fallback: ""` |
| Swap is disabled and LUKS1 is forced | `profile/airootfs/etc/calamares/modules/partition.conf:5-6,14-15` — `userSwapChoices: [ none ]`, `initialSwapChoice: none`, `luksGeneration: luks1` |
| Reboot defaults to checked | `profile/airootfs/etc/calamares/modules/finished.conf:2` — `restartNowMode: user-checked`; upstream explains this at `/home/tak/sunshineos-build/research/calamares/src/modules/finished/finished.conf:29-31` |
| Offline app selection is silently skipped but DB update remains on | `profile/airootfs/etc/calamares/modules/packages.conf:3-5` — comment, `skip_if_no_internet: true`, `update_db: true` |
| Crypt setup runs late and writes only `cryptkey` | `profile/airootfs/etc/calamares/settings.conf:47,60` vs `profile/airootfs/usr/local/bin/sunshine-crypt-setup:10-11`; CLI writes all three parameters at `profile/airootfs/usr/local/bin/sunshine-install:319` |
| Snapshots can abort Calamares but CLI ignores it | `profile/airootfs/etc/calamares/modules/shellprocess-snapshots.conf:7` has no `ignoreErrors`; `profile/airootfs/usr/local/bin/sunshine-snapshots-setup:13,16,56,62` contains `exit 1`; CLI uses `\|\| true` at `sunshine-install:291` |
| Calamares has no final verification, CLI does | `settings.conf:68` ends exec at `umount`; `sunshine-install:334-337` checks `grub.cfg`, initramfs and UEFI fallback |
| EOS has desktop/bootloader/swap choices and log copy | `/home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/modules/packagechooser.conf:6-8`, `modules/bootloader.conf:7-8`, `modules/partition.conf:15-19`, `modules/shellprocess_copyfiles.conf:13-15` |
| CachyOS has bootloader/desktop/kernel/mirror/hardware features | `/home/tak/sunshineos-build/research/cachyos-calamares/src/modules/packagechooser/packagechooser_bootloader.conf:6-40`, `packagechooser_desktop.conf:23-53`, `partition/partition.conf:30-34,64-83`, `shellprocess/shellprocess_initialize_pacman.conf:10-22`, `settings.conf:67` |
| Upstream documents chooser/contextualprocess/netinstall semantics | `/home/tak/sunshineos-build/research/calamares/src/modules/packagechooser/packagechooser.conf:16-34`, `contextualprocess/contextualprocess.conf:4-16,47-60`, `netinstall/netinstall.conf:11-16` |
| Garuda fails loudly on systemd-boot install and defaults to LUKS2/argon2id | `/home/tak/sunshineos-build/research/g-pkgbuilds/calamares-garuda/0004-bootloader-install-systemd-boot-in-the-target.patch:3-8,64-69`, `garuda-specific-patches.patch:519-546,636-646` |
| Only Garuda NixOS full sequence exists in research tree | `/home/tak/sunshineos-build/research/g-garuda-nix/packages/calamares-nixos-extensions/config/settings.conf:114-131,127,145` |

All other claims in the research report are tied to paths and lines in the same way; the report does not infer a missing distro sequence or config file.

## Files created

1. `docs/team/research/tak-7a-installer-compare.md` — main comparison report.
2. `docs/team/reports/installer-proposals/01-confirm-and-reboot.conf`
3. `docs/team/reports/installer-proposals/02-locale-not-hardcoded.sh`
4. `docs/team/reports/installer-proposals/03-bootloader-choice.conf`
5. `docs/team/reports/installer-proposals/04-desktop-choice.conf`
6. `docs/team/reports/installer-proposals/05-swap-layout.conf`
7. `docs/team/reports/installer-proposals/06-driver-detection.sh`
8. `docs/team/reports/installer-proposals/07-verify-install.sh`
9. `docs/team/reports/installer-proposals/08-mirror-keyring.conf`
10. `docs/team/reports/installer-proposals/09-encryption-options.conf`
11. `docs/team/reports/installer-proposals/10-offline-skipped-apps.sh`
12. `docs/team/reports/installer-proposals/11-live-leftovers.sh`
13. `docs/team/reports/installer-proposals/12-kernel-choice.conf`
14. `REPORT.md` — this file.

## Files modified

1. `docs/team/log/tak-7a.md` — appended one timestamped work-log entry; no earlier line was altered. Standing requirement: `docs/team/TASKS.md:3-5`.

No file under `profile/`, `src/`, `tools/`, `test/` or any other source tree was created, modified or deleted.

## Validation performed

Commands run from the worktree root:

```sh
bash -n docs/team/reports/installer-proposals/*.sh
export PATH=/home/tak/.local/bin:$PATH; shellcheck -S warning docs/team/reports/installer-proposals/*.sh
python3 -c 'import glob,sys,yaml
files=sorted(glob.glob("docs/team/reports/installer-proposals/*.conf"))
for f in files:
    yaml.safe_load(open(f))
    print("OK", f)
print("checked", len(files), "conf files")'
```

Results:

- `bash -n`: no output, exit 0 for all five `.sh` files.
- `shellcheck -S warning`: no output, exit 0 for all five `.sh` files.
- `yaml.safe_load`: printed `OK` for all seven `.conf` files and `checked 7 conf files`.

The research report reproduces every proposal verbatim in section 5, so the report and the standalone snippets cannot drift silently.

## What could not be done

- **No runtime proof.** No ISO was built, no VM was started, and no Calamares or CLI installer was executed. The proposals are static, syntax-validated artifacts only.
- **No network-dependent verification.** Web downloads, package installs and mirror/keyring ranking were not run; proposal 08 deliberately copies the live keyring/mirrorlist offline instead of claiming a network-tested path.
- **Garuda Arch sequence unavailable.** The research tree contains a complete Garuda-branded sequence only for the NixOS extension (`g-garuda-nix/.../config/settings.conf:114-131,145`). It is used in the side-by-side table with an explicit limitation, never presented as Arch Garuda. The only Arch Garuda evidence available is patch/config evidence under `g-pkgbuilds/calamares-garuda/`.
- **Some upstream example configs absent.** `.conf` examples for `networkcfg`, `hwclock`, `localecfg`, `summary` and `hardwaredetect` were not found at the expected upstream paths, so the report cites only module names in distro sequences and does not quote nonexistent files.
- **Proposal 10 limitation.** It reads default-selected entries from `usr/share/sunshine/netinstall.yaml`; it does not read the live checkbox state from Calamares global storage. The file and report say this explicitly.
- **CLI remains unchanged where noted.** Proposals primarily target Calamares. The CLI still hard-codes LUKS1 (`sunshine-install:179`), creates no swap partition (`:166-170`), keeps the shallow size check (`:152-155`) and uses `|| true` for Hyprland/snapshots (`:265`, `:291`).
- **No source patch applied.** Nothing was staged or committed from the installer source tree; a senior developer must review and port the proposals.

## Senior-developer decisions recorded

1. Use the Garuda NixOS `settings.conf` for the Garuda sequence row and disclose the limitation; do not invent an Arch Garuda sequence.
2. Treat `.conf` proposal files as valid YAML change bundles/drop-in configs and validate all of them with `yaml.safe_load`.
3. Keep GRUB/LUKS1 as the safe default until bootloader choice (rank 03) and verification (rank 07) are tested; pair LUKS2/argon2id with systemd-boot/Limine overrides (rank 09).
4. Use upstream `contextualprocess` plus documented `packagechooser_<id>` global storage keys for conditional desktop installation; do not assume unobserved shellprocess condition syntax.
5. Rank offline-safe, one-line correctness fixes first; mark optional rEFInd/Limine/lts/zen paths `partial` instead of assuming they are on the ISO.
6. Treat Calamares GUI and `sunshine-install` CLI as separate installers; every proposal that leaves CLI behavior unchanged says so.
7. Work docs-only in this worktree and commit locally on `agent/tak-7a-calam`; never push.

## Result

The branch contains only the documentation artifacts listed above plus the log append. The working tree was clean at the start of the task and is clean after the local commit. Nothing was pushed.
