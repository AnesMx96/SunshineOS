# Live VM view / control bridge

The host is headless, so VirtualBox has no visible desktop window. This tiny HTTP server exposes:

- `http://127.0.0.1:8765/` (or `http://10.2.1.210:8765/` from the LAN)
- `/frame.png` — refreshed `VBoxManage controlvm SuOS-1.5-Test screenshotpng` capture
- `/key/<name>` — virtual HID key via `VBoxManage controlvm keyboardputscancode` (works with Wayland)
- `/type?text=...` — virtual HID text
- `/click?x=&y=` — Xwayland mouse click via `xdotool` (only for X11 apps)

Remote tunnel: `ssh -L 8765:127.0.0.1:8765 <host>`, then open `http://127.0.0.1:8765/`.

Start manually with:

```bash
cd /home/niktro2/SunshineOS/logs/VM_Test_Report_2026-11-19/live-view
nohup python3 server.py > server.log 2>&1 < /dev/null &
```
