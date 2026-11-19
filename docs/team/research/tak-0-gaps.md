# Breakage catalogue gaps vs sunshine-gaming/performance scope (by tak-0, 2026-11-19)

Research note, not a replacement for docs/team/breakage-catalogue.md (45 items, A-E). Checked `sunshine-gaming` and
`sunshine-performance`: both are install/apply-time only (`install`, `tune`, `on`/`off`, `status`, `bench`) — neither has
a doctor-style detect/repair for drift after the fact. The 45-item catalogue has no gaming, audio, Flatpak, power or
TPM/LUKS2/systemd-boot section. Given the stated goal ("gamers over Garuda"), gaming/audio breakage is probably the
highest-value gap. Numbering continues from the existing catalogue (items 1-45) so this can be appended there directly
if the senior wants to merge it; I have not touched breakage-catalogue.md myself.

## F. Gaming / Steam / Proton

46. **Steam won't start after update ("steamwebhelper" crash / missing 32-bit libs).** DETECT `steam 2>&1 | grep -iE 'error while loading shared|steamwebhelper'`; `pacman -Qk lib32-*` for altered/missing. REPAIR ensure `multilib` enabled (`sunshine-gaming` already does this at install, but a user can disable `[multilib]` later): `pacman -S --needed lib32-mesa lib32-vulkan-icd-loader` + vendor-specific lib32 driver; clear `~/.local/share/Steam/package/steamwebhelper.deb` for Steam to refetch. Risk low.
47. **GPU driver/Vulkan mismatch after a driver switch (proprietary<->open NVIDIA, or AMD mesa update) -> Proton games black-screen or "no Vulkan devices found".** DETECT `vulkaninfo --summary 2>&1 | grep -c deviceName`; compare `nvidia-smi` driver version to `pacman -Qi nvidia-dkms`. REPAIR rebuild DKMS module for the running kernel (`dkms autoinstall`), reinstall matching `lib32-nvidia-utils`/`vulkan-icd-loader` pair, `mkinitcpio -P`. Overlaps catalogue #30/#28 but Vulkan-specific symptom is different from a black X session. Risk medium.
48. **Proton/Wine prefix corrupted (game won't launch, "This app needs Visual C++").** DETECT per-game: `protontricks -l` exits nonzero, or prefix dir missing `system.reg`. REPAIR `protontricks --force -c "wineboot -u" APPID` or delete+recreate the one prefix (never touch other prefixes or the user's save-game-bearing `compatdata` wholesale). Never auto: delete a prefix without a `.bak` copy first, since saves can live under `pfx/drive_c/users/steamuser`.
49. **Gamescope/Gamemode installed but not applied (session launched without them, no FPS gain, laptop still on balanced governor).** DETECT `gamemoded -s 2>&1 | grep -i inactive`; check `sunshine-performance status` vs whether the gaming group/udev rule from `sunshine-gaming tune` is actually present (`getent group gamemode`, `/etc/udev/rules.d/*gamemode*`). REPAIR re-run `sunshine-gaming tune` (idempotent per its own design) and tell the user to add `gamemoderun %command%` in Steam launch options if missing — that part cannot be automated, it's per-game Steam config. Risk none.
50. **MangoHud overlay doesn't show (env var not exported, or config path wrong after a MangoHud update changed the config dir).** DETECT `env | grep MANGOHUD`; `ls ~/.config/MangoHud/MangoHud.conf`. REPAIR re-source the Sunshine profile.d snippet; recreate the default config from the packaged example if the user's is 0 bytes. Risk none.
51. **Controller not detected in-game (udev rule/group missing after a kernel or systemd update reset permissions).** DETECT `ls -l /dev/input/js0 2>/dev/null`; `groups $USER | grep -q input`. REPAIR `usermod -aG input $USER` (session restart required, tell the user), reinstall `game-devices-udev` if the package is what ships the rule. Low.

## G. Audio (PipeWire)

52. **No sound after update (PipeWire/WirePlumber crash-looping or socket stale).** DETECT `systemctl --user is-active pipewire pipewire-pulse wireplumber`; `pactl info 2>&1 | grep -i 'connection refused'`. REPAIR `systemctl --user restart pipewire wireplumber pipewire-pulse`; if the socket is stuck, `rm -rf $XDG_RUNTIME_DIR/pulse $XDG_RUNTIME_DIR/pipewire-0` then restart (per-user runtime dir only, never system files). Risk low — this is probably the single most common "my sound stopped working" ticket on any desktop distro and is currently unhandled.
53. **Wrong default sink after a USB headset/HDMI reconnect (audio keeps going to the old device).** DETECT compare `pactl get-default-sink` to `pactl list short sinks` for a now-present device that isn't default. REPAIR not safely automatable (user preference) — surface it via `sunshine-doctor` as an informational line only, never auto-switch. Risk: none if left informational.
54. **Bluetooth audio device won't pair/reconnect (bluez + pipewire module mismatch).** DETECT `systemctl is-active bluetooth`; `pactl list modules | grep -c bluez5`. REPAIR `systemctl restart bluetooth`; ensure `pipewire-pulse` + `lib32-` not relevant here but `bluez-utils` present; re-trust/re-pair cannot be automated (needs the device in pairing mode) — doctor should only detect and point at `sunshine-doctor`'s message, not auto-pair.

