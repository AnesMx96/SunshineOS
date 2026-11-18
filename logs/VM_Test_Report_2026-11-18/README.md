# SuOS / Sunshine OS VM test report — 2026-11-18

## Scope and environment

- VM: `SuOS` (UUID `a99ed23f-36a7-4a41-9eba-b77648858987`), VirtualBox 7.1.18, BIOS boot, 4 vCPU, 5.3 GiB RAM, 8 GiB test disk.
- ISO: `/home/niktro2/Downloads/SunshineOS/SunshineOS_13.4.7.1.4_Release_2026-11-17.iso` (live Arch-based session, kernel `7.3.4-arch1-2`, Plasma 6.8.3/Wayland).
- Source tree: `/home/niktro2/SunshineOS`, branch `main`, HEAD at test start `dc5cdd3`/`ad8e8d0` (the latter is a local screenshot commit).
- Guest access: `VBoxManage guestcontrol` with user/password `sunshine`; root password `sunshine` (`sudo -n` works). SSH was not usable (`sshpass` absent on host, port 2222 dead,guest `10.0.2.15:22` unreachable).
- This was a **live ISO session**, not an installed system: root is an `airootfs` overlay with 256 MiB cowspace; `/dev/sr0` is mounted at `/run/archiso/bootmnt`.

Evidence is in this directory:

- `commands-and-outputs.log` — commands run in the VM and their captured output (ANSI stripped).
- `raw/` — individual captured test logs.
- `system-logs/` — Calamares session, journal excerpt, installer log, VirtualBox host log.
- `screenshots/` — the six pre-flagged screenshots plus new VM captures; `screenshots/ocr.txt` contains OCR text.
- `fixes/` — patched files prepared for the remediation pass.

---

## Findings

