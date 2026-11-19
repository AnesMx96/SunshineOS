> DRAFT written by an opencode agent (big-pickle model). Not reviewed: verify every statement against the scripts before publishing. Known issue: a pasted script header in the sunshine-doctor section.

# Sunshine OS tools — user guide

This guide explains the Sunshine OS command-line tools that live in `/usr/local/bin`.
It describes what each tool really does, which command to use, and how to undo a change.

The tools are made for people, not for experts. They print what they are doing and say when something failed.
Most of them ask for your password themselves, so you can run them as your normal user.

## The tools at a glance

| Tool | What it is for | Runs on |
|------|----------------|---------|
| `sunshine-rescue` | Repair an installed system from the live USB: boot loader, kernel, initramfs, packages, password, file system, chroot | live session |
| `sunshine-kernel` | Install, remove and choose kernels; rebuild initramfs and the boot menu | installed system |
| `sunshine-performance` | One switch for system tuning: zram, kernel settings, I/O schedulers, earlyoom, TRIM, journal limits | installed system |
| `sunshine-gaming` | Install the graphics stack and gaming software; apply game tuning | installed system |
| `sunshine-drivers` | Detect the hardware and install the drivers it needs (NVIDIA, Broadcom Wi-Fi, laptop helpers, VM tools) | installed system |
| `sunshine-desktops` | Install other desktops and window managers next to Plasma; choose the default session | installed system |
| `sunshine-toolsync` | Update the Sunshine tools from the signed tools repository; roll back; verify | installed system |
| `sunshine-migrate` | Run small one-time fixes after an update | installed system |
| `sunshine-game-run` | Start a game with Gamemode, MangoHud and the performance power profile | your desktop session |
| `sunshine-doctor` | Check the health of the system and repair what is safe | installed system (limited in live) |
| `sunshine-update-run` | The safe full-system updater behind `sunshine-update` | installed system |
| `sunshine-fix-pacman` | Repair pacman: lock, keyring, mirrors, databases, AUR helper | installed system or live |
| `sunshine-boot-repair` | Rebuild the kernel image, initramfs, GRUB and boot menu of the running system | installed system |

## How to read the examples

* The examples show a normal user prompt `$`. The tool asks for your password when it needs root.
  Commands that must run as root are shown with `sudo`.
* The tools print coloured lines. A success line starts with `✔`, a warning with `!`, an error with `✘`,
  and a section with `☀`. With the default `cozy=on` setting a success line also gets a cup `☕` and an error
  line a teapot `🫖`. The examples below leave the colours and these symbols out.
* Lines that come from another program (pacman, mkinitcpio, grub-install) can look different on your computer.
  The examples are realistic, not fixed text.
* If your system language is Ukrainian, the tools speak Ukrainian. To force English, put `language=en`
  in `~/.config/sunshine/tools.conf`.
* Exit status is usually `0` for success, `1` when the tool found a problem or a repair step failed, and `2` for
  wrong usage. Read the last line of the output; that is the reliable answer.

---

## `sunshine-rescue`

**What it is for.** Repair an installed Linux system from the live USB.
It finds installed systems on all disks (ext4, btrfs with `@` subvolumes, XFS, f2fs), opens encrypted disks when you give the passphrase,
mounts them the way the installed system mounts them (its `fstab`, `/boot`, the EFI partition), and works inside them with `arch-chroot`.

**When to use it.** The installed system does not boot. GRUB is broken. The kernel or initramfs is missing.
You forgot your password. The file system needs a check. You need a shell inside the installed system.
You are in the live session because the desktop does not start.

It is not a backup tool. It repairs; it does not copy your data to another disk.

### Commands

| Command | What it does |
|---------|--------------|
| `sunshine-rescue` | Open the menu (same as `sunshine-rescue menu`). |
| `sunshine-rescue list` | List the installed Linux systems found on this computer. |
| `sunshine-rescue repair [DEV]` | Check the file system, mount the system, repair the package database, kernel, initramfs, `fstab`, GRUB, and run `sunshine-doctor --fix`. |
| `sunshine-rescue bootloader [DEV]` | Only reinstall GRUB and rebuild its menu. |
| `sunshine-rescue initramfs [DEV]` | Only restore the kernel images and rebuild the initramfs for every installed kernel. |
| `sunshine-rescue passwd USER [DEV]` | Set a new password for a user of the installed system and clear the login lock. |
| `sunshine-rescue fsck [DEV]` | Check the file system while it is not mounted. |
| `sunshine-rescue chroot [DEV]` | Open a shell inside the installed system. |
| `sunshine-rescue run [DEV] -- CMD...` | Run one command inside the installed system. |
| `sunshine-rescue mount [DEV]` | Mount the system under `/mnt/sunshine-rescue` and leave it mounted. |
| `sunshine-rescue umount` | Unmount everything this tool mounted and close the encrypted disks it opened. |

`DEV` is the root partition, for example `/dev/nvme0n1p2` or `/dev/sda2`.
When only one installed system is found, you can leave `DEV` out.
When several are found, the tool asks you to choose, or you must name one.

### Examples

List the installed systems:

```
$ sudo sunshine-rescue list
/dev/nvme0n1p2           btrfs  Sunshine OS
/dev/sda2                ext4   Linux Mint 22
```

If a disk is encrypted, the tool asks for the passphrase before it can read the system.
With several systems, the printed first column is also what you pass as `DEV`.
For an encrypted system that is the `/dev/mapper/sunshine-luks-...` name shown by the list.

Open the menu:

```
$ sudo sunshine-rescue
Sunshine OS rescue

  found: /dev/nvme0n1p2           btrfs  Sunshine OS

  1) Repair everything (recommended)
  2) Reinstall the boot loader
  3) Rebuild the initramfs
  4) Reset a user password
  5) Check the file system
  6) Open a shell inside the installed system
  q) Quit
> 
```

Repair everything on the only installed system:

```
$ sudo sunshine-rescue repair
☀ File system check (btrfs)
✔ btrfs is consistent
✔ mounted at /mnt/sunshine-rescue (Sunshine OS)

☀ Package database
✔ package database is consistent

☀ Kernel and initramfs
✔ initramfs rebuilt for every kernel

☀ fstab
✔ every fstab entry points to an existing partition

☀ Boot loader
✔ GRUB (UEFI) installed on /boot/efi
✔ boot menu rebuilt

☀ Sunshine doctor
  ...
✔ Repair finished. Restart and remove the live medium.
```

Repair a named system:

```
$ sudo sunshine-rescue repair /dev/nvme0n1p2
```

On an encrypted disk, pass the passphrase in the environment (for scripts and for a non-interactive session):

```
$ sudo SUNSHINE_LUKS_PASS='your passphrase' sunshine-rescue repair /dev/nvme0n1p2
```

Repair the boot loader only:

```
$ sudo sunshine-rescue bootloader
☀ Boot loader
✔ GRUB (UEFI) installed on /boot/efi
✔ boot menu rebuilt
```

Rebuild the initramfs only:

```
$ sudo sunshine-rescue initramfs
☀ Kernel and initramfs
✔ initramfs rebuilt for every kernel
```

Set a new password:

```
$ sudo sunshine-rescue passwd alice
New password:
Retype new password:
passwd: password updated successfully
✔ password changed for alice
```

For a script, without typing the password twice:

```
$ sudo SUNSHINE_NEW_PASS='new password' sunshine-rescue passwd alice
✔ password changed for alice
```

The password is visible in the process list and in your shell history when you use `SUNSHINE_NEW_PASS`.
Use the interactive form on a computer that other people use.

Check the file system:

```
$ sudo sunshine-rescue fsck
☀ File system check (ext4)
✔ file system is clean or was repaired
```

On btrfs the tool only reads (`btrfs check --readonly`). It reports problems but does not repair them:

```
$ sudo sunshine-rescue fsck
☀ File system check (btrfs)
✔ btrfs is consistent
```

If btrfs reports problems, copy your data to another disk first. `btrfs check --repair` is a last resort.

Open a shell inside the installed system:

```
$ sudo sunshine-rescue chroot
✔ mounted at /mnt/sunshine-rescue (Sunshine OS)
You are inside the installed system. Type exit to leave.
[root@sunshine /]# exit
$ 
```

Run one command inside it:

```
$ sudo sunshine-rescue run -- pacman -Q linux
linux 6.12.7.arch1-1
```

Mount and leave it mounted:

```
$ sudo sunshine-rescue mount
✔ mounted at /mnt/sunshine-rescue (Sunshine OS)
$ ls /mnt/sunshine-rescue/etc
...
$ sudo sunshine-rescue umount
✔ unmounted
```

### Environment variables

| Variable | Effect |
|----------|--------|
| `SUNSHINE_LUKS_PASS` | Passphrase for the encrypted disk, so the tool does not ask. |
| `SUNSHINE_NEW_PASS` | New password for `sunshine-rescue passwd`, so the tool does not ask. |
| `SUNSHINE_RESCUE_FSCK=0` | Skip the file system check at the start of `repair`. |
| `SUNSHINE_RESCUE_MNT` | Mount somewhere else than `/mnt/sunshine-rescue`. |

