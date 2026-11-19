# Sunshine OS installer vs EndeavourOS, CachyOS, upstream Calamares and Garuda (tak-7a, 2026-11-19)

## Scope, sources and method

I read the complete Sunshine Calamares configuration in this worktree (`profile/airootfs/etc/calamares/settings.conf`, all 22 files in `profile/airootfs/etc/calamares/modules/`, `branding/sunshine/branding.desc`, `profile/airootfs/usr/share/sunshine/netinstall.yaml`, the first 80 lines of `profile/airootfs/usr/share/sunshine/catalogue.toml`, and `profile/airootfs/usr/local/bin/sunshine-install`). I also read the scripts that the `shellprocess` instances actually call (`sunshine-post-install`, `sunshine-hyprland-install`, `sunshine-crypt-setup`, `sunshine-snapshots-setup`, `sunshine-set-shell`, `sunshine-detect-location`) so that the module purposes below are not guesses.

Comparison sources were read only from `/home/tak/sunshineos-build/research/`: EndeavourOS (`eos-iso/root/etc/calamares/`), CachyOS (`cachyos-calamares/`), upstream Calamares (`calamares/`), Garuda (`g-pkgbuilds/calamares-garuda/`, `g-pkgbuilds/calamares-tools/`, `g-pkgbuilds/garuda-systemd-boot/`, `g-garuda-nix/packages/calamares-nixos-extensions/`). No source file in this worktree was changed. No ISO, VM, container, pacman transaction, mount, sudo, systemctl or network install was run.

### Limitations that must be disclosed with this report

- **Garuda row is NixOS, not Arch.** The only complete Garuda-branded Calamares `settings.conf` found in the research tree is `/home/tak/sunshineos-build/research/g-garuda-nix/packages/calamares-nixos-extensions/config/settings.conf:114-131` (it uses `nixos` in exec at line 127 and `branding: garuda` at line 145). No normal Arch Garuda `settings.conf` sequence was present, so this report does not invent one. Garuda Arch evidence here is limited to patches and helper config (`g-pkgbuilds/...`).
- **Upstream is a template, not a distro installer.** `calamares/settings.conf:121-163` is the shipped example sequence. It is useful as a baseline for module order and semantics, but it is not a Garuda/EOS/CachyOS production sequence.
- **Some upstream example `.conf` files were not found** at the expected paths: `networkcfg`, `hwclock`, `localecfg`, `summary` and `hardwaredetect`. Their module names appear in distro sequences, but this report does not cite those nonexistent config files.
- **No runtime proof.** The proposals are static files validated with `bash -n`, `shellcheck -S warning` and `yaml.safe_load`; they were not installed into an ISO or run in Calamares.

---

## 1. Side-by-side module sequence

The table below is the one side-by-side sequence comparison. “show” entries are pages, “exec” entries are jobs. The order is copied exactly from each `settings.conf`; the final `finished` page and the two safety flags are included where the file defines them.

| Installer / config | show phase | exec phase | final / flags | Evidence |
|---|---|---|---|---|
| **Sunshine OS** | `welcome → locale → keyboard → partition → users → netinstall → summary` | `partition → mount → unpackfs → machineid → fstab → luksbootkeyfile → locale → keyboard → localecfg → shellprocess@location → shellprocess@cleanup → shellprocess@hyprland → shellprocess@netup → packages → shellprocess@netdown → shellprocess@ownbase → users → shellprocess@usershell → shellprocess@crypt → shellprocess@snapshots → networkcfg → hwclock → services-systemd → initcpio → grubcfg → bootloader → umount` | `finished`; `prompt-install: false`; `disable-cancel-during-exec: true` | `profile/airootfs/etc/calamares/settings.conf:32-70,72,76` |
| **EndeavourOS offline** | `welcome@offline → locale → keyboard → packagechooserq → partition → usersq → summary` | `partition → mount → unpackfs → machineid → locale → keyboard → localecfg → luksbootkeyfile → dracutlukscfg → fstab → removeuser → shellprocess@fixes → usersq → networkcfg → displaymanager → eos_pacman → packages@offline → hwclock → eos_script@cleaner_script → eos_script@chrooted_cleaner_script → hardwaredetect → eos_bootloader@offline → windowsbootentry → grubcfg → bootloader → services-systemd → preservefiles → shellprocess@removepackagefiles → shellprocess@copyfiles → umount` | `finished`; `prompt-install: true`; `disable-cancel-during-exec: false` | `/home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/settings_offline.conf:41-82,86,94` |
| **EndeavourOS online** | `welcome@online → locale → keyboard → packagechooser → netinstall → packagechooserq → partition → usersq → summary` | `partition → mount → eos_pacman → pacstrap → machineid → locale → keyboard → localecfg → usersq → networkcfg → userpkglist → packages@online → luksbootkeyfile → dracutlukscfg → fstab → shellprocess@xfcewall → displaymanager → hwclock → eos_script@cleaner_script → eos_script@chrooted_cleaner_script → hardwaredetect → eos_bootloader → grubcfg → windowsbootentry → bootloader → services-systemd → eos_script@user_commands → preservefiles → shellprocess@copyfiles → umount` | `finished`; `prompt-install: true`; `disable-cancel-during-exec: false` | `/home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/settings_online.conf:38-81,85,93` |
| **CachyOS** | `welcome@online → locale → keyboard → partition → packagechooser → netinstall → users → summary` | `partition → zfs → mount → shellprocess@modify_mk_hook → shellprocess@initialize_pacman → pacstrap → machineid → locale → keyboard → localecfg → chwd → shellprocess@before-online → packages@online → luksbootkeyfile → luksopenswaphookcfg → fstab → plymouthcfg → zfshostid → initcpiocfg → initcpio → users → networkcfg → displaymanager → hwclock → bootloader → shellprocess@reset_mk_hook → services-systemd → shellprocess → shellprocess@enable_ufw → shellprocess@btrfs_snapshot → shellprocess@cleanup_calamares → umount` | `finished`; `prompt-install: true`; `disable-cancel-during-exec: false` | `/home/tak/sunshineos-build/research/cachyos-calamares/settings.conf:46-90,94,102` |
| **Upstream Calamares example** | `welcome → locale → keyboard → partition → users → summary` | `partition → mount → unpackfs → machineid → locale → keyboard → localecfg → fstab → initcpiocfg → initcpio → users → displaymanager → networkcfg → hwclock → services-systemd → initramfs → bootloader → umount` | `finished` | `/home/tak/sunshineos-build/research/calamares/settings.conf:121-163` |
| **Garuda NixOS extension (limitation: not Arch)** | `welcome → locale → keyboard → users → packagechooser → netinstall@features → partition → summary` | `partition → mount → nixos → users → umount` | `finished`; `branding: garuda`; `prompt-install: false` | `/home/tak/sunshineos-build/research/g-garuda-nix/packages/calamares-nixos-extensions/config/settings.conf:114-131,145,153` |

