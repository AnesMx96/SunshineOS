#!/usr/bin/env python3
"""Generates the artwork of the "Sunshine theme" Plasma desktop theme: dialog/menu, panel (taskbar), tooltip and widget backgrounds as Plasma SVG
frames (translucent variant 85% opaque, opaque variant 100%), plus metadata.json. The icons and the `colors` file are kept.
usage: python3 tools/make-sunshine-theme.py            (writes overlay/system/usr/share/plasma/desktoptheme/Sunshine/ and mirrors it into profile/airootfs)"""
import json, pathlib, shutil, sys
root = pathlib.Path(__file__).resolve().parent.parent
OV = root / "overlay/system/usr/share/plasma/desktoptheme"       # the source: tools/import-end4.sh copies overlay/system into the image
PR = root / "profile/airootfs/usr/share/plasma/desktoptheme"     # mirrored here so both trees stay identical
OUT = OV / "Sunshine"
OLD = OV / "SunshineWin11"                                       # first run only: the colours and panel icons of the previous theme

# The Sunshine palette (same as the Plasma colour scheme, GRUB, terminals, prompt)
BG_DIALOG = "#141b2e"      # menus, popups, flyouts
BG_PANEL = "#0e1422"       # taskbar
BG_TOOLTIP = "#1a2236"
TEXT = "#efe5d0"
ACCENT = "#ff9654"
BORDER = TEXT              # drawn at low opacity
TRANSLUCENCY = 0.85        # 15% transparent: the maximum allowed for the application menu is 20%

def frame(r, fill, fill_op, border_op, border_sides, margin, name):
    """A 3x3 Plasma SVG frame. r = corner radius (0 = square), border_sides subset of {top,bottom,left,right}, margin = content margin in px."""
    c = max(r, 3); n = 3 * c
    def px(x, y, w, h): return f'x="{x}" y="{y}" width="{w}" height="{h}"'
    sw = 1
    def edge(id_, x, y, w, h, side):
        line = ""
        if side in border_sides:
            lx = {"top": (x, y, w, sw), "bottom": (x, y + h - sw, w, sw), "left": (x, y, sw, h), "right": (x + w - sw, y, sw, h)}[side]
            line = f'<rect {px(*lx)} fill="{BORDER}" fill-opacity="{border_op}"/>'
        return f'<g id="{id_}"><rect {px(x, y, w, h)} fill="{fill}" fill-opacity="{fill_op}"/>{line}</g>'
    def corner(id_, x, y, quad, sides):
        if r == 0:
            parts = f'<rect {px(x, y, c, c)} fill="{fill}" fill-opacity="{fill_op}"/>'
            for s in sides:
                if s in border_sides:
                    lx = {"top": (x, y, c, sw), "bottom": (x, y + c - sw, c, sw), "left": (x, y, sw, c), "right": (x + c - sw, y, sw, c)}[s]
                    parts += f'<rect {px(*lx)} fill="{BORDER}" fill-opacity="{border_op}"/>'
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
            parts += f'<path d="{arc_line()}" fill="none" stroke="{BORDER}" stroke-opacity="{border_op}" stroke-width="1"/>'
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
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{n}" height="{n}" viewBox="0 0 {n} {n}">\n' + "\n".join(el) + "\n" + hints + "\n" + masks + "\n" + tile + "\n</svg>\n")

ALL = {"top", "bottom", "left", "right"}
SPECS = {   # relative path inside the theme: (radius, fill, border sides, margin)
    "dialogs/background": (12, BG_DIALOG, ALL, 10),
    "widgets/background": (12, BG_DIALOG, ALL, 8),
    "widgets/translucentbackground": (12, BG_DIALOG, ALL, 8),
    "widgets/tooltip": (8, BG_TOOLTIP, ALL, 6),
    "widgets/panel-background": (0, BG_PANEL, {"top"}, 0),
}

def fix_modes(path):
    # files must be readable by every user whatever the umask / default ACL of the machine that runs this tool
    import os
    for r, ds, fs in os.walk(path):
        os.chmod(r, 0o755)
        for f in fs: os.chmod(os.path.join(r, f), 0o644)

def main():
    keep = {}                                   # colours and icons survive a regeneration
    for item in ("colors", "icons"):
        for base in (OUT, OLD):
            if (base / item).exists(): keep[item] = base / item; break
    stash = root / ".theme-stash"
    if stash.exists(): shutil.rmtree(stash)
    stash.mkdir()
    for item, path in keep.items(): (shutil.copytree if path.is_dir() else shutil.copy)(path, stash / item)
    if OUT.exists(): shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    for variant, op, bop in (("", TRANSLUCENCY, 0.14), ("translucent/", TRANSLUCENCY, 0.14), ("opaque/", 1.0, 0.18)):
        for rel, (r, fill, sides, margin) in SPECS.items():
            if variant == "opaque/" and rel in ("widgets/background", "widgets/translucentbackground"): continue
            if variant == "translucent/" and rel in ("widgets/background", "widgets/translucentbackground"): pass
            p = OUT / (variant + rel + ".svg"); p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(frame(r, fill, op, bop, sides, margin, rel))
    for item in keep:
        (shutil.copytree if (stash / item).is_dir() else shutil.copy)(stash / item, OUT / item)
    shutil.rmtree(stash)
    (OUT / "metadata.json").write_text(json.dumps({
        "KPlugin": {"Id": "Sunshine", "Name": "Sunshine theme", "Category": "",
                    "Description": "Sunshine OS: a dark Windows 11 style in the Sunshine palette (indigo, cream, orange). Menus and the taskbar are 15% transparent.",
                    "EnabledByDefault": True, "License": "GPL-3.0-or-later", "Version": "1.0", "Website": "https://github.com/tak0dan/SunshineOS",
                    "Authors": [{"Name": "Sunshine OS"}]},
        "X-Plasma-API": "5.0"}, indent=2) + "\n")   # same shape as the KDE themes (breeze-dark): Plasma's theme list needs X-Plasma-API
    fix_modes(OUT)
    if (PR / "Sunshine").exists(): shutil.rmtree(PR / "Sunshine")
    shutil.copytree(OUT, PR / "Sunshine"); fix_modes(PR / "Sunshine")
    print("theme written to", OUT, "(and mirrored to profile/airootfs)", "-", sum(1 for _ in OUT.rglob("*.svg")), "svg files")

if __name__ == "__main__":
    main()