Pass them after `sudo`, not before, for example `sudo SUNSHINE_LUKS_PASS='...' sunshine-rescue repair`.
Otherwise `sudo` may remove them from the environment.

Skip the file system check when you know the disk is fine:

```
$ sudo SUNSHINE_RESCUE_FSCK=0 sunshine-rescue repair
```

### What it changes on the system

* It mounts the installed system read-write and mounts its `/boot`, EFI partition, `/home` and other `fstab` entries.
* `fsck` and `repair` can change the file system: `e2fsck -fy` repairs ext2/ext3/ext4, `xfs_repair` repairs XFS,
  `fsck.f2fs -f` repairs f2fs. btrfs is only checked, never repaired.
* `repair` removes a stale `/var/lib/pacman/db.lck`, checks the package database, and recreates the keyring only when
  `/etc/pacman.d/gnupg` is empty. It also runs `sunshine-repo ensure`.
* If no kernel is installed, `repair` installs `linux` and `linux-firmware` (this needs internet in the live session).
  It copies missing `vmlinuz` files from `/usr/lib/modules` into `/boot` and runs `mkinitcpio -P`.
* It checks every `UUID=` and `LABEL=` entry in `/etc/fstab` and reports entries whose partition no longer exists.
  It does not rewrite `fstab` for you.
* It reinstalls GRUB for UEFI or BIOS and runs `grub-mkconfig`.
* `repair` runs `sunshine-doctor --fix` inside the installed system.
* `passwd` changes the password and clears `faillock` for that user.
* It writes a log to `/tmp/sunshine-rescue.log` (and `/tmp/sunshine-rescue.log.grub`).
  `/tmp` lives in RAM, so copy the log before you restart if you need it:
  `cp /tmp/sunshine-rescue.log /mnt/sunshine-rescue/root/`.

### How to undo it

* Mounts: `sudo sunshine-rescue umount`. `chroot` and `run` unmount by themselves when they finish.
* Password: run `sunshine-rescue passwd USER` again with the old password.
* File system repairs cannot be undone. Make a backup or a restore point before you repair a disk with valuable data.
* A reinstalled GRUB and a rebuilt initramfs have no "undo" command. They are safe to repeat.
  If the result is worse, boot a restore point from the GRUB menu (see situation 12) or repair again from the live USB.

---

## `sunshine-kernel`

**What it is for.** Keep several kernels side by side (`linux`, `linux-lts`, `linux-zen`, `linux-hardened`, `linux-rt-lts`,
CachyOS kernels and similar), each in the boot menu. Install and remove them, choose the default, rebuild the boot files.

**When to use it.** A new kernel broke something and you want the LTS kernel. You want the zen or hardened kernel.
You need to free space in `/boot`. The boot menu or an initramfs needs a rebuild.

It refuses to run in the live session. Use `sunshine-rescue` there.

### Commands

| Command | What it does |
|---------|--------------|
| `sunshine-kernel list` | Show installed kernels, their version, the running one, and the default boot entry. |
| `sunshine-kernel available` | Show kernels that are in the enabled repositories. |
| `sunshine-kernel install NAME` | Install a kernel and its headers, then rebuild the boot menu. |
| `sunshine-kernel remove NAME` | Remove a kernel and its headers. Never the running kernel, never the last kernel. |
| `sunshine-kernel default NAME` | Make this kernel the default boot entry. |
| `sunshine-kernel rebuild` | Rebuild every initramfs and the boot menu. |

Kernel names this tool manages: `linux`, `linux-lts`, `linux-zen`, `linux-hardened`, `linux-rt`, `linux-rt-lts`,
`linux-cachyos`, `linux-cachyos-lts`, `linux-cachyos-bore`, `linux-cachyos-rc`, `linux-xanmod`, `linux-mainline`,
`linux-clear`, and `linux-tkg-*`.

### Examples

See what you have:

```
$ sunshine-kernel list
Installed kernels
  linux                  6.12.7.arch1-1   <- running now
  linux-lts              6.6.66-1

Default boot entry: saved
```

See what you can install:

```
$ sunshine-kernel available
Kernels in the enabled repositories
  linux                   core 6.12.7.arch1-1 (installed)
  linux-lts               core 6.6.66-1 (installed)
  linux-zen               extra 6.12.7.zen1-1
  linux-hardened          extra 6.12.7.hardened1-1
```

Install the LTS kernel:

```
$ sudo sunshine-kernel install linux-lts
☀ Installing linux-lts
✔ boot menu rebuilt
✔ linux-lts installed; choose it in the boot menu, or make it the default with: sunshine-kernel default linux-lts
```

Install a kernel that is not in the enabled repositories:

```
$ sudo sunshine-kernel install linux-cachyos
✘ linux-cachyos: is not in any enabled repository (try: sunshine-update, or enable Chaotic-AUR for the CachyOS kernels)
```

Remove a kernel you no longer need:

```
$ sudo sunshine-kernel remove linux-zen
✔ linux-zen removed
✔ boot menu rebuilt
```

The tool refuses to remove the running kernel or the last kernel:

```
$ sudo sunshine-kernel remove linux
✘ this is the running kernel: boot another one first
```

Make the LTS kernel the default:

```
$ sudo sunshine-kernel default linux-lts
✔ boot menu rebuilt
✔ boot menu rebuilt
✔ default boot entry: Sunshine OS, with Linux linux-lts
```

The menu is rebuilt twice by this command; that is harmless. The exact title comes from the GRUB menu on your system. It can be slightly different.

Rebuild all boot files after an update or a repair:

```
$ sudo sunshine-kernel rebuild
✔ initramfs rebuilt
✔ boot menu rebuilt
```

### What it changes on the system

* `install` and `remove` use pacman: they install or remove the kernel package and, when it exists, its `-headers` package.
* Kernel images appear in `/boot` (`vmlinuz-*`, `initramfs-*.img`).
* `install`, `remove`, `default` and `rebuild` regenerate `/boot/grub/grub.cfg`.
* Every menu rebuild writes `GRUB_DISABLE_SUBMENU=y` to `/etc/default/grub`, so every kernel gets its own flat menu entry.
* `default` sets `GRUB_DEFAULT=saved` and `GRUB_SAVEDEFAULT=false` in `/etc/default/grub`,
  then stores the chosen title with `grub-set-default` in the GRUB environment block.
* The boot menu is only rebuilt when `grub-mkconfig` exists. This tool assumes GRUB.

### How to undo it

* Undo `install NAME` with `sudo sunshine-kernel remove NAME`.
* Undo `remove NAME` by installing the kernel again: `sudo sunshine-kernel install NAME`.
* Undo `default NAME` with `sudo sunshine-kernel default linux` (or whichever kernel you want).
  You can also choose a kernel once in the GRUB menu; with `GRUB_SAVEDEFAULT=false` that choice is not saved.
* `rebuild` only recreates generated files. It has nothing to undo.

---

## `sunshine-performance`

**What it is for.** Apply a tested performance profile with one switch: compressed swap in RAM (zram), kernel settings for games,
I/O schedulers for NVMe/SSD/HDD, earlyoom, ananicy-cpp, weekly TRIM, journal limits, faster shutdown, build settings, watchdog and
writeback tuning, and sane time servers.

**When to use it.** A fresh install, when `status` shows that the profile is off. A desktop that stutters when memory is full.
You want to compare numbers before and after. You want to remove the tuning because something behaves strangely.

### Commands

| Command | What it does |
|---------|--------------|
| `sunshine-performance status` | Show which parts are on, the active services, zram, and the current kernel values. |
| `sunshine-performance on` | Apply the profile. Installs `earlyoom` and, when available, `ananicy-cpp`. |
| `sunshine-performance off` | Remove the setting files and disable its services. |
| `sunshine-performance bench` | Print boot time, memory, slowest services, disk schedulers, load and CPU governor. Read-only. |

### Examples

Check the state:

```
$ sunshine-performance status
  + sysctl profile
  + I/O schedulers
  + journal limit
  + service timeouts
  + makepkg all cores
  + earlyoom active
  - ananicy-cpp inactive
  + fstrim.timer active
NAME  ALGORITHM  DISKSIZE  DATA  COMPR  ...
zram0 zstd       7.8G      ...
  swappiness=150  max_map_count=2147483642  tcp=bbr
```

The `+` and `-` marks show what is on and off. The values at the end are the live kernel values.

Turn the profile on:

```
$ sudo sunshine-performance on
☀ Memory and swap
✔ kernel settings applied (swap tuned for zram, bigger map count for games, BBR network)
✔ earlyoom keeps the desktop alive when memory runs out
☀ Disk
✔ weekly TRIM for SSDs
☀ System
✔ journal capped, quick service stop, builds and package compression use all cores
✔ watchdogs off, NTSync for Wine, writeback caps for USB sticks and HDDs, sane time servers
✔ ananicy-cpp gives games and the desktop priority over background work
✔ profile is on
A restart applies everything; check the numbers with: sunshine-performance bench
```

