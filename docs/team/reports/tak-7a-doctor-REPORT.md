# Doctor gaps: design and patch (worktree agent/tak-7a-doctor)

No source file was changed. The patch is a proposal only; it has not been applied to
`profile/airootfs/usr/local/bin/sunshine-doctor`.

## What I did

I read `profile/airootfs/usr/local/bin/sunshine-doctor` (all 198 lines),
`docs/team/research/tak-7a-NOTES.md`, `docs/team/breakage-catalogue.md`, and the
twelve requested scenarios `03 04 05 09 10 11 17 18 19 22 24 26` under `test/break/`.
I also read `test/break/08-vmlinuz-deleted.sh` and four existing hook files
(`98-sunshine-state.hook`, `90-sunshine-identity.hook`, `94-sunshine-migrate.hook`)
and `profile/airootfs/usr/local/bin/sunshine-state-hook` for style. I did not read any
other file and make no claim about it.

I made a scratch copy at `/tmp/doctor-edit.sh` (the path the task named), edited only
that copy, produced one unified diff from it, and rewrote the two diff headers to
`a/profile/airootfs/usr/local/bin/sunshine-doctor` and
`b/profile/airootfs/usr/local/bin/sunshine-doctor`.

All new messages are short fixed English strings like the existing ones; no message
of an existing check was changed. Every new automatic repair is guarded by
`[ $FIX = 1 ]` and is idempotent (remove-then-refetch, copy the same file again,
`--needed`, `enable --now`, `set-ntp true`).

## Files changed or created in this worktree

* `docs/team/reports/doctor-gaps.patch` (created) — one unified diff, 118 lines, six hunks.
* `docs/team/reports/96-sunshine-partial-upgrade.hook` (created) — proposed libalpm hook.
* `REPORT.md` (created) — this file, including the helper script as a heredoc below.

Nothing else in the worktree was added, modified or deleted. `/tmp/doctor-edit.sh` is
only a scratch file outside the worktree and is not part of the commit.

## New and changed checks, with the scenario they address

| Item | Check / message | Repair under `--fix` | Scenario |
|---|---|---|---|
| (a) sync databases | `sync database missing or damaged:<repo>`; also `sync databases are readable`. Uses `pacman-conf --repo-list` plus every existing `*.db`, and `bsdtar -tf` on each. | `rm -f` each bad `*.db`, then `pacman -Sy --noconfirm`; `fx "sync databases refreshed"` | **03, 04** (03 `expect_detect` `sync (database\|db)`; 04 `bsdtar -tf core.db`) |
| (b) required/unknown repos | `pacman.conf does not list [core] repository` / `[extra]`; `unknown repository [<name>] in pacman.conf (checked, not removed)`. `[options]` and `core extra multilib sunshine chaotic-aur` are ignored; unknown repos are only warned about, never deleted. | none | **05** — the warning matches `community\|repositor(y\|ies)`. Note: the pre-existing obsolete-repo line already matched this scenario's `expect_detect`; this adds the explicit unknown-repo warning asked for. |
| (c) GRUB menu content | `GRUB menu has entries` / `/boot/grub/grub.cfg has no menu entries` (`grep -q menuentry`). The old existence check is untouched. | `grub-mkconfig -o /boot/grub/grub.cfg`; `fx "GRUB menu rebuilt"` | **09** (`grep -q menuentry /boot/grub/grub.cfg`) |
| (d) kernel image content | `kernel image matches module: <base>` / `/boot/vmlinuz-<base> differs from the installed kernel`, using `cmp -s` against `/usr/lib/modules/<version>/vmlinuz`. | re-copy the module image with the same flags as the existing copy and `chmod 644`; `fx "vmlinuz-<base> restored from module"` | No `test/break/` file exercises a *present but corrupt* image. It covers the case called "scenario 28 to add" in `tak-7a-NOTES.md`. Scenario **08** (image deleted) is still handled by the unchanged original line. |
| (e) required packages | `required packages missing:<list> (login manager, network service, sudo, base)` for `sddm`, `networkmanager`, `sudo` and `pacman -Sgq base` members. | `pacman -S --needed --noconfirm <missing>`; `fx "required packages installed:<list>"` | **10** (`sddm`), **11** (`network service` in the fixed suffix; `networkmanager` in the list). `sudo` is included as the task requires. I did not read `test/break/12-remove-sudo.sh`, so I make no claim about it. |
| (f) mkinitcpio HOOKS | `mkinitcpio hook <hook> has no install file` when neither `/usr/lib/initcpio/install/<hook>` nor `/etc/initcpio/install/<hook>` exists; `mkinitcpio hooks have install files` otherwise. | **none** — warn only, never edits `mkinitcpio.conf` | **17** for detection (`mkinitcpio\|hook`); see "Cannot do / decisions". |
| (g) partial upgrade | `partial upgrade detected: a full upgrade is needed` when `/var/lib/sunshine/partial_upgrade` exists; `no partial upgrade pending` otherwise. | `pacman -Syu --noconfirm`, then remove the flag; `fx "full upgrade applied"` on success, otherwise a `bad` line | **26** (`DETECT_ONLY`, `partial upgrade`) |
| (h) clock | Original warning string is unchanged; a repair was added to that same check. | `timedatectl set-ntp true`; `fx "network time enabled"` | **22** (`clock is not synchronised`) |
| (i) NetworkManager | Original warning string is unchanged; a repair was added to that same check. | `systemctl enable --now NetworkManager`; `fx "network service started"` | **19** (`NetworkManager is not running`) and **11** (also `systemctl is-enabled NetworkManager`) |
| (j) root disk >= 95% | Original `root disk <n>% full` line is unchanged; cleanup was added to that branch. | `paccache -rk1` and `journalctl --vacuum-size=200M`; measures avail bytes before/after and prints `freed <n> MB` | **18** (`root disk .*% full`); see "Cannot do / decisions". |

