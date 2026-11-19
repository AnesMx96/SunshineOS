# Something is wrong. What do I do?

Every command below exists in Sunshine OS and was run in a virtual machine. Start at the top; stop when the problem is gone.

| Situation | Do this |
|---|---|
| **The computer does not start** (black screen, GRUB error, "no initramfs") | Boot the Sunshine OS USB stick, choose "live session". Open the Welcome window and click **Repair an installed system** (or run `sudo sunshine-rescue repair`). It finds your system, checks the disk, rebuilds the kernel files and the boot menu, and keeps a log in `/var/log/sunshine/` on your system. Restart without the stick. |
| **Black screen right after the logo** | At the boot menu choose **safe graphics (nomodeset)**. Then run `sudo sunshine-drivers detect`; NVIDIA owners: `sudo sunshine-drivers install`. |
| **Forgot my password** | Live session: `sudo sunshine-rescue passwd YOURNAME`. |
| **An update broke something** | At the boot menu choose a restore point (btrfs systems), or run `sunshine-snapshot list` and restore. Then `sudo sunshine-doctor --fix`. |
| **The update stops with key or database errors** | `sudo sunshine-fix-pacman`, then `sunshine-update` again. |
| **The desktop looks wrong** (missing icons, no panel, wrong colours) | `sunshine-reset-plasma` (your settings are saved first; `--undo` brings them back). |
| **No sound / no network / no picture on the second monitor / slow graphics / disk full** | `sunshine-fix audio`, `sunshine-fix network`, `sunshine-fix display`, `sunshine-fix gpu`, `sunshine-fix storage` (or `sunshine-fix all`). |
| **I don't know what is wrong** | `sudo sunshine-doctor` (read-only check) and `sunshine-support` (makes a report with your personal data removed, to send to whoever helps you). |
| **Wrong kernel boots / I want another kernel** | `sudo sunshine-kernel list`, `sudo sunshine-kernel install linux-lts`, `sudo sunshine-kernel default linux-lts`. |
| **Games run badly** | `sudo sunshine-gaming install`, `sudo sunshine-performance on`; in Steam launch options: `sunshine-game-run %command%`. |
| **I want another desktop** | `sudo sunshine-desktops list`, `sudo sunshine-desktops install gnome`; choose it at the login screen. |
| **I want to protect my files** | `sunshine-backup init /path/to/backup-folder`, then `sunshine-backup run`; `sunshine-backup schedule on` for a daily backup. |

## Good to know
- `sudo sunshine-doctor --fix` takes a restore point first (btrfs), repairs only what is safe and never removes your files.
- Ukrainian: [FIRST-AID.uk.md](FIRST-AID.uk.md)
- Tools update themselves: `sunshine-update` first pulls the newest signed tools. `sudo sunshine-toolsync status` shows the version, `rollback` undoes the last tool update.
- The firewall is on (incoming connections denied, KDE Connect and discovery allowed). Open a port with `sudo ufw allow PORT`; turn it off for good with `sudo touch /etc/sunshine/no-firewall`.
- A repair that cannot be done safely stops and says so; it never guesses a partition or overwrites `fstab` blindly.