What the sequence comparison shows: Sunshine is the only row with no choice page at all besides `netinstall` (`settings.conf:33-40`), the only one with `prompt-install: false` plus `disable-cancel-during-exec: true` (`settings.conf:72,76`), and one of the few that puts a `shellprocess` cleanup before user creation and another after it (`settings.conf:52,58`). EOS and CachyOS both put a chooser in the show phase and a hardware/cleanup job in the exec phase; upstream supplies the `contextualprocess` mechanism that can make such choices conditional.

---

## 2. Every Sunshine module: purpose and problem

This table covers all 22 files in `profile/airootfs/etc/calamares/modules/`. Each “purpose” cell is one sentence; the “problem” cell gives the concrete tester-visible issue with path and line evidence.

| Module file | Purpose (one sentence) | Problem(s) with evidence |
|---|---|---|
| `welcome.conf` | Gates installation on storage/RAM/root and exposes support links (`modules/welcome.conf:5-10`; `branding/sunshine/branding.desc:18-21`). | It probes the external URL `https://archlinux.org` (`modules/welcome.conf:8`) although the CLI is advertised as offline (`usr/local/bin/sunshine-install:2`), and known-issues/release-notes URLs are hidden (`modules/welcome.conf:3-4`). |
| `locale.conf` | Seeds the locale page with a starting region/zone and locale.gen path (`modules/locale.conf:2-4`). | `Europe/Madrid` is hard-coded (`modules/locale.conf:2-3`) although upstream supports `useSystemTimezone` (`/home/tak/sunshineos-build/research/calamares/src/modules/locale/locale.conf:23-30`) and the CLI defaults to UTC (`usr/local/bin/sunshine-install:92`). |
| `partition.conf` | Defines the ESP, btrfs default, automated LUKS and initial erase choice (`modules/partition.conf:2-15`). | Swap is limited to `none` (`modules/partition.conf:5-6,14`), encryption is locked to `luks1` (`:15`), and the default is destructive `erase` (`:13`) with no bootloader-aware overrides like CachyOS (`/home/tak/sunshineos-build/research/cachyos-calamares/src/modules/partition/partition.conf:64-83`). |
| `users.conf` | Creates the first account with group, sudo, shell and password policy (`modules/users.conf:2-13`). | `minLength: 1` plus `allowWeakPasswords: true` (`modules/users.conf:10-14`) permits a trivial administrator password, and root password creation is disabled (`:6`). |
| `netinstall.conf` | Shows the local app catalogue groups from `file:///usr/share/sunshine/netinstall.yaml` (`modules/netinstall.conf:2-8`). | `required: false` (`:8`) and catalogue entries for AUR/web apps (`usr/share/sunshine/netinstall.yaml:14-18,71-75`; `usr/share/sunshine/catalogue.toml:6-10`) let an offline tester tick apps the installer cannot deliver. |
| `packages.conf` | Installs selected packages with pacman and retries downloads (`modules/packages.conf:2-9`). | `skip_if_no_internet: true` (`:4`) silently drops selected apps while `update_db: true` (`:5`) still attempts a refresh; EOS separates those cases into offline/online configs (`/home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/modules/packages_offline.conf:7-10`, `packages_online.conf:7-15`). |
| `bootloader.conf` | Installs and configures GRUB for UEFI with the Sunshine ID and fallback loader (`modules/bootloader.conf:2-12`). | It is GRUB-only (`:2`), hard-codes kernel/img paths (`:3-5`) and has no `efiBootLoaderVar`, unlike EOS (`/home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/modules/bootloader.conf:7-8`) and CachyOS (`/home/tak/sunshineos-build/research/cachyos-calamares/src/modules/bootloader/bootloader.conf:12-17`). |
| `grubcfg.conf` | Writes GRUB defaults, OS prober, timeout and pastel kernel parameters (`modules/grubcfg.conf:2-13`). | `overwrite: false` (`:2`) and `always_use_defaults: false` (`:13`) let the ISO’s existing `/etc/default/grub` win, and recovery entries are disabled (`:9`). |
| `initcpio.conf` | Builds an initramfs image for every installed kernel (`modules/initcpio.conf:2`). | `kernel: all` is unconditional and there is no `initcpiocfg` job in the sequence (`settings.conf:65` has only `initcpio`), so hooks depend on separate scripts (`usr/local/bin/sunshine-post-install:38`, `usr/local/bin/sunshine-snapshots-setup:70-73`). |
| `mount.conf` | Binds live pseudo-filesystems and creates a fixed btrfs subvolume layout with mount options (`modules/mount.conf:21-74,121-129`). | The layout is not user-selectable (`:52-69`), and although btrfs swap subvolume/options exist (`:71-74,128-129`), `partition.conf:5-6` disables every swap choice. |
| `services-systemd.conf` | Enables NetworkManager, SDDM, graphical target and optional helpers (`modules/services-systemd.conf:2-20`). | SDDM is mandatory (`:5-6`) even though there is no desktop choice and Hyprland is always run (`settings.conf:33-40,53`), so a text-only tester still gets a display manager. |
| `unpackfs.conf` | Unpacks the ISO squashfs into the target root (`modules/unpackfs.conf:2-5`). | The source is fixed to `/run/archiso/bootmnt/arch/x86_64/airootfs.sfs` (`:3`) while the CLI copies from `/run/archiso/airootfs` (`usr/local/bin/sunshine-install:9`), so the two installers are not interchangeable in a test. |
| `finished.conf` | Defines the final page and reboot command (`modules/finished.conf:2-4`). | `restartNowMode: user-checked` (`:2`) defaults to rebooting (upstream `finished.conf:29-31`) and `notifyOnFinished: false` (`:4`) hides the result, so a tester can lose the log before inspection. |
| `shellprocess-location.conf` | Records the install location for Sunshine tool language defaults and never fails the install (`modules/shellprocess-location.conf:2-9`). | It can still make an external HTTPS request to ipapi.co for Europe/Paris (`usr/local/bin/sunshine-detect-location:3,8`), and `ignoreErrors: true` (`modules/shellprocess-location.conf:5`) hides that from the installer. |
| `shellprocess-cleanup.conf` | Runs `sunshine-post-install` in the chroot to strip live-session files and set GRUB/theme/kernel defaults (`modules/shellprocess-cleanup.conf:2-5`; `usr/local/bin/sunshine-post-install:2-39`). | It runs before user creation and crypt setup (`settings.conf:52` vs `:58,60`), so encryption and snapshot details are split across three scripts that must stay in sync (`usr/local/bin/sunshine-crypt-setup:7-11`, `usr/local/bin/sunshine-snapshots-setup:70-73`). |
| `shellprocess-hyprland.conf` | Copies the offline Hyprland payload and installs its package list from the live system (`modules/shellprocess-hyprland.conf:2-7`; `usr/local/bin/sunshine-hyprland-install:2-7,22-46`). | No desktop choice exists in the show phase (`settings.conf:33-40`) and failed packages are skipped with a Plasma fallback (`usr/local/bin/sunshine-hyprland-install:32-35,57-68`), so the tester may not get the advertised desktop. |
| `shellprocess-netup.conf` | Borrows the live resolver so chosen apps can be installed inside the target (`modules/shellprocess-netup.conf:2-8`). | It runs after the Hyprland install (`settings.conf:53-54`) although that script already swaps the resolver (`usr/local/bin/sunshine-hyprland-install:16-20`), and its fallback is a hard-coded `1.1.1.1` (`shellprocess-netup.conf:8`). |
| `shellprocess-netdown.conf` | Restores the target resolver after the packages step (`modules/shellprocess-netdown.conf:2-5`). | The command ends in `true` (`:5`) so any restore failure is swallowed, and it uses `${ROOT}/etc/resolv.conf.sunshine-apps` while Hyprland uses `.sunshine-bak` (`usr/local/bin/sunshine-hyprland-install:17-20`). |
| `shellprocess-ownbase.conf` | Registers the already-copied Sunshine tools with pacman from the signed ISO repo (`modules/shellprocess-ownbase.conf:2-11`). | `ignoreErrors: true` (`:7`) makes a failed ownership registration silent, and the offline claim depends on that ISO repo (`:3`). |
| `shellprocess-usershell.conf` | Sets fish as the login shell after the user exists (`modules/shellprocess-usershell.conf:2-5`). | The called script rewrites every UID 1000-59999, not only the account created by Calamares (`usr/local/bin/sunshine-set-shell:5`). |
| `shellprocess-crypt.conf` | Puts the LUKS key file into the initramfs and GRUB configuration (`modules/shellprocess-crypt.conf:2-7`). | It runs after `luksbootkeyfile`, `fstab` and `users` (`settings.conf:47,46,58` vs `:60`) and its script writes only `cryptkey=...` (`usr/local/bin/sunshine-crypt-setup:10-11`) whereas the CLI writes `cryptdevice`, `root` and `cryptkey` together (`usr/local/bin/sunshine-install:319`). |
| `shellprocess-snapshots.conf` | Configures Snapper on btrfs or Timeshift elsewhere, with timers and update hooks (`modules/shellprocess-snapshots.conf:2-7`; `usr/local/bin/sunshine-snapshots-setup:2-5`). | Unlike the CLI which calls it with `|| true` (`usr/local/bin/sunshine-install:291`), the Calamares instance has no `ignoreErrors` (`shellprocess-snapshots.conf:2-7`) and the script exits 1 when Timeshift/Snapper is missing or `create-config` fails (`usr/local/bin/sunshine-snapshots-setup:13,16,56,62`). |