| ID | Severity | Problem | Evidence |
|---|---|---|---|
| F1 | Critical | `pacman-init.service` is `bad-setting`/inactive. The base unit is `Type=oneshot` with two `ExecStart=` lines, but the shipped drop-in sets `Type=simple`, `RemainAfterExit=no`. Result: `pacman -Sy`/`paru -Syyu` fail with unknown key `8253720323C575207CC781B5DB345EF676CCD13D` and `keyring is not writable`. | `systemctl status pacman-init.service`; `raw/SuOS-test-raw.log`; screenshot `Screenshot_20261118_183701.png`; source `profile/airootfs/etc/systemd/system/pacman-init.service.d/async.conf:3`. |
| F2 | Critical | GUI install (Calamares) fails: **“Installation Failed — Could not run command … The commands use variables that are not defined. Missing variables are: p,p.”** Calamares interprets the inline shell variable `$p` in `shellprocess-ownbase.conf` as its own placeholder. | `system-logs/calamares-session.log:575,647-649`; screenshot `Screenshot_20261118_184313.png`; source `profile/airootfs/etc/calamares/modules/shellprocess-ownbase.conf:10`. |
| F3 | High | `sunshine-welcome` and `sunshine-toolbox` crash at startup with `NameError: name 'sys' is not defined` because `sys.path.insert(...)` runs on line 2, before `import sys`. Their `.desktop` launchers therefore lead to nothing. | `raw/SuOS-tools-test.log`; source `profile/airootfs/usr/local/bin/sunshine-welcome:2`, `sunshine-toolbox:2`. |
| F4 | High | `sunshine-doctor --fix` gives wrong diagnostics. `ui.sh` defines a translation helper named `tr()`, which shadows `/usr/bin/tr` after the script sources it. The doctor then prints `failed services: \n` and `root disk -dc 0-9% used` instead of real values. It also hides repair output: `--fix` silently created a **0-byte `/boot/initramfs-linux.img`** with a failing `mkinitcpio`, then the next check reported “initramfs present”. | `raw/SuOS-repair-test.log`; guest `ls -l /boot`; source `profile/airootfs/usr/local/lib/sunshine/ui.sh:18`, `profile/airootfs/usr/local/bin/sunshine-doctor:78,80,58`. |
| F5 | Medium | CLI installer (`sunshine-install`) fails at the copy step with `rsync: [sender] write error: Broken pipe (32)`, `received SIGUSR1`, `ERROR: rsync failed`; exit 1. Direct `rsync` with the same options on a small tree works. Later investigation showed the 8 GiB target filled up while copying the ~8.5 GiB uncompressed system, so the real blocker is **undersized disk**, with rsync reporting a broken pipe when the receiver died. The installer still gives a confusing error instead of a clear “no space” message. | `raw/SuOS-cli-install-foreground.log` (17 MB, not committed), `raw/SuOS-rsync-test.log`, `system-logs/sunshine-install.log`, `remediation.log` step 3. |
| F6 | Medium | Visual theme is inconsistent: Qt uses `SunshineDark`/Kvantum widget style, but GTK2/GTK3 report `Breeze-Dark`/`Breeze`. `sunshine-restore-visuals --offline` reports “visuals restored” but leaves `gtk-theme-name=Breeze` in GTK3/GTK4 and creates no `~/.config/Kvantum` config. | `raw/SuOS-theme-test2.log`; `fastfetch --format json`; screenshot `Screenshot_20261118_183519.png` (fastfetch theme line). |
| F7 | Medium | Live overlay (256 MiB) fills during a full update; `pacman -Syu` aborts with many `Write failed` errors and `no packages were upgraded`. Retry with `--cachedir /tmp/pacman-cache` fixed the mirror byte-range/download errors but still hit the overlay limit. Remounting cowspace to 1 GiB is possible and was used in remediation. | `raw/SuOS-update-test.log`, `raw/SuOS-update-test2.log`; `remediation.log`. |
| F8 | Medium | `sunshine-fix-pacman` prints `rm: cannot remove '/etc/pacman.d/gnupg': Device or resource busy` but still reports `✔ keyring recreated and populated` and exit 0. The keyring did work afterwards, but the tool hides a real failure. | `raw/SuOS-tools-test.log:124-157`. |
| F9 | Low | Calamares warnings: missing `chcon` (repeated), `os-prober cannot start`, invalid `xkbmap selection changed to: "custom"`, `GeoIP style *none*` not recognized, deprecated `restartNowEnabled`, unknown branding style. The keymap error also appears in the journal as `systemd-localed: Cannot compile XKB keymap ... layout='custom'`. | `system-logs/calamares-session.log`; `system-logs/journal-excerpts.log`. |
| F10 | Low | Host-side VirtualBox log shows `VERR_HGCM_SERVICE_NOT_FOUND`, `BIOS: Boot from Floppy 0 failed`, and several guestcontrol `VERR_INTERRUPTED`/`VERR_TOO_MUCH_DATA` errors. The latter explain a failed long theme-test command: it exceeded the 1024-byte guestcontrol command limit. These are environment/harness issues, not necessarily OS bugs. | `system-logs/vbox-host-errors.log`. |
| F11 | Low / environment | Repeated `VBoxService pam_loginuid ... Operation not permitted`, `gkr-pam: couldn't unlock the login keyring`, `librepods: BLE scan error ... InputOutputError`, `vmwgfx: Cursor dimensions (64, 64) exceed device max 0`, `virt/tdx: TDX not supported`. | `system-logs/journal-excerpts.log`. |
| F12 | Info | `sunshine-store` opens (with a real display) and shows the catalogue UI with “Preparing the app catalog…”; `--help` is not implemented and the headless invocation dumps core. `uni detect` works. | `screenshots/suos-store.png`, `screenshots/suos-store-loaded.png`; `raw/SuOS-tools-test.log:200-209`. |
| F13 | High (introduced by the update test) | The aborted full upgrade left the package database inconsistent: `pacman -Dk` reports `missing 'pipewire-audio=1:1.6.11-1' dependency for 'pipewire-alsa'` and `missing 'pipewire=1:1.6.11-1' dependency for 'pipewire-alsa'`. Caused by the transaction that hit the 256 MiB overlay limit; to be repaired with a complete update now that cowspace is 1 GiB. | `remediation.log` doctor verification after applying patches. |
| F14 | High (configuration/test setup) | The VM's 8 GiB disk cannot hold the uncompressed live system (`du -xhd1 /` reported ~8.5 GiB under `/usr`). The installer fills `/mnt/sunshine-target` to 100% and rsync dies with a broken pipe. The test VM needs a larger virtual disk; real hardware should also be checked against the uncompressed size, not the ISO size. | `remediation.log` step 3, `df -h /mnt/sunshine-target`. |
| F15 | Medium | Live-session changes do not survive a reboot: the `persistent_` cowspace appears fresh after `VBoxManage` poweroff/start, so `pacman-init`, patched tools and `/tmp/sunshine-fixes` all reverted. Any remediation applied in the live ISO must be reapplied after every boot, or baked into the ISO/target system. This is expected for a live ISO but important for test reproducibility. | `remediation.log` step 5 showed `pacman-init=inactive` and the original `--info=progress2` line after reboot. |
| F16 | Medium | After failed install attempts, stale btrfs filesystem registrations kept `/dev/sda2` busy (`btrfs filesystem show` still listed old UUIDs, `mkfs.btrfs -f` → `Device or resource busy`). `btrfs device scan --forget` alone did not release it; a kernel device delete/rescan was needed, after which the disk reappeared as `/dev/sdb`. The installer has no handling for this state. | `remediation.log` steps 9-10. |
| F17 | Medium | The installed user only gets Qt theming via `/etc/skel/.config/autostart/sunshine-plasma-setup.desktop`; `/etc/skel` contains **no GTK settings** and the live GTK CSS under `/home/sunshine/.config/gtk-*` is deleted by the installer (`rm -rf home/sunshine`). Unless fixed post-install, the installed system inherits F6 with no recovery path in the offline restore tool. | Guest `find /etc/skel`, `cat /etc/skel/.config/gtk-3.0/settings.ini` (NONE); installer line 218; `remediation.log` step 11. |
| F18 | High | The successful install skipped **all 114 optional Hyprland packages**. `/usr/local/bin/sunshine-hyprland-install` was called before the target's Sunshine repo key was trusted, so attempts 1-3 failed with `sunshine: key 8253720323C575... is unknown`; later attempts failed with `config file /tmp/pm-hypr.conf could not be read`. The log ends with a 114-package `failed packages:` list and `Hyprland could not be fully installed`, yet the installer continues (`|| true`) and prints `SUNSHINE_INSTALL_OK`. | `remediation.log` install tail; installer line 239; `sunshine-hyprland-install` package loop. |
| F19 | Low (after install) | `systemd-networkd-wait-online.service` stays in `activating (start)` in the NAT VM, so `systemctl is-system-running` never leaves `starting` even though there are zero failed units and `pacman -Sy` works. Should be masked or made non-blocking for virtual machines. | `remediation.log` step 15/16, `systemctl list-units --state=activating`. |

