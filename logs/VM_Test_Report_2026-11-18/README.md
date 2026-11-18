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
| F5 | Medium | CLI installer (`sunshine-install`) fails at the copy step with `rsync: [sender] write error: Broken pipe (32)`, `received SIGUSR1`, `ERROR: rsync failed`; exit 1. Direct `rsync` with the same options on a small tree works, so the failure is likely an interaction between `--info=progress2` and the guestcontrol/tee pipe, but the installer has no `EPIPE`/progress fallback. | `raw/SuOS-cli-install-foreground.log` (17 MB, not committed), `raw/SuOS-rsync-test.log`, `system-logs/sunshine-install.log`. |
| F6 | Medium | Visual theme is inconsistent: Qt uses `SunshineDark`/Kvantum widget style, but GTK2/GTK3 report `Breeze-Dark`/`Breeze`. `sunshine-restore-visuals --offline` reports “visuals restored” but leaves `gtk-theme-name=Breeze` in GTK3/GTK4 and creates no `~/.config/Kvantum` config. | `raw/SuOS-theme-test2.log`; `fastfetch --format json`; screenshot `Screenshot_20261118_183519.png` (fastfetch theme line). |
| F7 | Medium | Live overlay (256 MiB) fills during a full update; `pacman -Syu` aborts with many `Write failed` errors and `no packages were upgraded`. Retry with `--cachedir /tmp/pacman-cache` fixed the mirror byte-range/download errors but still hit the overlay limit. Remounting cowspace to 1 GiB is possible and was used in remediation. | `raw/SuOS-update-test.log`, `raw/SuOS-update-test2.log`; `remediation.log`. |
| F8 | Medium | `sunshine-fix-pacman` prints `rm: cannot remove '/etc/pacman.d/gnupg': Device or resource busy` but still reports `✔ keyring recreated and populated` and exit 0. The keyring did work afterwards, but the tool hides a real failure. | `raw/SuOS-tools-test.log:124-157`. |
| F9 | Low | Calamares warnings: missing `chcon` (repeated), `os-prober cannot start`, invalid `xkbmap selection changed to: "custom"`, `GeoIP style *none*` not recognized, deprecated `restartNowEnabled`, unknown branding style. The keymap error also appears in the journal as `systemd-localed: Cannot compile XKB keymap ... layout='custom'`. | `system-logs/calamares-session.log`; `system-logs/journal-excerpts.log`. |
| F10 | Low | Host-side VirtualBox log shows `VERR_HGCM_SERVICE_NOT_FOUND`, `BIOS: Boot from Floppy 0 failed`, and several guestcontrol `VERR_INTERRUPTED`/`VERR_TOO_MUCH_DATA` errors. The latter explain a failed long theme-test command: it exceeded the 1024-byte guestcontrol command limit. These are environment/harness issues, not necessarily OS bugs. | `system-logs/vbox-host-errors.log`. |
| F11 | Low / environment | Repeated `VBoxService pam_loginuid ... Operation not permitted`, `gkr-pam: couldn't unlock the login keyring`, `librepods: BLE scan error ... InputOutputError`, `vmwgfx: Cursor dimensions (64, 64) exceed device max 0`, `virt/tdx: TDX not supported`. | `system-logs/journal-excerpts.log`. |
| F12 | Info | `sunshine-store` opens (with a real display) and shows the catalogue UI with “Preparing the app catalog…”; `--help` is not implemented and the headless invocation dumps core. `uni detect` works. | `screenshots/suos-store.png`, `screenshots/suos-store-loaded.png`; `raw/SuOS-tools-test.log:200-209`. |

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

Next steps: apply the patches, run a full update, install to `/dev/sda`, reboot from disk, verify tools/theme, and commit each step.