---

## 3. What the other installers actually do

### EndeavourOS

- **Desktop chooser:** `mode: required` and `method: netinstall-add` with a “No Desktop” first item (`/home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/modules/packagechooser.conf:6-8,27-35`); it appears in both show phases (`settings_online.conf:43`, `settings_offline.conf:46`).
- **Bootloader chooser and package staging:** `efiBootLoaderVar: "packagechooser_packagechooserq"` (`modules/bootloader.conf:7-8`), `gsName: packagechooser_packagechooserq` with package maps for grub/systemd-boot/refind/none (`modules/eos_bootloader.conf:13,19-28`), `packageChoice: systemd-boot` as the QML default (`modules/packagechooserq.conf:77`), and `eos_bootloader` jobs before `bootloader` (`settings_offline.conf:72,75`; `settings_online.conf:71,74`).
- **Swap choices:** `none`, `small`, `suspend`, `file` are listed in `modules/partition.conf:15-19`; Sunshine lists only `none` (`profile/.../modules/partition.conf:5-6`).
- **Cleanup and drivers:** `_clean_archiso` removes live files (`scripts/chrooted_cleaner_script.sh:55-79`), `_clean_offline_packages` removes ISO-only packages including Calamares itself (`:81-126`), Broadcom detection/install is offline-aware (`:128-159`), firmware is selected by `lspci` (`:161-172`), and the script removes `.pacnew` files and `/etc/calamares` at the end (`:249-252`). The outside-chroot cleaner detects Broadcom hardware with `lsmod`/`lspci` (`scripts/cleaner_script.sh:35-51`).
- **Offline/online package policy:** offline uses `skip_if_no_internet: true` and `update_db: false` (`modules/packages_offline.conf:7-10`), online uses `skip_if_no_internet: false` and `update_db: true` (`modules/packages_online.conf:7-15`).
- **Logs preserved in the target:** `cp /home/liveuser/endeavour-install.log ${ROOT}/var/log/...` plus `chmod 0600` (`modules/shellprocess_copyfiles.conf:13-15`), and `preservefiles` is in both exec phases (`settings_offline.conf:77`, `settings_online.conf:77`).
- **Safer finish:** `prompt-install: true` (`settings_online.conf:85`) and `restartNowMode: user-unchecked` (`modules/finished.conf:8`).

### CachyOS

- **Bootloader choice:** required chooser with GRUB, rEFInd, systemd-boot and Limine (`/home/tak/sunshineos-build/research/cachyos-calamares/src/modules/packagechooser/packagechooser_bootloader.conf:6-40`), consumed by `efiBootLoaderVar: "packagechooser_bootloader"` (`src/modules/bootloader/bootloader.conf:12-17`).
- **Desktop/WM choice:** required chooser with “No Desktop”, Plasma, GNOME and many WMs (`src/modules/packagechooser/packagechooser_desktop.conf:23-35,38-53,51-271`) and a `packagechooser` show step (`settings.conf:52`).
- **LUKS2 and bootloader overrides:** `luksGeneration: luks2` (`src/modules/partition/partition.conf:30-34`) plus per-bootloader overrides for filesystem, ESP size and LUKS generation (`:64-83`).
- **Mirror/keyring preparation:** a dedicated `initialize_pacman` shellprocess instance (`settings.conf:29-31,61`) runs mirror update, keyring creation, mirror/keyring copies and resolv.conf copy (`src/modules/shellprocess/shellprocess_initialize_pacman.conf:10-22`).
- **Hardware configuration:** `chwd` is in the exec phase (`settings.conf:67`), and the audio/driver tooling is a first-class package set rather than a hidden shell script.
- **Live leftovers:** target cleanup removes `/home/liveuser`, helper scripts and conflicting display-manager state (`src/modules/shellprocess/shellprocess.conf:92-106`), with a separate `cleanup_calamares` instance (`settings.conf:41-43,87`).
- **Restore point:** a permanent Snapper snapshot of the fresh install is an explicit module (`src/modules/shellprocess/shellprocess_btrfs_snapshot.conf:4-14`; `settings.conf:86`).
- **Safer finish:** `prompt-install: true` (`settings.conf:94`) and `restartNowMode: user-unchecked` (`src/modules/finished/finished.conf:7`).

### Upstream Calamares

