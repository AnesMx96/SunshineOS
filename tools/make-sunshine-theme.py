#!/usr/bin/env python3
"""Builds the "Sunshine theme" from Win11OS-kde (https://github.com/yeyushengfan258/Win11OS-kde, GPL-3.0, the dark variant; KDE Store item 2106375):
its Plasma desktop theme, Aurorae window frame and Kvantum widget style, re-coloured into the Sunshine palette (blue -> orange accent, white -> cream, grey ->
indigo ramp) with Sunshine's own rules on top: menus, popups and the taskbar are 15% transparent (85% opaque). The SDDM parts of Win11OS-kde are NOT used.
Output (and a mirror in profile/airootfs):
  usr/share/plasma/desktoptheme/Sunshine   usr/share/aurorae/themes/Sunshine   usr/share/Kvantum/Sunshine
usage: python3 tools/make-sunshine-theme.py [path to a Win11OS-kde checkout]     (default: cache/win11os-kde, cloned at the pinned commit)"""
import colorsys, gzip, json, os, pathlib, re, shutil, subprocess, sys
root = pathlib.Path(__file__).resolve().parent.parent
PIN = "9f021c3"      # Win11OS-kde commit this was built from
SRC = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else root / "cache/win11os-kde"
OV = root / "overlay/system/usr/share"; PR = root / "profile/airootfs/usr/share"
CREAM, ACCENT, AMBER, GOLD, RED, GREEN, YELLOW = "#f4f0eb", "#e87932", "#f5a442", "#ffd27a", "#e06c75", "#7fae6a", "#e5c07b"
NAVY, INDIGO, GLASS, ELEV, MUTED, DIS = "#0b1020", "#151729", "#191923", "#24202a", "#aaa3a0", "#69636a"
KEEP = {"#ff00ff", "#00ff00", "#ff0000", "#0000ff", "#00ffff", "#ffff00", "#000000", "#ffffff00"}   # hidden helper shapes and shadows in Plasma SVGs
TRANSLUCENCY = 0.85          # 15% transparent: the limit set for the application menu is 20%

def hexrgb(h):
    h = h.lstrip("#")
    if len(h) == 3: h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))

def tohex(r, g, b): return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))

def hls(h, hh, l, s):
    r, g, b = colorsys.hls_to_rgb(hh / 360 % 1.0, max(0, min(1, l)), max(0, min(1, s)))
    return tohex(r, g, b)

def mapc(hexcolor):
    c = hexcolor.lower()
    if c in KEEP or c in {CREAM, ACCENT, AMBER, GOLD, RED, GREEN, YELLOW}: return c
    r, g, b = hexrgb(c); h, l, s = colorsys.rgb_to_hls(r, g, b); h *= 360
    if l >= .86 and s < .25: return CREAM                               # white and near white: text, glyphs, strokes
    if s < .2:                                                          # greys: navy / indigo surfaces, muted warm text greys
        if l < .02: return c
        if l < .30: return hls(0, 236, l * 1.05 + .01, .30)             # dark greys: midnight navy / deep indigo
        if l < .60: return hls(0, 285, l, .05)                          # mid greys (disabled: #69636a)
        return hls(0, 18, l, .05)                                       # light greys: muted warm grey (#aaa3a0)
    if 185 <= h <= 265: return hls(0, 24, min(.7, l + .02), min(1, max(.75, s)))   # blues -> burnt orange
    if 70 <= h < 170: return hls(0, 105, l, .30)                        # greens -> the soft green
    if h >= 335 or h < 15: return hls(0, 355, l, .60)                   # reds -> the soft red
    return hls(0, 38, l, .65)                                           # yellows / oranges -> the soft yellow

HEX = re.compile(r"#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})(?![0-9a-fA-F])")
def recolor(t): return HEX.sub(lambda m: mapc(m.group(0)), t)

def read(p):
    b = p.read_bytes()
    if p.suffix == ".svgz":
        try: b = gzip.decompress(b)
        except Exception: pass
    return b.decode("utf-8", "surrogateescape")