Working parts confirmed: `systemctl is-system-running` = `running` with no failed units at first boot; `sunshine-identity check` = `Identity OK: Sunshine OS`; `sunshine-snapshot status/backend` work; `sunshine-diagnose --print` runs but repeats the F1 package-key error; `uni detect` reports the correct OS and package sources.

---

## Poor or questionable decisions observed

These are design/implementation choices that made the system harder to debug or directly broke it:

1. **Shipping a `Type=simple` drop-in for a two-`ExecStart` oneshot unit** (F1). A one-line change disables the pacman keyring at every live boot.
2. **Putting shell variables in Calamares YAML commands** (F2). Calamares performs its own `${...}`/`$var` substitution; `$p` must live in a script file or be removed.
3. **Naming an i18n helper `tr` in a shared shell library** (`ui.sh`). It shadows the coreutils `tr` for every script that sources the library and uses it for text processing (F4).
4. **Doctor hides repair command output and declares success**. `--fix` redirected `mkinitcpio` to `/dev/null`, created an empty initramfs, and the subsequent existence check called that “present” (F4).
5. **Doctor treats live-ISO conditions as installed-system failures**: missing `/boot/vmlinuz-linux`, missing GRUB menu, no Timeshift/snapper on an overlay root, and missing `hyprland` on the Plasma edition. This generates false “problem(s) found” and can trigger pointless repairs.
6. **Offline “restore visuals” claims success without local assets**. The external assets repo is only used when online; with `--offline` the GTK and Kvantum settings are left at Breeze while Qt gets the Sunshine theme (F6).
7. **Repair tool prints success after a failed step** (`Device or resource busy` from `rm -rf /etc/pacman.d/gnupg`) instead of stopping or reporting partial failure (F8).
8. **Scripted installer uses `--info=progress2`** and no broken-pipe handling, which is fragile under terminals/pipes/guestcontrol (F5).
9. **Launchers point to broken GUI scripts** (`sunshine-welcome.desktop` → `/usr/local/bin/sunshine-welcome`) even though the scripts crash on line 2 (F3).
10. **Live ISO has only 256 MiB of cowspace** while the update tool offers a full 28-package upgrade with a 115 MiB download and ~423 MiB installed size; there is no guard or suggestion to use a larger overlay or an installed system (F7).
11. **Two copies of several tools exist** (`profile/airootfs/usr/local/bin` and `overlay/system/usr/local/bin`), e.g. `sunshine-fix-pacman`; drift between them is easy and both need the same fixes.
12. **Starship warns about a scan timeout**, and Calamares config includes `GeoIP style none`, deprecated keys, and missing optional helpers (`chcon`, `os-prober`, `ckbcomp`). These are small but avoidable polish issues (F9).
13. **The optional Hyprland layer is installed before the repo key is trusted and its failure is swallowed** (`|| true`). A user can get `SUNSHINE_INSTALL_OK` with 114 silently missing packages (F18).
14. **The installer unconditionally removes `vboxservice.service` from `multi-user.target.wants`**, disabling VirtualBox guest integration on the installed system purely because the live ISO did not need it.