If a package is not in the enabled repositories, the tool says so and continues:

```
earlyoom could not be installed (offline?): skipped
ananicy-cpp is not in the enabled repositories (Chaotic-AUR has it): skipped
```

Measure the result:

```
$ sunshine-performance bench
Sunshine OS performance numbers
  Startup finished in 4.2s (firmware) + 1.1s (loader) + 2.3s (kernel) + 3.0s (userspace) = 10.6s
  1.2s NetworkManager-wait-online.service;  0.8s systemd-udev-settle.service;  ...
  RAM used 3120 of 15872 MiB
  swap used 120 of 7936 MiB
  processes: 210   services running: 37
  nvme0n1 scheduler: none
  sda scheduler: mq-deadline
  load: 0.42 0.35 0.30   cpu governor: powersave
```

Turn it off:

```
$ sudo sunshine-performance off
✔ profile removed (zram swap and the installed packages stay)
```

### What it changes on the system

On `on`, it writes these files:

* `/etc/sysctl.d/99-sunshine-performance.conf` — swappiness, cache pressure, dirty limits, `max_map_count`, BBR network settings.
* `/etc/modules-load.d/sunshine-bbr.conf` — load `tcp_bbr`.
* `/etc/udev/rules.d/60-sunshine-ioschedulers.rules` — `none` for NVMe, `mq-deadline` for SSDs, `bfq` for HDDs.
* `/etc/udev/rules.d/61-sunshine-writeback.rules` — cap dirty data for USB sticks and HDDs.
* `/etc/udev/rules.d/30-sunshine-zram.rules` — swappiness 150 and zswap off when zram is initialised.
* `/etc/systemd/journald.conf.d/50-sunshine.conf` — limit the journal to 300 MB.
* `/etc/systemd/system.conf.d/50-sunshine-timeouts.conf` — faster service stop, start timeout, file limit.
* `/etc/systemd/system.conf.d/60-sunshine-limits.conf` — higher open-file limit.
* `/etc/systemd/coredump.conf.d/50-sunshine.conf` — store core dumps externally, limit them to 500 MB.
* `/etc/makepkg.conf.d/sunshine.conf` — build with all cores and compress with all cores.
* `/etc/modprobe.d/sunshine-no-watchdog.conf` — blacklist hardware watchdogs.
* `/etc/tmpfiles.d/sunshine-thp.conf` — transparent huge page defrag policy.
* `/etc/modules-load.d/sunshine-ntsync.conf` — load `ntsync` when the kernel has it (Wine/Proton).
* `/etc/systemd/timesyncd.conf.d/10-sunshine.conf` — Cloudflare and Arch time servers.
* `/etc/systemd/zram-generator.conf` — only if it does not exist yet; zram sized `min(ram/2, 8192)`, zstd.
* `/etc/default/earlyoom` — earlyoom arguments, marked with `# SUNSHINE`.

It also:

* installs `earlyoom` and enables `earlyoom.service`;
* installs `ananicy-cpp` (and `cachyos-ananicy-rules` when available) and enables `ananicy-cpp.service`;
* enables `fstrim.timer`;
* reloads sysctl and udev rules.

`off` removes the setting files it wrote (the zram generator file excepted) and the `# SUNSHINE` block from `/etc/default/earlyoom`,
and disables `earlyoom.service` and `ananicy-cpp.service`. It does **not** remove the installed packages.
It also leaves `/etc/systemd/zram-generator.conf` and `fstrim.timer` in place, so zram swap and weekly TRIM stay.
The output says this: "zram swap and the installed packages stay".

### How to undo it

```
$ sudo sunshine-performance off
$ sudo reboot
```

The reboot makes every service and udev rule start from the stock settings.
To remove the packages too:

```
$ sudo pacman -Rns earlyoom ananicy-cpp
```

To remove zram as well, delete the file and reboot:

```
$ sudo rm /etc/systemd/zram-generator.conf
$ sudo reboot
```

---

## `sunshine-gaming`

**What it is for.** Set up a computer for games: the right graphics stack for the detected card, Steam, Gamemode, MangoHud,
and the system tuning games need. The `full` level adds Lutris, Wine, Gamescope, Heroic and ProtonUp.

**When to use it.** After a fresh install. A new graphics card. Steam does not start a game. You want the MangoHud overlay
or Gamemode. You want the extra launchers.

It needs internet for `install`. Packages that are not in the enabled repositories are skipped and listed.

### Commands

| Command | What it does |
|---------|--------------|
| `sunshine-gaming status` | Show the graphics hardware, the gaming packages, `max_map_count`, and whether multilib is on. |
| `sunshine-gaming gpu` | Show the graphics hardware and the packages this tool would choose for it. |
| `sunshine-gaming install [LEVEL]` | Install the graphics stack and games software. `LEVEL` is `base` (default) or `full`. |
| `sunshine-gaming tune` | Apply only the game tuning: sysctl, open-file limits, Gamemode group, ananicy. |

`base` installs the graphics packages, Vulkan loaders, Steam, Gamemode (64 and 32 bit) and MangoHud (64 and 32 bit).
`full` also installs Lutris, Wine staging, Winetricks, Gamescope, Goverlay, ProtonUp-Qt, Heroic, Proton-GE
and the 32-bit libraries those need.

### Examples

See the current state:

```
$ sunshine-gaming status
Graphics
  01:00.0 VGA compatible controller: NVIDIA Corporation GA104 [GeForce RTX 3070] (rev a1)
Gaming software
  + steam                       1.0.0.81-1
  - lutris
  + gamemode                    1.8.2-1
  - mangohud
  vm.max_map_count=2147483642  ok
✔ multilib
```

A `+` means installed, a `-` means missing.

Ask what this computer needs:

```
$ sunshine-gaming gpu
01:00.0 VGA compatible controller: NVIDIA Corporation GA104 [GeForce RTX 3070] (rev a1)

packages for it: nvidia-open-dkms nvidia-utils lib32-nvidia-utils nvidia-settings
```

For NVIDIA, this tool chooses the DKMS package (`nvidia-open-dkms` for Turing and newer cards, `nvidia-dkms` for older ones).
`sunshine-drivers install` instead chooses the prebuilt `nvidia-open` for a stock kernel. Both are only listed when they are in the enabled repositories.

Install the base level:

```
$ sudo sunshine-gaming install
✔ multilib
☀ Graphics drivers
✔ installed: nvidia-open-dkms nvidia-utils lib32-nvidia-utils nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader
☀ Games
✔ installed: steam gamemode lib32-gamemode mangohud lib32-mangohud
☀ Tuning for games
✔ map count raised (needed by many Proton games), split-lock penalty off
✔ alice is in the gamemode group (log out and in)
✔ Gaming setup done. Open Steam, then Settings > Compatibility > enable Steam Play for all titles. Launch options: sunshine-game-run --hud %command%
```

Install everything:

```
$ sudo sunshine-gaming install full
...
✔ installed: lutris wine-staging winetricks gamescope goverlay lib32-gnutls lib32-sdl2 protonup-qt heroic-games-launcher-bin proton-ge-custom-bin
```

Packages that are not available are listed, not fatal:

```
not in the enabled repositories (skipped): proton-ge-custom-bin heroic-games-launcher-bin
```

Apply only the tuning:

```
$ sudo sunshine-gaming tune
☀ Tuning for games
✔ map count raised (needed by many Proton games), split-lock penalty off
✔ alice is in the gamemode group (log out and in)
✔ ananicy-cpp
More tuning: sunshine-performance on
```

### What it changes on the system

* `install` enables `[multilib]` in `/etc/pacman.conf` when it is only commented out, and runs `pacman -Sy` once.
* It installs packages with pacman. Missing packages are skipped.
* `tune` writes `/etc/sysctl.d/98-sunshine-gaming.conf` (`vm.max_map_count`, `kernel.split_lock_mitigate`, `fs.file-max`)
  and `/etc/security/limits.d/90-sunshine-gaming.conf` (open-file limits), then reloads sysctl.
* `tune` adds the user who called `sudo` to the `gamemode` group, when the group exists.
* `tune` enables `ananicy-cpp` when it is installed.
* `install` runs `tune` at the end.

### How to undo it

Remove the tuning files and reload the settings:

```
$ sudo rm /etc/sysctl.d/98-sunshine-gaming.conf /etc/security/limits.d/90-sunshine-gaming.conf
$ sudo sysctl --system
```

Remove yourself from the Gamemode group (log out and in afterwards):

```
$ sudo gpasswd -d "$USER" gamemode
```

Remove packages you do not want, for example:

```
$ sudo pacman -Rns steam mangohud lib32-mangohud
```

Leave `[multilib]` enabled. Turning it off can break installed 32-bit packages.

---

## `sunshine-drivers`