def write(p, text, gz=False):
    p.parent.mkdir(parents=True, exist_ok=True)
    data = text.encode("utf-8", "surrogateescape")
    p.write_bytes(gzip.compress(data) if gz else data)

def convert_tree(src, dst, rename=None, post=None):
    for f in sorted(src.rglob("*")):
        if not f.is_file(): continue
        rel = f.relative_to(src); parts = list(rel.parts)
        if rename: parts = [rename(x) for x in parts]
        out = dst.joinpath(*parts)
        if f.suffix in (".svg", ".svgz", ".kvconfig", ".qml", ".desktop", ".json", ".colors") or f.name == "colors" or f.name.endswith("rc"):
            t = recolor(read(f))
            if post: t = post(str(rel), t)
            write(out, t, gz=f.suffix == ".svgz")
        else:
            out.parent.mkdir(parents=True, exist_ok=True); shutil.copy(f, out)

def fix_modes(path):
    for r, ds, fs in os.walk(path):
        os.chmod(r, 0o755)
        for f in fs: os.chmod(os.path.join(r, f), 0o644)

def ensure_source():
    if SRC.exists(): return
    SRC.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "clone", "-q", "https://github.com/yeyushengfan258/Win11OS-kde.git", str(SRC)], check=True)
    subprocess.run(["git", "-C", str(SRC), "checkout", "-q", PIN], check=True)

