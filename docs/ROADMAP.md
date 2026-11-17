# Roadmap

Everything requested so far for Sunshine OS, with its status. `[x]` done and pushed, `[~]` partly done, `[ ]` not started. Items marked **note** have a
design remark that needs a decision or has a limit worth knowing about.

## Boot and installer
- [x] GRUB: Ventoy GRUB2-mode crash and the UEFI theme error fixed (graphics mode only when the theme is readable on the ISO)
- [x] GRUB theme panel redone as a 9-slice frame (no longer runs off the screen; checked at 1024x768 and 1920x1080)
- [x] Installer failed at the bootloader step (`42_nixos` printed a mount warning into grub.cfg); fixed, with smoke-test checks
- [x] Packages built from the AUR were root-only (Darkly, GTK theme, `uni`, browser ...): repaired, build fixed, repair runs in `make-iso.sh`
- [x] Btrfs layout mirrors the maintainer's PC (@, @home, @root, @srv, @cache, @log, @tmp, noatime + zstd; Snapper adds .snapshots)
- [x] Snapper (btrfs) and Timeshift/rsync (other file systems) behind `sunshine-snapshot`; daily timer, pre-update restore point, doctor and Welcome support
- [~] Installer: apps list with groups and a checkbox per app (Calamares `netinstall`, generated from `catalogue/apps.toml`; the wiring is done and its files validate, but it has not been run in a real installer yet: needs an ISO rebuild)
- [~] Installer: app selection, grouped (same list; see "Catalogue")

## Look and feel
- [x] Terminals (konsole, kitty, ghostty, alacritty, foot) 20% transparent in the Sunshine palette
- [x] Dolphin/Darkly settings carried over (80% view and sidebar opacity); Darkly installed in the live image
- [x] fastfetch: Sunshine logo and palette through a system-wide config
- [x] Prompt: `✘ command not found 127` instead of `? 127`
- [ ] Plasma theme renamed "Sunshine theme" (not "Sunshine Win11"), dark, a redesigned Windows 11 look matching the system; currently reported as broken, icons to fix
- [ ] It is the default theme in the live session and in every session unless the user changes it
- [ ] Application menu 15% transparent
- [ ] Top bar like Garuda Mokka, with graph widgets for network, disk space, CPU and GPU usage
- [ ] Plasma welcome (splash) animation: the Sunshine logo animation
- [ ] Kando with the Sunshine theme; pamac with a matching theme
- [ ] Firefox is the default browser of the live session (Zen leaves the live image; it stays in the catalogue)

## Tools (TUI/CLI)
- [ ] ASCII graph animation while an action runs; the OS animation with the result when everything succeeded (no animation on serious errors)
- [ ] Warm default messages with sun and tea emojis; a config switch for it
- [ ] Ukrainian translation of all Sunshine tools, selectable in the apps and in the config; default Ukrainian when the chosen language is Ukrainian or the installation happened in Toulouse, France
- [ ] Repair of pacman and the AUR helper taken from Garuda and EndeavourOS (their approach, adapted)
- [x] The `[sunshine]` repository is part of every system and of the repair tools (`sunshine-repo`, doctor, fix-pacman, update-run, pacman hook)
- [ ] "Restore visuals" button in sunshine-welcome: pull themes/configs from the repository into a directory (new names) and apply them; offline = apply the existing ones
- [ ] Themes and configs stored in the repository (assets repo), pulled on update

## Diagnostics
- [ ] `~/` log directory (up to 20 logs), written by a diagnosis script run 10 minutes after each graphical login and after every update through Sunshine tools
- [ ] Checks: performance, temperatures, package integrity, conflicts, orphans, disk space, packages in general, file system sanity, initramfs (initrd/dracut), daemons and services, snapshots

## Editors, git
- [ ] nano and Kate plugins: syntax highlighting and suggestions for C, C++, C#, Java, JavaScript, MySQL/MariaDB, Nix, Python, Rust, Ruby, Lua, shell
- [ ] git with aliases; a GitHub GUI app. **note:** GitHub Desktop has no official Linux build; candidates are the community build from the AUR or `gh` with `gitg`/GitKraken

## Catalogue (installer groups and first-update apps)
Status: the catalogue (47 apps, all package names verified against the official repos and the AUR), the 47 `sunshine-app-*` meta-packages in the `[sunshine]` repo, the `sunshine-apps` queue (AUR via the AUR helper at the first online start, setup scripts, web apps), `sunshine-webapp`, and the first-update step in `sunshine-update` are done and tested in a clean container. Web wrappers and GitHub Desktop (AUR `github-desktop-bin`) are included. Still to do: the Kando and Pamac themes (wait for the Sunshine theme), real-installer test, and a store view of the catalogue.
Installed on the very first update: Zen browser, LibreOffice.
Groups to offer in the installer (each de-selectable):
- **System:** BlackArch repository, printer support (CUPS), linux-zen kernel, linux-lts kernel, wine, proton-ge, bottles, VirtualBox, QEMU, Piper
- **Dev:** vim, neovim, VS Code, VSCodium, PyCharm, Sublime, NetBeans, Eclipse, MySQL Workbench (set up for MariaDB with a default user and the installer's password), GitHub GUI app, GitKraken, alacritty, ghostty
- **Internet:** Firefox, Brave, Tor Browser (configured, with a low-level firewall), Chrome, Chromium, AnyDesk, Discord, Outlook, WhatsApp. **note:** Outlook and WhatsApp "for Linux" are web wrappers
- **Media/Games:** Steam, VLC, mpv, Gwenview (default image and video viewer), Spotify, Netflix (web wrapper), GOG launcher (Heroic/Minigalaxy), Epic launcher (Heroic)
- **Notes/AI:** Obsidian, Notion (wrapper), Claude (AUR CLI and a desktop app), Kando, pamac
All of them go in a catalogue file the installer and `sunshine-store` read; AUR-only entries are built into the `[sunshine]` repo.

## Distribution of the Sunshine packages
- [x] `sunshineos-repo` publishes `sunshine-base`, `sunshine-payload` and the AUR-built packages as the `[sunshine]` repository
- [ ] The ISO installs `sunshine-base` and `sunshine-payload` from that repository instead of copying their files into the image, so tool updates reach installed systems through normal pacman updates. Today an ISO-installed system owns those files without a package, and `sunshine-converge` would hit file conflicts there.
- [ ] Sign the repository (it is `Optional TrustAll` for now)
