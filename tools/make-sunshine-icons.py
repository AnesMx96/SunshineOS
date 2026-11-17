#!/usr/bin/env python3
"""Panel and tray icons of the Sunshine theme: puts the colours of overlay/system/.../desktoptheme/Sunshine/icons into the Sunshine palette
(white strokes -> cream, loud red/green/blue/orange -> the palette's soft red, green and the orange accent) and replaces the Windows start logo with the
Sunshine mark. Idempotent. usage: python3 tools/make-sunshine-icons.py   (also mirrors into profile/airootfs)"""
import colorsys, gzip, os, pathlib, re, shutil
root = pathlib.Path(__file__).resolve().parent.parent
D = root / "overlay/system/usr/share/plasma/desktoptheme/Sunshine/icons"
P = root / "profile/airootfs/usr/share/plasma/desktoptheme/Sunshine/icons"
CREAM, ACCENT, RED, GREEN, YELLOW = "#efe5d0", "#ff9654", "#e06c75", "#7fae6a", "#e5c07b"

PALETTE = {CREAM, ACCENT, RED, GREEN, YELLOW}

def mapc(m):
    h = m.group(1)
    if len(h) == 3: h = "".join(c * 2 for c in h)
    if "#" + h.lower() in PALETTE: return m.group(0)         # the palette's own colours stay (makes a second run change nothing)
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hh, l, s = colorsys.rgb_to_hls(r, g, b); hh *= 360
    if s < .12 and l > .88: return CREAM                      # white / near white strokes and fills
    if s < .6 or l < .2: return m.group(0)                   # greys, darks and soft colours (incl. the cream itself) stay
    if hh >= 345 or hh < 15: return RED
    if hh < 45: return ACCENT
    if hh < 70: return YELLOW
    if 85 <= hh < 170: return GREEN
    if 185 <= hh < 265: return ACCENT                         # blues (the Windows logo, links)
    return m.group(0)

COL = re.compile(r"#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})(?![0-9a-fA-F])")
START = f'''<?xml version="1.0" encoding="UTF-8"?>
<!-- The Sunshine mark: a four-pointed sparkle in a ring (the logo of the Welcome window), accent orange. -->
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <circle cx="32" cy="32" r="27" fill="none" stroke="{ACCENT}" stroke-width="3"/>
  <path d="M32 12 C33.6 24 40 30.4 52 32 C40 33.6 33.6 40 32 52 C30.4 40 24 33.6 12 32 C24 30.4 30.4 24 32 12 Z" fill="{ACCENT}"/>
</svg>
'''

def main():
    changed = 0
    for f in sorted(D.iterdir()):
        if f.suffix not in (".svg", ".svgz"): continue
        if f.stem == "start": continue
        raw = f.read_bytes(); gz = f.suffix == ".svgz"
        try: txt = (gzip.decompress(raw) if gz else raw).decode("utf-8")
        except Exception: continue
        new = COL.sub(mapc, txt)
        if new != txt:
            f.write_bytes(gzip.compress(new.encode()) if gz else new.encode()); changed += 1
    for old in D.glob("start.*"): old.unlink()
    (D / "start.svg").write_text(START)
    for r, ds, fs in os.walk(D):
        os.chmod(r, 0o755)
        for x in fs: os.chmod(os.path.join(r, x), 0o644)
    if P.exists(): shutil.rmtree(P)
    shutil.copytree(D, P)
    print(f"{changed} icons recoloured, start.svg replaced")

if __name__ == "__main__":
    main()