def frame(r, fill, fill_op, border_op, border_sides, margin, name):
    """A 3x3 Plasma SVG frame. r = corner radius (0 = square), border_sides subset of {top,bottom,left,right}, margin = content margin in px."""
    c = max(r, 3); n = 3 * c
    def px(x, y, w, h): return f'x="{x}" y="{y}" width="{w}" height="{h}"'
    sw = 1
    def edge(id_, x, y, w, h, side):
        line = ""
        if side in border_sides:
            lx = {"top": (x, y, w, sw), "bottom": (x, y + h - sw, w, sw), "left": (x, y, sw, h), "right": (x + w - sw, y, sw, h)}[side]
            line = f'<rect {px(*lx)} fill="url(#rim)" fill-opacity="{border_op}"/>'
        return f'<g id="{id_}"><rect {px(x, y, w, h)} fill="{fill}" fill-opacity="{fill_op}"/>{line}</g>'
    def corner(id_, x, y, quad, sides):
        if r == 0:
            parts = f'<rect {px(x, y, c, c)} fill="{fill}" fill-opacity="{fill_op}"/>'
            for s in sides:
                if s in border_sides:
                    lx = {"top": (x, y, c, sw), "bottom": (x, y + c - sw, c, sw), "left": (x, y, sw, c), "right": (x + c - sw, y, sw, c)}[s]
                    parts += f'<rect {px(*lx)} fill="url(#rim)" fill-opacity="{border_op}"/>'
            return f'<g id="{id_}">{parts}</g>'
        R = c
        shapes = {
            "tl": (f"M{x},{y+R} A{R},{R} 0 0 1 {x+R},{y} L{x+R},{y+R} Z", f"M{x+.5},{y+R} A{R-.5},{R-.5} 0 0 1 {x+R},{y+.5}"),
            "tr": (f"M{x},{y} A{R},{R} 0 0 1 {x+R},{y+R} L{x},{y+R} Z", f"M{x},{y+.5} A{R-.5},{R-.5} 0 0 1 {x+R-.5},{y+R}"),
            "bl": (f"M{x},{y} L{x+R},{y} L{x+R},{y+R} A{R},{R} 0 0 1 {x},{y} Z".replace(f"L{x+R},{y+R} A", f"L{x+R},{y+R} L{x+R},{y+R} A"), f"M{x+.5},{y} A{R-.5},{R-.5} 0 0 0 {x+R},{y+R-.5}"),
            "br": (f"M{x},{y} L{x+R},{y} A{R},{R} 0 0 1 {x},{y+R} Z", f"M{x+R-.5},{y} A{R-.5},{R-.5} 0 0 1 {x},{y+R-.5}"),
        }
        # simple, explicit quarter shapes (centre of the arc is the inner corner of the cell)
        cx, cy = {"tl": (x + R, y + R), "tr": (x, y + R), "bl": (x + R, y), "br": (x, y)}[quad]
        import math
        def arc_fill():
            if quad == "tl": return f"M{x},{y+R} A{R},{R} 0 0 1 {x+R},{y} L{x+R},{y+R} Z"
            if quad == "tr": return f"M{x},{y} A{R},{R} 0 0 1 {x+R},{y+R} L{x},{y+R} Z"
            if quad == "bl": return f"M{x},{y} L{x+R},{y} L{x+R},{y+R} A{R},{R} 0 0 1 {x},{y} Z"
            return f"M{x},{y+R} L{x},{y} L{x+R},{y} A{R},{R} 0 0 1 {x},{y+R} Z"
        def arc_line():
            h = R - .5
            if quad == "tl": return f"M{x+.5},{y+R} A{h},{h} 0 0 1 {x+R},{y+.5}"
            if quad == "tr": return f"M{x},{y+.5} A{h},{h} 0 0 1 {x+R-.5},{y+R}"
            if quad == "bl": return f"M{x+R},{y+R-.5} A{h},{h} 0 0 1 {x+.5},{y}"
            return f"M{x+R-.5},{y} A{h},{h} 0 0 1 {x},{y+R-.5}"
        parts = f'<path d="{arc_fill()}" fill="{fill}" fill-opacity="{fill_op}"/>'
        if set(sides) & border_sides:
            parts += f'<path d="{arc_line()}" fill="none" stroke="url(#rim)" stroke-opacity="{border_op}" stroke-width="1"/>'
        return f'<g id="{id_}">{parts}</g>'
    el = [
        corner("topleft", 0, 0, "tl", ("top", "left")), edge("top", c, 0, c, c, "top"), corner("topright", 2 * c, 0, "tr", ("top", "right")),
        edge("left", 0, c, c, c, "left"), f'<g id="center"><rect {px(c, c, c, c)} fill="{fill}" fill-opacity="{fill_op}"/></g>', edge("right", 2 * c, c, c, c, "right"),
        corner("bottomleft", 0, 2 * c, "bl", ("bottom", "left")), edge("bottom", c, 2 * c, c, c, "bottom"), corner("bottomright", 2 * c, 2 * c, "br", ("bottom", "right")),
    ]
    m = margin
    hints = "".join(f'<rect id="hint-{k}" x="{x}" y="{y}" width="{w}" height="{h}" fill="none"/>' for k, (x, y, w, h) in {
        "top-margin": (0, 0, 1, m), "bottom-margin": (0, 0, 1, m), "left-margin": (0, 0, m, 1), "right-margin": (0, 0, m, 1),
        "top-inset": (0, 0, 1, 0), "bottom-inset": (0, 0, 1, 0), "left-inset": (0, 0, 0, 1), "right-inset": (0, 0, 0, 1)}.items())
    masks = "".join(f'<rect id="mask-{k}" x="{x}" y="{y}" width="{c}" height="{c}" fill="#000"/>' for k, (x, y) in {
        "topleft": (0, 0), "top": (c, 0), "topright": (2 * c, 0), "left": (0, c), "center": (c, c), "right": (2 * c, c),
        "bottomleft": (0, 2 * c), "bottom": (c, 2 * c), "bottomright": (2 * c, 2 * c)}.items())
    tile = f'<rect id="hint-tile-center" x="0" y="0" width="1" height="1" fill="none"/>'
    return (f'<?xml version="1.0" encoding="UTF-8"?>\n<!-- Sunshine theme: {name}. Generated by tools/make-sunshine-theme.py: edit the generator, not this file. -->\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{n}" height="{n}" viewBox="0 0 {n} {n}">\n<defs><linearGradient id="rim" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="{n}" y2="{n}"><stop offset="0" stop-color="{ACCENT}"/><stop offset=".5" stop-color="{AMBER}"/><stop offset="1" stop-color="{GOLD}"/></linearGradient></defs>\n' + "\n".join(el) + "\n" + hints + "\n" + masks + "\n" + tile + "\n</svg>\n")

