#!/usr/bin/env bash
# Publishes the Sunshine themes and visual configs to the assets repository (default tak0dan/sunshineos-assets), which the
# "Restore visuals" button / sunshine-restore-visuals pulls from. The source of truth stays in this checkout (overlay/); this only mirrors it.
#   tools/publish-assets.sh            sync and push (creates the repository on first use)
#   DRY=1 tools/publish-assets.sh      only show what would change
set -euo pipefail
cd "$(dirname "$0")/.."
REPO=${SUNSHINE_ASSETS_REPO:-tak0dan/sunshineos-assets}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
O=overlay/system/usr/share; K=overlay/skel/.config
mkdir -p "$T/stage/share/plasma" "$T/stage/config"
cp -a $O/plasma/desktoptheme $O/plasma/look-and-feel "$T/stage/share/plasma/"
mkdir -p "$T/stage/share/plasma/plasmoids"; cp -a $O/plasma/plasmoids/com.sunshineos.* "$T/stage/share/plasma/plasmoids/"
mkdir -p "$T/stage/share/aurorae" "$T/stage/share/color-schemes"; cp -a $O/aurorae/themes "$T/stage/share/aurorae/"; cp -a $O/Kvantum "$T/stage/share/"; cp -a $O/color-schemes/Sunshine*.colors "$T/stage/share/color-schemes/"
for f in kwinrc kdeglobals plasmarc ksplashrc kglobalshortcutsrc katerc darklyrc dolphinrc Kvantum gtk-3.0 gtk-4.0 kando kate kitty konsole; do [ -e "$K/$f" ] && cp -a "$K/$f" "$T/stage/config/"; done
cp docs/previews/sunshine-theme/menu.png docs/previews/sunshine-theme/topbar.png docs/previews/sunshine-theme/splash.png "$T/stage/" 2>/dev/null || true
cat > "$T/stage/README.md" <<'MD'
# Sunshine OS assets

The visual side of Sunshine OS: the Plasma theme, start menu, top-bar widgets, window decoration, Kvantum style, colour scheme, splash
(look-and-feel) and the default visual configs (kwin, GTK, Kando, Kate, terminals).

    share/   goes to ~/.local/share/   (plasma/desktoptheme, plasma/plasmoids, plasma/look-and-feel, aurorae/themes, Kvantum, color-schemes)
    config/  goes to ~/.config/        (kwinrc, kdeglobals, plasmarc, ksplashrc, kglobalshortcutsrc, gtk-3.0, gtk-4.0, kando, ...)

`sunshine-restore-visuals` (the "Restore visuals" button in Sunshine Welcome) pulls this repository and applies it; offline it applies what is
installed. This repository is generated from the Sunshine OS sources (`tools/publish-assets.sh`); change things there.
Theme base: Win11OS-kde by yeyushengfan258 (GPL-3.0), icons: Fluent icon theme by vinceliuice (GPL-3.0). Licence: GPL-3.0-or-later.

![menu](menu.png)
MD
if [ -n "${DRY:-}" ]; then find "$T/stage" -type f | sed "s#$T/stage/##" | head -20; echo "... $(find "$T/stage" -type f | wc -l) files"; exit 0; fi
gh repo view "$REPO" >/dev/null 2>&1 || gh repo create "$REPO" --public --description "Themes, widgets and visual configs of Sunshine OS" >/dev/null
git clone -q "https://github.com/$REPO.git" "$T/repo"
git -C "$T/repo" checkout -q -B main 2>/dev/null || true
find "$T/repo" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a "$T/stage/." "$T/repo/"
cd "$T/repo"; git add -A
if git diff --cached --quiet; then echo "assets: nothing changed"; exit 0; fi
git -c user.name="$(git -C "$OLDPWD" config user.name)" -c user.email="$(git -C "$OLDPWD" config user.email)" commit -q -m "Sync from Sunshine OS $(git -C "$OLDPWD" rev-parse --short HEAD)"
git push -q origin HEAD:main && echo "assets: pushed to $REPO"