---

## Reproduction summary

```bash
# F1
systemctl status pacman-init.service
sudo pacman-key --list-keys
sudo pacman -Sy

# F2 (in the live GUI)
# Open Sunshine OS Installer -> choose disk -> Install
grep -n 'Missing variables' ~/.cache/calamares/session.log

# F3
/usr/local/bin/sunshine-welcome
/usr/local/bin/sunshine-toolbox

# F4
sudo /usr/local/bin/sunshine-doctor --fix
ls -l /boot/initramfs-linux.img

# F5
sudo env SUNSHINE_AUTO=1 SUNSHINE_DISK=/dev/sda SUNSHINE_USER=tester \
  SUNSHINE_PASS=testpass123 SUNSHINE_FS=btrfs /usr/local/bin/sunshine-install

# F6
fastfetch --format json | grep theme2
cat ~/.config/gtk-3.0/settings.ini

# F7
sudo pacman -Syu --noconfirm --cachedir /tmp/pacman-cache
```

---

## Design dissection — theme, icons and visual style

### What the design is trying to be

Sunshine OS has a clear, likeable identity: **warm sunlight on dark graphite**. The accent palette is amber/yellow/orange, the backgrounds are near-black/dark charcoal, and the motif is a sun/flower (braille sun animation, flower bloom wallpaper, orange Fluent-derived icon set). The “cozy” copy (`☕`, tea wording, “Have a warm cup of tea…”) gives the tools a friendly, non-corporate voice. That is a distinctive and coherent idea, and most of the first-party Plasma surface follows it.

### Qt / Plasma layer — strongest part

- `SunshineDark` color scheme and `Sunshine` desktop theme are applied by `sunshine-plasma-setup` and `sunshine-restore-visuals`.
- Window decoration uses Aurorae `Sunshine` with buttons on the **right** (`ButtonsOnRight IAX`), a deliberate Windows-like spatial language rather than stock Plasma.
- Widget style is Kvantum, with a Sunshine Kvantum theme shipped at `/usr/share/Kvantum/Sunshine`.
- Icons are `Sunshine-orange-dark` (orange Fluent variant) for Qt and GTK in the stock config; the custom sun/menu icon is used in the panel.
- The panel is a deliberate Windows 11-style 48 px full-width bar: centered start/apps icons between spacers, tray/clock on the right. Custom plasmoids add the active-window title and live network/disk/CPU/GPU graphs.

Visually this is the most complete part of the distro: wallpaper, colors, icons, decorations and panel all agree with each other.

### GTK layer — the visible break

GTK2 reported `Breeze-Dark`, GTK3 reported `Breeze` in the flagged fastfetch screenshot, while Qt reported `SunshineDark`. There is **no Sunshine GTK theme installed** in `/usr/share/themes` (only `Breeze`, `Breeze-Dark`, `Default`, `Emacs`). `sunshine-restore-visuals --offline` writes custom CSS into `~/.config/gtk-{3,4}.0` but leaves `gtk-theme-name=Breeze` and creates no Kvantum user config. In practice GTK apps inherit dark-ish custom colors but not the Sunshine widget language, and third-party dialogs (Calamares, Firefox, store internals) look like stock desktop GTK. This is the single largest visual inconsistency.