ALL = {"top", "bottom", "left", "right"}
# relative path: (radius, fill, fill opacity, border opacity, border sides, margin)
FRAMES = {
    "dialogs/background": (12, GLASS, 0.86, 0.85, ALL, 10),
    "widgets/background": (12, GLASS, 0.86, 0.85, ALL, 8),
    "widgets/translucentbackground": (12, GLASS, 0.86, 0.85, ALL, 8),
    "widgets/tooltip": (8, ELEV, 0.92, 0.75, ALL, 6),
    "widgets/panel-background": (0, NAVY, 0.78, 0.8, {"top"}, 0),
}

def write_frames(out):
    for variant in ("", "translucent/", "opaque/"):
        for rel, (r, fill, op, bop, sides, margin) in FRAMES.items():
            if variant == "opaque/" and rel in ("widgets/background", "widgets/translucentbackground"): continue
            (out / (variant + rel + ".svg")).parent.mkdir(parents=True, exist_ok=True)
            (out / (variant + rel + ".svg")).write_text(frame(r, fill, 1.0 if variant == "opaque/" else op, bop, sides, margin, rel))
    for f in list(out.rglob("background.svgz")) + list(out.rglob("panel-background.svgz")) + list(out.rglob("tooltip.svgz")) + list(out.rglob("translucentbackground.svgz")):
        f.unlink()                       # the generated .svg frames replace the upstream .svgz ones

# ---- window decoration: our own, with the gradient rim ----
AP, AB, ATH = 20, 4, 30          # shadow padding, border, title height (a rounded corner can be no larger than the border: Aurorae limit)
def deco_piece(id_, w, h, body, rim, shadow, active):
    ro = 0.9 if active else 0.32
    return (f'<g id="{id_}"><rect width="{w}" height="{h}" fill="#000" fill-opacity="0.004"/>{shadow}{body}{rim.replace("RO", str(ro))}</g>')

