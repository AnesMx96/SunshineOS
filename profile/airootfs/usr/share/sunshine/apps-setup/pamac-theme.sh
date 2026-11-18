#!/usr/bin/env bash
# Pamac (GTK) in the Sunshine look: the account gets the Sunshine GTK settings and colour overrides (the same ones as every new user).
# args: id user home   (runs as root)
ID=$1; U=$2; H=$3
for f in gtk-3.0/settings.ini gtk-3.0/gtk.css gtk-4.0/settings.ini gtk-4.0/gtk.css; do
  [ -f "$H/.config/$f" ] && continue
  [ -f "/etc/skel/.config/$f" ] || continue
  install -D -o "$U" -g "$U" -m 644 "/etc/skel/.config/$f" "$H/.config/$f"
done
echo "pamac-theme: GTK settings for $U are in place"
