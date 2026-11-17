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
CREAM, ACCENT, RED, GREEN, YELLOW = "#efe5d0", "#ff9654", "#e06c75", "#7fae6a", "#e5c07b"
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
    if c in KEEP or c in {CREAM, ACCENT, RED, GREEN, YELLOW}: return c
    r, g, b = hexrgb(c); h, l, s = colorsys.rgb_to_hls(r, g, b); h *= 360
    if l >= .86 and s < .25: return CREAM                               # white and near white: text, glyphs, strokes
    if s < .2:                                                          # greys -> the indigo / warm ramp
        if l < .02: return c
        if l < .30: return hls(0, 250 if l < .12 else 12, l * 1.15 + .01, .22 if l < .12 else .30)               # dark greys: the indigo backgrounds
        if l < .60: return hls(0, 20, l, .12)                          # mid greys
        return hls(0, 38, l, .16)                                       # light greys: warm
    if 185 <= h <= 265: return hls(0, 22, min(.8, l + .06), min(1, s * 1.1 + .1))   # blues -> the orange accent
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
    rc = au / "Sunshinerc"; t = rc.read_text()
    t = re.sub(r"ActiveTextColor=.*", "ActiveTextColor=239,229,208,255", t); t = re.sub(r"InactiveTextColor=.*", "InactiveTextColor=154,146,127,255", t); rc.write_text(t)
    # Kvantum widget style (Windows 11 like controls)
    kv = OV / "Kvantum/Sunshine"
    if kv.exists(): shutil.rmtree(kv)
    convert_tree(SRC / "Kvantum/Win11OS-dark", kv, rename=lambda x: x.replace("Win11OS-dark", "Sunshine"))
    cf = kv / "Sunshine.kvconfig"; t = cf.read_text()
    pal = {"window.color": "#17121a", "base.color": "#1a141c", "alt.base.color": "#1f1820", "button.color": "#2b2027", "light.color": "#3a2b30", "mid.light.color": "#322529",
           "dark.color": "#100c13", "mid.color": "#231a21", "highlight.color": ACCENT, "inactive.highlight.color": "#7a5a45", "text.color": CREAM, "window.text.color": CREAM,
           "button.text.color": CREAM, "disabled.text.color": "#7d7766", "tooltip.base.color": "#2b2027", "tooltip.text.color": CREAM, "highlight.text.color": "#2a1a0e",
           "link.color": ACCENT, "link.visited.color": "#c9a15a"}
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
