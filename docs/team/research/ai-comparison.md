# ChatGPT vs Grok on the Sunshine OS design prompt

Inputs (read-only): `ai-answers/PROMPT.md`, `ai-answers/chatgpt-raw.txt` (89 KB, PARTs 1-5),
`ai-answers/grok-raw.txt` (19 KB). Tools checked before claiming anything is handled:
`overlay/system/usr/local/bin/sunshine-*`, `profile/airootfs/usr/local/bin/sunshine-*`,
`profile/airootfs/usr/share/libalpm/hooks/*.hook`.

Status vocabulary in the table:

- **HANDLED** — an automatic repair path exists today.
- **PARTIAL** — Sunshine detects or installs something, but there is no automatic repair of this exact failure.
- **NOT HANDLED** — nothing in the tree addresses it.

---

## 1. Which AI was better per part

**PART 1 — ChatGPT.** It numbers all 40 failures, gives each one Detect / Repair / Risk / Never and labels the
environment (RUNNING, LIVE, CHROOT) before every command block (e.g. C1 `grub-script-check`, C7 root UUID,
C17 stale lock). Grok also has 40 items and is denser, but several "repairs" are destructive one-liners
(`pacman -Syu --overwrite '*'`, `genfstab -U / > /etc/fstab`, `btrfs check --repair`) and it omits the
"never do this automatically" discipline for roughly a third of its items, which matters more than brevity.

**PART 2 — ChatGPT.** Its 15-phase live order and 17-step doctor order each carry a reason and a hard-stop
table (SMART failure, ambiguous ESP/root/subvolume, LUKS, `.pacnew` conflicts, NVIDIA branch). Grok's live
recipe is shorter but orders badly: it creates the safety snapshot *after* fsck and bootloader repair
("Create a new snapper/Timeshift snapshot before any further changes"), and its doctor does a full
`pacman -Syu` before checking disk space or active transactions.

**PART 3 — ChatGPT.** Both name plausible upstreams, but ChatGPT is more accurate and ranks twice: per
category and in a final table (Garuda update/health, CachyOS kernel/performance, Manjaro mhwd, openSUSE
snapper, pacdiff, sbctl, Garuda diagnostics). Grok's "Fedora system-check", "EndeavourOS doctor-like
scripts" and "Proton-GE helpers from GloriousEggroll" are vague or not distribution tools, and its
"EndeavourOS eos-update is ranked highest, Garuda's update is more aggressive (avoid)" contradicts what
Garuda's script actually does (pre-update health check, keyring, conflict handling).

**PART 4 — ChatGPT.** It gives 15 features for each of the three audiences (45 total), ordered, each mapped
to a named testable tool (`sunshine-storage`, `sunshine-vulkan`, `sunshine-config`). Grok gives only 5 per
audience and its feature list is a wish list without priority numbers inside each group or a test surface.
ChatGPT's weakness is that it invents many new tools instead of extending existing ones; Grok stays closer
to the current toolbox ("extend your doctor", "extend driver installer").

**PART 5 — ChatGPT.** It specifies golden qcow2 images per firmware/filesystem/encryption matrix,
copy-on-write overlays, a per-scenario injection and verification table for all 40 items, pytest examples,
an idempotency test (`sunshine-doctor --fix` twice), release gates and JSON metrics. Grok offers a
six-step loop and a YAML idea, but its injections include `pacman -Rdd systemd` and `mv /var/lib/pacman ...`
with no snapshot/rollback rule, and it gives one generic verification line per scenario instead of an
expected outcome.

---

## 2. Every distinct breakage scenario named by either AI

C#/G# are the item numbers in that answer. "Detection" and "repair" are the commands the AIs proposed,
shortened; risk is the repair risk.