def build_deco(path):
    W = AP + AB; T = AP + ATH; Bt = AP + AB; M = 25
    r = AB
    grad = lambda i, x1, y1, x2, y2, c1, c2: f'<linearGradient id="{i}" gradientUnits="userSpaceOnUse" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}"><stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></linearGradient>'
    fill = f'fill="{NAVY}" fill-opacity="0.9"'
    def shade(x, y, w, h, kind, a=0.42):
        # soft shadow: kind = linear direction or radial centre
        gid = f"s{abs(hash((x, y, w, h, kind))) % 10**8}"
        if kind[0] == "lin":
            x1, y1, x2, y2 = kind[1]
            d = f'<linearGradient id="{gid}" gradientUnits="userSpaceOnUse" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}"><stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="{a}"/></linearGradient>'
        else:
            cx, cy = kind[1]
            d = f'<radialGradient id="{gid}" gradientUnits="userSpaceOnUse" cx="{cx}" cy="{cy}" r="{AP + r}"><stop offset="{r/(AP+r):.3f}" stop-color="#000" stop-opacity="{a}"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>'
        return f'<defs>{d}</defs><rect x="{x}" y="{y}" width="{w}" height="{h}" fill="url(#{gid})"/>'
    out = []
    for active in (True, False):
        pre = "decoration-" + ("" if active else "inactive-")
        sa = 0.42 if active else 0.25
        k = "a" if active else "i"
        rimg = lambda n, x1, y1, x2, y2, c1, c2: grad(f"r{k}{n}", x1, y1, x2, y2, c1, c2)
        # corner pieces, all in local coordinates (origin = top-left of the piece)
        pieces = {
          "topleft": (W, T, shade(0, 0, W, AP + r, ("rad", (W, AP + r)), sa) + shade(0, AP + r, AP, T - AP - r, ("lin", (0, 0, AP, 0)), sa) if False else
                      shade(0, 0, W, AP + r, ("rad", (W, AP + r)), sa) + shade(0, AP + r, AP, T - AP - r, ("lin", (0, 0, AP, 0)), sa),
                      f'<path d="M{AP},{T} V{AP+r} A{r},{r} 0 0 1 {AP+r},{AP} L{W},{AP} V{T} Z" {fill}/>',
                      f'<defs>{rimg("tl",AP,AP,W,T,ACCENT,AMBER)}</defs><path d="M{AP+.5},{T} V{AP+r} A{r-.5},{r-.5} 0 0 1 {AP+r},{AP+.5} H{W}" fill="none" stroke="url(#r{k}tl)" stroke-width="1" stroke-opacity="RO"/>'),
          "top": (M, T, shade(0, 0, M, AP, ("lin", (0, 0, 0, AP)), sa),
                      f'<rect x="0" y="{AP}" width="{M}" height="{ATH}" {fill}/>',
                      f'<defs>{rimg("t",0,0,M,0,ACCENT,AMBER)}</defs><rect x="0" y="{AP}" width="{M}" height="1" fill="url(#r{k}t)" fill-opacity="RO"/>'),
          "topright": (W, T, shade(0, 0, W, AP + r, ("rad", (0, AP + r)), sa) + shade(AB, AP + r, AP, T - AP - r, ("lin", (AB + AP, 0, AB, 0)), sa),
                      f'<path d="M0,{AP} H{AB} V{AP} A{r},{r} 0 0 1 {AB+0},{AP}" fill="none"/><path d="M0,{AP} H{AB-r} A{r},{r} 0 0 1 {AB},{AP+r} V{T} H0 Z" {fill}/>',
                      f'<defs>{rimg("tr",0,AP,AB,T,AMBER,GOLD)}</defs><path d="M0,{AP+.5} H{AB-r} A{r-.5},{r-.5} 0 0 1 {AB-.5},{AP+r} V{T}" fill="none" stroke="url(#r{k}tr)" stroke-width="1" stroke-opacity="RO"/>'),
          "left": (W, M, shade(0, 0, AP, M, ("lin", (0, 0, AP, 0)), sa),
                      f'<rect x="{AP}" y="0" width="{AB}" height="{M}" {fill}/>',
                      f'<defs>{rimg("l",0,0,0,M,ACCENT,AMBER)}</defs><rect x="{AP}" y="0" width="1" height="{M}" fill="url(#r{k}l)" fill-opacity="RO"/>'),
          "center": (M, M, "", f'<rect width="{M}" height="{M}" {fill}/>', ""),
          "right": (W, M, shade(AB, 0, AP, M, ("lin", (AB + AP, 0, AB, 0)), sa),
                      f'<rect x="0" y="0" width="{AB}" height="{M}" {fill}/>',
                      f'<defs>{rimg("r",0,0,0,M,AMBER,GOLD)}</defs><rect x="{AB-1}" y="0" width="1" height="{M}" fill="url(#r{k}r)" fill-opacity="RO"/>'),
          "bottomleft": (W, Bt, shade(0, 0, AP, Bt - AP - r + r, ("lin", (0, 0, AP, 0)), sa) + shade(0, AB, W, AP + 0, ("rad", (W, 0)), sa) if False else
                      shade(0, 0, W, AB, ("lin", (0, 0, 0, 0.001)), 0) + shade(0, 0, AP, AB, ("lin", (0, 0, AP, 0)), sa) + shade(0, AB, W, AP, ("rad", (W, AB - r)), sa),
                      f'<path d="M{AP},0 V{AB-r} A{r},{r} 0 0 0 {AP+r},{AB} L{W},{AB} V0 Z" {fill}/>',
                      f'<defs>{rimg("bl",AP,0,W,AB,AMBER,AMBER)}</defs><path d="M{AP+.5},0 V{AB-r} A{r-.5},{r-.5} 0 0 0 {AP+r},{AB-.5} H{W}" fill="none" stroke="url(#r{k}bl)" stroke-width="1" stroke-opacity="RO"/>'),
          "bottom": (M, Bt, shade(0, AB, M, AP, ("lin", (0, AB + AP, 0, AB)), sa),
                      f'<rect x="0" y="0" width="{M}" height="{AB}" {fill}/>',
                      f'<defs>{rimg("b",0,0,M,0,AMBER,GOLD)}</defs><rect x="0" y="{AB-1}" width="{M}" height="1" fill="url(#r{k}b)" fill-opacity="RO"/>'),
          "bottomright": (W, Bt, shade(AB, 0, AP, AB, ("lin", (AB + AP, 0, AB, 0)), sa) + shade(0, AB, W, AP, ("rad", (0, AB - r)), sa),
                      f'<path d="M0,0 H{AB} V{AB-r} A{r},{r} 0 0 1 {AB-r},{AB} H0 Z" {fill}/>',
                      f'<defs>{rimg("br",0,AB,AB,AB,AMBER,GOLD)}</defs><path d="M{AB-.5},0 V{AB-r} A{r-.5},{r-.5} 0 0 1 {AB-r},{AB-.5} H0" fill="none" stroke="url(#r{k}br)" stroke-width="1" stroke-opacity="RO"/>'),
        }
        pos = {"topleft": (0, 0), "top": (W, 0), "topright": (W + M, 0), "left": (0, T), "center": (W, T), "right": (W + M, T),
               "bottomleft": (0, T + M), "bottom": (W, T + M), "bottomright": (W + M, T + M)}
        yoff = 0 if active else T + M + Bt + 10
        for name, (w, h, sh, body, rim) in pieces.items():
            x, y = pos[name]
            out.append(f'<g transform="translate({x},{y + yoff})">{deco_piece(pre + name, w, h, body, rim, sh, active)}</g>')
    tw = W + M + W; th = (T + M + Bt) * 2 + 10
    path.write_text(f'<?xml version="1.0" encoding="UTF-8"?>\n<!-- Sunshine theme window frame. Generated by tools/make-sunshine-theme.py -->\n<svg xmlns="http://www.w3.org/2000/svg" width="{tw}" height="{th}" viewBox="0 0 {tw} {th}">\n<rect id="hint-stretch-borders" width="1" height="1" fill="none"/>\n' + "\n".join(out) + "\n</svg>\n")

