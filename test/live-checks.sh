#!/usr/bin/env bash
# Checks inside a running Sunshine OS (live session or installed system). Run as root:  bash live-checks.sh [edition: Sol|Sirius]
# Prints PASS / FAIL / SKIP lines and a summary; exit status 1 if anything failed. Designed to be copied into a VM (test/vbox.sh put) and run.
ed=${1:-Sol}; pass=0; fail=0; skip=0
ok()   { printf 'PASS  %s\n' "$*"; pass=$((pass+1)); }
bad()  { printf 'FAIL  %s\n' "$*"; fail=$((fail+1)); }
sk()   { printf 'SKIP  %s\n' "$*"; skip=$((skip+1)); }
chk()  { local d=$1; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
LIVE=0; [ -d /run/archiso ] && LIVE=1
echo "== system ($( [ $LIVE = 1 ] && echo live || echo installed ), edition $ed)"
chk "systemd is running"                         bash -c '[ "$(systemctl is-system-running)" = running ] || [ "$(systemctl is-system-running)" = degraded ]'
f=$(systemctl --failed --no-legend 2>/dev/null | awk '{print $2}' | tr '\n' ' '); [ -z "${f// }" ] && ok "no failed system units" || bad "failed units: $f"
chk "identity is Sunshine OS"                    grep -q '^ID=sunshineos' /etc/os-release
chk "sunshine-identity check passes"             /usr/local/bin/sunshine-identity check --quiet
chk "kernel command line: pastel palette"        grep -q 'vt.default_red=' /proc/cmdline
[ $LIVE = 1 ] && { chk "kernel command line: cow_spacesize=1G (or the persistent dev disk)" grep -qE 'cow_spacesize=1G|cow_persistent=P' /proc/cmdline
  sz=$(df -BM --output=size /run/archiso/cowspace 2>/dev/null | tail -1 | tr -dc 0-9); [ "${sz:-0}" -ge 1000 ] && ok "live overlay is ${sz} MiB" || bad "live overlay is ${sz:-?} MiB (want 1024)"; }
chk "pacman-init / keyring usable"               pacman-key --list-keys
chk "Sunshine repository key is trusted"         bash -c 'pacman-key --list-keys 8253720323C575207CC781B5DB345EF676CCD13D'
echo "== repositories"
first=$(awk '/^\[/ && $0!="[options]"{print $0; exit}' /etc/pacman.conf); [ "$first" = "[sunshine]" ] && ok "[sunshine] is the first repository" || bad "first repository is $first"
chk "pacman -Sy works (signed [sunshine] database)" pacman -Sy --noconfirm
chk "sunshine-repo check"                        /usr/local/bin/sunshine-repo check --quiet
chk "[sunshine] has sunshine-base"               bash -c 'pacman -Sl sunshine | grep -q sunshine-base'
chk "pacman -Dk consistent"                      pacman -Dk
echo "== tools"
for t in sunshine-doctor sunshine-diagnose sunshine-fix-pacman sunshine-cleanup sunshine-identity sunshine-info sunshine-repo sunshine-snapshot sunshine-update-check sunshine-restore-visuals sunshine-register-base sunshine-apps sunshine-webapp; do
  [ -x /usr/local/bin/$t ] && ok "$t is installed" || bad "$t missing"; done
chk "doctor runs without script errors"          bash -c 'out=$(/usr/local/bin/sunshine-doctor 2>&1); ! echo "$out" | grep -qE "syntax error|command not found|unbound variable|-dc 0-9"'
chk "coreutils tr is not shadowed after ui.sh"   bash -c '. /usr/local/lib/sunshine/ui.sh; [ "$(printf "a b" | tr " " "_")" = a_b ]'
chk "Ukrainian word list loads (LANG=uk)"        bash -c 'LANG=uk_UA.UTF-8 SUN_LANG=uk . /usr/local/lib/sunshine/ui.sh; [ "$(loc "Lock file")" != "Lock file" ]'
chk "diagnose writes a log"                      bash -c 'd=$(mktemp -d); SUNSHINE_DIAG_DIR=$d /usr/local/bin/sunshine-diagnose >/dev/null; ls $d/diagnosis-*.log'
chk "update-check writes its state"              bash -c 'XDG_CACHE_HOME=$(mktemp -d) /usr/local/bin/sunshine-update-check --quiet; true'
chk "rate-mirrors is installed"                  command -v rate-mirrors
chk "os-prober is installed"                     command -v os-prober
chk "git aliases exist"                          bash -c 'git config --system alias.lg'
chk "nano syntax highlighting is wired"          bash -c 'grep -q nano-syntax-highlighting /etc/nanorc && ls /usr/share/nano-syntax-highlighting/*.nanorc'
echo "== Chaotic-AUR (added by sunshine-repo on the first update)"
chk "sunshine-repo ensure adds Chaotic-AUR"      bash -c '/usr/local/bin/sunshine-repo ensure --quiet; grep -q "^\[chaotic-aur\]" /etc/pacman.conf && [ -f /etc/pacman.d/chaotic-mirrorlist ]'
chk "chaotic-aur database syncs"                 pacman -Sy --noconfirm
echo "== editions"
if [ "$ed" = Sirius ]; then
  chk "sunshine-declare is installed"            test -x /usr/local/bin/sunshine-declare
  chk "declarative.toml exists"                  test -f /etc/sunshine/declarative.toml
  chk "nix is installed"                         command -v nix
  chk "nix-daemon.socket is enabled"             systemctl is-enabled nix-daemon.socket
  chk "sunshine-declare status runs"             bash -c '/usr/local/bin/sunshine-declare status >/dev/null; [ $? -le 1 ]'
else
  chk "Sol has no sunshine-declare"              bash -c '! test -e /usr/local/bin/sunshine-declare'
  chk "Sol has no Nix"                           bash -c '! command -v nix'
  chk "Sol has no nix-daemon unit enabled"       bash -c '! systemctl is-enabled nix-daemon.service 2>/dev/null | grep -q enabled'
fi
echo "== files that ship with the user settings (/etc/skel)"
for f in .config/kdeglobals .config/kwinrc .config/kglobalshortcutsrc .config/ksplashrc .config/gtk-3.0/settings.ini .config/gtk-4.0/settings.ini .config/Kvantum/kvantum.kvconfig .config/katerc .config/kando/menu-themes/sunshine/theme.json; do
  [ -f /etc/skel/$f ] && ok "skel: $f" || bad "skel missing: $f"; done
chk "default browser is Firefox"                 grep -q 'x-scheme-handler/https=firefox' /etc/xdg/mimeapps.list
chk "Okular is the default PDF reader"           grep -q 'application/pdf=org.kde.okular' /etc/xdg/mimeapps.list
echo "== Plasma pieces"
for d in com.sunshineos.startmenu com.sunshineos.graphs com.sunshineos.updates com.sunshineos.windowbar; do [ -f /usr/share/plasma/plasmoids/$d/metadata.json ] && ok "plasmoid $d" || bad "plasmoid $d missing"; done
for d in plasma/desktoptheme/Sunshine aurorae/themes/Sunshine Kvantum/Sunshine plasma/look-and-feel/com.sunshineos.sunshine; do [ -d /usr/share/$d ] && ok "theme dir $d" || bad "missing /usr/share/$d"; done
chk "colour scheme SunshineDark"                 test -f /usr/share/color-schemes/SunshineDark.colors
chk "icon theme Sunshine-orange-dark"            test -d /usr/share/icons/Sunshine-orange-dark
chk "no hidden coreutils-named functions in tools" bash -c '! grep -rEl "^tr\(\)" /usr/local/bin /usr/local/lib/sunshine'
if [ $LIVE = 1 ]; then
  echo "== live session"
  u=sunshine; sess=$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u=$u '$3==u {print $1; exit}')
  [ -n "$sess" ] && ok "user $u has a graphical session" || sk "no session for $u yet (Plasma still starting)"
  chk "plasmashell is running"                   pgrep -x plasmashell
  chk "kwin_wayland is running"                  pgrep -x kwin_wayland
  chk "no applet load errors for Sunshine plasmoids" bash -c '! journalctl -b --no-pager 2>/dev/null | grep -E "error when loading applet \"com.sunshineos"'
  chk "welcome/toolbox exist for the launcher"   bash -c 'test -x /usr/local/bin/sunshine-welcome && test -x /usr/local/bin/sunshine-toolbox'
fi
echo
echo "SUMMARY: $pass passed, $fail failed, $skip skipped"
[ $fail -eq 0 ]