**What it is for.** Look at the hardware and install what it needs: NVIDIA drivers, Broadcom Wi-Fi, laptop power and thermal helpers,
network discovery for printers and shares, fingerprint readers, and guest tools inside a virtual machine.

**When to use it.** After a fresh install, or after you changed the graphics card or added a laptop. A device does not work
(Wi-Fi, fingerprint reader, printer discovery). NVIDIA is not installed and you want the right package chosen for you.
A virtual machine needs clipboard, shared folders and screen resizing.

`detect` only shows the plan. `install` changes the system. `auto` is the quiet version used once after the first start;
you normally do not run it by hand.

### Commands

| Command | What it does |
|---------|--------------|
| `sunshine-drivers detect` | Show the hardware and which packages would be installed, with a reason for each. |
| `sunshine-drivers install` | Install those packages and apply their settings. Asks nothing. Needs internet. |
| `sunshine-drivers auto` | Same as `install`, quiet. Used by `sunshine-apps first-update`; never installs GPU drivers in a virtual machine. |

### Examples

Detect:

```
$ sunshine-drivers detect
Hardware
  CPU: GenuineIntel   (laptop)
  GPU: 0000:00:02.0 VGA compatible controller: Intel Corporation ...
  GPU: 0000:01:00.0 VGA compatible controller: NVIDIA Corporation GA104 [GeForce RTX 3070] ...
Would install
  nvidia-open               NVIDIA open modules for linux
  nvidia-utils              NVIDIA                                    installed
  nvidia-settings           NVIDIA                                    installed
  nvidia-prime              Hybrid graphics: prime-run starts a program on the NVIDIA card
  lib32-nvidia-utils        NVIDIA 32-bit (Steam, Wine)               installed
  thermald                  Intel laptop: keeps it cool without throttling too early
  power-profiles-daemon     laptop power profiles
  avahi                     network discovery (printers, shares)      installed
  nss-mdns                  .local names                              installed
```

Install:

```
$ sudo sunshine-drivers install
Installing: nvidia-open nvidia-prime thermald power-profiles-daemon
✔ Drivers installed. Restart to use the NVIDIA driver.
```

If a package is missing:

```
not in the enabled repositories (skipped): nvidia-580xx-dkms
Installing: nvidia-dkms nvidia-utils ...
✔ Drivers installed. Restart to use the NVIDIA driver.
```

When everything is already there:

```
$ sudo sunshine-drivers install
Everything this computer needs is already installed.
```

`auto` is quiet on success and prints nothing. It is used once after the first start:

```
$ sudo sunshine-drivers auto
```

### What it changes on the system

* Installs packages with pacman. On btrfs with snapper it makes a restore point before installing.
* For NVIDIA it writes `/etc/modprobe.d/sunshine-nvidia.conf` (`modeset=1`, `fbdev=1`, preserve video memory)
  and `/etc/modprobe.d/sunshine-nouveau.conf` (blacklist nouveau), enables the NVIDIA suspend, resume and hibernate services,
  and runs `mkinitcpio -P`.
* Choosing the NVIDIA package:
  * Turing and newer cards get the open modules. Stock kernels get the prebuilt `nvidia-open` and `nvidia-open-lts`;
    other kernels get `nvidia-open-dkms`.
  * Older cards get `nvidia-580xx-dkms` when it exists, otherwise `nvidia-dkms`.
  * On hybrid laptops with an Intel or AMD graphics chip it adds `nvidia-prime`. `prime-run` starts a program on the NVIDIA card.
* Broadcom Wi-Fi gets `broadcom-wl-dkms`.
* Intel laptops get `thermald`; every laptop gets `power-profiles-daemon`.
* It installs `avahi` and `nss-mdns`, enables `avahi-daemon`, and adds `mdns_minimal` to the `hosts:` line of `/etc/nsswitch.conf`.
* A fingerprint reader gets `fprintd`.
* In a virtual machine it installs guest tools only: VirtualBox, VMware, or QEMU/SPICE tools.
* The full pacman output goes to `/tmp/sunshine-drivers.log`.

### How to undo it

There is no single undo command. Remove what you do not want:

```
$ sudo pacman -Rns nvidia-open nvidia-utils nvidia-settings nvidia-prime
$ sudo rm /etc/modprobe.d/sunshine-nvidia.conf /etc/modprobe.d/sunshine-nouveau.conf
$ sudo mkinitcpio -P
$ sudo reboot
```

Turn off helpers you do not want:

```
$ sudo systemctl disable --now avahi-daemon.service thermald.service
```

`/etc/nsswitch.conf` is edited in place and not backed up. If `.local` name resolution causes trouble, remove
`mdns_minimal [NOTFOUND=return]` from the `hosts:` line by hand.

---

## `sunshine-desktops`

**What it is for.** Install another desktop or window manager next to Plasma and pick it at the login screen.
Everything comes from the official repositories. Removing one leaves the others alone.

**When to use it.** You want to try GNOME, Xfce, Sway, Hyprland and so on. You want a lighter desktop on an old laptop.
You want a tiling window manager. You want the login screen to start with another session by default.

`install` refuses to run in the live session. Install the system first. `list` works anywhere.

### Commands

| Command | What it does |
|---------|--------------|
| `sunshine-desktops list` | Show every desktop this tool knows, and whether it is installed or available. |
| `sunshine-desktops install NAME` | Install a desktop. On btrfs it makes a restore point first. |
| `sunshine-desktops remove NAME` | Remove what that desktop brought. Shared packages stay. Plasma cannot be removed. |
| `sunshine-desktops default NAME` | Make the login screen start with this session selected. |

Names: `kde`, `gnome`, `xfce`, `cinnamon`, `mate`, `budgie`, `lxqt`, `cosmic`, `i3`, `sway`, `hyprland`, `niri`,
`openbox`, `qtile`, `bspwm`, `awesome`.

### Examples

List:

```
$ sunshine-desktops list
Desktops and window managers
  kde        KDE Plasma (the default)                          installed
  gnome      GNOME: a focused, modern desktop                  available
  xfce       Xfce: light and traditional                       available
  ...
  hyprland   Hyprland: animated tiling (Wayland)               available
```

Install Xfce:

```
$ sudo sunshine-desktops install xfce
✔ restore point made
☀ Installing xfce
✔ xfce installed: pick it at the login screen (the session menu)
```

If the login screen is not enabled, the tool tells you:

```
No login screen is enabled: sudo systemctl enable sddm
```

Make Xfce the preselected session:

```
$ sudo sunshine-desktops default xfce
✔ the login screen starts with xfce
```

Remove it again:

```
$ sudo sunshine-desktops remove xfce
✔ xfce removed
```

Sometimes a package is still needed by something else. Then the tool says so instead of breaking the system:

```
$ sudo sunshine-desktops remove gnome
✘ some of it is still needed by other packages
```

Plasma is protected:

```
$ sudo sunshine-desktops remove kde
✘ Plasma is the default desktop and stays
```

### What it changes on the system

* `install` refreshes the package lists once (`pacman -Sy`), checks that every package of that desktop exists,
  makes a restore point on btrfs with snapper when it is set up, and installs the packages with pacman.
* It does not enable or start a display manager. Sunshine OS uses `sddm`, and this tool leaves it in charge.
* `default` writes `/var/lib/sddm/state.conf` with the session file the login screen should preselect.
  This only affects SDDM. It does not change what starts after a login on another display manager.
* `remove` removes each package separately with `pacman -Rns`, so shared dependencies and packages needed by other software stay.
* It does not touch your personal settings in `/home`.

### How to undo it

```
$ sudo sunshine-desktops remove NAME
```

If you set it as the default session, choose Plasma again:

```
$ sudo sunshine-desktops default kde
```

or pick another session at the login screen. Removing a desktop does not remove your files, but it can remove its
programs and settings packages. A btrfs restore point was made before the install if snapper is set up.

---

## `sunshine-toolsync`

**What it is for.** Update the Sunshine tools themselves (scripts, library, translations, widgets, hooks) from the signed tools
repository, without a new ISO and without waiting for a package. `sunshine-update` runs it first, so every update starts with the
newest repair tools.

**When to use it.** You want a tool fix now. A tool behaves differently from this guide. `sunshine-doctor` suggests it.
You want to check that the installed tools were not changed. An update of the tools broke something and you want the previous files.

The release is signed with the Sunshine OS key. A release with a bad signature, a file with a wrong checksum, or a path outside
the Sunshine paths is refused.

### Commands

| Command | What it does |
|---------|--------------|
| `sunshine-toolsync status` | Show the installed tools version and the version the repository offers. |
| `sunshine-toolsync update [--force]` | Install the newest tools. Only files that differ are replaced; the old ones are kept. |
| `sunshine-toolsync rollback` | Put back the files of the previous update. |
| `sunshine-toolsync verify` | Check the installed tools against the manifest of the installed version. |

`--force` makes `update` download and apply the same version again. It is mainly for testing:

```
$ sudo sunshine-toolsync update --force
✔ tools updated: 2026.11.2 -> 2026.11.2 (0 files changed, 0 refused)
```

