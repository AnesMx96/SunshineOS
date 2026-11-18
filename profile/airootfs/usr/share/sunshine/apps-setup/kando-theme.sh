#!/usr/bin/env bash
# Kando pie menu in the Sunshine theme: the theme (dark smoked glass nodes with an orange-to-gold rim) is installed for the account and selected.
# args: id user home   (runs as root)
ID=$1; U=$2; H=$3
SRC=/etc/skel/.config/kando/menu-themes/sunshine
[ -d "$SRC" ] || { echo "kando-theme: the Sunshine theme is not on this system"; exit 0; }
D="$H/.config/kando/menu-themes"
install -d -o "$U" -g "$U" "$D" "$H/.config/kando"
cp -a "$SRC" "$D/" && chown -R "$U:$U" "$D/sunshine"
C="$H/.config/kando/config.json"
python3 - "$C" "$U" <<'PY'
import json, os, sys, pwd
p, u = sys.argv[1], sys.argv[2]
try: cfg = json.load(open(p))
except Exception: cfg = {}
cfg["menuTheme"] = "sunshine"
json.dump(cfg, open(p, "w"), indent=2)
os.chown(p, pwd.getpwnam(u).pw_uid, pwd.getpwnam(u).pw_gid)
PY
echo "kando-theme: Sunshine theme selected for $U"
