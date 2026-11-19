> Draft by an opencode agent (big-pickle). Several points are marked GUESS; not implemented: needs a shim/MOK decision and an OVMF Setup-Mode test first.

# Secure Boot design for Sunshine OS (research + design only, 2026-11-19)

Sources read (all under `~/sunshineos-build/research/`, READ ONLY):
`g-pkgbuilds/garuda-secureboot/{garuda-secureboot,PKGBUILD,garuda-secureboot.install}`,
`g-pkgbuilds/garuda-hooks/{garuda-hooks-runner,grub-install.hook,update-grub.hook,garuda-hooks-runner.hook,90-mkinitcpio-install.hook}`,
`g-pkgbuilds/garuda-systemd-boot/{uki.conf,kernel-install-uki,95-garuda-kernel-install.hook}`,
`CachyOS-Settings/usr/bin/{sbctl-batch-sign,eac-setup,eac-status}` and `CachyOS-Settings/README.md:70`.
Sunshine-side facts: `profile/airootfs/usr/local/bin/sunshine-install` and `sunshine-boot-repair` in this repo.

Conventions: `[file:LINE]` = line in the file as read. Statements not verifiable from these files or from certain
knowledge of the tools are tagged **GUESS**. No code was added to the repository by this task.

## 1. How each distro does it, step by step

### 1.1 Garuda: `garuda-secureboot` = shim + MOK (not sbctl)

Packages (`garuda-secureboot/PKGBUILD:14`): `python`, `shim-signed`, `sbsigntools`,
`garuda-dracut-support>=1.6.0`, `garuda-hooks>=2.15.0`, `mokutil`, `grub`.
State: keys `/var/lib/garuda/secureboot/keys` (`garuda-secureboot:163`), flag
`/etc/garuda/secureboot/enabled` (`:176-177`), boot files under `/boot/efi/EFI/garuda/` (`:129-133`).

`--install` (`enable_secure_boot()`, `:135-220`):
1. Root check `:303-306`, UEFI check (`/sys/firmware/efi`) `:307-310`; warn if shim already present `:141-144`;
   require `EFI/garuda/grubx64.efi` `:145-147`; parse `efibootmgr` `:60-87`, warn if the current entry is not
   named "garuda" `:149-154`; remember whether the fallback `EFI/Boot/bootx64.efi` is byte-identical to GRUB
   `:156-160`.
2. Create an RSA-2048 self-signed MOK with `openssl req ... -days 3650 -subj '/CN=Garuda User Machine Owner Key/'`
   and convert to DER (`MOK.crt` -> `MOK.cer`) `:162-169` (single shell command at `:166`).
3. Copy `MOK.cer` to the ESP and queue it for MOK enrollment with `mokutil --import`, feeding the **fixed
   password "garuda"** twice on stdin `:107-126`, `:171-173`. Enrollment completes only at the next reboot in
   the MOK manager (the final message at `:218` says so).
4. Write the flag file `:175-177`.
5. If the fallback matched, copy the new GRUB to `EFI/Boot/grubx64.efi` `:181-182`; call
   `/usr/share/libalpm/scripts/garuda-hooks-runner grub-update` to reinstall+sign GRUB `:183-186`; call
   `dracut-rebuild` to reinstall/sign kernels `:188-193` (the actual kernel-signing code is in
   `garuda-dracut-support`, **not** in the read tree — mechanism not verified here).
6. Install Microsoft-signed shim from `/usr/share/shim-signed/{shimx64.efi,mmx64.efi}` into `EFI/garuda/`, and
   into `EFI/Boot/` when the fallback matched `:195-200`.
7. Delete all "garuda" NVRAM entries and create a new one pointing to `\EFI\garuda\shimx64.efi` using `-d/-p`
   derived from `findmnt -n -o SOURCE /boot/efi` `:89-105`, `:202-216`.
8. Tell the user to enable Secure Boot in firmware and finish MOK enrollment `:218`.