### Installer / dialogs

Calamares branding exists (`/etc/calamares/branding/sunshine`) and the installer dialogs are meant to be dark/yellow. The session log complains about a missing translations file, an unknown branding style `SidebarTextSelect`, and the sidebar being interpreted as a `"widget" left` setting. The failure dialog itself is a bright/default-looking Qt error box (“Installation Failed / Could not run command”), which clashes with the dark branding. Repeated `chcon` warnings and `os-prober cannot start` make the install flow feel unfinished even before the fatal `$p` error.

### Icons and typography

- The orange icon theme is a good differentiator and is applied consistently to Qt and GTK when the config is correct.
- Noto Sans 10 pt is used in GTK and terminal; the terminal prompt uses fish + starship. Starship emitted `Scanning current directory timed out`, so the prompt can stall in large directories.
- The doctor warns if `ttf-material-symbols-variable` is replaced, because Hyprland icons then “show as odd letters”. This shows the theme depends on an exact font version rather than a robust fallback.
- Cursor theme remains `breeze_cursors`; the Sunshine identity stops at the mouse pointer.

### Welcome / Toolbox / Store

- Welcome and Toolbox are intended as friendly first-run hubs with the same warm styling. Both are completely unusable because of the `NameError: sys` bug, so the designed entry points are dead.
- The Store has a polished dark catalogue shell with a left category rail (Installed, Windows, Web apps, Flatpak/AppImage/Snap/Wine) and a “Preparing the app catalog…” first-run state. It is a good concept, but first load has no progress detail and `--help` opens the GUI/dumps core in headless environments.
- `sunshine-identity`, `sunshine-info`, `sunshine-diagnose` and `sunshine-snapshot` continue the friendly CLI style and mostly work, but the doctor’s false positives undermine trust.

### Poor or questionable design decisions (visual/UX)

1. **Two theming systems, one set of assets.** Sunshine themes Qt/KDE thoroughly but ships no GTK theme; offline “restore” therefore cannot deliver a coherent desktop.
2. **Visual restoration depends on an external git repository** (`sunshineos-assets`) only when online, yet reports success offline without local GTK/Kvantum assets.
3. **Bright, unthemed error dialogs** for critical installer failures break the dark visual language exactly when users are stressed. The installed user also relies on an autostart hook for the Qt theme while GTK defaults are left to Breeze and the live CSS is thrown away (F17).
4. **Panel layout lives in one long inline QML `evaluateScript` string.** It is hard to review, version, diff or debug; it is also fragile across Plasma releases.
5. **Windows 11-style taskbar copied wholesale** (centred icons, right tray, 48 px height) without a documented fallback for Plasma/VM variations; cursor warnings appear under VirtualBox.
6. **Exact-version icon-font dependency** enforced by a doctor warning instead of a bundled font or fallback glyph mapping.
7. **Cozy copy paired with hidden failures** (“visuals restored”, “keyring recreated”) is tone-deaf when the underlying step actually failed.
8. **Branding config contains dead keys** (`SidebarTextSelect`, `GeoIP style none`, deprecated `restartNowEnabled`) instead of being cleaned up.
9. **Cursor theme not branded**, leaving a stock element in an otherwise custom visual stack.
10. **Flagged “To_Fix” screenshots committed at the repo root** rather than triaged into the report folder; evidence and product assets are mixed.

Net assessment: the artistic direction is strong and mostly coherent on the Plasma/Qt side. The weak points are not the taste of the design but the **delivery**: missing GTK assets, offline restore overpromising, unthemed error paths, and fragile inline configuration.

---

## Remediation status

In progress. The following has been done and is recorded in `remediation.log`:

1. Live cowspace enlarged from 256 MiB to 1 GiB with `sudo mount -o remount,size=1G /run/archiso/cowspace` (no data loss).
2. Patched replacement files prepared in `fixes/` and copied into the guest at `/tmp/sunshine-fixes/`:
   - `pacman-init.async.conf` — correct `Type=oneshot`, `RemainAfterExit=yes`.
   - `sunshine-welcome`, `sunshine-toolbox` — `import sys` before first use.
   - `sunshine-doctor` — explicit `/usr/bin/tr` for the two coreutils calls.
   - `shellprocess-ownbase.conf` + `sunshine-register-base` — move the `$p` loop out of Calamares YAML.
   - `sunshine-install` — remove `--info=progress2`.
   - `gtk-settings.ini`, `kvantum.kvconfig` — dark GTK theme and Sunshine Kvantum config.

