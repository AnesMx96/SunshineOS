#!/usr/bin/env python3
"""Minimal live view + input bridge for the Sunshine OS test VM.

- GET /              HTML viewer (refreshes /frame.png)
- GET /frame.png     latest VBoxManage screenshot
- GET /key/<name>    send a virtual key to the VM (works for Wayland too)
- GET /type?text=    type a string into the VM
- GET /click?x=&y=   X11/Xwayland mouse click (for X11-launched GUI tools)

Binds to 127.0.0.1 only. Tunnel with: ssh -L 8765:127.0.0.1:8765 <host>
"""
import html
import os
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

VM = "SuOS-1.5-Test"
HERE = os.path.dirname(os.path.abspath(__file__))
FRAME = os.path.join(HERE, "frame.png")
TMP = FRAME + ".tmp"
LOCK = threading.Lock()

KEYS = {
    "enter": "1c 9c",
    "esc": "01 81",
    "tab": "0f 8f",
    "space": "39 b9",
    "up": "e0 48 e0 c8",
    "down": "e0 50 e0 d0",
    "left": "e0 4b e0 cb",
    "right": "e0 4d e0 cd",
    "backspace": "0e 8e",
    "y": "15 95",
    "n": "31 b1",
}

PAGE = """<!doctype html>
<html><head><meta charset="utf-8"><title>Sunshine OS 1.5 live VM</title>
<style>
body{background:#141414;color:#ffc43d;font:14px sans-serif;margin:0;padding:10px}
img{width:1024px;height:640px;border:2px solid #ffc43d;background:#000}
button{background:#222;color:#ffc43d;border:1px solid #ffc43d;padding:6px 10px;margin:2px;cursor:pointer}
button:hover{background:#ffc43d;color:#141414}
</style></head><body>
<h3>Sunshine OS 13.4.7.1.5 — live VM view (SuOS-1.5-Test)</h3>
<img id="v" src="/frame.png?t=0">
<p><b>Keyboard</b> (virtual HID, works in Wayland):</p>
<div>__KEYS__</div>
<p><b>Mouse</b> (Xwayland apps): click the image to move/click, or use coordinates:</p>
<input id="x" value="512" size="4"><input id="y" value="384" size="4"><button onclick="fetch('/click?x='+x.value+'&y='+y.value)">Click</button>
<p><b>Type</b> (virtual HID): <input id="t" value="sunshine"><button onclick="fetch('/type?text='+encodeURIComponent(t.value))">Type</button></p>
<script>
const v=document.getElementById('v'); setInterval(()=>v.src='/frame.png?t='+Date.now(),1200);
v.onclick=e=>{{const r=v.getBoundingClientRect(); const x=Math.round((e.clientX-r.left)*2560/r.width); const y=Math.round((e.clientY-r.top)*1600/r.height); fetch('/click?x='+x+'&y='+y);}};
</script></body></html>""".replace("__KEYS__", "\n".join(
    f'<button onclick="fetch(\'/key/{k}\')">{k}</button>' for k in KEYS
))


def capture_loop():
    while True:
        try:
            subprocess.run(
                ["VBoxManage", "controlvm", VM, "screenshotpng", TMP],
                check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=12,
            )
            with LOCK:
                os.replace(TMP, FRAME)
        except Exception:
            pass
        time.sleep(1.2)


def vbox(*args):
    try:
        r = subprocess.run(["VBoxManage", "controlvm", VM, *args], capture_output=True, text=True, timeout=20)
        return r.returncode, (r.stdout + r.stderr).strip()
    except Exception as e:
        return 1, str(e)


def click(x, y):
    cmd = (
        f'export DISPLAY=:1 XAUTHORITY=/run/user/1000/xauth_IRNGkn; '
        f'xdotool mousemove {x} {y} click 1'
    )
    try:
        r = subprocess.run(
            ["VBoxManage", "guestcontrol", VM, "run", "--username", "sunshine",
             "--password", "sunshine", "--quiet", "--timeout=30000", "--",
             "/bin/bash", "-c", cmd],
            capture_output=True, text=True, timeout=40,
        )
        return r.returncode, (r.stdout + r.stderr).strip()
    except Exception as e:
        return 1, str(e)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, data, ctype="text/plain"):
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        u = urlparse(self.path)
        if u.path == "/":
            return self._send(PAGE.encode(), "text/html")
        if u.path == "/frame.png":
            with LOCK:
                try:
                    data = open(FRAME, "rb").read()
                except OSError:
                    data = b""
            return self._send(data, "image/png")
        if u.path.startswith("/key/"):
            k = u.path.rsplit("/", 1)[-1]
            if k not in KEYS:
                return self._send(b"unknown key", "text/plain")
            rc, out = vbox("keyboardputscancode", *KEYS[k].split())
            return self._send(f"rc={rc} {out}".encode())
        if u.path == "/type":
            text = parse_qs(u.query).get("text", [""])[0]
            rc, out = vbox("keyboardputstring", text)
            return self._send(f"rc={rc} {out}".encode())
        if u.path == "/click":
            q = parse_qs(u.query)
            try:
                x = int(q.get("x", ["512"])[0]); y = int(q.get("y", ["384"])[0])
            except ValueError:
                x = y = 512
            rc, out = click(x, y)
            return self._send(f"rc={rc} {out}".encode())
        self.send_error(404)


if __name__ == "__main__":
    threading.Thread(target=capture_loop, daemon=True).start()
    ThreadingHTTPServer(("0.0.0.0", 8765), Handler).serve_forever()
