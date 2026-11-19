# Dev log: senior developer (night run 2026-11-19)

Goal from the owner: Sunshine OS good enough that professionals pick it over EndeavourOS, gamers over Garuda, ordinary users over Ubuntu.
Work: real-user tests (install, packages, modifications, tools), deliberate breakage and repair with sunshine-doctor, performance,
features taken from EndeavourOS / Garuda / CachyOS, a separate tools repository that sunshine-update pulls from.

## Log
- 01:40 started. Sol-dev VM (persistent live session) up, fast build of the current tree started (log /tmp build-fast1.log).
- 02:00 New tools written: sunshine-rescue (live repair of an installed system), sunshine-kernel, sunshine-performance, sunshine-gaming, sunshine-desktops.
- 02:20 sunshine-toolsync + tools/publish-tools.sh; repository github.com/tak0dan/sunshine-tools created and published (signed manifest). Tamper tests: changed
  manifest -> signature refused; changed file -> checksum refused; local server test against Sol-dev OK. sunshine-update runs toolsync first.
- 02:30 Toolbox sections: Repair (rescue in live), Make it yours (gaming, kernels, performance, desktops). Live desktop icon "Repair an installed system".
- Bugs found by running the tools: GPU detection matched "ati" inside "compatible" (VMs got AMD drivers) -> PCI vendor ids; desktops list was slow and missed
  package groups (xfce4, mate, lxqt, cosmic) -> one repo listing + group expansion. pkill -f killed my own shell again (use PIDs).
- 01:45-02:00 New tools written: sunshine-rescue (live repair of installed systems), sunshine-kernel, sunshine-performance, sunshine-gaming, sunshine-desktops, sunshine-toolsync (+ tools/publish-tools.sh, signed releases; verified against a local server incl. tamper tests). sunshine-base 0.5 published (no window-title applet).
- 02:00 fastfetch logo for upstream prepared locally (scratch/fastfetch-pr, branch logo-sunshineos, ASCII '#' from the repo's own logo). Upstream needs a Logo Request issue first and a stable release: submit after the replacement Sol release is out.
- 02:19 moved to branch team/night-run; shared layout docs/team/ created (owner order, relayed).
- 02:21 merged agent/lint and agent/translate (reviewed).
- 01:40-02:30 Built and tested (static/VM smoke): sunshine-rescue (live repair), -kernel, -performance, -gaming, -drivers, -desktops, -toolsync (+tools repo
  github.com/tak0dan/sunshine-tools, signed, tamper-tested), -migrate (4 migrations), -pacnew, -reset-plasma, -fix (network/audio/display/gpu/storage),
  -support (sanitized report), -backup (restic), -state-hook (initramfs_error, last_update), game-run. Doctor extended: every kernel, core packages,
  obsolete repos, sync dbs, partial upgrade, grub.cfg content, kernel image content, hooks, services, sudoers, clock, DNS, microcode, encrypt hook.
  Update: smart retry by failure reason, snapshot guard, news manual-intervention check, nvidia/kernel sync check, faillock, keyring first, disk check.
  Boot: safe-graphics entry, 4G overlay. Research: EndeavourOS ISO unpacked (eos-update, eos-hwtool, calamares), CachyOS-Settings, Garuda pkgbuilds (health,
  update, hooks, migrations, hardware profiles). ChatGPT and Grok answered the same 5-part design prompt (ai-answers/); Gemini not logged in.
- 02:24 fast ISO (before the later tools) built; install test on Sol-inst started (test/install-test.sh). Host under load 17 (agents' git snapshots).
- Lessons: pkill -f kills own shell; sudo -E drops env; VirtualBox NAT guest cannot reach 10.0.2.2 ports (use host LAN IP); opencode free model hit usage limit
  after ~25 min (switch model); shellcheck was missing so earlier lint runs were silent (installed in ~/.local/bin from pip shellcheck-py).
