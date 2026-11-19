# Live-session baseline — Sunshine OS 13.4.7.1.5

Booted the verified ISO in `SuOS-1.5-Test` at 15:12 UTC. Full captured output:
`raw/live-tests.log`; desktop capture: `screenshots/02-live-desktop.png`.

## Environment

- Kernel `7.3.4-arch1-2`, host `sunshineos`, Plasma 6.8.3 Wayland session, `VBoxService` active.
- Live root is an overlay on a 3.1 GiB squashfs; `/dev/sda` is a blank 20 GiB disk.
- **Cowspace is now 4 GiB** (`size=4194304k`), up from 256 MiB in 13.4.7.1.4.
- Uncompressed tree is still ~8.5 GiB under `/usr`, so a 20 GiB target disk is appropriate.
- User `sunshine` has the expected wheel/power/storage groups; `sudo -n` works.

## Fixes confirmed present in this release

| Previous issue | Status in 13.4.7.1.5 | Evidence |
|---|---|---|
| `pacman-init.service` bad-setting | **Fixed**: `active (exited)`, both `ExecStart` lines succeeded, no failed units, `systemctl is-system-running = running`. | `raw/live-tests.log` services section |
| Sunshine repo key unknown | **Fixed**: key `8253720323C575207CC781B5DB345EF676CCD13D` is present and fully trusted. | `pacman-key --list-keys` |
| `sunshine-welcome` / `sunshine-toolbox` `NameError: sys` | **Fixed**: `import sys` now precedes `sys.path.insert` (line 13). | grep output |
| Doctor `tr()` shadowing | **Fixed**: no `tr()` helper found in `ui.sh`; doctor help/parse works. | grep output |
| Calamares `$p` variable error | **Likely fixed**: no `Missing variables are` string in installed Calamares config; still need GUI install confirmation. | grep output |
| 256 MiB overlay | **Fixed**: 4 GiB cowspace. | `findmnt -R /`, `df -h` |
| GTK/Kvantum settings absent from `/etc/skel` | **Fixed**: GTK3/GTK4 settings and `Kvantum/kvantum.kvconfig` now ship in skel. | skel file dumps |
| `sunshine-restore-visuals --offline` overpromise | **Improved**: tool explicitly says skel defaults are used when config files are missing, and creates `~/.config/Kvantum`; custom CSS/GTK settings are applied. | tool source grep, config dumps |

## Remaining / new observations in the live session

| ID | Severity | Observation | Evidence |
|---|---|---|---|
| N1 | Medium | GTK theme is still **Breeze-Dark** while Qt is `Sunshine (Dark)`. No Sunshine GTK theme is installed (`/usr/share/themes` only has Breeze/Default/Emacs). The custom identity still stops at the GTK widget layer. | fastfetch JSON, `/usr/share/themes` |
| N2 | Medium | Icon themes are inconsistent in the fastfetch report: `breeze-dark [Qt]` but `Sunshine-orange-dark [GTK2/3/4]`. This is the reverse of the 13.4.7.1.4 report and suggests the restore/plasma setup ordering needs checking. | fastfetch JSON |
| N3 | Low | Several tools do not implement `--help`: `sunshine-fix-pacman --help` and `sunshine-restore-visuals --help` actually run their normal jobs and hit the 12 s test timeout; `sunshine-hyprland-install --help` passes the flag into `mkdir`/`tee` and produces `mkdir: unrecognized option '--help/var/log/sunshine'`; `sunshine-install --help` opens the TUI and fails headlessly with `cannot open tty-output`. | tool smoke section |
| N4 | Low | `/usr/local/bin/uni` no longer exists. The 13.4.7.1.4 report used `uni detect`; current first-party CLI entry point appears to be `sunshine-pet`/`sunshine-apps`. Need confirm the replacement and whether documentation/menu launchers were updated. | `ls /usr/local/bin/sunshine*` |
| N5 | Low | `sunshine-install` still uses `--info=progress2` in its `rsync` call. This can still break under non-TTY/guestcontrol pipes, although the root cause of the previous failure was the undersized 8 GiB disk. | grep output |
| N6 | Low | Live journal still shows repeated `kwin_wayland: Modeset failed: Invalid argument` under VirtualBox, `librepods` BLE scan error, and `VBoxService pam_loginuid` warnings. These are environment-related and non-fatal. | journal excerpt |
| N7 | Info | `plasma-apply-colorscheme` coredumped when our headless theme smoke test invoked it without a Qt platform plugin. This was caused by the test environment (no `DISPLAY`/`WAYLAND_DISPLAY` in guestcontrol), not by normal desktop use. | journal excerpt |
| N8 | Info | `pacman -Q` warns that repo databases have not been downloaded yet (`use -Sy`), but `pacman -Dk` reports no database errors. Update test is next. | package section |

The Welcome desktop capture shows the intended live-session hub: install, repair, visuals and apps tiles with the warm yellow-on-dark styling. OCR is in `screenshots/ocr.txt`.

## Next steps

1. Launch Welcome/Toolbox/Store with the real Wayland environment and capture screenshots.
2. Run the full system update (`pacman -Syu`) and check keyring/overlay behaviour.
3. Test GUI Calamares and CLI `sunshine-install`; verify the old `$p` and rsync failures are gone.
4. Exercise doctor/`--fix`, snapshot, fix-pacman and other OS-specific tools with real arguments.
5. Install to disk, reboot, then verify theme, tools, updates and final health.