- **Sequence semantics:** a show phase defines pages, the immediately following exec phase runs their jobs plus listed job modules, and a view job not named in the following exec phase is not executed (`/home/tak/sunshineos-build/research/calamares/settings.conf:101-111`). Sunshine’s `netinstall` show step (`settings.conf:39`) and `packages` exec step (`:55`) rely on exactly this contract.
- **Chooser storage contract:** `method: legacy` writes `packagechooser_<id>` to global storage; `method: packages` hands selections to a later `packages` module (`/home/tak/sunshineos-build/research/calamares/src/modules/packagechooser/packagechooser.conf:16-34`). This is why proposals 03/04 use `legacy` + `contextualprocess` and proposal 12 uses `packages`.
- **Conditional jobs without shell hacks:** `contextualprocess` compares global-storage values and runs the associated shellprocess-style script (`/home/tak/sunshineos-build/research/calamares/src/modules/contextualprocess/contextualprocess.conf:4-16,47-60`).
- **Netinstall needs a later packages module:** the upstream netinstall example says that without a `packages` module after the netinstall, nothing is installed (`/home/tak/sunshineos-build/research/calamares/src/modules/netinstall/netinstall.conf:11-16`).
- **Swap-file contract:** if `file` is enabled in `userSwapChoices`, a `fstab` module must come later in exec (`/home/tak/sunshineos-build/research/calamares/src/modules/partition/partition.conf:79-87`); Sunshine already has `fstab` at `settings.conf:46`.
- **Logs and leftovers:** `preservefiles` can copy the Calamares log with restrictive permissions (`/home/tak/sunshineos-build/research/calamares/src/modules/preservefiles/preservefiles.conf:52-61`), and `removeuser` exists for a spilled live user (`src/modules/removeuser/removeuser.conf:4-13`).
- **Locale default:** upstream says `region`/`zone` only set the starting pin and `useSystemTimezone` can use the system’s notion instead (`/home/tak/sunshineos-build/research/calamares/src/modules/locale/locale.conf:13-30`).
- **Bootloader discovery:** upstream documents `kernelSearchPath`, `kernelPattern`, loader entries and `refindKernelList` (`/home/tak/sunshineos-build/research/calamares/src/modules/bootloader/bootloader.conf:19-36`), which Sunshine’s hard-coded `kernel`/`img` do not use.
- **Finish modes:** upstream defines `user-unchecked` as “show button, default unchecked, restart if checked” and `user-checked` as default checked (`/home/tak/sunshineos-build/research/calamares/src/modules/finished/finished.conf:20-37`).

### Garuda

- **Garuda-branded full sequence exists only for NixOS** in this research tree (`/home/tak/sunshineos-build/research/g-garuda-nix/packages/calamares-nixos-extensions/config/settings.conf:114-131,145`), and it uses an edition chooser (`config/modules/packagechooser.conf:1-27`) plus `user-unchecked` reboot (`config/modules/finished.conf:2-4`). This is a disclosure, not an Arch sequence claim.
- **Bootloader failures must be loud:** Garuda’s patch states that `bootctl --path` ignored its exit code and left a system without a bootloader behind a successful install; it changes to `check_target_env_call(["bootctl", "install", "--esp-path=...", "--variables=yes"])` (`/home/tak/sunshineos-build/research/g-pkgbuilds/calamares-garuda/0004-bootloader-install-systemd-boot-in-the-target.patch:3-8,64-69`).
- **LUKS2 with argon2id:** Garuda explicitly changes defaults to `luks2`, `luks2Hash: argon2id` and an explicit PBKDF, while noting GRUB needs PBKDF2 or a patched GRUB for argon2id (`garuda-specific-patches.patch:519-546,589-594,636-646`).
- **UKI awareness:** the bootloader patch avoids creating an empty machine-ID directory when `layout=uki` (`0004...patch:41-53`), and Garuda’s systemd-boot config uses `layout=uki` (`/home/tak/sunshineos-build/research/g-pkgbuilds/garuda-systemd-boot/install.conf:1-6`).
- **Filesystem whitelist:** Garuda patches its partition dialogs to use a fixed allowed set including btrfs, fat32, swap, unformatted and ZFS (`garuda-fswhitelist.patch:43-70`).
- **Packaging limitation:** `calamares-tools` only installs Calamares schemas (`/home/tak/sunshineos-build/research/g-pkgbuilds/calamares-tools/PKGBUILD:20-24`); it is not a distro installer sequence.

---

## 4. Current-installer tester failure points

These are the failure points a tester should be able to reproduce today. They come from the configs/scripts above, not from a VM run.

1. **No last-minute confirmation and no escape during execution.** `prompt-install: false` (`settings.conf:72`) and `disable-cancel-during-exec: true` (`:76`) mean one click on Next starts destructive work; EOS and CachyOS set both more permissive (`eos settings_online.conf:85,93`; `cachyos settings.conf:94,102`).
2. **The finish page defaults to rebooting.** `restartNowMode: user-checked` (`modules/finished.conf:2`) is defined upstream as checked by default (`calamares/src/modules/finished/finished.conf:29-31`), and `notifyOnFinished: false` (`modules/finished.conf:4`) hides the outcome.
3. **Wrong timezone for most testers.** The locale page starts on `Europe/Madrid` (`modules/locale.conf:2-3`) while the CLI starts on UTC (`sunshine-install:92`); a tester who accepts defaults gets Madrid.
4. **No choice of desktop, bootloader, swap or kernel.** The show phase has only `welcome, locale, keyboard, partition, users, netinstall, summary` (`settings.conf:33-40`); Hyprland is always installed (`:53`), GRUB is fixed (`modules/bootloader.conf:2`), swap is `none` (`modules/partition.conf:5-6`) and initramfs builds all kernels (`modules/initcpio.conf:2`).
5. **Selected apps can vanish silently offline.** `skip_if_no_internet: true` (`modules/packages.conf:4`) hides the skip while `update_db: true` (`:5`) still tries a refresh, and `netinstall required: false` (`modules/netinstall.conf:8`) makes the selection optional.
6. **An “offline” install still makes an external request.** `sunshine-detect-location` calls `https://ipapi.co/city/` when the zone is Europe/Paris (`usr/local/bin/sunshine-detect-location:3,8`), although the CLI header says no network is needed (`sunshine-install:2`).
7. **Encryption ordering and command line are fragile.** `shellprocess@crypt` runs after `luksbootkeyfile`, `fstab` and `users` (`settings.conf:47,46,58` vs `:60`) and writes only `cryptkey=...` (`sunshine-crypt-setup:10-11`) where the CLI writes `cryptdevice`, `root` and `cryptkey` (`sunshine-install:319`).
8. **Optional snapshots can abort the install.** The Calamares shellprocess has no `ignoreErrors` (`modules/shellprocess-snapshots.conf:2-7`) but the script exits 1 on missing Timeshift/Snapper or failed create-config (`sunshine-snapshots-setup:13,16,56,62`); the CLI uses `|| true` (`sunshine-install:291`).
9. **Calamares has no post-install boot verification.** Its exec phase ends at `umount` (`settings.conf:68`), while the CLI checks `grub.cfg`, initramfs and the UEFI fallback (`sunshine-install:334-337`).
10. **No install log is kept in the target.** EOS copies its log with `0600` (`shellprocess_copyfiles.conf:13-15`) and upstream has `preservefiles` (`preservefiles.conf:52-61`); Sunshine has neither module in its sequence (`settings.conf:41-68`).
11. **CLI size check can be bypassed.** `need`/`have` default to 0 and the guard requires both `> 0` (`sunshine-install:152-155`), so a failed `df` or `blockdev` skips the “disk too small” error before `wipefs -af` (`:164`).
12. **CLI wipes the chosen disk with little friction.** `wipefs -af "$DISK"` (`:164`) and `sgdisk --zap-all` (`:165`) follow only a dialog warning (`:82`); auto mode requires `SUNSHINE_DISK` but has no confirmation (`:75-77`).
13. **CLI boot-mode detection has one probe.** It sets `BOOT=uefi` only when `/sys/firmware/efi/efivars` exists (`sunshine-install:65`), then uses that value for partition tables (`:166-170`) and GRUB target (`:322-329`); a UEFI system presenting no efivars gets a BIOS layout.
14. **CLI encryption is LUKS1-only.** `cryptsetup luksFormat --type luks1` is hard-coded (`sunshine-install:179`) with the GRUB rationale in the preceding comment (`:178`), and the key file is added after `genfstab` (`:231-235`).
15. **CLI offline desktop can silently degrade.** `sunshine-hyprland-install "$MNT" || true` (`:265`) hides failures from a script that retries mirrors and can keep Plasma instead (`sunshine-hyprland-install:32-35,57-68`).
16. **CLI timezone and keyboard checks are shallow.** The timezone is only checked for a zoneinfo file (`sunshine-install:148`), and the keyboard choice is written to `vconsole.conf` (`:272`) with an unused `/etc/X11/xorg.conf.d` directory (`:273`).

