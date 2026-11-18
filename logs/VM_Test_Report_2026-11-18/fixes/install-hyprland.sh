#!/usr/bin/env bash
# Install the 114 packages skipped by the original installer, now that the
# [sunshine] keyring is trusted. Also mask the stuck wait-online unit.
exec > >(tee -a /tmp/hypr-final.log) 2>&1
echo "=== Hyprland package repair @ $(date -Is) ==="
echo sunshine | sudo -S systemctl mask systemd-networkd-wait-online.service 2>&1
echo sunshine | sudo -S systemctl stop systemd-networkd-wait-online.service 2>&1 || true
PKGS="hyprland hypridle hyprlock hyprsunset hyprpolkitagent hyprland-guiutils xdg-desktop-portal-hyprland quickshell uwsm hyprshot hyprpicker cliphist grim slurp swappy wf-recorder wtype ydotool fuzzel foot btop easyeffects songrec translate-shell matugen geoclue pavucontrol-qt libdbusmenu-gtk3 yq adw-gtk-theme tinyxml2 gtkmm3 gtksourceviewmm cairomm clang uv cpptrace jemalloc tesseract tesseract-data-eng upower python-numpy python-pillow lm_sensors libnotify polkit-gnome qt5ct qt6ct kvantum kvantum-qt5 nwg-look breeze-plus darkly-bin ttf-material-symbols-variable ttf-readex-pro ttf-rubik-vf ttf-twemoji illogical-impulse-microtex-git illogical-impulse-bibata-modern-classic-bin wlogout flat-remix-gtk bluedevil gnome-keyring plasma-nm polkit-kde-agent systemsettings dolphin wireplumber pipewire-pulse playerctl brightnessctl ddcutil bc cmake ripgrep jq xdg-user-dirs rsync fontconfig breeze eza fish starship ttf-jetbrains-mono-nerd wl-clipboard xdg-desktop-portal xdg-desktop-portal-kde xdg-desktop-portal-gtk gtk4 libadwaita libsoup3 libportal-gtk4 gobject-introspection glib2 imagemagick qt6-5compat qt6-imageformats qt6-multimedia qt6-positioning qt6-quicktimeline qt6-sensors qt6-translations qt6-virtualkeyboard qt6-wayland qt6-declarative qt6-svg qt6-tools kirigami kdialog syntax-highlighting libqalculate cava fastfetch lsd"
n=0; ok=0; fail=0
for p in $PKGS; do
  n=$((n+1))
  echo sunshine | sudo -S pacman -S --needed --noconfirm --disable-download-timeout "$p" >/tmp/hypr-pkg.log 2>&1
  rc=$?
  if [ $rc = 0 ]; then ok=$((ok+1)); echo "[$n/114] $p OK"; else
    fail=$((fail+1))
    echo "[$n/114] $p FAILED rc=$rc: $(grep -m1 -i 'error' /tmp/hypr-pkg.log | cut -c1-120)"
  fi
done
echo "RESULT ok=$ok failed=$fail"
echo "=== essential check ==="
for p in hyprland quickshell matugen foot; do echo sunshine | sudo -S pacman -Q "$p" 2>&1; done
echo "=== system state ==="
systemctl is-system-running
echo HYPR_REPAIR_DONE