def plasma_post(rel, t):
    # menus, popups, tooltips and the taskbar: 85% opaque (upstream: 60%)
    if rel.startswith("translucent/"):
        t = t.replace("opacity:0.6;fill:", f"opacity:{TRANSLUCENCY};fill:")
        # thin orange rim, like the reference mock-up: the frame edge pieces were near-black
        if rel.endswith(("dialogs/background.svg", "widgets/panel-background.svg", "widgets/background.svg", "widgets/tooltip.svg")):
            t = re.sub(r'(<g\s+style="fill:)#050505(;fill-opacity:)0\.85882("\s+id="(?:top|bottom|left|right|topleft|topright|bottomleft|bottomright)")', r'\1#d9803f\g<2>0.9\3', t)
    return t

def main():
    ensure_source()
    dark = SRC / "plasma/desktoptheme/Win11OS-dark"
    out = OV / "plasma/desktoptheme/Sunshine"
    if out.exists(): shutil.rmtree(out)
    convert_tree(dark, out, rename=lambda x: "opaque" if x == "solid" else x, post=plasma_post)
    write_frames(out)
    # the palette of the theme = the Sunshine colour scheme
    scheme = (root / "overlay/system/usr/share/color-schemes/SunshineDark.colors").read_text()
    (out / "colors").write_text(re.sub(r"\n\[(General|KDE|WM)\][^\[]*", "\n", scheme))
    for old in ("metadata.desktop",): (out / old).unlink(missing_ok=True)
    (out / "metadata.json").write_text(json.dumps({
        "KPlugin": {"Id": "Sunshine", "Name": "Sunshine theme", "Category": "", "EnabledByDefault": True, "License": "GPL-3.0-or-later", "Version": "2.0",
                    "Description": "Sunshine OS: a dark Windows 11 style in the Sunshine palette (indigo, cream, orange), after Win11OS-kde by yeyushengfan258. Menus and the taskbar are 15% transparent.",
                    "Website": "https://github.com/tak0dan/SunshineOS", "Authors": [{"Name": "Sunshine OS"}, {"Name": "yeyushengfan258 (Win11OS-kde)"}]},
        "X-Plasma-API": "5.0"}, indent=2) + "\n")
    (out / "NOTICE").write_text("Based on Win11OS-kde (dark) by yeyushengfan258, GPL-3.0: https://github.com/yeyushengfan258/Win11OS-kde (KDE Store item 2106375).\nRe-coloured and adapted for Sunshine OS by tools/make-sunshine-theme.py.\n")
    # window frame
    au = OV / "aurorae/themes/Sunshine"
    if au.exists(): shutil.rmtree(au)
    convert_tree(SRC / "aurorae/Win11OS-dark", au, rename=lambda x: x.replace("Win11OS-dark", "Sunshine"))
    (au / "metadata.desktop").write_text("[Desktop Entry]\nName=Sunshine theme\nComment=Sunshine OS window decoration (after Win11OS-kde)\nX-KDE-PluginInfo-Name=Sunshine\nX-KDE-PluginInfo-Author=Sunshine OS\nX-KDE-PluginInfo-License=GPL-3.0-or-later\n")
    build_deco(au / "decoration.svg")
    rc = au / "Sunshinerc"; t = rc.read_text()
    t = re.sub(r"ActiveTextColor=.*", "ActiveTextColor=244,240,235,255", t); t = re.sub(r"InactiveTextColor=.*", "InactiveTextColor=170,163,160,255", t)
    for k, v in {"BorderLeft": AB, "BorderRight": AB, "BorderBottom": AB, "TitleHeight": ATH, "TitleHeightMaximized": ATH, "PaddingTop": AP, "PaddingBottom": AP, "PaddingLeft": AP, "PaddingRight": AP,
                 "TitleEdgeTop": 0, "TitleEdgeBottom": 0, "TitleEdgeLeft": 0, "TitleEdgeRight": 0, "TitleBorderLeft": 10, "ButtonHeight": 28, "ButtonMarginTop": 1}.items():
        t = re.sub(rf"(?m)^{k}=.*$", f"{k}={v}", t)
    rc.write_text(t)
    # Kvantum widget style (Windows 11 like controls)
    kv = OV / "Kvantum/Sunshine"
    if kv.exists(): shutil.rmtree(kv)
    convert_tree(SRC / "Kvantum/Win11OS-dark", kv, rename=lambda x: x.replace("Win11OS-dark", "Sunshine"))
    cf = kv / "Sunshine.kvconfig"; t = cf.read_text()
    pal = {"window.color": INDIGO, "base.color": NAVY, "alt.base.color": INDIGO, "button.color": ELEV, "light.color": "#332d3a", "mid.light.color": "#2a2531",
           "dark.color": "#0b0d18", "mid.color": GLASS, "highlight.color": ACCENT, "inactive.highlight.color": "#7a4a2a", "text.color": CREAM, "window.text.color": CREAM,
           "button.text.color": CREAM, "disabled.text.color": DIS, "tooltip.base.color": ELEV, "tooltip.text.color": CREAM, "highlight.text.color": "#ffffff",
           "link.color": AMBER, "link.visited.color": GOLD}
    for k, v in pal.items(): t = re.sub(rf"(?m)^{re.escape(k)}=.*$", f"{k}={v}", t)
    t = re.sub(r"(?m)^author=.*$", "author=Sunshine OS, after Win11OS-kde (yeyushengfan258) and Vince Liuice's KvAdapta-based theme", t)
    cf.write_text(t)
    for p in (out, au, kv): fix_modes(p)
    for sub in ("plasma/desktoptheme/Sunshine", "aurorae/themes/Sunshine", "Kvantum/Sunshine"):
        if (PR / sub).exists(): shutil.rmtree(PR / sub)
        shutil.copytree(OV / sub, PR / sub)
    print("Sunshine theme built:", sum(1 for _ in out.rglob("*") if _.is_file()), "plasma files,", sum(1 for _ in au.iterdir()), "aurorae files,", sum(1 for _ in kv.iterdir()), "kvantum files")

if __name__ == "__main__":
    main()