`--uninstall` (`disable_secure_boot()`, `:222-288`): remove the flag `:228-229`; point the NVRAM entry back to
`grubx64.efi` `:231-247`; delete shim, `mmx64.efi`, `MOK.cer` and the fallback copies `:249-266`; reinstall
unsigned GRUB and kernels `:268-282`; delete the keys directory `:284-286`. The package's `pre_remove` also
deletes the flag (`garuda-secureboot.install:1-5`). Note: it does **not** un-enroll the MOK (not possible without
MOK manager / Setup Mode) and does not turn firmware Secure Boot off.

Re-signing after updates: `garuda-hooks-runner Grub-update()` (`garuda-hooks-runner:83-141`), triggered by
`grub-install.hook:1-9` (grub upgrade) and indirectly by `update-grub.hook:1-17` (new `vmlinuz`):
- If the flag file exists `:91-93`, read `insmod` module names from `/boot/grub/grub.cfg` plus a hard-coded
  default module list `:102-109`, then run
  `grub-install --no-nvram --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Garuda" --modules "<list>" --sbat /usr/share/grub/sbat.csv`
  and sign the installed binary in place with
  `sbsign --key .../MOK.key --cert .../MOK.crt --output EFI/Garuda/grubx64.efi EFI/Garuda/grubx64.efi`
  `:110-114`. With no flag, plain `grub-install --no-nvram ...` `:115-118`.
- Keep fallback copies identical only if they were identical before (`cmp -s`) `:100`, `:119-125`; warn if the
  current NVRAM entry is not Garuda `:128-139`. Kernel/initramfs rebuild is the `kernel` case `:156-174`,
  hooked by `90-mkinitcpio-install.hook:1-19`.

Requirements summary: UEFI boot; root; ESP at `/boot/efi`; Microsoft-signed shim (already trusted by firmware)
+ a **user MOK** signed with `sbsign`; the vendor EFI signature database must still trust Microsoft's shim;
firmware Secure Boot is turned on by the user **after** install; no Setup Mode is needed (MOK enrollment is a
shim mechanism, not a firmware-key change).

### 1.2 CachyOS: `sbctl-batch-sign` = batch re-sign of whatever `sbctl verify` flags