### Examples

Check the versions:

```
$ sunshine-toolsync status
installed tools version: 2026.11.1
repository offers: 2026.11.2
```

Offline:

```
$ sunshine-toolsync status
installed tools version: 2026.11.1
repository: not reachable (offline?)
```

Update:

```
$ sudo sunshine-toolsync update
✔ tools updated: 2026.11.1 -> 2026.11.2 (7 files changed, 0 refused)
```

Already current:

```
$ sudo sunshine-toolsync update
✔ tools are up to date (2026.11.2)
```

Offline update keeps what you have and does not fail the whole update:

```
$ sudo sunshine-toolsync update
tools repository not reachable: keeping the installed tools
```

A refused release:

```
$ sudo sunshine-toolsync update
✘ the manifest signature is not valid: refusing this release
```

Check the installed files:

```
$ sudo sunshine-toolsync verify
✔ every tool matches the manifest
```

If someone edited a tool by hand:

```
$ sudo sunshine-toolsync verify
✘ differs: /usr/local/bin/sunshine-kernel
```

Roll back the last update:

```
$ sudo sunshine-toolsync rollback
✔ previous tools put back
```

### What it changes on the system

* It downloads `manifest.json`, its signature, and `sunshine-tools.tar.gz` into a temporary directory.
* It verifies the manifest with `/usr/share/pacman/keyrings/sunshine.gpg`.
* It installs only files whose path matches the Sunshine paths:
  `usr/local/bin/sunshine-*`, `usr/local/lib/sunshine/*`, `usr/share/sunshine/*`,
  Sunshine Plasma widgets and look-and-feel packages, `usr/share/libalpm/hooks/NNNN-sunshine-*.hook`,
  and `usr/share/applications/sunshine-*.desktop`.
* It checks every file against the SHA-256 in the signed manifest.
* Before replacing a file it copies the old one to `/var/lib/sunshine/tools-backup/<date>/`.
  Files that did not exist before are recorded in `.new/list`.
* It writes the new version to `/var/lib/sunshine/tools-version` and the manifest to `/var/lib/sunshine/tools-manifest.json`.
* It points `/var/lib/sunshine/tools-backup/latest` to the newest backup.
* After an update it runs `sunshine-migrate run`, so migrations can change other settings.

### How to undo it

```
$ sudo sunshine-toolsync rollback
```

This restores the files of the last update and deletes files that the update added.
It only goes back one step. It also removes the version file, so `status` then says `none` until the next update.

`rollback` does not undo migrations that ran after the update. If a migration changed a setting, see the migration log
`/var/log/sunshine/migrations.log` and the migration itself in `/usr/share/sunshine/migrations/`.

---

## `sunshine-migrate`

**What it is for.** Run small, one-time fixes on an already installed system after an update: a setting that moved,
a removed widget, a new default. Each migration runs once and must be safe to run twice.

**When to use it.** You normally do not. The pacman hook runs it automatically when `sunshine-base` is installed or
upgraded, and `sunshine-update` runs it through `sunshine-toolsync`.
Use it by hand to see the state, to retry a failed migration, or to run one again after you changed something.

### Commands

| Command | What it does |
|---------|--------------|
| `sunshine-migrate` | Run every migration that has not run yet (same as `run`). |
| `sunshine-migrate list` | Show every migration and its state: `new`, `ok`, or `failed:N`. |
| `sunshine-migrate redo NAME` | Forget that `NAME` ran, so it runs again next time. |

### Examples

See the state:

```
$ sunshine-migrate list
  0001-pacman-community-merged               ok
  0002-sddm-session-path                     new
  0003-hyprland-portal                       failed:1
```

Run what is pending:

```
$ sudo sunshine-migrate
✔ 0002-sddm-session-path: session path updated
migrations applied: 1
```

When everything already ran, it prints nothing and exits successfully.

Run one again:

```
$ sudo sunshine-migrate redo 0003-hyprland-portal
✔ 0003-hyprland-portal will run again
$ sudo sunshine-migrate
✔ 0003-hyprland-portal: portal configured
migrations applied: 1
```

### What it changes on the system

* It runs the scripts in `/usr/share/sunshine/migrations/NNNN-name.sh`.
  Each script changes what it was written to change and says what it did.
* It writes the state to `/var/lib/sunshine/migrations/<name>`: `ok`, or `failed:N`.
* It appends the output of every run to `/var/log/sunshine/migrations.log`.
* A migration that failed is retried on the next run. After three failures it is left alone.
* The scripts are part of the Sunshine tools, so they arrive with `sunshine-toolsync`.

### How to undo it

There is no general undo. A migration is a small change, not a transaction.
Read what it did in `/var/log/sunshine/migrations.log` and in the script itself, then reverse that change by hand.
`redo` does not undo anything; it only makes the migration run again.

---

## `sunshine-game-run`

**What it is for.** Start a game with the helpers that make it run better: MangoHud for the overlay, Gamemode for CPU
scheduling and process priority, and the "performance" power profile for as long as the game runs. The power profile goes
back to normal when the game exits.

**When to use it.** In Steam launch options, in a desktop launcher, or in a terminal when you start a game.
It is not a launcher by itself: it wraps the command that starts the game.

Do not run it with `sudo`. It belongs to your desktop session.

### Commands

| Command | What it does |
|---------|--------------|
| `sunshine-game-run COMMAND...` | Start the command with Gamemode and the performance power profile. |
| `sunshine-game-run --hud COMMAND...` | The same, plus the MangoHud overlay. |

### Examples

In Steam: right-click the game, **Properties**, **Launch options**:

```
sunshine-game-run %command%
```

With the overlay:

```
sunshine-game-run --hud %command%
```

In a terminal:

```
$ sunshine-game-run --hud ./MyGame
```

The game's own output appears as usual. The tool prints nothing of its own.

Each helper is used only when it is installed:

* `mangohud` is added when `--hud` is given and MangoHud is installed.
* `gamemoderun` is added when Gamemode is installed.
* `powerprofilesctl` is used when it exists and lists a `performance` profile. The game then runs under
  `systemd-inhibit` and `powerprofilesctl launch -p performance`, so the power profile is temporary.
  If `powerprofilesctl` is not there, the game simply runs with the other helpers.

### What it changes on the system

Nothing on disk. While the game runs, with the helpers installed:

* the power profile is set to `performance`;
* `systemd-inhibit` keeps the running session from being treated as idle;
* Gamemode applies its scheduling and priority rules.

When the game exits, the power profile is restored.

### How to undo it

Nothing to undo. Close the game. If you started it from a terminal and stopped the tool with `Ctrl+C`,
the game also stops; the power profile is restored when the wrapper exits.

---

## `sunshine-doctor`

**What it is for.** Check the health of the system: identity, package manager, desktop, boot files, disk, services and restore points.
With `--fix`, repair what is safe to repair. It never removes your packages or your files.

**When to use it.** Something feels wrong and you do not know where to start. After an update. Before you ask for help
(the output shows what is broken). On a schedule, or when `sunshine-update` finishes.

It needs root to read the boot menu and the restore points, so it asks for your password.

### Commands

| Command | What it does |
|---------|--------------|
| `sunshine-doctor` | Check and report. Changes nothing. |
| `sunshine-doctor --fix` | Check and repair what is safe to repair. |
| `sunshine-doctor --quiet` | Print only problems, not the successful checks. |
| `sunshine-doctor -h`, `--help` | Show the short usage text. |

`--fix` and `--quiet` can be combined: `sunshine-doctor --fix --quiet` is what the updater uses at the end.

```
$ sunshine-doctor --help
# Sunshine OS health check: identity, package manager, boot files, disk, services, snapshots.
#   sunshine-doctor          check and report
#   sunshine-doctor --fix    also repair what is safe to repair (never removes packages or files of yours)
#   sunshine-doctor --quiet  only print problems
FIX=0; Q=0
```

The last line is an internal line that this version prints by mistake. Ignore it.

### Examples

A healthy system:

```
$ sunshine-doctor
Sunshine OS doctor  (check only; add --fix to repair)

☀ Identity
  ✔ this is Sunshine OS (Sunshine OS)
☀ Package manager
  ✔ no lock file
  ✔ package keyring present
  ✔ package database consistent
  ✔ core packages are installed
  ✔ no pending .pacnew files
  ✔ [sunshine] repository is configured
...
☀ System
  ✔ clock is synchronised
  ✔ swap is active
  ✔ no failed services
  ✔ root disk 42% used
  ✔ network service running
  ✔ running kernel matches installed modules
☀ Restore points
  ✔ snapper configured for /
  ✔ 3 restore point(s) available
  ✔ automatic snapshot before/after every update (snap-pac)

All good (2 note(s))
```

A problem:

```
$ sunshine-doctor
...
☀ Boot
  ✘ /boot/initramfs-linux.img missing or empty
  ✘ EFI fallback boot file (EFI/BOOT/BOOTX64.EFI) is missing: some firmwares will not find the system
...
2 problem(s) found — run: sunshine-doctor --fix
```