## H. Flatpak / sandboxed apps

55. **Flatpak apps fail to launch ("No remote refs found", runtime missing after a Flathub schema change).** DETECT `flatpak list --app 2>&1 | grep -i error`; per-app `flatpak info APPID` missing runtime. REPAIR `flatpak repair`; `flatpak update` for the missing runtime. Risk low.
56. **GPU acceleration missing inside Flatpak (freedesktop Mesa extension out of sync with host driver after a driver upgrade) -> software rendering inside sandboxed apps only.** DETECT `flatpak run --command=glxinfo org.freedesktop.Platform.GL... 2>&1 | grep -i llvmpipe` (or simpler: compare installed `org.freedesktop.Platform.GL32` extension version to host mesa). REPAIR `flatpak update` the GL extension. Medium (easy to misdiagnose as catalogue #30, but the host session is fine — only sandboxed apps are affected, which is the distinguishing symptom worth documenting so sunshine-doctor doesn't send the user down the NVIDIA-driver path by mistake).

## I. Power management / laptops

57. **TLP/power-profiles-daemon conflict (both installed, or both disabled -> no battery saving / fans always on).** DETECT `systemctl is-enabled tlp power-profiles-daemon 2>/dev/null | sort | uniq -c` (both "enabled" is the bug). REPAIR disable one (prefer `power-profiles-daemon` since it's what KDE's battery widget talks to) via `systemctl disable --now tlp`. Low but explains a very common "fan noise"/"battery drains fast" complaint after a user installs TLP from a forum post on top of the default.
58. **Suspend/resume broken (GPU doesn't wake, black screen after lid close) — NVIDIA specific sleep services not enabled.** DETECT for NVIDIA: `systemctl is-enabled nvidia-suspend nvidia-resume nvidia-hibernate`. REPAIR `systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service` + `nvidia_drm.modeset=1 NVreg_PreserveVideoMemoryAllocations=1` kernel/module option (also ties into catalogue #30). Medium.

## J. Secure Boot / TPM / LUKS2 (catalogue only covers LUKS1 and generic Secure Boot)

59. **LUKS2 + TPM2 auto-unlock stops working after a kernel/initramfs update (systemd-cryptenroll token present but initramfs hook missing it) -> falls back to asking for the passphrase, or hangs.** DETECT `systemd-cryptenroll /dev/DISK --tpm2-device=list` shows an enrolled slot but `lsinitcpio` the current initramfs lacks `sd-encrypt`/`tpm2`. REPAIR ensure `HOOKS` has `sd-encrypt` (not the older `encrypt`) when TPM2 enrollment is used, `mkinitcpio -P`. Never auto: re-enroll or wipe a LUKS2 token slot. Risk medium — distinct from catalogue #9 which is LUKS1/keyfile only.
60. **Secure Boot enrolled with `sbctl`, then a kernel/boot binary update leaves it unsigned (sbctl didn't re-sign on a pacman hook, or the hook is missing).** DETECT `sbctl verify | grep -v '✓'` (unsigned files). REPAIR `sbctl sign-all` (only files already tracked — never auto-enroll new keys or change Secure Boot state itself). This is a sharper version of catalogue #11 and matches what CachyOS's `sbctl-batch-sign` pacman hook already automates (seen in research/CachyOS-Settings) — worth adopting the same hook here. Low.

## Suggested priority if the senior wants to fold any of this in

Highest value for an ordinary user, cheapest to implement, matching the existing "25 ranked" style in ai-comparison.md:
52 (no sound) > 46 (Steam won't start) > 57 (TLP/power-profiles-daemon double-enabled) > 60 (Secure Boot pacman hook, CachyOS already has the pattern) > 47 (Vulkan/driver mismatch) > 56 (Flatpak GL extension) > 59 (TPM2/LUKS2 initramfs hook).

Not touched: breakage-catalogue.md, any agent's worktree/branch, any file outside docs/team/research/tak-0-gaps.md and my own log.