`sbctl-batch-sign` (`CachyOS-Settings/usr/bin/sbctl-batch-sign:1-37`):
1. Refuse if `/boot/limine.conf` exists `:8-11`; require root `:13-16`.
2. Set `EAC_CA=/usr/share/cachyos-eac/cachyos-eac-ca.crt` `:20` and `ESP_PATH=/boot` `:22`.
3. Ask `sbctl` which files are not properly signed: `sbctl verify 2>/dev/null | awk '/✗/ {print $2}'` `:23`.
4. Skip Microsoft/Windows ESP files, `*.mui`, `*.dll`, and anything under `/boot/grub` `:24-31` (comment
   `:24-27`: users enroll their own keys *alongside* Microsoft's, so MS files need no re-signing).
5. Skip files already verifiable with the CachyOS EAC CA (`sbverify --cert "$EAC_CA"`) `:32-35`, then
   `sbctl sign -s "$entry"` on the rest `:36`. `-s` also records the file in sbctl's database
   (`eac-setup:380-381`, `sbctl list-files`/`remove-file` at `:388-399`), so later `sbctl sign-all` re-signs it.

The script itself never creates or enrolls keys — that is `eac-setup` (`eac-setup:1-569`) and `eac-status`:
- Tools: `sbctl sbsigntools tpm2-tools efibootmgr cachyos-eac-signing-key` via pacman `eac-setup:148-157`.
- Firmware state is read from the efivar directly: `SetupMode-8be4df61-93ca-11d2-aa0d-00e098032b8c` /
  `SecureBoot-...`, skipping the 4 attribute bytes (`eac-setup:23`, `:81-87`); `eac-status` uses `sbctl status`
  strings instead (`eac-status:50-62`).
- In Setup Mode: `sbctl create-keys` then `sbctl enroll-keys --microsoft --custom [--firmware-builtin]`
  (`eac-setup:245-283`). `--firmware-builtin` is added only when `dbDefault-...` exists and the board vendor is
  not ASUS/Gigabyte (duplicate keys -> Secure Boot Violation) `:265-271`; MSI needs "Image Execution Policy =
  Deny Execute" `:276-279`. It explicitly warns that enrolling can require a BitLocker recovery key and make a
  TPM-bound LUKS disk ask for its passphrase `:273-275`. Entering Setup Mode: `systemctl reboot --firmware-setup`
  with keys deleted/reset, Secure Boot left disabled `:257`, `:293-297`.
- Outside Setup Mode with existing keys: `sbctl enroll-keys --append --partial db --custom --ignore-immutable`
  and a failure message telling the user to return to Setup Mode `:284-291`.
- Signing: `sign_file()` = `sbctl sign -s` + verify with `sbverify --cert /var/lib/sbctl/keys/db/db.pem`
  `:305-309`, `:21-22`; kernels are `/boot/vmlinuz-*` from `find` `:311-318`; systemd-boot / rEFInd / Limine
  loaders at `:357-372`.
- Files that must keep **exactly one** CachyOS signature (EAC kernel, signed systemd-boot at
  `/usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed`) are removed from sbctl's DB and reinstalled from
  packages `:208-213`, `:374-421`; `eac-status` counts signatures with `sbverify --list | grep -c '^signature'`
  `:91-106`.
- No shim in this flow: trust comes from keys in firmware `db`, and CachyOS's signed systemd-boot for EAC
  (`eac-setup:423-449`). `garuda-systemd-boot/uki.conf:4-7` says UKI Secure Boot signing is "not set up yet"
  (only a commented example), so it is not a second implementation.

## 2. Risks and how the two projects mitigate them

| Risk | What can happen | Mitigation seen in the files |
|---|---|---|
| Bricked boot: firmware enforces signatures but GRUB/kernel is unsigned | "bad shim signature"/Secure Boot violation, no GRUB menu | Garuda queues MOK and tells the user to enable SB only after reboot and to finish MOK enrollment (`garuda-secureboot:218`); it checks GRUB exists and shim/fallback copies match before touching NVRAM (`:141-160`); CachyOS verifies every signed file with `sbverify` and re-runs setup idempotently (`eac-setup:305-309`, `:3-8`). |
| Locked-out LUKS | If GRUB or its disk-crypto modules are unsigned/missing, the passphrase prompt never appears; re-enrolling keys or adding TPM binding can also change what is required to unlock | CachyOS warns *before* enrolling that TPM-bound LUKS may ask for a passphrase (`eac-setup:273-275`). Sunshine installs **LUKS1** with `GRUB_ENABLE_CRYPTODISK=y` and `/boot` inside the encrypted root (`sunshine-install:176-181`, `:232-237`, `:316-320`), so GRUB needs `cryptodisk`/`luks`/`gcry_*` modules available at boot; Garuda's `--modules` list (`garuda-hooks-runner:102-111`) is the mitigation pattern. |
| Firmware rejects keys / breaks dual boot | Wrong key set, duplicate keys, or dropping MS keys stops Windows or the current loader | `enroll-keys --microsoft` keeps MS trust (`eac-setup:245-283`); skip `--firmware-builtin` on ASUS/Gigabyte, MSI policy note `:265-279`; read back enrolled keys with `sbctl export-enrolled-keys` and compare certificates (`eac-setup:221-243`, `eac-status:72-89`); `sbctl-batch-sign:24-31` never re-signs MS files. |
| Kernel/GRUB updates leave files unsigned | Next boot fails after a routine `pacman -Syu` | Garuda's pacman hooks always reinstall+sign GRUB when the flag is set (`grub-install.hook:1-9`, `garuda-hooks-runner:83-141`) and rebuild initramfs (`90-mkinitcpio-install.hook`); CachyOS's `sbctl sign -s` puts files in sbctl's DB so they are re-signed on updates (`eac-setup:380-381`) and `sbctl-batch-sign` sweeps everything `sbctl verify` flags. |
| Signature collisions | A vendor file that must carry only one signature gets a second one and is rejected (EAC) | `sbverify --cert` skip in `sbctl-batch-sign:32-35`; `sbverify --list` count + removal from sbctl DB in `eac-setup:374-421`. |

## 3. Proposed `sunshine-secureboot` (design only, no code written)

Base design: **sbctl with our own keys in firmware `db`, no shim** (avoids depending on `shim-signed` and a MOK
password). Keys live in sbctl's default `/var/lib/sbctl/keys` (`eac-setup:21-22`). Our own flag
`/etc/sunshine/secureboot/enabled` gates hooks, mirroring Garuda's flag. Packages needed: `sbctl`,
`sbsigntools`, `grub`, `efibootmgr`, `mokutil` (only for `status` on shim-based systems).
Sign **before** enrolling; enroll last. Keep Microsoft keys (`-m`) so dual boot survives.

### 3.1 Subcommands and exact commands

- `status` (read-only; run as root so `sbctl` can read all files): test `-d /sys/firmware/efi`; `sbctl status`; `mokutil --sb-state`
  if available; `sbctl verify`; `findmnt -no SOURCE /boot/efi`; print flag state and each unsigned file.
  Read Setup Mode from `/sys/firmware/efi/efivars/SetupMode-8be4df61-93ca-11d2-aa0d-00e098032b8c`
  (byte 5, as in `eac-setup:81-87`).
- `setup` (root, UEFI, ESP mounted; require Setup Mode; refuse if keys already exist unless `--force`):
  1. `sbctl create-keys`
  2. Build the module list from `awk '/insmod ([^ ]+)$/ {print $2}' /boot/grub/grub.cfg` **plus** a default
     list including `all_video btrfs cat configfile cryptodisk luks gcry_rijndael gcry_sha256 ext2 echo font
     gettext gfxterm keystatus loadenv loopback linux ls minicmd normal part_gpt probe reboot search
     search_fs_uuid search_label sleep test video` (Garuda pattern `garuda-hooks-runner:102-109`; extend for
     our LUKS1 setup), keep only modules present in `/usr/lib/grub/x86_64-efi/*.mod`.
  3. `grub-install --no-nvram --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=SunshineOS --recheck --modules "<list>" --disable-shim-lock --sbat /usr/share/grub/sbat.csv`
     (`--no-nvram`, `--modules`, `--sbat` verified in Garuda; `--disable-shim-lock` is required when GRUB is
     signed with our db key and no shim is loaded — known GRUB behaviour; without it GRUB's shim_lock verifier
     would call a shim that is not present). Also do the `--removable` install to keep the fallback
     `EFI/BOOT/BOOTX64.EFI` (Sunshine already installs both, `sunshine-install:324-325`).
  4. `sbctl sign -s /boot/efi/EFI/SunshineOS/grubx64.efi`; `sbctl sign -s /boot/efi/EFI/BOOT/BOOTX64.EFI`;
     `for f in /boot/vmlinuz-* ; do sbctl sign -s "$f"; done` (kernel pattern from `eac-setup:311-318`).
     The GRUB config is `/boot/grub/grub.cfg` (`sunshine-install:330`), inside the encrypted root; it is not
     PE-signed and is read only after GRUB unlocks LUKS.
  5. **Kernel verification needs an explicit choice.** With shim (Garuda's design) the `shim_lock` verifier in
     GRUB checks kernel PE signatures via shim, so signing the kernel with the same MOK/db key is enough. In
     our no-shim design there is no shim to call; passing `--disable-shim-lock` makes GRUB load the signed
     kernel without verifying it, so firmware trust stops at GRUB. To check the kernel too, GRUB's own GPG
     verification (`check_signatures=enforce` + `trust`) must be configured, and the GPG public key must be
     available before any unverified file is read — that is exactly when a **custom `core.img` with an
     embedded pubkey** is needed (`grub-mkimage --pubkey=<file>` is a **GUESS** for the exact option in our
     GRUB version). Alternative: keep shim and drop `--disable-shim-lock` (then use `shim-signed` + MOK as
     Garuda does). Decide this before implementation; the rest of this design assumes no shim.
  6. **Kernel modules are not signed with the db key by default.** The kernel checks module signatures against
     its own built-in keyring, not Secure Boot `db`, so `sbctl sign -s` on a `.ko` does not authorize it
     (certain Linux behaviour). Stock Arch modules are signed by the kernel package; DKMS modules need a key
     the kernel trusts (custom `CONFIG_MODULE_SIG_KEY` or, **GUESS**, shim's MOK on kernels that import it).
     Offer `sign --modules` only when the user points to a kernel key, and document that DKMS/virtualbox/nvidia
     modules are the main failure case.
  7. `sbctl enroll-keys -m` (or `sbctl enroll-keys` for an MS-free system); refuse if not in Setup Mode.
     Verify: `sbctl status`, `sbctl verify`, `sbctl export-enrolled-keys --dir <tmp>` and compare our db cert.
     Print: enable Secure Boot in firmware, reboot, confirm GRUB + LUKS prompt.
- `sign`: re-sign after updates: `sbctl sign-all`; `sbctl verify | awk '/✗/ {print $2}'` then
  `sbctl sign -s <entry>` on new unsigned files (CachyOS pattern, `sbctl-batch-sign:23-36`), skipping
  Microsoft/Windows/`*.mui`/`*.dll` and vendor-signed files (`sbverify --cert <vendor-ca>`).
  Re-run step 2-4 of `setup` (with `--no-nvram`) when `grub` was upgraded, so `core.img` always contains the
  modules needed by the new config; keep fallback copies identical as in `garuda-hooks-runner:100`,`:119-125`.
- `enroll`: only `sbctl create-keys` (if missing) + `sbctl enroll-keys -m`, guarded by Setup Mode; used to
  finish `setup` after an interrupted run or after clearing firmware keys. Never append keys silently: outside
  Setup Mode require explicit `--append` and use `sbctl enroll-keys --append --partial db --custom --ignore-immutable`
  (`eac-setup:284-291`) with a consent prompt.
- `disable`: remove the flag file; re-run plain `grub-install --no-nvram --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=SunshineOS --recheck` if the user wants a non-SB GRUB; **keep keys and signed
  files**; print instructions to turn Secure Boot off in firmware (a software flag cannot change firmware state).
  Do not delete keys here — that would make a later re-enable unbootable.
- `undo`: full rollback, interactive consent: `disable`, remove our NVRAM entry (via `efibootmgr -b <id> -B`
  after `efibootmgr` parse as in `garuda-secureboot:60-87`,`:202-209`), `sbctl remove-file <each>` for files in
  `sbctl list-files`, then delete `/var/lib/sbctl/keys` (back it up first). If firmware keys are enrolled,
  `undo` must say that they can only be removed in Setup Mode/firmware setup and cannot be deleted from Linux
  (same limitation as Garuda's MOK).
- Global `--dry-run`: print every command that would run (including the generated `--modules` list) and make
  no writes; `status` is always read-only. Commands that only read state (`findmnt`, `sbctl verify`, `find`,
  efivar reads) still run so the plan is accurate.

### 3.2 Pacman hook (re-sign after kernel/GRUB updates)

`/usr/share/libalpm/hooks/99-sunshine-secureboot.hook`:

```
[Trigger]
Operation = Install
Operation = Upgrade
Type = Path
Target = usr/lib/modules/*/vmlinuz
[Trigger]
Operation = Upgrade
Type = Package
Target = grub
[Action]
Description = Re-sign Sunshine OS boot files for Secure Boot
When = PostTransaction
Exec = /usr/local/bin/sunshine-secureboot sign --hook
```

`sign --hook` must exit 0 immediately when `/etc/sunshine/secureboot/enabled` is absent or Setup Mode is
enabled, so it is harmless before `setup`; otherwise run the `sign` steps above and log to
`/var/log/sunshine-secureboot.log`. This is the union of Garuda's `grub-install.hook` + `update-grub.hook` and
CachyOS's "sbctl re-signs its DB" behaviour.

### 3.3 Rollback path (firmware refuses the keys / boot fails)

1. Do not keep retrying: reboot into firmware setup (Esc/F2 in a VM; `systemctl reboot --firmware-setup` on a
   running system) and either disable Secure Boot or clear/reset Secure Boot keys (Setup Mode). Our
   `--removable` fallback entry boots `EFI/BOOT/BOOTX64.EFI` independently of NVRAM.
2. If the machine still boots via another OS or the live ISO, run `sunshine-secureboot status` and
   `sunshine-secureboot sign`; re-check with `sbctl verify` **before** rebooting.
3. If GRUB will not start at all: boot the Sunshine live ISO and use `sunshine-rescue mount` +
   `sunshine-rescue run -- sunshine-secureboot sign` (the rescue helper exists in this repo:
   `profile/airootfs/usr/local/bin/sunshine-rescue`), or `sign --force-grub` to redo step 3.1.2/3.1.3 with the
   module list, then sign. As a last resort run `sunshine-secureboot undo` in the chroot.
4. LUKS: keep the passphrase and a `cryptsetup luksHeaderBackup` outside the disk; the initramfs keyfile
   (`sunshine-install:232-237`) only helps once GRUB and the kernel have started. Verify the passphrase prompt
   still appears in the VM before enabling firmware enforcement.
5. Always keep the previous kernel and its signed copy until the new kernel has booted once (Garuda-style
   fallback copies and content checks, `garuda-hooks-runner:96-125`).

### 3.4 VirtualBox/OVMF test matrix

VM setup: enable EFI (OVMF) in the VM settings; install Sunshine normally (LUKS1 + btrfs/ext4 as chosen).
To put the VM firmware in **Setup Mode**: boot to the firmware UI (Esc/F2 at power-on), open
Security → Secure Boot and choose "Reset/Delete Secure Boot Keys" (clears PK/KEK/db; leave Secure Boot
disabled), save and reboot; `sbctl status` must then report `Setup Mode: Enabled` and `Secure Boot: Disabled`
(the exact VirtualBox UI labels are **GUESS**; the efivar/GUESS alternative is deleting the PK/KEK/db efivars
from Linux with `chattr -i` then rebooting — verify on the actual VirtualBox OVMF build).

| # | Test | Pass condition |
|---|---|---|
| 1 | Fresh install, `status` | UEFI detected, keys absent, SB off, module list non-empty |
| 2 | `setup --dry-run` | No files/keys/NVRAM changed; exact commands printed |
| 3 | `setup` in Setup Mode, then `status` | Keys created, all `sbctl verify` entries signed, flag set |
| 4 | Enable SB in firmware and reboot | GRUB menu, LUKS passphrase prompt, desktop; `sbctl verify` clean |
| 5 | `sbctl status` after reboot | `Secure Boot: Enabled`, `Setup Mode: Disabled` |
| 6 | Install/upgrade `linux` (hook runs) | New `/boot/vmlinuz-*` signed, hook log written, reboot works |
| 7 | Upgrade `grub` (hook runs) | `core.img` rebuilt with modules incl. crypto, both GRUB copies signed |
| 8 | Simulate missed signing (`sbctl remove-file` + upgrade) | Boot shows SB violation; rollback §3.3 restores boot |
| 9 | Dual boot with Windows present, `enroll -m` | Windows Boot Manager still boots |
| 10 | After `undo` + SB still on | Expected failure; after SB off, unsigned GRUB boots |
| 11 | Vendor-pre-signed file present | Not double-signed (`sbverify --list` count = 1) |
| 12 | DKMS module (e.g. virtualbox-guest) with SB on | Module loads or tool reports "kernel-trusted key required" |

## 4. Open questions / not verified here

- How Garuda's `garuda-dracut-support` signs kernels and initramfs (not in the read tree).
- Whether CachyOS invokes `sbctl-batch-sign` from a pacman hook (not found in the read tree).
- Exact `grub-mkimage` option for embedding a GPG public key into a custom `core.img` (**GUESS**: `--pubkey=`)
  and the exact `check_signatures=enforce`/`trust` syntax for current GRUB (**GUESS**). Needed only if we
  choose no-shim **and** require GRUB to verify the kernel; a self-contained `--modules` core.img alone only
  guarantees GRUB itself loads. The shim alternative avoids this.
- Whether stock Arch/Sunshine kernels import shim MOK for module verification (**GUESS**: no); test #12 decides.
- VirtualBox OVMF Setup Mode UI labels and whether efivar deletion works there (**GUESS**).