Scenario **24** (`.pacnew`) needs no new check: the unchanged existing
`$n config update(s) waiting for review (*.pacnew)` line already matches its
`expect_detect`, and it is `DETECT_ONLY`.

## The pacman hook and the script it runs

`docs/team/reports/96-sunshine-partial-upgrade.hook` (created) follows the shape of
`profile/airootfs/usr/share/libalpm/hooks/98-sunshine-state.hook`: package
Install/Upgrade/Remove, `Target = *`, `When = PostTransaction`, `Exec` the helper
below. The task asked for the helper to be supplied as a heredoc in this report, so
no script file was created in the worktree. The proposed install path is
`/usr/local/bin/sunshine-partial-upgrade-hook`; the proposed hook install path is
`profile/airootfs/usr/share/libalpm/hooks/96-sunshine-partial-upgrade.hook`.

```sh
cat > /usr/local/bin/sunshine-partial-upgrade-hook <<'EOF'
#!/usr/bin/env bash
# pacman hook helper (the idea is Garuda's): after every transaction, record what sunshine-doctor needs to know without guessing later.
#   /var/lib/sunshine/partial_upgrade   exists when pacman -Qu still lists packages (a partial upgrade)
#   /var/lib/sunshine/last_update       touched when there is nothing left to upgrade
mkdir -p /var/lib/sunshine
if [ -n "$(pacman -Qu 2>/dev/null)" ]; then
  touch /var/lib/sunshine/partial_upgrade
else
  rm -f /var/lib/sunshine/partial_upgrade
  touch /var/lib/sunshine/last_update
fi
exit 0
EOF
chmod 755 /usr/local/bin/sunshine-partial-upgrade-hook
```

The heredoc content was not written to a file or executed here; it is a proposal.

## Verification actually run

Run from the worktree root unless noted:

* `bash -n /tmp/doctor-edit.sh` -> exit 0.
* `PATH=/home/tak/.local/bin:$PATH shellcheck -S warning /tmp/doctor-edit.sh` -> exit 0, no output. The unpatched original also gave exit 0, so the patch adds no new warnings at that level.
* `git apply --check docs/team/reports/doctor-gaps.patch` -> exit 0 (one patch, applies cleanly to the current source file).

## What I could not do

* I did not run `git apply` for real, and did not change the doctor itself: this task is design/patch only.
* I did not run any virtual machine, test harness, network command, `pacman`, `sudo`, `systemctl`, `docker`, `VBoxManage`, `mount` or a download; those are forbidden here. So no scenario was executed and no repair command was executed.
* Consequently I cannot claim that scenario 17's `verify()` passes: it runs a real `mkinitcpio` build, which will still fail while the bad hook remains in `mkinitcpio.conf`. The patch deliberately only warns there.
* I cannot claim that scenario 18's `verify()` (`< 90%` used) passes: `paccache -rk1` keeps one version of each package, and the scenario fills the cache with three differently named fake packages, so those files may survive. The patch does exactly the two cleanup commands the task specified and reports MB freed; it never deletes user or cache files by name.
* I did not validate hook execution or the helper script at runtime (no pacman transaction was run).

## Things the senior developer must decide

1. Keep (f) warn-only, or add an opt-in fix that edits `HOOKS`? Scenario 17's `verify()` cannot pass with warn-only, but the task forbids editing `mkinitcpio.conf` automatically.
2. Is `paccache -rk1` + `journalctl --vacuum-size=200M` enough for scenario 18, or should the fix also call an existing cleanup tool (the scenario names `sunshine-cleanup` as `repair_alt`)? I did not read that tool, so I did not wire it in.
3. Approve installation of the new hook and helper into `profile/airootfs` (they are currently design artifacts under `docs/team/reports/` only), and confirm the two proposed paths.
4. Confirm that a full `pacman -Syu` under `--fix` for (g) is acceptable in a non-interactive doctor; the notes propose it, but it is the most invasive repair added here.
5. Confirm the fixed known-repository list `core extra multilib sunshine chaotic-aur` and that unknown repos stay a warning rather than a failure.
6. (e) relies on the Arch install scripts to enable `sddm.service` and `NetworkManager.service` after reinstall; (i) explicitly enables NetworkManager, but nothing in this patch explicitly enables `sddm`. Decide whether to add `systemctl enable sddm` to the (e) fix for scenario 10's `systemctl is-enabled sddm`.
