# Sunshine OS Sol 1.5 / Sirius 0.3: what is new

This release replaces Sol 1.4, whose installer had a bug. Every change below was run in a virtual machine before it was kept.

## Rescue and repair
- **sunshine-rescue** (live session): finds the installed system on any disk (ext4, btrfs `@`, XFS, f2fs; LUKS), mounts it the way it is mounted when running, and repairs
  package database, kernel image, initramfs, GRUB, fstab, core packages; resets passwords; checks the file system (read-only first, asks before writing); refuses to repair
  a disk that reports a hardware failure. Also a button in the Welcome window and a desktop icon in the live session.
- **sunshine-doctor** now checks every installed kernel, core packages, obsolete repositories, package databases, partial upgrades, boot menu content and root UUID,
  microcode, DKMS, SMART, btrfs errors, sudo configuration, DNS, services, clock and more; `--fix` repairs what is safe. `sunshine-reset-plasma` puts the desktop look back.
- **sunshine-fix**: one command each for network, audio, display, graphics and storage problems. **sunshine-support**: a report with personal data removed.
- A weekly silent health check feeds the tray widget.

## Updates that heal themselves
- `sunshine-update` first pulls the newest signed tools (**sunshine-toolsync**, repository github.com/tak0dan/sunshine-tools: signed manifest, checksums, no downgrades, rollback),
  checks Arch news for manual-intervention notices, refreshes keys first, retries with a targeted fix when a download or signature fails, refuses to update while booted into a snapshot.
- **sunshine-migrate**: small one-time fixes applied to systems that are already installed. **sunshine-pacnew** merges config updates safely.

## Hardware, kernels, games, desktops
- **sunshine-drivers** (NVIDIA open modules or prebuilt packages, Wayland settings, PRIME, Broadcom, laptop helpers, VM tools), **sunshine-kernel** (zen, LTS, hardened, CachyOS...),
  **sunshine-performance** (zram, I/O schedulers, earlyoom, ananicy, writeback caps, NTSync), **sunshine-gaming**, **sunshine-game-run**,
  **sunshine-desktops** (GNOME, Xfce, Cinnamon, MATE, LXQt, i3, Sway... listed at the login screen), **sunshine-backup** (encrypted backup of your files).
- The installer offers a Desktops group; the boot menu has a safe-graphics entry (nomodeset); the live overlay is 4 GB.

## Fixed
- **Boot no longer waits two minutes** for a network-online unit left over from the live image (2 min 35 s to 34 s in a VM).
- The command-line installer now registers sunshine-base, enables the VM guest service, starts the login screen on Plasma.
- Top bar: menu, centred clock, graphs (no window buttons); start menu without the "More" button; icons were red (a clashing Fluent icon removed); splash plays the website animation.
- The firewall (UFW) is on by default (incoming denied, KDE Connect and discovery open).
