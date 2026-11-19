# REPORT — tak-7a-perf (research + patch proposal)

Branch: `agent/tak-7a-perf`, worktree `/home/tak/sunshineos-build/agents/wt-tak7a-perf`.

## What I did

1. Read both Sunshine tools in full before writing anything:
   - `overlay/system/usr/local/bin/sunshine-performance:1-114` (sysctl, zram, udev, earlyoom, ananicy, journal/timeouts, makepkg, status, bench).
   - `overlay/system/usr/local/bin/sunshine-gaming:1-70` (GPU PCI-vendor package choice, Steam/Gamemode/MangoHud/Lutris/Wine, tuning).
   - Also read `overlay/system/usr/local/bin/sunshine-game-run:1-12` to answer the helper-script question with evidence.
2. Read every CachyOS performance/gaming file named in the task, all udev rules found with `find` (including `usr/lib/udev/rules.d/*`), all `usr/lib/tmpfiles.d/*`, `usr/lib/modprobe.d/*`, `usr/lib/modules-load.d/*`, the systemd conf/generators/services, all `usr/bin` scripts, and the udev helpers `usr/lib/udev/audio-pm-ctl` and `usr/lib/iw-set-regdomain`. Every citation in the research doc carries `file:line`.
3. Read Garuda `garuda-common-settings` sysctl/systemd/tmpfiles/udev/modprobe files, `g-pkgbuilds/performance-tweaks`, `g-pkgbuilds/garuda-common-settings`, `powersave-tweaks`, `garuda-hardware-profiles` (NVIDIA modprobe/udev files), `garuda-update/auto-pacman:23`, and the sysctl file in `garuda-blackarch`. Used `ls` on `/home/tak/sunshineos-build/research/g-pkgbuilds`: no `garuda-gamer`, no ananicy package directory.
4. Wrote the comparison with a full setting table, ranked top 15, hurt/guard matrix and step-by-step helper analysis: `docs/team/research/tak-7a-perf-compare.md`.
5. Wrote **one** unified diff proposal, `docs/team/reports/perf-gaming.patch`, with rewritten headers `a/overlay/system/usr/local/bin/sunshine-performance` and `b/overlay/system/usr/local/bin/sunshine-performance`. I edited only the copy `/tmp/perf-edit.sh` and generated the diff against the untouched source. No existing source file was changed.
6. The patch adds only settings I rated safe and valuable: guarded larger zram pool (`docs/team/reports/perf-gaming.patch:19-26`), `fs.file-max`, CFS slice and TCP fin timeout (`:36-39`), system/user timeout abort (`:51-52`), coredump age (`:54-55`), THP shrinker behind a sysfs-existence check (`:64-66`), HDD/USB writeback caps (`:76-79`), and new-file cleanup in `off()` (`:88-89`). It also disables `fstrim.timer` in `off()` (`:92`) so the service state is symmetric.
7. Proofs run from the repository root, all with exit status 0:
   - `git apply --check docs/team/reports/perf-gaming.patch` → OK.
   - `bash -n /tmp/perf-edit.sh` → OK.
   - `shellcheck -S warning /tmp/perf-edit.sh` with `/home/tak/.local/bin` on PATH → OK (the unpatched source is also clean at warning level).
   - Applying the patch to a temporary copy reproduced `/tmp/perf-edit.sh` byte for byte (`cmp` OK).
   - Baseline `shellcheck -S warning overlay/system/usr/local/bin/sunshine-performance` was also clean.

## Every file changed or created

| path | status | note |
|---|---|---|
| `docs/team/research/tak-7a-perf-compare.md` | created | research report required by the task. |
| `docs/team/reports/perf-gaming.patch` | created | patch proposal only; not applied to any source. |
| `REPORT.md` | created | this file. |
| `/tmp/perf-edit.sh` | created outside the repo | working copy used to generate the diff; not committed. |
| `overlay/system/usr/local/bin/sunshine-performance` | **unchanged** | diff was generated against it, never applied. |
| `overlay/system/usr/local/bin/sunshine-gaming` | **unchanged** | read only. |