---

## 5. Ranked 12 changes

`offline: yes` means the proposal needs no network for its default path; `partial` means the default can be offline but optional choices need packages staged on the ISO or a network. Risks are engineering judgement from the cited code paths, not tested results.

| Rank | Proposal file | Module / config touchpoint | Change | Offline | Risk | Why this rank |
|---|---|---|---|---|---|---|
| 1 | `docs/team/reports/installer-proposals/01-confirm-and-reboot.conf` | `settings.conf`, `modules/finished.conf` | `prompt-install: true`; `restartNowMode: user-unchecked` | yes | low | Two one-line edits remove the most dangerous tester surprise. |
| 2 | `.../02-locale-not-hardcoded.sh` | `modules/locale.conf` | Generate `region`/`zone` from live `/etc/localtime` and set `useSystemTimezone: true` | yes | low | Removes a wrong default without taking choice away from the user. |
| 3 | `.../03-bootloader-choice.conf` | `settings.conf`, `modules/bootloader.conf`, new packagechooser | Add chooser and `efiBootLoaderVar`; keep GRUB safe default | partial | medium | Required before LUKS2 or non-GRUB verification can be trusted. |
| 4 | `.../04-desktop-choice.conf` | `settings.conf`, new packagechooser/contextualprocess, `services-systemd.conf` | Conditional Hyprland/Plasma/no-desktop; SDDM optional | partial | medium | Uses upstream chooser+contextualprocess instead of inventing shell conditions. |
| 5 | `.../05-swap-layout.conf` | `modules/partition.conf`, `mount.conf` | Restore `small`, `suspend`, `file` swap choices | yes | medium | Reuses existing btrfs swap subvolume config and existing `fstab` job. |
| 6 | `.../06-driver-detection.sh` | new shellprocess instance before `packages` | Offline hardware survey into target log; no installs | yes | low | Gives testers evidence without changing package state. |
| 7 | `.../07-verify-install.sh` | new shellprocess instance before `umount` | Fail on missing kernel/initramfs/grub.cfg/menuentry/fstab/UEFI fallback | yes | low | Brings Calamares up to the CLI’s existing sanity-check bar. |
| 8 | `.../08-mirror-keyring.conf` | `settings.conf`, new shellprocess instance | Copy live mirrorlist/keyring/resolver before `packages` | yes | low | Removes silent pacman preparation gap without network calls. |
| 9 | `.../09-encryption-options.conf` | `partition.conf`, new `luksbootkeyfile.conf`, `settings.conf` | LUKS2 default with GRUB→LUKS1 override; move crypt setup earlier | yes | high | Depends on ranks 3 and 7; a mismatch can make the target unbootable. |
| 10 | `.../10-offline-skipped-apps.sh` | new shellprocess instance after `packages` | Write skipped/default-selected app report into target | yes | low | Makes the existing silent offline skip visible; limitation is documented. |
| 11 | `.../11-live-leftovers.sh` | new shellprocess instance after `users` | Remove Calamares/live leftovers and copy install log | yes | low-medium | Must run after `users` and refuse `/`; otherwise low impact. |
| 12 | `.../12-kernel-choice.conf` | `settings.conf`, new packagechooser, `bootloader.conf` | Choose linux/lts/zen via `method: packages`; discover kernels | partial | medium | Last because it depends on bootloader choice and verification. |

### Verbatim proposed snippets

The following blocks are the complete contents of the 12 proposal files. They were validated as described in section 6.

#### 01-confirm-and-reboot.conf

```yaml
# Rank 01 - confirmation before destructive work + safer reboot default.
# Change bundle, not a drop-in Calamares config: each entry under files: is the
# exact replacement to apply to the named target.
rank: 1
files:
  profile/airootfs/etc/calamares/settings.conf:
    replace:
      prompt-install: false
    with:
      prompt-install: true
  profile/airootfs/etc/calamares/modules/finished.conf:
    replace:
      restartNowMode: user-checked
    with:
      restartNowMode: user-unchecked
evidence:
  - "profile/airootfs/etc/calamares/settings.conf:72 prompt-install: false"
  - "profile/airootfs/etc/calamares/settings.conf:76 disable-cancel-during-exec: true"
  - "profile/airootfs/etc/calamares/modules/finished.conf:2 restartNowMode: user-checked"
  - "/home/tak/sunshineos-build/research/calamares/src/modules/finished/finished.conf:26-31 user-unchecked vs user-checked"
  - "/home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/settings_online.conf:85 prompt-install: true"
  - "/home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/modules/finished.conf:8 restartNowMode: user-unchecked"
offline: "yes"
risk: "low"
```

#### 02-locale-not-hardcoded.sh