Repair:

```
$ sudo sunshine-doctor --fix
...
  ✘ /boot/initramfs-linux.img missing or empty
  ↺ fixed: initramfs rebuilt: linux
...
All good
```

Only the problems:

```
$ sudo sunshine-doctor --quiet
  ! the last update was 21 days ago (sunshine-update)
  ! no swap is active (zram swap normally is: sunshine-performance on)
```

The exit status is `1` when at least one problem was found, even with `--fix`. It is `0` when the system is good
(or only has notes).

In the live session, the boot and restore-point sections are skipped, because the live system has no `/boot` of its own:

```
☀ Boot
  ✔ live session: boot files are checked on the installed system
```

### What it checks

* **Identity:** `os-release`, `lsb-release`, `issue` and the Sunshine identity files still say Sunshine OS.
* **Package manager:** lock file, keyring, database consistency, core packages, obsolete repositories,
  pending `.pacnew` files, the `[sunshine]` repository, installer leftovers.
* **Desktop:** the tested icon font, Hyprland crash reports, the login screen sessions.
* **Boot:** every kernel has an image and an initramfs, the last update left the boot files complete,
  the update age, the EFI fallback file, free space in `/boot` and on the EFI partition, microcode,
  DKMS modules, holes in the kernel image on btrfs, the GRUB menu, the mounted EFI partition, `fstab`.
* **System:** SMART health, btrfs device errors, clock synchronisation, swap, failed services, disk usage,
  NetworkManager, running kernel against installed modules.
* **Restore points:** snapper or Timeshift setup, timers, available points, `snap-pac`, snapshot entries in GRUB.
* **Declarative setup (Sirius only):** `/etc/sunshine/declarative.toml`, Nix and the Nix daemon.

### What `--fix` changes

`--fix` only repairs. It does not remove packages or personal files. Depending on what it finds, it can:

* restore the Sunshine identity (`sunshine-identity apply`);
* remove a stale pacman lock (only when no pacman is running);
* recreate an empty keyring;
* reinstall missing core packages (`base`, `linux`, `linux-firmware`, `mkinitcpio`, `grub`, `sudo`, `networkmanager`,
  `sddm`, `plasma-desktop`, `pipewire`, `pacman`, `sunshine-base`);
* remove obsolete or unstable repositories by running `sunshine-fix-pacman`;
* restore the tested icon font package;
* copy a missing kernel image from `/usr/lib/modules` to `/boot`, or rebuild a missing initramfs;
* restore the EFI fallback boot file with `grub-install --removable`;
* install `intel-ucode` or `amd-ucode`;
* build DKMS modules (`dkms autoinstall`);
* rewrite a kernel image that has holes on btrfs;
* regenerate `/boot/grub/grub.cfg`;
* set up snapshots and enable the snapshot timers when they are missing;
* apply the declarative setup on Sirius.

Most of these need internet. Repairs that install packages log to `/tmp/sunshine-core.log`;
initramfs builds log to `/tmp/sunshine-mkinitcpio.log`.

### How to undo it

There is no single undo. `--fix` is additive and does not delete your own files.
If it turned on a timer or installed a package you do not want, turn it off or remove it:

```
$ sudo systemctl disable --now snapper-timeline.timer
$ sudo pacman -Rns intel-ucode
```

`--fix` does not make a restore point before repairing. If you want to be able to go back, make one first:

```
$ sudo sunshine-snapshot create "before doctor --fix"
```

---

## `sunshine-update-run`

**What it is for.** The safe full-system update. It updates the Sunshine tools, checks the news, refreshes the mirrors,
updates the keyring and the system packages, then Flatpak, AUR and (on Sirius) Nix and the declarative setup.
It finishes with a health check and a cleanup.

**When to use it.** Once a week, or when the update icon shows updates. Always through `sunshine-update`,
which opens a terminal window and asks for your password with polkit.

### Commands

| Command | What it does |
|---------|--------------|
| `sunshine-update` | The normal way: opens a terminal and runs the update with a password prompt. |
| `sudo sunshine-update-run` | Run the same update directly in your terminal. |

`sunshine-update-run` has no options. It explains each step and stops with a clear message when it cannot continue.

Directly in a terminal, without the extra window:

```
$ sudo sunshine-update-run
☀ Sunshine OS update
...
Press Enter to close this window.
```

The output is the same as in the window.

Run it through `sunshine-update` when you can. With plain `sudo`, the tool cannot tell which user you are:
it skips the AUR update, the per-user update check, the login-lock reset, and it updates only system Flatpaks.

### Example

```
$ sunshine-update
```

The window shows:

```
☀ Sunshine OS update
☀ Sunshine tools
✔ tools are up to date (2026.11.2)
☀ Latest Arch Linux news (read if something looks important)
  • Firefox 135 requires ...
☀ Checking for updates
12 package update(s) available.
☀ Refreshing the mirror list
✔ arch mirrors ranked
✔ chaotic-aur mirrors ranked
☀ Updating system packages
✔ Package keyring is current
...
✔ System packages are up to date
☀ Updating Flatpak apps
☀ Updating AUR (community) packages
☀ Final health check
☀ Tidying up
✔ Old package cache cleaned
Config updates waiting for review (*.pacnew):
/etc/pacman.conf.pacnew
The kernel was updated. Please restart your computer when convenient.
☀ Apps you chose
☀ Health check
✔ All done
Press Enter to close this window.
```

When it stops, the message says why. Common stops:

```
✘ No internet connection. Connect to Wi-Fi or a cable and try again.
```

```
✘ Another update or install is running. Close it and try again.
```

```
✘ Less than 1.5 GB is free on the system disk: the update could fail halfway. Free some space first (sunshine-cleanup).
```

```
✘ The update has a new linux but not yet a matching nvidia-open: the NVIDIA driver would not load. Try again in a few hours (the mirrors are still syncing).
```

```
Arch Linux announced a change that may need your action before updating:
  ...
Have you read it and want to continue anyway? [y/N]
```

If you answer `n`, the update stops before the package update. If you answer `y`, it continues.

### What it changes on the system

* Updates the Sunshine tools (`sunshine-toolsync update`) and makes sure the `[sunshine]` repository is configured.
* Removes a stale pacman lock, but only when no pacman is running.
* Ranks the Arch and Chaotic-AUR mirrors with `rate-mirrors` and keeps the old lists as `*.sunshine-backup`.
* Updates `archlinux-keyring`, then the system packages with pacman. If a new repository was added by a new
  `sunshine-base`, it updates once more.
* Updates Flatpak apps, AUR packages (with `paru` or `yay`), and on Sirius the Nix profiles and the declarative setup.
* Restores the Sunshine identity if an update replaced it.
* Clears the login lock of your user if there were too many wrong passwords.
* Runs `sunshine-doctor --quiet --fix`, removes old cached packages with `paccache -rqk2`, and prints unused packages
  and `.pacnew` files for you to review.
* Installs apps you queued in Sunshine Store, and the first-update apps (LibreOffice, Zen and similar) on the first update.
* Makes restore points automatically when snapshots are set up: before and after every package transaction on btrfs
  with `snap-pac`, and before the transaction with the Timeshift pre-hook on other file systems.
* Writes a diagnosis after the update in the background (`sunshine-diagnose --after-update`), when available.

### How to undo it

There is no single undo for a full update. Use a restore point:

* btrfs: restart, choose **Sunshine OS snapshots** in the GRUB menu, boot the point from before the update,
  then restore it with Btrfs Assistant.
* Timeshift: open **Restore points** and restore the point from before the update.

Only the tools can be rolled back on their own:

```
$ sudo sunshine-toolsync rollback
```

If the update stopped halfway, run it again. Stopping does not break the system; the next run installs what is still missing.

---

## `sunshine-fix-pacman`

**What it is for.** Repair the package manager and the AUR helper. It clears a stale lock, checks `pacman.conf`,
removes obsolete repositories, resets a broken keyring, ranks the mirrors, repairs damaged databases, deletes corrupt
cached packages, installs the current `archlinux-keyring`, and reinstalls a broken `paru` or `yay`.

**When to use it.** pacman fails with keyring errors. The databases are damaged. A download was interrupted.
"Unable to lock database" appears although no update is running. The AUR helper does not start.
`sunshine-doctor` reports package manager problems.

It can run on the installed system and in the live session. In the live session it repairs the live environment;
changes there are lost when you restart the live session.
To repair an installed system, run `sunshine-rescue repair`, or open `sunshine-rescue chroot` and run
`sunshine-fix-pacman` inside it.

### Commands

| Command | What it does |
|---------|--------------|
| `sunshine-fix-pacman` | Run every repair step that is needed. |
| `sunshine-fix-pacman --reset-keys` | Force a full rebuild of the pacman keyring, even when it looks usable. |

Every step reports what really happened. If any step failed, the exit status is `1`.

### Example