3. Applied all prepared patches in the live system (originals backed up under `/root/suos-test-backup/`). Verified:
   - `pacman-init.service` is now `active (exited)` instead of `bad-setting`.
   - `sunshine-welcome` and `sunshine-toolbox` parse cleanly (no `NameError`).
   - Doctor no longer prints `-dc 0-9`; remaining reports are live-ISO false positives plus F13.
   - GTK3/GTK4 now request `Breeze-Dark`, Kvantum user config selects `Sunshine`, and the same settings were copied into `/etc/skel`.

4. Repaired the package database (F13) with a successful `pacman -Syu --noconfirm --cachedir /tmp/pacman-cache`: 20 packages upgraded, `PACMAN_SYU_RC=0`, `pacman -Dk` reports `No database errors have been found!`, overlay usage 359M/1.0G.

5. First install attempt to `/dev/sda` still failed at rsync. Manual copy confirmed the target reached 100% (8 GiB disk vs ~8.5 GiB uncompressed system), so the virtual disk must be enlarged before retrying (F14).

6. Enlarged the VirtualBox disk from 8192 MB to 20480 MB with `VBoxManage modifymedium disk ... --resize 20480`, powered the VM back on, and re-extended cowspace to 1 GiB. The old 8 GiB partition table remained, as expected; the installer will recreate it using the full 20 GiB.

7. Reapplied all patches after the reboot, reinitialized the keyring and synced package databases. The reinstall reached formatting but failed with `ERROR: unable to open /dev/sda2: Device or resource busy` / `mkfs.btrfs failed`.
8. Retry with no visible holders failed the same way. Manual reproduction showed stale btrfs superblocks registered in the kernel (`btrfs filesystem show` listed two old filesystems); `btrfs device scan --forget` and `wipefs` could not clear `/dev/sda2`.
9. Removed the disk from the kernel with `echo 1 > /sys/block/sda/device/delete` and rescanned SCSI hosts. The disk reappeared as `/dev/sdb`; after wiping old superblocks, `mkfs.btrfs -f -L sunshine /dev/sdb2` succeeded (F16).
10. Started the installer against `/dev/sdb` with all live patches reapplied and the keyring working.
11. Discovered that `sunshine-install` copies from `SRC=/run/archiso/airootfs` (the squashfs), so none of the overlay fixes are included in the installed system. Prepared `fixes/inject-into-target.sh` (copied to the guest at `/tmp/sunshine-fixes/`) to mount the installed `@`/`@home` subvolumes and apply the patched tools, Calamares config, GTK/Kvantum settings and skel defaults before the first boot.
12. The install on the 20 GiB disk completed: `grub-install` (i386-pc on `/dev/sdb`), `grub.cfg` with Sunshine theme, initramfs generated, and `SUNSHINE_INSTALL_OK`. All 114 Hyprland packages were skipped (F18) but the Plasma desktop remains the default session.
13. Injected the fixes into the mounted target (`@`/`@home`): patched tools, Calamares config, GTK/Kvantum settings for both skel and the created user, the working pacman keyring (including the Sunshine key), and re-enabled `vboxservice`/`sshd` so the VM stays controllable after reboot. Verification: `INJECT_OK`, target filesystem 9.0G/20G used.
14. Booted the installed system from the 20 GiB disk with the ISO detached: hostname `sunshine-os`, `Sunshine OS`, root `/dev/sda2` (9.0G/20G), `vboxservice`, `sshd`, `sddm` and `NetworkManager` active, zero failed units.
15. Enabled SDDM autologin for `sunshine`/`plasma` and restarted SDDM. A real user session started on `seat0`; the Sunshine Welcome app opened on the desktop (screenshot `suos-installed-logged-in.png`).
16. Verified in the installed system: `pacman -Sy` succeeds, `pacman -Dk` reports no database errors, `sunshine-identity check` = `Identity OK`, both patched Python GUI tools parse, `sunshine-doctor --quiet` = `All good (1 note(s))` (only the missing optional Hyprland package), and fastfetch reports `Sunshine (Dark) [Qt]`, `Sunshine-orange-dark [Qt]`, `Breeze-Dark [GTK2/3/4]`.