```bash
#!/usr/bin/env bash
# Rank 02 - print replacement locale.conf lines derived from the live system.
# Usage: ./02-locale-not-hardcoded.sh > profile/airootfs/etc/calamares/modules/locale.conf
# Evidence: profile/airootfs/etc/calamares/modules/locale.conf:2-3;
# /home/tak/sunshineos-build/research/calamares/src/modules/locale/locale.conf:23-30;
# profile/airootfs/usr/local/bin/sunshine-install:92.
set -euo pipefail

zone=$(readlink -f /etc/localtime 2>/dev/null | sed -n 's#.*/zoneinfo/##p' || true)
[ -n "$zone" ] || zone=UTC
[ -e "/usr/share/zoneinfo/$zone" ] || zone=UTC

if [[ "$zone" == */* ]]; then
  region=${zone%%/*}
  city=${zone#*/}
else
  region=UTC
  city=$zone
fi

printf 'region: "%s"\nzone: "%s"\nuseSystemTimezone: true\n' "$region" "$city"
exit 0
```

#### 03-bootloader-choice.conf

```yaml
# Rank 03 - bootloader choice for UEFI, with GRUB as the safe default.
# Change bundle; exact keys/files below. Keep every key not mentioned here.
rank: 3
files:
  profile/airootfs/etc/calamares/settings.conf:
    add_instance:
      - id: bootloader_choice
        module: packagechooser
        config: packagechooser_bootloader.conf
    show_insert_after: keyboard
    show_insert:
      - packagechooser@bootloader_choice
  profile/airootfs/etc/calamares/modules/bootloader.conf:
    replace:
      efiBootLoader: grub
    with:
      efiBootLoaderVar: packagechooser_bootloader_choice
      efiBootLoader: grub
      kernelSearchPath: /usr/lib/modules
      kernelPattern: ^vmlinuz.*
      loaderEntries:
        - "timeout 5"
        - "console-mode auto"
      kernelParams:
        - "quiet"
        - "loglevel=3"
      refindKernelList:
        - linux
        - linux-lts
  profile/airootfs/etc/calamares/modules/packagechooser_bootloader.conf:
    create: |
      ---
      mode: required
      method: legacy
      labels:
        step: "Bootloader"
      default: grub
      items:
        - id: grub
          name: "GRUB"
          description: "BIOS and UEFI; can unlock LUKS1; safest default."
        - id: systemd-boot
          name: "systemd-boot"
          efiOnly: true
          description: "Simple UEFI loader; pair with LUKS2 and unencrypted /boot."
        - id: refind
          name: "rEFInd"
          efiOnly: true
          description: "UEFI multi-boot loader; needs its package on the ISO or network."
        - id: limine
          name: "Limine"
          description: "Modern BIOS/UEFI loader with snapshot support; needs its package on the ISO or network."
notes:
  - "Stage rEFInd/Limine packages on the ISO before offering them offline; GRUB and systemd-boot ship with the base image."
  - "Keep modules/grubcfg.conf for the GRUB branch; other loaders use loaderEntries/kernelParams above."
evidence:
  - "profile/airootfs/etc/calamares/modules/bootloader.conf:2-12"
  - "profile/airootfs/etc/calamares/settings.conf:33-40,66-67"
  - "/home/tak/sunshineos-build/research/calamares/src/modules/packagechooser/packagechooser.conf:16-28"
  - "/home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/modules/bootloader.conf:7-8"
  - "/home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/modules/eos_bootloader.conf:13,19-28"
  - "/home/tak/sunshineos-build/research/cachyos-calamares/src/modules/packagechooser/packagechooser_bootloader.conf:6-40"
  - "/home/tak/sunshineos-build/research/cachyos-calamares/src/modules/bootloader/bootloader.conf:12-17,21-36"
  - "/home/tak/sunshineos-build/research/g-pkgbuilds/calamares-garuda/0004-bootloader-install-systemd-boot-in-the-target.patch:3-8,64-69"
offline: "partial"
risk: "medium"
```

#### 04-desktop-choice.conf

```yaml
# Rank 04 - desktop choice using upstream packagechooser + contextualprocess.
# Change bundle; exact keys/files below.
rank: 4
files:
  profile/airootfs/etc/calamares/settings.conf:
    add_instance:
      - id: desktop_choice
        module: packagechooser
        config: packagechooser_desktop.conf
      - id: desktop_apply
        module: contextualprocess
        config: contextualprocess-desktop.conf
    show_insert_after: keyboard
    show_insert:
      - packagechooser@desktop_choice
    exec_replace:
      shellprocess@hyprland: contextualprocess@desktop_apply
  profile/airootfs/etc/calamares/modules/packagechooser_desktop.conf:
    create: |
      ---
      mode: required
      method: legacy
      labels:
        step: "Desktop"
      default: hyprland
      items:
        - id: hyprland
          name: "Sunshine Hyprland"
          description: "Offline Hyprland payload from the ISO; current default."
        - id: plasma
          name: "Plasma"
          description: "Already in the base image; no extra packages."
        - id: none
          name: "No desktop"
          description: "Text-only install; SDDM must be optional for this branch."
  profile/airootfs/etc/calamares/modules/contextualprocess-desktop.conf:
    create: |
      ---
      dontChroot: true
      timeout: 3600
      packagechooser_desktop_choice:
        hyprland:
          - command: "/usr/local/bin/sunshine-hyprland-install ${ROOT}"
        plasma:
          - command: "true"
        none:
          - command: "true"
  profile/airootfs/etc/calamares/modules/services-systemd.conf:
    replace_text: |
      - name: "sddm"
        mandatory: true
    with_text: |
      - name: "sddm"
        mandatory: false
notes:
  - "Keep shellprocess-hyprland.conf as a fallback file but remove shellprocess@hyprland from the exec phase once this is tested."
  - "contextualprocess uses global storage keys of the form packagechooser_<id>; no shellprocess condition syntax is invented here."
evidence:
  - "profile/airootfs/etc/calamares/settings.conf:33-40,53"
  - "profile/airootfs/etc/calamares/modules/shellprocess-hyprland.conf:2-7"
  - "profile/airootfs/usr/local/bin/sunshine-hyprland-install:2-7,22-46,57-68"
  - "/home/tak/sunshineos-build/research/calamares/src/modules/packagechooser/packagechooser.conf:16-28"
  - "/home/tak/sunshineos-build/research/calamares/src/modules/contextualprocess/contextualprocess.conf:4-16,52-60"
  - "/home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/modules/packagechooser.conf:6-8,27-35"
  - "/home/tak/sunshineos-build/research/cachyos-calamares/src/modules/packagechooser/packagechooser_desktop.conf:23-35,38-49"
offline: "partial"
risk: "medium"
```

#### 05-swap-layout.conf

