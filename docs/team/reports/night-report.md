# Night report 2026-11-19 (senior developer, until 12:00)

## Goal (from the owner)
Make Sunshine OS good enough that professionals pick it over EndeavourOS, gamers over Garuda, ordinary users over Ubuntu: real-user tests (install, packages, tools),
break the system on purpose and repair it with the doctor, check performance, take the best ideas from EndeavourOS / Garuda / CachyOS, a tools repository that
`sunshine-update` pulls from, live-session repair.

## What was built (all on branch team/night-run, merged into main at the end)
| Area | Result |
|---|---|
| Live-session repair | `sunshine-rescue`: finds installed systems (LUKS, btrfs, ext4, XFS, f2fs), mounts like fstab, repairs boot/kernel/initramfs/packages/fstab, passwords, fsck with consent, SMART gate, log kept on the repaired system; button in Welcome + desktop icon |
| Health and repair | `sunshine-doctor` 35+ checks incl. every kernel, core packages, repos, partial upgrade, boot menu, microcode, DKMS, SMART, sudoers, DNS; rescue mode; restore point before `--fix`; weekly silent scan -> tray widget; `sunshine-fix` (network/audio/display/gpu/storage), `sunshine-reset-plasma`, `sunshine-support` |
| Updates | `sunshine-toolsync` + repo github.com/tak0dan/sunshine-tools (signed manifest, SHA-256, no downgrade, rollback); `sunshine-migrate` (5 migrations); `sunshine-pacnew`; update: keyring first, news check, smart retry by failure reason, nvidia/kernel sync check, snapshot-boot guard |
| Hardware and games | `sunshine-drivers` (NVIDIA prebuilt/open/NVK, Broadcom, laptop, VM tools), `sunshine-kernel`, `sunshine-performance` (CachyOS-style tuning), `sunshine-gaming`, `sunshine-game-run`, `sunshine-desktops` (15 desktops/WMs), `sunshine-backup` (restic), read-only `sunshine-secureboot` |
| Installer/boot | safe-graphics boot entry, 4 GB live overlay, installer registers sunshine-base, VM guest service, Plasma default session, no 2-minute network wait, Desktops group, printing/scanning/firewall GUI packages |

## Real tests and what they found
(see docs/team/log/senior.md for the timeline) Fast ISO installed in VirtualBox (btrfs, UEFI): installer OK, boots to the login screen. Real rescue runs on the installed system. Smoke test of all tools: 29/30.
Bugs found by running things (all fixed): 2 min boot delay (systemd-networkd-wait-online), sunshine-base not registered by the CLI installer, no VM guest service, false positives (SMART, pacman -Qq),
doctor behaving as "live" inside the rescue chroot, partial-upgrade heuristic, tool modes in the tools release (644), desktops not visible at the login screen, UFW blocking test ssh (intended), support-report sanitizer.

## Performance (installed system in a VM, login screen)
Boot before fix: 2 min 35 s (userspace 2 min 26 s). After: 34 s (kernel 4.7 + initrd 8.8 + userspace 20.7). RAM 556 MB of 3.9 GB used, 23 services, 188 processes, BFQ/mq-deadline schedulers.

## Team
senior (tak-2f), tak-7a (break-repair harness with 34 scenarios, reviews, research, site cards), tak-0 (desktop PC: review/docs tasks), opencode workers (lint, translate, docs draft, comparison, secure-boot design, README.uk),
ChatGPT and Grok answered the same 5-part design prompt (Gemini was not logged in); comparison in docs/team/research/ai-comparison.md.

## Releases and final verification
- **Sol 1.5** (13.4.7.1.5, Release, 2026-11-19, zstd-15 image 3.5 GB, sha256 9cb5bc4c...): installed in a VM (btrfs), booted (47 s with another VM competing, 0 failed units), smoke test 28/30 (the 2 are stale-marker and ICMP findings, both fixed in tools delivered by `sunshine-update`),
  then a real update `sunshine-base` 0.6 -> 0.7 through normal pacman. The ISO before it (ext4 install) also passed; installer fixes verified on both. Published; the website shows it; Sol 1.4 marked superseded.
- **Sirius 0.3** (Testing): live session 69/69 checks, Nix and `sunshine-declare` present. Published as a Testing release.
- `[sunshine]` repository: sunshine-base 0.7 with all new tools (signed), desktops metapackages; tools repository version 2026.11.19.197.
- Break-and-repair harness (tak-7a): 24 of 34 scenarios run before the host disk ran out: 17 pass; gaps found were fixed afterwards (EFI mount, cache cleanup, corrupt cache package, clock wait); scenarios 25-34 not run (docs/team/reports/break-repair-results.md).

## Known limits / next steps
Secure Boot tool (design only), Calamares GUI install was not clicked through (CLI installer tested; GUI config changed only by "ask before installing" and the shared post-install fixes), USB/Ventoy boot of the final ISOs not re-tested tonight,
the 12 installer proposals (docs/team/reports/installer-proposals), 10 break scenarios not run, fastfetch/hyfetch logo PRs prepared but not submitted (need the owner's go), the host disk is nearly full (VM disks were deleted; old ISOs in ~/sunshineos-build/isos left untouched).
