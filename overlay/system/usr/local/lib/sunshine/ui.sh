# Shared look of the Sunshine tools (source it):  . /usr/local/lib/sunshine/ui.sh
# say / ok / bad / sec           coloured lines (warm wording when cozy=on)
# t KEY                          the text for KEY in the selected language
# sun_run "label" command...     runs a command behind an ASCII graph animation; on success a short Sunshine animation, on failure the output (no animation)
[ -n "${SUN_UI_LOADED:-}" ] && return 0; SUN_UI_LOADED=1
SUN_CONF_SYS=/etc/sunshine/tools.conf; SUN_CONF_USER=${XDG_CONFIG_HOME:-${SUDO_USER:+$(getent passwd "$SUDO_USER" | cut -d: -f6)/.config}}; SUN_CONF_USER=${SUN_CONF_USER:-$HOME/.config}/sunshine/tools.conf
sun_conf() { local v; for f in "$SUN_CONF_USER" "$SUN_CONF_SYS"; do [ -r "$f" ] && v=$(sed -n "s/^$1=//p" "$f" | tail -1) && [ -n "$v" ] && { printf '%s' "$v"; return; }; done; printf '%s' "$2"; }
SUN_COZY=$(sun_conf cozy on); SUN_ANIM=$(sun_conf animation on); SUN_LANG=$(sun_conf language auto)
if [ "$SUN_LANG" = auto ]; then
  case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in uk*) SUN_LANG=uk ;; *) SUN_LANG=en ;; esac
  grep -qi toulouse /etc/sunshine/install-location 2>/dev/null && SUN_LANG=uk
fi
declare -A T
[ "$SUN_LANG" = uk ] && [ -r /usr/share/sunshine/i18n/uk.sh ] && . /usr/share/sunshine/i18n/uk.sh
t() { local k=$1; printf '%s' "${T[$k]:-$2}"; }
B=$'\e[1m'; Y=$'\e[38;5;220m'; O=$'\e[38;5;208m'; G=$'\e[32m'; R=$'\e[31m'; D=$'\e[2m'; N=$'\e[0m'
_cozy() { [ "$SUN_COZY" = on ] && printf '%s' "$1" || printf '%s' "$2"; }
sec() { printf '\n%s%s %s%s\n' "$Y$B" "$(_cozy ☀ '*')" "$*" "$N"; }
say() { sec "$@"; }
ok()  { printf '%s%s %s%s\n' "$G" "$(_cozy '✔ ☕' '+')" "$*" "$N"; }
bad() { printf '%s%s %s%s\n' "$R" "$(_cozy '✘ 🫖' 'x')" "$*" "$N"; }
cozy_done() { [ "$SUN_COZY" = on ] && printf '%s\n' "$Y$(t cozy_done 'All done. Have a warm cup of tea and enjoy the sunshine ☀️🍵')$N"; }
_sun_frames() { cat <<'S'
      \   |   /
       .-"""-.
   -- (   ☀   ) --
       '-...-'
      /   |   \
S
}
sun_success_anim() {
  [ "$SUN_ANIM" = on ] && [ -t 1 ] || return 0
  local i c
  for i in 1 2 3; do
    for c in 208 214 220 226 220 214; do
      printf '\e[?25l\e[5A'; _sun_frames | while IFS= read -r l; do printf '\e[38;5;%sm%s\e[0m\e[K\n' "$c" "$l"; done; sleep 0.06
    done
  done; printf '\e[?25h'
}
sun_run() {            # sun_run "label" cmd args...
  local label=$1; shift; local log; log=$(mktemp)
  if [ "$SUN_ANIM" != on ] || ! [ -t 1 ]; then printf '%s ...\n' "$label"; "$@" >"$log" 2>&1; local rc=$?; [ $rc -eq 0 ] && ok "$label" || { bad "$label"; tail -n 20 "$log"; }; rm -f "$log"; return $rc; fi
  "$@" >"$log" 2>&1 & local pid=$! i=0 h=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █ ▇ ▆ ▅ ▄ ▃ ▂) g
  printf '\e[?25l'
  while kill -0 "$pid" 2>/dev/null; do
    g=""; local k; for k in 0 1 2 3 4 5 6 7 8 9 10 11; do g+=${h[$(( (i + k * 3 + (k % 4) * 2) % ${#h[@]} ))]}; done
    printf '\r%s%s%s  %s' "$O" "$g" "$N" "$label"; i=$((i + 1)); sleep 0.09
  done
  wait "$pid"; local rc=$?; printf '\r\e[K\e[?25h'
  if [ $rc -eq 0 ]; then ok "$label"; else bad "$label"; tail -n 20 "$log"; fi
  rm -f "$log"; return $rc
}