```yaml
# Rank 05 - restore user-selectable swap instead of the forced 'none' choice.
# Change bundle; exact keys/files below.
rank: 5
files:
  profile/airootfs/etc/calamares/modules/partition.conf:
    replace:
      userSwapChoices: [ none ]
      initialSwapChoice: none
    with:
      userSwapChoices: [ none, small, suspend, file ]
      initialSwapChoice: none
  profile/airootfs/etc/calamares/modules/mount.conf:
    keep:
      btrfsSwapSubvol: /@swap
      btrfs_swap_mount_options_present: "profile/airootfs/etc/calamares/modules/mount.conf:71-74,128-129"
notes:
  - "fstab is already in the exec phase at settings.conf:46, which upstream requires for the file choice."
  - "The CLI installer still creates no swap partition; zram remains its only swap (sunshine-install:166-170; etc/systemd/zram-generator.conf:1-3)."
evidence:
  - "profile/airootfs/etc/calamares/modules/partition.conf:5-6,14"
  - "profile/airootfs/etc/calamares/modules/mount.conf:71-74,128-129"
  - "profile/airootfs/etc/calamares/settings.conf:46"
  - "/home/tak/sunshineos-build/research/calamares/src/modules/partition/partition.conf:79-87"
  - "/home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/modules/partition.conf:15-19"
offline: "yes"
risk: "medium"
```

#### 06-driver-detection.sh

```bash
#!/usr/bin/env bash
# Rank 06 - offline hardware survey for the target; never installs or fails the install.
# Wire as shellprocess@driver_detect before packages.
# Evidence: /home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/scripts/cleaner_script.sh:35-51;
# /home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/scripts/chrooted_cleaner_script.sh:128-172;
# /home/tak/sunshineos-build/research/cachyos-calamares/settings.conf:67.
set -uo pipefail

ROOT=${1:-}
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
  echo "usage: $0 <target-root>" >&2
  exit 2
fi

OUT="$ROOT/var/log/sunshine-hardware.txt"
mkdir -p "${OUT%/*}"

{
  echo "Sunshine OS hardware survey"
  if command -v lspci >/dev/null 2>&1; then
    lspci -nn 2>/dev/null || echo "lspci failed"
    echo
    printf 'NVIDIA devices: %s\n' "$(lspci -nn 2>/dev/null | grep -Eic 'vga.*nvidia|3d.*nvidia' || true)"
    printf 'Broadcom devices: %s\n' "$(lspci -nn 2>/dev/null | grep -Eic '14e4:' || true)"
    printf 'Wireless devices: %s\n' "$(lspci -nn 2>/dev/null | grep -Eic 'network controller.*wireless|802\.11' || true)"
    printf 'VirtualBox devices: %s\n' "$(lspci -nn 2>/dev/null | grep -Eic 'virtualbox' || true)"
  else
    echo "lspci not available; no hardware details collected"
  fi

  if [ -d /usr/share/sunshine/drivers/repo ]; then
    echo "offline driver repo present; installation left to the driver tool after first boot"
  else
    echo "no offline driver repo; no packages installed"
  fi
} > "$OUT"

cat "$OUT"
exit 0
```

#### 07-verify-install.sh

```bash
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
```

#### 08-mirror-keyring.conf

```yaml
# Rank 08 - offline-safe pacman mirror/keyring preparation before packages.
# Change bundle; exact keys/files below.
rank: 8
files:
  profile/airootfs/etc/calamares/settings.conf:
    add_instance:
      - id: initialize_pacman
        module: shellprocess
        config: shellprocess-initialize-pacman.conf
    exec_insert_before: packages
    exec_insert:
      - shellprocess@initialize_pacman
  profile/airootfs/etc/calamares/modules/shellprocess-initialize-pacman.conf:
    create: |
      ---
      dontChroot: true
      timeout: 120
      ignoreErrors: true
      i18n:
        name: "Preparing pacman mirrors and keyring (offline-safe)"
      script:
        - "mkdir -p ${ROOT}/etc/pacman.d"
        - "cp -a /etc/pacman.d/gnupg ${ROOT}/etc/pacman.d/ || true"
        - "cp -a /etc/pacman.d/mirrorlist ${ROOT}/etc/pacman.d/mirrorlist || true"
        - "cp -L /etc/resolv.conf ${ROOT}/etc/resolv.conf || true"
notes:
  - "Offline copy only; with network present, replace with CachyOS-style update-mirrorlist/create-pacman-keyring scripts."
  - "ignoreErrors is deliberate: a missing optional mirrorlist must not abort an offline install."
evidence:
  - "profile/airootfs/etc/calamares/modules/packages.conf:3-5"
  - "profile/airootfs/etc/calamares/settings.conf:54-55"
  - "/home/tak/sunshineos-build/research/cachyos-calamares/settings.conf:29-31,61"
  - "/home/tak/sunshineos-build/research/cachyos-calamares/src/modules/shellprocess/shellprocess_initialize_pacman.conf:10-22"
  - "/home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/settings_online.conf:52,66"
  - "/home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/modules/packages_online.conf:7-15"
offline: "yes"
risk: "low"
```

#### 09-encryption-options.conf

```yaml
# Rank 09 - bootloader-aware LUKS generation instead of hard-coded luks1.
# Change bundle; exact keys/files below. Depends on ranks 03 and 07.
rank: 9
files:
  profile/airootfs/etc/calamares/modules/partition.conf:
    replace:
      luksGeneration: luks1
    with:
      luksGeneration: luks2
      bootloaderOverrides:
        - name: grub
          luksGeneration: luks1
        - name: systemd-boot
          luksGeneration: luks2
        - name: limine
          luksGeneration: luks2
  profile/airootfs/etc/calamares/modules/luksbootkeyfile.conf:
    create: |
      ---
      luks2Hash: argon2id
      efiBootLoaderVar: "packagechooser_bootloader_choice"
  profile/airootfs/etc/calamares/settings.conf:
    move_exec_item:
      shellprocess@crypt:
        from_after: packages
        to_before: luksbootkeyfile
notes:
  - "GRUB keeps LUKS1 until a patched GRUB is shipped; LUKS2/argon2id is for systemd-boot and Limine."
  - "The CLI still hard-codes luks1 at sunshine-install:179; change it only after the Calamares path passes rank 07."
evidence:
  - "profile/airootfs/etc/calamares/modules/partition.conf:11,15"
  - "profile/airootfs/etc/calamares/settings.conf:47,60"
  - "profile/airootfs/usr/local/bin/sunshine-install:178-182,232-237,316-320"
  - "/home/tak/sunshineos-build/research/calamares/src/modules/luksbootkeyfile/luksbootkeyfile.conf:7-14"
  - "/home/tak/sunshineos-build/research/cachyos-calamares/src/modules/partition/partition.conf:30-34,64-83"
  - "/home/tak/sunshineos-build/research/g-pkgbuilds/calamares-garuda/garuda-specific-patches.patch:519-546,589-594,636-646"
offline: "yes"
risk: "high"
```

#### 10-offline-skipped-apps.sh