| # | Scenario | ChatGPT | Grok | Detection command | Repair command (env) | Risk | Sunshine status |
|---|----------|---------|------|-------------------|----------------------|------|-----------------|
| 1 | GRUB menu missing, corrupt or invalid `/etc/default/grub` | C1, C40 | G34 | `test -f /boot/grub/grub.cfg; grub-script-check /boot/grub/grub.cfg` | `grub-mkconfig -o /boot/grub/grub.cfg` (chroot) | Low-Med | **HANDLED** — doctor "Boot" regenerates `grub.cfg`; rescue `step_boot`; no `grub-script-check` validation |
| 2 | GRUB EFI binary or NVRAM entry missing | C2, C3 | G6 | `efibootmgr -v; find /boot/efi -name grubx64.efi` | `grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=SunshineOS --recheck` (chroot) | Med | **HANDLED** — rescue `step_boot` (NVRAM + `--removable`), doctor restores `EFI/BOOT/BOOTX64.EFI`; NVRAM failure is only printed |
| 3 | Initramfs missing or corrupt | C4 | G5 | `ls -lh /boot/initramfs-*.img` | `mkinitcpio -P` (chroot/running) | Med | **HANDLED** — doctor "Boot" per-kernel rebuild to temp file; rescue `step_kernel`; `sunshine-boot-repair` |
| 4 | Kernel image or module tree missing | C5 | G5 | `pacman -Q linux; ls /usr/lib/modules/*/vmlinuz` | `pacman -S linux linux-headers; mkinitcpio -P` | Med | **PARTIAL** — doctor/rescue restore `vmlinuz` from modules; only rescue installs `linux` when no modules exist |
| 5 | Wrong kernel command line (`root=`, `cryptdevice=`, `resume=`) | C6 | — | `cat /proc/cmdline; grep GRUB_CMDLINE_LINUX /etc/default/grub` | edit a backup of `/etc/default/grub`, then `grub-mkconfig` | High | **NOT HANDLED** — nothing reads or validates the installed system's cmdline |
| 6 | Wrong root UUID in boot configuration | C7 | G7 | `blkid; grep -E 'root=UUID' /proc/cmdline /boot/grub/grub.cfg` | correct only the verified UUID, `grub-mkconfig` | High | **NOT HANDLED** — rescue `step_fstab` checks fstab UUIDs only, doctor `findmnt --verify` warns only |
| 7 | Wrong Btrfs root subvolume (`subvol=`) | C8 | G8 | `findmnt -no OPTIONS /; btrfs subvolume list /` | mount `-o subvol=CORRECT`, fix fstab, `grub-mkconfig` | High | **NOT HANDLED** — rescue `scan`/`do_mount` guesses `@`, `root`, `rootfs`; never verifies against fstab/cmdline |
| 8 | `mkinitcpio` HOOKS lost (`encrypt`, `btrfs`, `resume`) | — | G21 | `grep -E '^HOOKS=' /etc/mkinitcpio.conf; lsinitcpio /boot/initramfs-linux.img` | edit conf, `mkinitcpio -P` | Med | **PARTIAL** — doctor warns when root is encrypted and `encrypt` hook is absent; no fix |
| 9 | Initramfs built without microcode | G30 | G30 | `lsinitcpio /boot/initramfs-linux.img` (grep ucode) | install `intel-ucode`/`amd-ucode`, `mkinitcpio -P` | Low | **PARTIAL** — doctor installs the package and checks the GRUB menu; does not add microcode to the image |
| 10 | Secure Boot / module signature enforcement blocks boot or modules | — | G24, G36 | `mokutil --sb-state; dmesg | grep -i 'secure boot\|lockdown'` | sign with `sbctl`/enroll MOK (user decision) | High | **NOT HANDLED** — no `sbctl`, `mokutil` or signing code anywhere |
| 11 | LUKS header or keyslot damaged | — | G9 | `cryptsetup luksDump /dev/...; dmesg | grep -i luks` | header backup first, `cryptsetup repair` (manual) | Extreme | **NOT HANDLED** — rescue `open_luks` only opens; no `luksHeaderBackup` or repair |
| 12 | Bad fstab UUID, missing device or wrong options | C37 | G20 | `findmnt --verify --verbose; blkid` | correct verified UUID/options, or review `genfstab -U` output | High | **NOT HANDLED** — rescue `step_fstab` reports missing UUID/LABEL and stops; doctor warns |
| 13 | Root filesystem remounted read-only | C9 | G31 | `findmnt -no OPTIONS /; dmesg | grep -i 'read-only\|I/O error'` | `mount -o remount,rw /` only if dmesg is clean | High | **PARTIAL** — doctor "System" detects `ro`, tells the user to run `sunshine-rescue fsck`; no repair |
| 14 | Btrfs checksum/device errors | C10 | — | `btrfs device stats /; btrfs scrub status /` | `btrfs scrub start /` (never `check --repair`) | Low-Med | **NOT HANDLED** — doctor counts device errors and prints a hint; no scrub timer or command |
| 15 | Btrfs metadata exhausted / unbalanced allocation | C15 | — | `btrfs filesystem usage /; btrfs filesystem df /` | bounded `btrfs balance start -musage=50 /` | Med-High | **NOT HANDLED** |
| 16 | Interrupted `btrfs balance`/scrub leaves FS read-only | — | G31 | `dmesg | grep -i 'btrfs.*readonly'; btrfs balance status /` | cancel/resume balance, read-only `btrfs check` | High | **NOT HANDLED** |
| 17 | Ext4 metadata errors | C11 | — | `dmesg | grep -E 'EXT4-fs error|journal.*abort'` | `e2fsck -fn` first, then `e2fsck -f` (live) | High | **HANDLED** — `sunshine-rescue fsck`/`repair` runs `e2fsck -fy` unmounted (no read-only pass first) |
| 18 | Disk reporting SMART/NVMe hardware errors | C14 | — | `smartctl -H /dev/...; nvme smart-log /dev/...` | none: notify, stop writes, back up | High | **PARTIAL** — doctor "System" reports PASSED/FAIL detected; intentionally no repair |
| 19 | Root, `/var` or `/boot` full | C12 | G39 | `df -h / /boot /var; df -i /` | `paccache -r; journalctl --vacuum-time=14d` | Low-Med | **PARTIAL** — doctor warns at 85/95 %, `/boot` < 100 MB; `sunshine-cleanup` is manual |
| 20 | Inodes exhausted | C13 | — | `df -i /` | find the offender, use the app's own cache cleanup | Med | **NOT HANDLED** |
| 21 | Swap/zram missing or misconfigured | C16 | G23 | `swapon --show; free -h; zramctl` | `swapon -a` / restart `systemd-zram-setup@zram0` | Med | **PARTIAL** — doctor warns "no swap"; `sunshine-performance on` writes zram-generator config, no verification |
| 22 | Snapshot backend broken or points at the old disk | — | G10, G32 | `snapper list; timeshift --list` | re-create config against current UUID | Med | **PARTIAL** — doctor `--fix` runs `sunshine-snapshots-setup` only when unconfigured |
| 23 | Stale `/var/lib/pacman/db.lck` | C17 | G1 | `test -e /var/lib/pacman/db.lck; pgrep -a pacman` | `rm -f` only when no pacman/yay/paru runs | Med | **HANDLED** — doctor and `sunshine-fix-pacman` check `pgrep -x pacman`; rescue `step_pacman` removes it unconditionally |
| 24 | Package database corruption / interrupted transaction | C18 | G1, G2 | `pacman -Dk; tail -n 200 /var/log/pacman.log` | remove damaged sync DBs, re-sync, reinstall affected packages | High | **PARTIAL** — `sunshine-fix-pacman` deletes corrupt `sync/*.db` and re-syncs; local DB damage is only reported |
| 25 | Keyring/signature failure | C19 | G3 | `pacman-key --list-keys; pacman -Sy` | `pacman-key --init; --populate`; update `archlinux-keyring` | Med | **HANDLED** — doctor `--fix`, `sunshine-fix-pacman`, rescue `step_pacman` |
| 26 | Mirrors unreachable / out of date | C20 | G4 | `pacman -Sy; curl -sI $(awk '/^Server/{print $3;exit}' /etc/pacman.d/mirrorlist)` | rank with `rate-mirrors`/`reflector`, keep a backup | Low | **HANDLED** — `sunshine-fix-pacman` "Mirrors" with backup + fallback; `sunshine-update-run` `refresh_mirrors` |
| 27 | Partial upgrade / mixed package versions | C21 | G2 | `pacman -Qm; pacman -Qu; grep IgnorePkg /etc/pacman.conf` | `pacman -Syu` (full, never `-Sy pkg`) | Med-High | **NOT HANDLED** — no mixed-version detection; doctor may `pacman -S` core packages without a full upgrade |
| 28 | Missing dependency | C22 | — | `pacman -Dk` | `pacman -Syu` or install the verified package | Med | **PARTIAL** — `pacman -Dk` is reported by doctor/fix-pacman, no targeted reinstall |
| 29 | Core package removed / incomplete install | C23 | G19, G33 | `pacman -Q base systemd glibc linux linux-firmware` | `pacman -S base systemd glibc linux linux-firmware` (chroot) | High | **HANDLED** — doctor "Package manager" reinstalls a fixed core list; no install-profile manifest |
| 30 | AUR build/update failure, orphaned partial builds | C24 | G25 | `pacman -Qm; paru --version; ls /tmp/yay* /var/tmp/pamac*` | rebuild per package; `pacman -Rns $(pacman -Qdtq)` | Med | **PARTIAL** — fix-pacman reinstalls a broken helper; update-run runs `paru -Sua` and ignores failure; orphans only via `sunshine-cleanup` prompt |
| 31 | `.pacnew`/`.pacsave` left unresolved | C25 | G35 | `find /etc -name '*.pacnew' -o -name '*.pacsave'` | `sunshine-pacnew auto`, then `review`; never blanket replace | Med | **HANDLED** — `sunshine-pacnew` (safe auto + review), doctor counts, update-run runs `auto` |
| 32 | `pacman.conf` or repository config modified | C40 | — | `pacman-conf; grep '^\[' /etc/pacman.conf` | restore from `.pacnew`, remove obsolete repos | Med | **HANDLED** — `sunshine-fix-pacman` "pacman.conf", `sunshine-repo ensure`, doctor checks |
| 33 | Broken symlinks after partial package removal | — | G40 | `find /usr -xtype l; pacman -Qkk 2>&1 | grep 'is a broken'` | reinstall the packages that own them | Med | **NOT HANDLED** |
| 34 | NVIDIA module missing/mismatched for the kernel | C26 | G11 | `nvidia-smi; dkms status; ls /usr/lib/modules/$(uname -r)/extramodules` | install the matching branch, `mkinitcpio -P` | High | **HANDLED** — `sunshine-drivers` picks open/legacy/DKMS by PCI id; doctor runs `dkms autoinstall`; update-run blocks a kernel/NVIDIA skew |
| 35 | Hybrid graphics PRIME/offload broken | C27 | G12 | `lspci -nnk; prime-run glxinfo -B; ls /dev/dri` | install `nvidia-prime`, keep the iGPU as default | Med-High | **PARTIAL** — drivers installs `nvidia-prime` when an iGPU is present; no PRIME diagnosis or fallback check |
| 36 | Broadcom/Realtek Wi-Fi firmware missing | C28 | G13 | `lspci -nnk | grep -A3 Network; dmesg | grep -i firmware` | install `broadcom-wl-dkms` / matching firmware, reload module | Low-Med | **PARTIAL** — Broadcom covered by `sunshine-drivers`; Realtek/other firmware not checked |
| 37 | GPU driver blacklisted or wrong module order | — | G29 | `lsmod | grep -E 'nvidia|nouveau|amdgpu|i915'; cat /etc/modprobe.d/*` | remove the conflicting blacklist, `mkinitcpio -P` | Med | **NOT HANDLED** |
| 38 | PipeWire/WirePlumber broken or stuck after suspend | C29 | G14, G38 | `systemctl --user status pipewire wireplumber; pactl info` | `systemctl --user restart pipewire pipewire-pulse wireplumber` | Low | **NOT HANDLED** — doctor does not look at audio at all |
| 39 | SDDM fails to start / Wayland session file missing | C30 | G15, G37 | `systemctl status sddm; ls /usr/share/wayland-sessions/` | `systemctl enable --now sddm`; reinstall `plasma-workspace` | Med | **NOT HANDLED** — doctor only warns if the `sddm` package is absent; never checks the unit or session file |
| 40 | Plasma user configuration corrupted / crash loop | C31 | G16 | `journalctl --user -b | grep -iE 'plasmashell|kwin|segfault'` | `sunshine-reset-plasma` (backup + defaults + `--undo`) | Med | **HANDLED** — `sunshine-reset-plasma` |
| 41 | Wayland/KWin compositor failure | C32 | — | `journalctl -b | grep -iE 'kwin_wayland|drm|gbm|egl'` | restore last good driver/session; do not disable Wayland globally | Med-High | **NOT HANDLED** |
| 42 | NetworkManager stopped, disabled or unmanaged | C33 | G17 | `systemctl status NetworkManager; nmcli device status` | `systemctl enable --now NetworkManager`; `nmcli networking on` | Low | **NOT HANDLED** — doctor warns only |
| 43 | Wi-Fi soft-blocked by rfkill | C34 | — | `rfkill list all; nmcli radio all` | `rfkill unblock wifi; nmcli radio wifi on` | Low | **NOT HANDLED** |
| 44 | DNS resolution broken | C35 | G18 | `resolvectl status; getent hosts archlinux.org` | recreate the `resolv.conf` link, restart resolver | Med | **HANDLED** — doctor `--fix` recreates the `systemd-resolved` stub link |
| 45 | Essential systemd service failed | C36 | — | `systemctl --failed --no-legend` | restart only an understood service | Med | **NOT HANDLED** — doctor lists failed units, never restarts |
| 46 | Locale, timezone or keyboard layout broken | — | G27 | `localectl status; timedatectl` | `localectl set-locale/set-keymap`, `timedatectl set-timezone` | Low | **NOT HANDLED** |
| 47 | `/run/user` / XDG runtime dir wrong | — | G28 | `ls -ld /run/user/$(id -u); echo $XDG_RUNTIME_DIR` | `loginctl enable-linger`; `systemctl --user daemon-reexec` | Low | **NOT HANDLED** |
| 48 | System clock not synchronised | C39 | — | `timedatectl show -p NTPSynchronized --value` | `timedatectl set-ntp true` | Low | **NOT HANDLED** — doctor warns only |
| 49 | Wrong permissions on essential paths | C38 | — | `stat -c '%a %U:%G %n' / /etc /usr /var /tmp /boot` | targeted `chmod` from package metadata; `/tmp` 1777 | High | **NOT HANDLED** |
| 50 | Flatpak runtime mismatch after a system update | — | G26 | `flatpak list --runtime; flatpak remotes` | `flatpak repair; flatpak update -y` | Low | **NOT HANDLED** — update-run only runs `flatpak update` |
| 51 | earlyoom/OOM killed a critical process | — | G22 | `journalctl -b | grep -i 'earlyoom\|Out of memory'` | adjust `/etc/default/earlyoom`, restart service | Low | **NOT HANDLED** — performance writes the avoid list, nothing checks kills |