No other file in the worktree was added, edited or deleted by me.

## What I could not do

- No VM, Docker, ISO install, `pacman`, `sudo`, `systemctl`, `mount` or network access was used (all forbidden by the task), so I could not verify runtime behaviour of the new sysctl keys, udev rules or tmpfiles on a live system. All checks are static (`git apply --check`, `bash -n`, shellcheck) plus source reading.
- `/home/tak/sunshineos-build/research/g-pkgbuilds` has no `garuda-gamer` directory and no ananicy package directory; I only found references (`g-pkgbuilds/garuda-update/auto-pacman:23`, `g-pkgbuilds/performance-tweaks/PKGBUILD:12-16`), so I could not read their settings or rule content.
- `g-pkgbuilds/performance-tweaks/PKGBUILD:18,25` downloads its payload (`usr/...`) from a remote tarball with `sha256sums=('SKIP')`; that payload is absent locally and I did not download it (no network/install allowed). The same applies to `powersave-tweaks` (only its PKGBUILD is present).
- I did not read `C/usr/share/X11/xorg.conf.d/20-touchpad.conf`, `C/usr/share/glib-2.0/...` or `C/usr/lib/NetworkManager/conf.d/dns.conf` (not performance/gaming tuning), so the research doc makes no claims about them.
- I did not update `docs/team/log/tak-7a.md` because it belongs to another agent; no new log file was created because the task did not ask for one.
- I did not run a real `on`/`off` cycle, so the ownership marker for the zram config (patch line 89) is proven only by inspection: an upgrade from an older Sunshine-generated config without the `# SUNSHINE` marker would leave that old file in place on `off`.

## Decisions the senior developer must make

1. **Apply the patch at all**, and if so, accept the new `fstrim.timer` disable on `off` (patch line 92) — it is a behaviour change from the original tool, which left the timer enabled.
2. **zram**: accept `min(ram, 8192)` on battery-free, non-virtual desktops with >=8 GiB RAM, or keep the current `min(ram / 2, 8192)` everywhere (CachyOS and Garuda both use plain `ram`: `C/usr/lib/systemd/zram-generator.conf:3`, `G/usr/lib/systemd/zram-generator.conf:2`).
3. **Helper scripts**: confirm that no new game wrapper is needed because `overlay/system/usr/local/bin/sunshine-game-run:9-12` already mirrors `research/CachyOS-Settings/usr/bin/game-performance:13-23`; otherwise approve creating `overlay/system/usr/local/bin/sunshine-game-performance` as described in section 4 of the research doc.
4. **Port or reject** the risky settings I deliberately excluded: AC-only audio `power_save` with a new helper (`C/usr/lib/udev/rules.d/20-audio-pm.rules:5-12`), NVIDIA runtime PM (`C/usr/lib/udev/rules.d/71-nvidia.rules:2-9`), systemd-oomd slice defaults (`C/usr/lib/systemd/system/system.slice.d/10-oomd-per-slice-defaults.conf:2-4`), Garuda `irqbalance`/`preload` (`P/performance-tweaks/performance-tweaks.install:6-8`), `kernel.unprivileged_userns_clone` (`C/usr/lib/sysctl.d/70-cachyos-settings.conf:31`) and NVMe `kyber` (`C/usr/lib/udev/rules.d/60-ioschedulers.rules:10-11`).
5. **Garuda package alignment**: decide whether to add a Sunshine-owned ananicy rules package and whether to name it `cachyos-ananicy-rules` (as `overlay/system/usr/local/bin/sunshine-performance:87` probes) or something local, since only the AUR name is referenced in the research tree.
6. **Journal size**: keep Sunshine's 300M (`overlay/system/usr/local/bin/sunshine-performance:60`) or align to CachyOS/Garuda 50M (`C/usr/lib/systemd/journald.conf.d/00-journal-size.conf:2`, `G/usr/lib/systemd/journald.conf.d/00-journal-size.conf:2`); I recommend keeping 300M.