```
$ sudo sunshine-fix-pacman
☀ Lock file
✔ no lock
☀ pacman.conf
✔ pacman.conf has core and extra
☀ Keyring
✔ keyring populated
☀ Mirrors
✔ mirrors ranked (rate-mirrors)
☀ Sunshine repository
✔ [sunshine] repository is configured
☀ Databases
✔ package databases synchronised
☀ Interrupted updates and cached packages
✔ archlinux-keyring is current
✔ package database is consistent
☀ AUR helper
✔ paru works

Done. Try the update again.
```

With `--reset-keys`:

```
$ sudo sunshine-fix-pacman --reset-keys
...
☀ Keyring
✔ keyring recreated and populated
...
Done. Try the update again.
```

A step that failed is shown as failed:

```
☀ Databases
✘ could not synchronise the package databases: failed retrieving file 'core.db' ...
...
✘ 1 step(s) failed: the package manager may still be broken (see above)
```

### What it changes on the system

* Removes `/var/lib/pacman/db.lck` when no pacman is running.
* Checks `core` and `extra` in `/etc/pacman.conf`. If they are missing and `/etc/pacman.conf.pacnew` exists,
  it keeps the old file as `/etc/pacman.conf.broken` and restores the packaged one.
* Removes these obsolete or unstable repositories when present: `community`, `community-testing`, `testing`,
  `core-testing`, `extra-testing`, `multilib-testing`, `staging`, `kde-unstable`, `gnome-unstable`.
  It keeps a backup as `/etc/pacman.conf.sunshine-backup` before the first removal.
* Clears the login lock (`faillock`) of every normal user.
* Uncomments `ParallelDownloads` when the setting is commented out in `/etc/pacman.conf`.
* Rebuilds the keyring when it is broken or when `--reset-keys` is given: it deletes `/etc/pacman.d/gnupg`
  (or empties it in the live session) and runs `pacman-key --init` and `pacman-key --populate`.
* Ranks the mirrors with `rate-mirrors`, or `reflector` when `rate-mirrors` is not installed.
  It keeps `/etc/pacman.d/mirrorlist.sunshine-backup`. If no mirror works, it restores the backup or adds the Arch geo mirror.
* Ensures the `[sunshine]` repository with `sunshine-repo ensure`.
* Removes damaged `*.db` files from `/var/lib/pacman/sync` and runs `pacman -Syy`.
* Deletes `*.part` files and `download-*` directories from `/var/cache/pacman/pkg`, and removes cached packages
  that fail the zstd test.
* Installs the current `archlinux-keyring` and checks the package database with `pacman -Dk`.
* Tests `paru` and `yay`. If one does not start, it reinstalls it.

### How to undo it

Most of it is a repair. The parts that can be undone:

```
$ sudo cp /etc/pacman.conf.sunshine-backup /etc/pacman.conf
$ sudo cp /etc/pacman.d/mirrorlist.sunshine-backup /etc/pacman.d/mirrorlist
```

These backup files exist only when the matching change was made. Restoring them brings back the removed repositories
and the old mirror list. That is not recommended: the removed repositories no longer exist or are unstable.

A keyring rebuild cannot be undone, but the new keyring is complete and current. Removed corrupt cache files and
`.part` files cannot be recovered; they download again when needed. Removed obsolete repositories are not added back
automatically.

---

## `sunshine-boot-repair`

**What it is for.** Repair the boot files of the system you are running: rewrite the kernel image, rebuild the initramfs,
reinstall GRUB for UEFI or BIOS, and rebuild the boot menu.

**When to use it.** GRUB starts but the menu is missing or broken. The kernel or initramfs is damaged and `sunshine-doctor --fix`
did not fix it. You changed the disk layout and GRUB no longer starts. A message says "premature end of file" or
"no such device" at boot, and the system still starts far enough to log in.

It refuses to run in the live session. Use `sunshine-rescue` there.

It is interactive: it asks for confirmation before it changes anything.

### Commands

There are no options. It asks one question:

```
$ sudo sunshine-boot-repair
Reinstall GRUB and rebuild the boot files of this system? [y/N] y
☀ Kernel and initramfs
kernel image rewritten
initramfs rebuilt
☀ GRUB
Done. Restart to test the boot menu.
```

Answer `n` or press Enter to stop without changes.

A failure stops the tool and keeps the old initramfs:

```
mkinitcpio failed (the old initramfs is untouched):
...
```

For UEFI it mounts `/boot/efi` if it is not mounted. If GRUB cannot write the NVRAM entry, it continues with the removable
fallback path and says so. For BIOS it installs GRUB on the disk that holds `/`.

### What it changes on the system

* Copies the kernel image of the first kernel found in `/usr/lib/modules` to `/boot/vmlinuz-linux`.
* Builds a new initramfs in a temporary file and moves it to `/boot/initramfs-linux.img` only when the build succeeded.
* On UEFI: runs `grub-install --target=x86_64-efi --efi-directory=/boot/efi`, first with `--bootloader-id=SunshineOS`
  and then with `--removable` (the `EFI/BOOT/BOOTX64.EFI` fallback path).
* On BIOS: runs `grub-install --target=i386-pc` on the parent disk of `/`.
* Runs `grub-mkconfig -o /boot/grub/grub.cfg`.

**Limitation.** It handles one kernel and always uses the `linux` file names. On a system whose only kernel is
`linux-lts`, the copied image is written to `/boot/vmlinuz-linux`, not `/boot/vmlinuz-linux-lts`.
Use `sunshine-kernel rebuild` or `sunshine-rescue initramfs` when you have several kernels or no `linux` kernel.

### How to undo it

There is no undo and no backup of the old initramfs. The operation is safe to repeat.
If the result is worse, boot another kernel or a restore point from the GRUB menu, then repair again.
If GRUB does not start at all, use `sunshine-rescue` from the live USB.

---

## Something is wrong, what do I do?

Start here:

* If you can log in to the desktop, open a terminal and run `sudo sunshine-doctor --fix`.
* If the screen is black but the computer runs, press `Ctrl+Alt+F3` to get a text console. Log in there.
  Press `Ctrl+Alt+F2` or `Ctrl+Alt+F1` to go back to the graphical screen.
* If the installed system does not boot at all, start the Sunshine OS live USB and use `sunshine-rescue`
  (situation 2). In the live session, it finds and mounts the installed system for you.
* Do not run two package tools at the same time. Wait for one to finish.

The commands below assume the tool names are in your `PATH`, which they are on Sunshine OS.

### 1. Black screen after an update

The system starts but the screen stays black. This is usually the graphics driver or the kernel.

1. Wait one minute and move the mouse. Some updates rebuild drivers and take a while.
2. Press `Ctrl+Alt+F3` and log in on the text console.
3. Run the health check and repair:

```
sudo sunshine-doctor --fix
```

4. If the computer has NVIDIA, repair the driver and the boot files, then restart:

```
sunshine-drivers detect
sudo sunshine-drivers install
sudo sunshine-doctor --fix
sudo sunshine-kernel rebuild
sudo reboot
```

5. If it is still black, boot the previous kernel. Restart, hold `Shift` (BIOS) or press `Esc` (UEFI) for the GRUB menu,
   choose **Advanced options for Sunshine OS**, then the previous kernel or `linux-lts`.
   When it boots, make that kernel the default:

```
sunshine-kernel list
sudo sunshine-kernel default linux-lts
```

6. If no kernel helps, boot a restore point from the GRUB menu (situation 12).
7. If you cannot get a text console at all, use the live USB and situation 2.

### 2. The system will not boot

You are in the live session. Nothing on the disk starts, or GRUB itself is broken.

1. Start the Sunshine OS live USB. Choose the live session.
2. Open a terminal in the live session.
3. See what the tool finds:

```
sudo sunshine-rescue list
```

It asks for the disk passphrase when the disk is encrypted.

4. Repair everything:

```
sudo sunshine-rescue repair
```

If several systems are found, name the root partition:

```
sudo sunshine-rescue repair /dev/nvme0n1p2
```

For an encrypted disk, without a prompt:

```
sudo SUNSHINE_LUKS_PASS='your passphrase' sunshine-rescue repair /dev/nvme0n1p2
```

5. If only GRUB is broken and the kernel is fine, repair only the boot loader:

```
sudo sunshine-rescue bootloader
```

6. If the kernel or initramfs is missing, repair only those:

```
sudo sunshine-rescue initramfs
```

7. Read the result. If every line is `✔`, restart and remove the USB:

```
sudo reboot
```

8. If a step failed, read the message and the log:

```
cat /tmp/sunshine-rescue.log
```

The log disappears when you restart. Copy it to the installed system before restarting:

```
sudo cp /tmp/sunshine-rescue.log /mnt/sunshine-rescue/root/
```

9. If the disk is damaged, check it without mounting it:

```
sudo sunshine-rescue fsck
```

It repairs ext4 and XFS while they are unmounted. On btrfs it only reports; it does not repair.

### 3. The update failed halfway

The update stopped with an error. The message usually says what to do.

1. Run the update again:

```
sudo sunshine-update-run
```