```bash
#!/usr/bin/env bash
# Rank 10 - write a visible report of apps that cannot be delivered offline.
# Wire as shellprocess@skipped_apps after packages.
# Limitation: this reads default-selected entries, not the live checkbox state.
# Evidence: profile/airootfs/etc/calamares/modules/packages.conf:3-5;
# profile/airootfs/etc/calamares/modules/netinstall.conf:2-8;
# profile/airootfs/usr/share/sunshine/netinstall.yaml:14-18,71-75.
set -uo pipefail

ROOT=${1:-}
NET=${2:-/usr/share/sunshine/netinstall.yaml}
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
  echo "usage: $0 <target-root> [netinstall.yaml]" >&2
  exit 2
fi

OUT="$ROOT/var/log/sunshine-skipped-apps.txt"
mkdir -p "${OUT%/*}"

{
  echo "Sunshine OS offline app install report"
  if command -v ip >/dev/null 2>&1 && ip route get 1.1.1.1 >/dev/null 2>&1; then
    echo "network during install: available"
  else
    echo "network during install: unavailable"
  fi
  echo
  echo "Default-selected entries in $NET (not the live checkbox state):"
  if [ -r "$NET" ]; then
    grep -n 'selected: true' "$NET" || echo "  none"
  else
    echo "  catalogue not found"
  fi
  echo
  echo "After first online boot: sunshine-apps install ID, or the Sunshine store."
} > "$OUT"

cat "$OUT"
exit 0
```

#### 11-live-leftovers.sh

```bash
#!/usr/bin/env bash
# Rank 11 - late target cleanup after users, plus the install log.
# Wire as shellprocess@live_leftovers after users and before umount.
# Evidence: /home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/scripts/chrooted_cleaner_script.sh:249-252;
# /home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/modules/shellprocess_copyfiles.conf:13-15;
# /home/tak/sunshineos-build/research/cachyos-calamares/src/modules/shellprocess/shellprocess.conf:95-106;
# profile/airootfs/usr/local/bin/sunshine-install:239-257.
set -uo pipefail

ROOT=${1:-}
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ] || [ "$ROOT" = / ]; then
  echo "usage: $0 <target-root> (refuses /)" >&2
  exit 2
fi

rm -rf "$ROOT/etc/calamares" \
       "$ROOT/opt/extra-drivers" \
       "$ROOT/home/liveuser" \
       "$ROOT/home/sunshine" \
       "$ROOT/var/lib/NetworkManager/NetworkManager.state"

find "$ROOT/etc" -type f -name '*.pacnew' -delete 2>/dev/null || true

install -d "$ROOT/var/log/sunshine"
if [ -r /var/log/sunshine-install.log ]; then
  install -m 0600 /var/log/sunshine-install.log "$ROOT/var/log/sunshine/sunshine-install.log"
elif [ -r /var/log/calamares.log ]; then
  install -m 0600 /var/log/calamares.log "$ROOT/var/log/sunshine/calamares.log"
fi

exit 0
```

#### 12-kernel-choice.conf

```yaml
# Rank 12 - kernel choice instead of a fixed /vmlinuz-linux path.
# Change bundle; exact keys/files below. Depends on ranks 03 and 07.
rank: 12
files:
  profile/airootfs/etc/calamares/settings.conf:
    add_instance:
      - id: kernel_choice
        module: packagechooser
        config: packagechooser_kernel.conf
    show_insert_after: keyboard
    show_insert:
      - packagechooser@kernel_choice
  profile/airootfs/etc/calamares/modules/packagechooser_kernel.conf:
    create: |
      ---
      mode: required
      method: packages
      labels:
        step: "Kernel"
      default: linux
      items:
        - id: linux
          name: "linux (default)"
          packages: [ linux, linux-firmware ]
        - id: linux-lts
          name: "linux-lts"
          packages: [ linux-lts ]
        - id: linux-zen
          name: "linux-zen"
          packages: [ linux-zen ]
  profile/airootfs/etc/calamares/modules/bootloader.conf:
    replace_text: |
      kernel: "/vmlinuz-linux"
      img: "/initramfs-linux.img"
      fallback: ""
    with_text: |
      kernelSearchPath: "/usr/lib/modules"
      kernelPattern: "^vmlinuz.*"
      refindKernelList: [ "linux", "linux-lts", "linux-zen" ]
notes:
  - "initcpio.conf:2 already uses kernel: all, so all installed kernels get images."
  - "linux-lts and linux-zen need packages on the ISO or network; keep default linux for offline ISOs."
evidence:
  - "profile/airootfs/etc/calamares/modules/initcpio.conf:2"
  - "profile/airootfs/etc/calamares/modules/bootloader.conf:3-5"
  - "profile/airootfs/etc/calamares/modules/grubcfg.conf:12"
  - "/home/tak/sunshineos-build/research/calamares/src/modules/bootloader/bootloader.conf:21-36"
  - "/home/tak/sunshineos-build/research/calamares/src/modules/packagechooser/packagechooser.conf:30-34"
  - "/home/tak/sunshineos-build/research/cachyos-calamares/src/modules/bootloader/bootloader.conf:21-36"
  - "/home/tak/sunshineos-build/research/eos-iso/root/etc/calamares/modules/bootloader.conf:24-25"
offline: "partial"
risk: "medium"
```

---

## 6. Validation performed

Run from the worktree root:

- `bash -n docs/team/reports/installer-proposals/*.sh` — no output, exit 0.
- `export PATH=/home/tak/.local/bin:$PATH; shellcheck -S warning docs/team/reports/installer-proposals/*.sh` — no output, exit 0.
- `python3 -c 'import glob,yaml; ... yaml.safe_load(open(f)) ...'` over `docs/team/reports/installer-proposals/*.conf` — all 7 `.conf` files loaded successfully.

No snippet was applied to the installer tree; validation here is syntax/schema-level only.

---

## 7. Senior-developer decisions recorded in this research

1. **Garuda sequence disclosure:** use the Garuda NixOS `settings.conf` for the Garuda row because it is the only complete Garuda-branded sequence in the research tree; never present it as Arch Garuda.
2. **Proposal file format:** `.conf` files are valid YAML change bundles or drop-in configs; they are not claimed to be ready-to-copy Arch ISO files. Every `.conf` is `yaml.safe_load`-clean.
3. **Safe default preserved:** GRUB and LUKS1 remain the safe default in proposals 03/09 until bootloader choice and verification (03, 07) are tested; LUKS2/argon2id is paired with systemd-boot/Limine overrides.
4. **Upstream mechanisms over invented ones:** desktop conditional logic uses upstream `contextualprocess` and documented `packagechooser_<id>` global storage keys; no unobserved shellprocess condition syntax is assumed.
5. **Offline-first ranking:** one-line safety fixes and offline-only changes rank above network-dependent choices; optional rEFInd/Limine/lts/zen choices are marked `partial`, never silently assumed available.
6. **GUI and CLI are separate:** proposals target the Calamares GUI unless a note explicitly says the CLI still has the old behavior (swap, encryption, kernel); a follow-up patch must update `sunshine-install` separately.
7. **Docs only:** no existing source file was modified; all changes are proposals under `docs/team/reports/installer-proposals/` plus this research report.