---

## 3. The 25 scenarios without an automatic repair that matter most for ordinary users

Ranked by "a normal user hits this and cannot recover without a forum". Each item: where to implement,
detection, repair or safe stop.

1. **Wrong `root=` UUID / kernel command line** (unbootable, #5/#6).
   - Where: `sunshine-rescue` new `step_cmdline` after `step_fstab`; `sunshine-doctor` "Boot".
   - Detect: compare `root=UUID=` in `/boot/grub/grub.cfg` and `/etc/default/grub` with `blkid` of the mounted root.
   - Repair: back up both files, rewrite only the verified UUID, `grub-mkconfig`, `grub-script-check`; stop if two candidates.
2. **Bad fstab UUID/options** (#12).
   - Where: extend `sunshine-rescue` `step_fstab` (currently report-only) and doctor "Boot".
   - Detect: `findmnt --verify --verbose --tab-file`; per line `blkid -U`/`blkid -L`.
   - Repair: back up `/etc/fstab`, fix only entries whose device exists; never regenerate the whole file, never invent a UUID.
3. **Wrong Btrfs root subvolume** (#7).
   - Where: `sunshine-rescue` `scan`/`do_mount`; record the expected subvol in `/etc/sunshine/install.conf` at install time.
   - Detect: compare `findmnt -no OPTIONS /` and fstab `subvol=` with the subvolume that contains `etc/os-release`.
   - Repair: mount the matching subvolume, rewrite `rootflags=subvol=`/fstab; stop if more than one contains a full system.
4. **`mkinitcpio` HOOKS missing (encrypt/btrfs/resume)** (#8).
   - Where: doctor "Boot" encrypted-root block; add a `sunshine-mkinitcpio-check` migration for known-good HOOKS.
   - Detect: `grep -E '^HOOKS='`; `lsinitcpio` for `encrypt`, `btrfs`, `resume` against actual root/cmdline.
   - Repair: write a drop-in `/etc/mkinitcpio.conf.d/10-sunshine-hooks.conf`, rebuild to a temp file, verify before replacing; stop if the user customised HOOKS.
5. **Damaged local pacman database** (`pacman -Dk` fails) (#24).
   - Where: `sunshine-fix-pacman` section "Databases" (currently sync DBs only).
   - Detect: `pacman -Dk` non-zero; `bsdtar -tf /var/lib/pacman/local/*/desc` failures; interrupted marker in `pacman.log`.
   - Repair: back up `/var/lib/pacman/local`, reinstall the affected packages with `pacman -S --needed`; never delete `local/` automatically.
6. **Partial/interrupted upgrade, mixed versions** (#27).
   - Where: doctor "Package manager" new check; `sunshine-update-run` `run_update` preflight.
   - Detect: `pacman -Qkk` mismatches, `pacman -Qm` + `pacman -Qu`, installed kernel vs `/usr/lib/modules`, `pacman.log` without a closing transaction.
   - Repair: offer one full `pacman -Syu` (never `-Sy pkg`), snapshot first; stop if disk < 1.5 GB or keyring is broken.
7. **SDDM down or no session file** (boots to black screen/TTY) (#39).
   - Where: doctor new "Login" section next to "Desktop"; reuse the `sunshine-desktops` session lookup.
   - Detect: `systemctl is-enabled/is-active sddm`; `ls /usr/share/wayland-sessions/plasma.desktop`; `state.conf` points to an existing file.
   - Repair: `systemctl enable --now sddm`; reset `state.conf` to the Sunshine Plasma session; reinstall `plasma-workspace` only if the file is absent.
8. **Root, `/var` or `/boot` full** (#19).
   - Where: doctor "System" disk block; add `sunshine-cleanup --auto` (no prompts) and call it.
   - Detect: `df` thresholds 85/95 %, `/boot` < 100 MB, `btrfs filesystem usage`.
   - Repair: `paccache -rk1`, journal vacuum, `pacman -Sc`; never touch `/home`, snapshots or `/var/lib`; list old kernels instead of removing them.
9. **Root remounted read-only** (#13).
   - Where: doctor "System" root-ro block (currently a dead end).
   - Detect: `findmnt -no OPTIONS /`, `dmesg -T | grep -iE 'I/O error|read-only|EXT4-fs error|BTRFS.*error'`.
   - Repair: `mount -o remount,rw /` only when dmesg is clean; otherwise stop and point to `sunshine-rescue fsck`; never force it after I/O errors.
10. **Btrfs device errors, scrub overdue** (#14).
    - Where: new `sunshine-storage` (small wrapper) called from doctor "System"; systemd timer `sunshine-scrub.timer`.
    - Detect: `btrfs device stats /`, `btrfs scrub status -d /`, `dmesg | grep -i btrfs`.
    - Repair: `btrfs scrub start -B /` (read-only check first); never `btrfs check --repair`, never a full balance.
11. **NetworkManager down or unmanaged** (#42).
    - Where: doctor "System" network block (currently warn only).
    - Detect: `systemctl is-active NetworkManager`, `nmcli general status`, `nmcli device status`.
    - Repair: `systemctl enable --now NetworkManager`, `nmcli networking on`; do not delete connection profiles.
12. **Wi-Fi soft-blocked** (#43).
    - Where: same doctor network block.
    - Detect: `rfkill list`, `nmcli radio all`.
    - Repair: `rfkill unblock wifi`, `nmcli radio wifi on`; stop on `Hard blocked: yes` (firmware switch).
13. **PipeWire/WirePlumber audio failure** (#38).
    - Where: doctor new "Session services" section running as `$SUDO_USER` with `systemctl --user`.
    - Detect: user units inactive/failed, `pactl info` non-zero, `wpctl status` empty.
    - Repair: `systemctl --user restart pipewire pipewire-pulse wireplumber`; check the packages; never delete `~/.config/pulse`.
14. **Failed systemd service** (#45).
    - Where: doctor "System" failed-units list.
    - Detect: `systemctl --failed --no-legend`, `systemctl --user --failed`.
    - Repair: restart only an allowlist (NetworkManager, bluetooth, cups, sddm, pipewire); report the rest; never restart every failed unit.
15. **Kernel modules missing for the running kernel** (#4).
    - Where: doctor "Boot"/"System" kernel-match block.
    - Detect: `test -d /usr/lib/modules/$(uname -r)`; `pacman -Qo /usr/lib/modules/$(uname -r)`; `dkms status`.
    - Repair: reinstall the owning kernel package + headers, `mkinitcpio -P`, require reboot; stop if the running kernel package is unknown.
16. **GPU module blacklisted or wrong module order** (#37).
    - Where: `sunshine-drivers` `detect`/`plan`; doctor reports the plan.
    - Detect: `lsmod`, `cat /etc/modprobe.d/*.conf`, `/proc/fb`, `dmesg | grep -i 'nouveau\|nvidia'`.
    - Repair: remove only Sunshine-owned files (`/etc/modprobe.d/sunshine-nouveau.conf`), rebuild initramfs; never edit user modprobe files.
17. **Hybrid PRIME/offload misconfigured** (#35).
    - Where: `sunshine-drivers` `detect` (add `prime-run`/`/dev/dri` checks).
    - Detect: two GPUs, `prime-run glxinfo -B` fails, `xrandr --listproviders` missing NVIDIA provider.
    - Repair: install `nvidia-prime`, add the offload env to the session; never make the dGPU the default renderer.
18. **Locale, timezone or keymap wrong** (#46).
    - Where: doctor "System" new check.
    - Detect: `localectl status`, `timedatectl`, `/etc/localtime` symlink, `localectl list-keymaps` membership.
    - Repair: set only missing/empty values (`localectl set-locale`, `set-keymap`, `timedatectl set-timezone`); never overwrite a non-empty user choice.
19. **Clock not synchronised** (#48).
    - Where: doctor "System" clock check (currently warn only).
    - Detect: `timedatectl show -p NTPSynchronized --value`, `systemctl is-active systemd-timesyncd`.
    - Repair: `timedatectl set-ntp true`, enable timesyncd, re-check; if TLS still fails, report captive portal/firewall.
20. **Snapshot backend broken or on the old disk** (#22).
    - Where: `sunshine-snapshots-setup` new `verify` mode; doctor "Restore points".
    - Detect: snapper config root device vs `blkid` of `/`, `snapper list`, `timeshift --list --scripted`, `.snapshots` mount.
    - Repair: re-create the config against the current UUID and make one test snapshot; never delete the last good snapshot.
21. **Broken symlinks after a partial removal** (#33).
    - Where: doctor "Package manager" new `pacman -Qkk` pass.
    - Detect: `pacman -Qkk 2>&1 | grep 'is a broken'`, `find /usr -xtype l`.
    - Repair: map the path to its owning package (`pacman -Qo`), reinstall with `pacman -S --needed`; never delete links in `/etc`.
22. **Flatpak runtime mismatch** (#50).
    - Where: doctor "System" optional block; `sunshine-update-run` after the Flatpak update.
    - Detect: `flatpak remotes`, `flatpak list --runtime`, `flatpak repair --dry-run`.
    - Repair: `flatpak repair`, `flatpak update -y`; skip if no remotes; never remove user data or runtimes in use.
23. **AUR build failure / orphaned partial builds** (#30).
    - Where: `sunshine-update-run` AUR block (currently `paru -Sua || true`).
    - Detect: capture the AUR output; `paru -Qm`, failed PKGBUILD package names, `/tmp/yay*` leftovers.
    - Repair: report the failed package and keep the system update successful; reinstall only the helper (`sunshine-fix-pacman`); never run an unreviewed PKGBUILD as root.
24. **Secure Boot / signature enforcement breaks a module** (#10).
    - Where: new `sunshine-secureboot` (sbctl wrapper); doctor Boot warning before reboot.
    - Detect: `mokutil --sb-state`, `sbctl status`, `dmesg | grep -i 'module verification\|lockdown'`.
    - Repair: sign with the enrolled key (`sbctl sign -s`), or tell the user to enroll; never disable Secure Boot or `module.sig_enforce=0` automatically.
25. **Btrfs metadata exhausted / interrupted balance** (#15/#16).
    - Where: new `sunshine-storage`; doctor "System" filesystem block.
    - Detect: `btrfs filesystem usage /`, `btrfs balance status /`, `dmesg | grep -i 'btrfs.*readonly'`.
    - Repair: `btrfs balance cancel` if interrupted; only with >10 % free, offer `btrfs balance start -musage=50` after confirmation; never `btrfs check --repair`.

---

## 4. Wrong, risky or dangerous advice for an automatic repair tool

1. **Grok, repair of an "incomplete/corrupt package transaction":**
   `pacman -Syu --overwrite '*'` — overwrites *every* file on the system regardless of ownership,
   including `/etc` configuration and files from other packages. One interrupted download can silently
   replace a user's config. Never put this in a repair tool.
2. **Grok, fstab repair:** `genfstab -U / > /etc/fstab` (and the chroot variant `genfstab -U /mnt > /etc/fstab`).
   `genfstab` regenerates the whole file: it drops `compress`, `noatime`, `ssd`, `discard`, comments,
   bind mounts and any hand-added options, and on the running system it can include live mounts. It also
   writes the *live* `/etc/fstab` in the second form. A repair must edit verified lines, never regenerate.
3. **Grok, Btrfs repair:** `btrfs check --repair (careful), then btrfs balance start`.
   `btrfs check --repair` is documented as dangerous, can turn a recoverable filesystem into an
   unrecoverable one, and must never be automated. Grok itself says "never run --repair without backup",
   then lists it as the repair.
4. **Grok, clock/DNS:** `ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf`.
   This is correct only on a `systemd-resolved` system. On NetworkManager + dnsmasq, unbound, or a
   VPN-managed resolver it breaks DNS. It is what `sunshine-doctor --fix` does today; it should first
   check which resolver is active.
5. **Grok, Secure Boot:** "set `module.sig_enforce=0` temporarily or enroll keys" and "disable SB
   temporarily from firmware". Disabling enforcement defeats the feature and hides the real problem
   (an unsigned module after a kernel update). An automatic tool may sign or explain, never disable.
6. **Grok, LUKS:** `cryptsetup repair if needed`. `cryptsetup repair` is a LUKS2 header operation with a
   real chance of making the container unopenable; it needs a header backup and explicit consent, not a
   line in a repair list.
7. **Grok, pacman lock + update in one step:** `rm -f /var/lib/pacman/db.lck; pacman -Syu --noconfirm`.
   Removing the lock without checking `pgrep pacman` corrupts a live transaction; `--noconfirm` then
   applies a full upgrade unattended. The two operations must be separate and guarded.
8. **Grok, orphan removal:** `pacman -Rns $(pacman -Qdtq)`. Orphans include optional dependencies that a
   user-installed AUR package or a manual build still needs; `-Rns` also removes configuration. This is a
   prompt-with-list operation, not an automatic one.
9. **Grok, `pacman -Qkk` pipeline:** `pacman -Qkk | grep missing | cut -d: -f1 | xargs -r pacman -S --noconfirm`.
   `-Qkk` output is per package, not per file, and includes backup-file warnings; the pipeline can feed
   arbitrary text to `pacman -S` and reinstall the wrong set. Parse package names with `pacman -Qo`.
10. **ChatGPT, rescue Phase 7:** `arch-chroot /mnt pacman -Syu` as an unconditional repair step.
    A full upgrade during recovery changes the system the user asked to repair, may pull a new kernel
    and NVIDIA branch, and fails offline. Make it an explicit, snapshotted, opt-in step after mount and
    space checks (Sunshine rescue currently avoids it, which is safer).
11. **ChatGPT, root read-only:** `mount -o remount,rw /`. The text warns about corruption, but the command
    is listed as the repair; the safe order is dmesg check → refuse if I/O errors → only then remount.
12. **ChatGPT, inode offender finder:**
    `find /var -xdev -type f | awk -F/ '{print $1"/"$2"/"$3"/"$4}'`.
    With absolute paths the fields shift ($1 is empty), so the grouping is wrong and can point at `/`
    or at nothing. It is a harmless reporting bug, but it shows the command was not tested.
13. **ChatGPT, rescue Phase 15:** `systemctl reboot` from the live session without asking.
    A repair tool must unmount, close LUKS and return control; an unexpected reboot can interrupt a user
    who wanted to inspect the report.
14. **ChatGPT, rescue Phase 13:** `arch-chroot /mnt systemctl --failed`.
    It acknowledges the caveat, but the output is misleading: offline `systemctl` does not reflect the
    installed system's boot. Do not turn this into an automatic repair decision.

---

## 5. ChatGPT's PART 2 order vs the real `sunshine-rescue repair` and `sunshine-doctor`

**Actual `sunshine-rescue repair` order:** `pick`/`scan` (RO scan, opens LUKS) → `do_fsck` (unmounted,
`e2fsck -fy` automatically, only if `SUNSHINE_RESCUE_FSCK=1`) → `do_mount` (root + every fstab mount,
RW immediately) → `step_pacman` (unconditional `rm db.lck`, `pacman -Dk`, keyring if empty, repo ensure) →
`step_kernel` (restore `vmlinuz`, install `linux` if no modules, `mkinitcpio -P`) → `step_fstab`
(report-only UUID/LABEL check) → `step_boot` (`grub-install` + `grub-mkconfig`) → `step_doctor`
(`sunshine-doctor --fix` inside the chroot) → `do_umount` (unmount + close LUKS). No SMART check, no
space check, no package restore, no report file.

**Actual `sunshine-doctor --fix` order:** identity → package manager (lock, keyring, `pacman -Dk`, core
packages, repo sanity, `.pacnew` count) → desktop (icon font, Hyprland crashes, SDDM session warning) →
boot (kernels, initramfs, marker, last update, EFI fallback, `/boot` free, microcode, DKMS, btrfs holes,
`grub.cfg`, fstab warn) → system (SMART, btrfs stats, clock, swap, failed units, disk %, NetworkManager,
kernel match, root RO, DNS, encrypt hook) → restore points → declarative. It never snapshots before the
first repair and never re-runs the checks at the end.

Concrete differences worth adopting from ChatGPT:

1. **Hardware health before any write.** ChatGPT Phase 2 runs `smartctl`/`nvme smart-log` and stops on
   critical failure; rescue never checks SMART and will `e2fsck -fy` a failing disk. Add a read-only
   SMART gate before `do_fsck`/`do_mount`, and skip repairs on a failing device.
2. **Read-only filesystem check first, repair with consent.** ChatGPT Phase 5 uses `e2fsck -fn`, then asks
   before `-f`; rescue `do_fsck` runs `e2fsck -fy` immediately. Change to `-fn`, then a level-4 prompt.
3. **Validate the mount hierarchy before writing.** ChatGPT Phase 4 verifies root UUID, ESP, subvolume and
   "no mount hides data" before package work; rescue mounts fstab entries and proceeds even when one
   fails. Add a mount manifest check and abort on a missing `/boot` or ESP.
4. **Do not run `pacman -Syu` in rescue by default.** ChatGPT Phase 7 does; Sunshine does not. Keep
   Sunshine's offline-first behaviour and add ChatGPT's Phase 6/7 checks (clock, keyring, repo config,
   `pacman.log` interrupted marker) without the upgrade. Offer `-Syu` as an explicit post-repair option.
5. **Restore essential packages from a profile, not one kernel check.** ChatGPT Phase 8 reinstalls a
   manifest of mandatory packages; rescue only installs `linux` when the module tree is empty. Add a
   `pacman -Dk`-driven reinstall from `/etc/sunshine/profile` (or reuse doctor's core list) inside rescue.
6. **Check free space before initramfs and packages.** ChatGPT checks `df /boot` before `mkinitcpio -P`
   and free space before package work; rescue does neither, so a full `/boot` produces a half-written
   initramfs. Add the check and refuse instead of rebuilding.
7. **Validate GRUB syntax and the NVRAM entry.** ChatGPT runs `grub-script-check` and `efibootmgr -v` after
   `grub-mkconfig`; rescue only greps for `menuentry` and prints NVRAM failures. Add both checks and
   report the fallback path explicitly instead of silently relying on `--removable`.
8. **Back up before touching boot/config files.** ChatGPT copies `/etc/default/grub` and `/etc/fstab`
   before edits; rescue regenerates `grub.cfg` and doctor rewrites `grub.cfg` without a backup. Add
   timestamped backups under `/var/lib/sunshine/backups`.
9. **Do not treat offline `systemctl` as the installed system.** ChatGPT Phase 13 warns about it; rescue
   runs `sunshine-doctor --fix` in the chroot, whose `--fix` may `systemctl enable` units and run package
   installs. Either run doctor without `--fix` in the chroot, or restrict it to detection and report.
10. **Persist the report.** ChatGPT Phase 14 writes a structured report and lists repairs done/skipped;
    rescue logs only to `/tmp/sunshine-rescue.log`, which is lost on reboot. Write the report into the
    mounted system (`/var/log/sunshine/rescue-<date>.log`) and print the path.
11. **Clean shutdown first.** ChatGPT Phase 15 does `sync`, `umount -R`, `cryptsetup close`, then asks;
    rescue closes LUKS in `do_umount` but offers no explicit "safe to reboot" state or check. Adopt the
    sync/close sequence and a final "do not reboot until unmounted" message.
12. **Doctor: pre-repair restore point and transaction gate.** ChatGPT's doctor stops on *active package
    transactions* (not just `db.lck`) and puts disk space before package work; Sunshine checks only
    `pgrep -x pacman` and reaches the disk check late. Add `yay`/`paru` to the gate, create a snapshot
    before the first write, and move the space check before any `pacman -S`.
13. **Doctor: full upgrade before reinstalling core packages.** ChatGPT orders "partial upgrade → offer
    complete upgrade" (8) before "missing essential packages" (9). Sunshine's doctor runs
    `pacman -S --needed $core_missing` directly, which can install newer versions on an old sync DB and
    create the very partial upgrade it is meant to fix. Run `pacman -Syu` (or at least `-Sy` + full
    transaction) first, or install from cache/`--needed --asdeps` only when versions match.
14. **Doctor: explicit risk levels and a final re-check.** ChatGPT classifies every action 0-5 and ends
    with "repeat relevant health checks"; Sunshine has no levels and exits on the first pass. Add a
    `level` field per check, a `--json` schema (`sunshine-doctor --json`) and a final re-run of failed
    checks before reporting success.
15. **Doctor: separate user services from system services.** ChatGPT has explicit PipeWire (14) and
    SDDM/Plasma (15) stages and warns not to kill a live session; Sunshine has neither, and its only
    desktop repair (`sunshine-reset-plasma`) is user-invoked. Add a user-session section that restarts
    PipeWire and checks `sddm` without restarting it while a session is active.
16. **Doctor: NetworkManager and driver state.** ChatGPT repairs NetworkManager (13) and only identified
    driver mismatches (12); Sunshine warns about NetworkManager and runs a blanket `dkms autoinstall`.
    Add `systemctl enable --now NetworkManager` and a PCI-id/branch check before rebuilding DKMS.

Do not copy Grok's live order: it places the snapshot after the repairs ("create a new snapshot before
any further changes"), and its doctor updates packages before checking disk space or active transactions.
ChatGPT's order is the better base, with the offline-first and "ask before changing the system" rules
from the current Sunshine rescue kept.
