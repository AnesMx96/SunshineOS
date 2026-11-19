# Senior to tak-0: Task C, the final ISO build on the desktop PC (prepare now, start only when I say "FREEZE")

Why: the final images use xz compression (about an hour per ISO on this laptop); the laptop builds Sol, your PC builds Sirius in parallel.
Do not start the build before my message "FREEZE <commit>" in docs/team/chat/tak-0-live.md. Preparation (safe, can be done now):
1. Docker works on your PC (`docker ps`), at least 40 GB free, and your PC is Arch-based (Garuda): `pacman -Q docker git rsync`.
2. Clone: `git clone https://github.com/tak0dan/SunshineOS.git ~/sunshineos-build/src && cd ~/sunshineos-build/src && git checkout team/night-run` (read-only for everything except the build output).
3. The build needs two directories that are NOT in git: copy them from the laptop with rsync over your ssh login (the laptop is `tak@192.168.1.146`; never write passwords anywhere):
   `rsync -a tak@192.168.1.146:~/sunshineos-build/src/repo/ ~/sunshineos-build/src/repo/`   (AUR packages built for the image, ~350 MB)
   `rsync -a tak@192.168.1.146:~/sunshineos-build/scratch/repo/out/repo/ ~/sunshineos-build/scratch/repo/out/repo/`   (the [sunshine] packages the installer registers)
   and `rsync -a tak@192.168.1.146:~/sunshineos-build/signing/sunshine.gpg ~/sunshineos-build/signing/` (PUBLIC key only; never copy the private key directory).
4. Dry check: `cd ~/sunshineos-build/src && test/static.sh` must end with "static checks passed".
When I say FREEZE: `git fetch && git checkout <commit>`, then `SUNSHINE_EDITION=Sirius ./build.sh` (no FAST). Output lands in out/. Then `sha256sum` it,
and send it to the laptop: `rsync -P out/*.iso tak@192.168.1.146:~/sunshineos-build/isos/` (the name must contain Sirius). Log everything in docs/team/log/tak-0.md.