It removes a stale lock when no package manager is running. The next run installs what is still missing.

2. If it says another update is running, close the other window and try again.
3. If the lock stays although nothing is running, repair pacman first:

```
sudo sunshine-fix-pacman
sudo sunshine-update-run
```

4. If pacman reports database problems, run the health check and repair:

```
sudo sunshine-doctor --fix
```

5. If it stopped because the disk is full, see situation 6. The updater needs at least 1.5 GB free.
6. If it stopped because Arch Linux announced a manual step, read the news at <https://archlinux.org/news/>,
   do what it says, then run the update again.

Stopping an update does not break the system. The next run finishes the job.

### 4. pacman says keyring errors

Messages like `invalid or corrupted package (PGP signature)`, `signature from ... is unknown trust`,
or `key ... could not be looked up`.

1. Check the clock first. A wrong clock makes every signature look wrong:

```
timedatectl
```

If it is wrong, turn on time synchronisation and try again:

```
sudo timedatectl set-ntp true
```

2. Rebuild the keyring and repair pacman:

```
sudo sunshine-fix-pacman --reset-keys
```

3. Run the update again:

```
sudo sunshine-update-run
```

4. If it still fails, check for a broken mirror or a full disk (situation 6), then run the health check:

```
sudo sunshine-doctor --fix
```

### 5. I forgot my password

If you can still log in as another administrator, use that account:

```
sudo passwd your-user-name
```

If you cannot log in at all, use the live USB:

1. Start the live USB and open a terminal.
2. Run:

```
sudo sunshine-rescue passwd your-user-name
```

Type the new password twice. The tool also clears the login lock, so a lock from earlier wrong passwords is gone.

3. With several installed systems, name the root partition:

```
sudo sunshine-rescue passwd your-user-name /dev/nvme0n1p2
```

4. For an encrypted disk:

```
sudo SUNSHINE_LUKS_PASS='your disk passphrase' sunshine-rescue passwd your-user-name
```

5. Restart and log in with the new password.

For a script, `SUNSHINE_NEW_PASS` works, but the password is then visible in the process list and in the shell history.
Do not use it on a shared computer.

### 6. The disk is full

1. See where the space went:

```
df -h /
df -h /boot
```

2. Free space safely:

```
sudo sunshine-cleanup
```

It removes old package files, asks before removing unused packages, limits the journal to 200 MB, removes crash dumps,
and cleans old restore points on btrfs.

3. If you need more space, remove old kernels. Check the list first:

```
sunshine-kernel list
sudo sunshine-kernel remove linux-zen
```

Never remove the running kernel or the last kernel. The tool refuses anyway.

4. See which restore points take space:

```
sunshine-snapshot list
```

Delete an old one by its number or name:

```
sudo sunshine-snapshot delete 12
```

5. Check again:

```
df -h /
```

6. Run the update again. It needs 1.5 GB free:

```
sudo sunshine-update-run
```

### 7. Wi-Fi vanished after an update

The network worked before the update and now there is no Wi-Fi device or no networks.

1. Check whether the radio is blocked:

```
rfkill list
```

If it says `Soft blocked: yes`:

```
sudo rfkill unblock wifi
```

2. Check that NetworkManager is running and the radio is on:

```
nmcli radio wifi on
sudo systemctl restart NetworkManager
```

3. See whether the hardware is still detected:

```
lspci -nn | grep -i network
```

4. Let the driver tool look at it and install what is missing:

```
sunshine-drivers detect
sudo sunshine-drivers install
```

Broadcom cards get `broadcom-wl-dkms`. Intel and other cards use the kernel driver.

5. If the driver is a DKMS module and a new kernel was installed, build it and restart:

```
sudo sunshine-doctor --fix
sudo reboot
```

6. If it still does not work, boot the previous kernel from GRUB (situation 1, step 5) and run the update again
when the mirrors have the matching driver.

7. Use a cable or USB tethering for internet while you repair Wi-Fi.

### 8. NVIDIA: the screen is black

The computer starts, the disk works, but the graphical screen stays black. This is usually a kernel and NVIDIA driver mismatch.

1. Press `Ctrl+Alt+F3` and log in.
2. Check whether the driver is loaded:

```
lsmod | grep nvidia
nvidia-smi
```

If `nvidia-smi` is missing, the driver is not installed. See `sunshine-drivers detect`, then:

```
sudo sunshine-drivers install
sudo reboot
```

3. If the driver is installed but not loaded for the running kernel, boot the LTS kernel.
   In GRUB choose **Advanced options for Sunshine OS**, then `linux-lts`.
   When it boots, make it the default for now:

```
sunshine-kernel list
sudo sunshine-kernel default linux-lts
```

4. Repair the boot files for the current kernel:

```
sudo sunshine-doctor --fix
sudo sunshine-kernel rebuild
sudo reboot
```

5. If the screen is still black and the computer does not answer, use the live USB and situation 2:

```
sudo sunshine-rescue repair
```

6. The updater normally prevents this: it refuses to install a new `linux` when the matching `nvidia-open` is not
   in the same update. If you see that message, wait a few hours and update again.

### 9. The wrong kernel booted

1. See which kernel is running:

```
sunshine-kernel list
```

The line with `<- running now` is the one you are using.

2. Make the right kernel the default:

```
sudo sunshine-kernel default linux
```

3. Restart:

```
sudo reboot
```

4. To remove a kernel you do not want (not the running one, not the last one):

```
sudo sunshine-kernel remove linux-zen
```

5. In GRUB you can also pick a kernel once. With the setting that `sunshine-kernel default` writes
   (`GRUB_SAVEDEFAULT=false`), that one-time choice is not remembered after the next start.
   Use `sunshine-kernel default` to make it permanent.

6. If a kernel does not boot after an update, boot the older one, then rebuild its boot files:

```
sudo sunshine-kernel rebuild
```

### 10. I want another desktop

1. See what is available and what is installed:

```
sunshine-desktops list
```

2. Install one, for example Xfce:

```
sudo sunshine-desktops install xfce
```

This needs internet and can take a while. On btrfs it makes a restore point first.

3. Log out. At the login screen, choose the new session in the session menu, then log in.
4. To make it the preselected session:

```
sudo sunshine-desktops default xfce
```

This writes the SDDM state file. If no login screen appears at all, enable it:

```
sudo systemctl enable --now sddm
```

5. Remove it again when you do not want it:

```
sudo sunshine-desktops remove xfce
```

Plasma stays. Shared packages stay. Your files stay.

### 11. A game runs slow

1. See what is installed and whether the GPU is detected:

```
sunshine-gaming status
sunshine-gaming gpu
```

2. Install the missing graphics and gaming packages:

```
sudo sunshine-gaming install full
```

Use `sudo sunshine-gaming install` for the base set only.

3. Apply the game tuning:

```
sudo sunshine-gaming tune
sudo sunshine-performance on
```

Log out and in again, because the Gamemode group membership needs a new session.

4. Start the game through the wrapper. In Steam, **Properties**, **Launch options**:

```
sunshine-game-run --hud %command%
```

The overlay shows the FPS, the GPU and CPU load, and the frame time. That tells you what is slow.

5. On a hybrid laptop, make sure the game uses the NVIDIA card. In Steam launch options:

```
sunshine-game-run prime-run %command%
```

`prime-run` comes with `nvidia-prime`, which `sunshine-drivers install` adds on hybrid laptops.

6. Compare the system numbers before and after tuning:

```
sunshine-performance bench
```

7. Check in the game itself: lower shadows and textures first, then try another Proton version in Steam,
   **Properties**, **Compatibility**.

### 12. I want to go back to yesterday

You want the system as it was before an update or a change.

**If the system still starts:**

1. See the restore points:

```
sunshine-snapshot list
```

2. Make a point now, before you change anything:

```
sudo sunshine-snapshot create "before I go back"
```

3. Open the graphical restore tool:

```
sunshine-snapshot restore
```

On btrfs this opens Btrfs Assistant. On other file systems it opens Timeshift.
Choose the point from yesterday and restore it.

**If the system does not start, but GRUB does:**

1. Restart and open the GRUB menu.
2. Choose **Sunshine OS snapshots**.
3. Choose the point from before the change and boot it.
4. Restore that point from the booted snapshot with Btrfs Assistant (`sunshine-snapshot restore`).

**If GRUB does not start either:**

1. Start the live USB.
2. Repair the boot loader first (situation 2):

```
sudo sunshine-rescue bootloader
```

3. Restart and use the GRUB snapshot menu as above.
   If the snapshots do not appear in the menu, run `sudo sunshine-rescue bootloader` from the live session.
   It rebuilds the GRUB menu, and the snapshot entries come back when `grub-btrfs` is set up.

**Only the Sunshine tools are broken:**

```
sudo sunshine-toolsync rollback
```

This puts back the previous tool files. It does not undo package updates or migrations.

**After a full update**, a restore point is made automatically before the package transaction when snapshots
are set up (and after it too on btrfs with `snap-pac`). Pick the point from before the update.
