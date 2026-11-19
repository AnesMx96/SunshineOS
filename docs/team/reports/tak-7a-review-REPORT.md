# REPORT — sunshine-rescue code review (tak-7a, 2026-11-19)

## What I did

Read all 217 lines of `overlay/system/usr/local/bin/sunshine-rescue` and reviewed it by reasoning with the three requested concrete inputs (ext4 `/dev/sda2` + EFI `/dev/sda1` at `/boot/efi`; btrfs `/dev/nvme0n1p2` with `@`/`@home` + EFI at `/boot/efi`; LUKS1 `/dev/sda3` opened as `/dev/mapper/sunshine-luks-sda3` with btrfs inside). Ran the two required static checks on the original: `bash -n` (exit 0) and `shellcheck -S warning` with `/home/tak/.local/bin` on PATH (exit 0, **no warnings**). Also ran plain `shellcheck` to inspect all severities: only SC2015/SC1091 (info) and SC2005 (style) appear; each is explained in the review.

Wrote a line-by-line review with 14 numbered critical/high/medium findings (each with exact line numbers, a quote, why it is wrong, a concrete failing scenario and a minimal unified-diff fix), lower-severity observations, the three example walkthroughs, an inventory of every message and of all 15 `arch-chroot` call sites. The most serious issues are: `fsck` on a still-mounted filesystem (critical); closing every LUKS mapping instead of only our own; unmount and repair steps that report false success; no Ctrl-C/SIGTERM trap; an fstab mount loop in a pipe subshell whose errors are lost; BIOS GRUB installed to the root disk without a whole-disk check; and sourcing a target's `/etc/os-release` as root.

Built the requested patch by copying the original to `/tmp/rescue-edit.sh`, editing only that copy, running `diff -u`, and rewriting the header paths. Verified `git apply --check` succeeds, and that the edited copy passes `bash -n` and `shellcheck -S warning`. Committed the three new files on branch `agent/tak-7a-review`. No source file was modified.

## Files changed or created

* `docs/team/reports/rescue-review.md` — created: full review (findings 1–14, low-severity notes, static-check explanations, example walkthroughs, message/`arch-chroot` inventories, verification, decisions).
* `docs/team/reports/rescue-fixes.patch` — created: one valid unified diff against `overlay/system/usr/local/bin/sunshine-rescue`, applying all critical, high and medium fixes (202 lines). `git apply --check` passes.
* `REPORT.md` — created: this file.

No other files were created, modified or deleted. `overlay/system/usr/local/bin/sunshine-rescue` is unchanged in the worktree. `/tmp/rescue-edit.sh` and `/tmp/osr-test` were temporary helper files outside the worktree, created only as instructed for the diff and a `sed` parser test.

## What I could not do

* Run `sunshine-rescue`: it needs root, real disks, a live ISO and tools such as `cryptsetup`, `mount`, `e2fsck`, `btrfs`, `grub-install` and `arch-chroot`. I did not use sudo, mount, pacman, systemctl, docker, VM software or the network.
* Test actual mount/LUKS/fsck/GRUB/chroot behaviour or boot the patched script; all scenarios are static reasoning.
* Check `/usr/local/lib/sunshine/ui.sh` (it is an ISO overlay path not present in this worktree), so I cannot confirm exact `loc`/`ok`/`bad`/`sec` output strings; the review discusses the message text passed to them.
* Resolve the functional gaps listed as low severity (e.g. corrupt-but-present `vmlinuz`, btrfs `@boot` discovery, fstab auto-rewrite): they are documented but not patched.
* No git push, no docker/VM, no changes outside this worktree (except the explicitly requested `/tmp/rescue-edit.sh` copy and the tiny `/tmp/osr-test` parser test).

## Decisions for the senior developer

1. LUKS cleanup policy: the patch closes only mappings opened by this tool (recorded under `/run/sunshine-rescue/luks`); stale mappings from a killed run are no longer auto-closed.
2. `noauto`/`x-systemd.automount` fstab entries are now mounted during rescue (needed for a `noauto` `/boot` or ESP); confirm this is wanted instead of skipping them.
3. Lazy unmount is kept as a fallback but now warns and returns failure; confirm whether a busy mount should be a hard error.
4. `nofail` missing devices are no longer counted as failures, but wrong UUIDs are still only reported, not fixed; decide whether `sunshine-rescue` should rewrite fstab.
5. `e2fsck -fy` and `pacman -S --noconfirm` still act without consent; decide whether to add confirmation.
6. btrfs discovery still covers only `@`, `root`, `rootfs`; supporting `@boot`, snapshot boot layouts and root mount options needs design work.
