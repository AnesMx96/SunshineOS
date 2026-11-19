# Test plan — Sunshine OS 13.4.7.1.5 (2026-11-19)

Fresh VM `SuOS-1.5-Test` (UUID `a0c9d2e0-41c3-417a-8907-9b92f34fe094`): 4 vCPU, 5120 MiB RAM,
BIOS, NAT, 20 GiB SATA disk, DVD attached from the downloaded ISO. Guest access via
`VBoxManage guestcontrol` with `sunshine`/`sunshine`.

Same workflow as the 2026-11-18 report, applied to the new release:

1. Download/join/verify the latest ISO (`release-info.md`).
2. Live-session basics: kernel, OS identity, storage, services, credentials, screenshots.
3. Updates: `pacman -Syu`, AUR/tool update path, database integrity, overlay capacity.
4. OS-specific tools: identity, info, diagnose, doctor (`--fix`), fix-pacman, snapshot,
   restore-visuals, welcome/toolbox/store, Calamares GUI, CLI installer.
5. Theme/design dissection: Qt/KDE, GTK, icons, wallpaper, panel, installer branding;
   mark poor/questionable decisions.
6. Installation to disk, boot from disk, verification of tools/theme/packages after update.
7. Every step appended to `remediation.log`, committed and pushed separately.

Evidence layout mirrors `logs/VM_Test_Report_2026-11-18/`: `raw/`, `system-logs/`,
`screenshots/` (with `ocr.txt`), `fixes/`, `README.md`, `commands-and-outputs.log`.
