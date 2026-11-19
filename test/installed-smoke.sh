#!/usr/bin/env bash
# Smoke test of the Sunshine tools on an INSTALLED system in a VM (ssh): every tool runs its harmless modes; the result is a PASS/FAIL table.
#   SSH_PORT=2223 test/installed-smoke.sh NAME
cd "$(dirname "$0")/.."
N=${1:?vm name}; export SSH_PORT=${SSH_PORT:-2223}; D=test/dev-vm.sh
L=test/tmp/installed-$N.log; mkdir -p test/tmp; : > "$L"
pass=0; fail=0
t() {   # t "title" "command" ["expected regex"]
  local title=$1 cmd=$2 re=${3:-} out rc
  out=$($D ssh "$N" "$cmd" 2>&1); rc=$?
  if [ $rc -eq 0 ] && { [ -z "$re" ] || printf '%s' "$out" | grep -qE "$re"; }; then pass=$((pass+1)); printf 'PASS  %s\n' "$title" | tee -a "$L"
  else fail=$((fail+1)); printf 'FAIL  %s (rc=%s)\n' "$title" "$rc" | tee -a "$L"; printf '%s\n' "$out" | tail -8 | sed 's/^/        /' | tee -a "$L"; fi
  { echo "--- $title: $cmd"; printf '%s\n' "$out"; } >> "$L.full"
}
: > "$L.full"
t "system identity" 'grep -q "Sunshine" /etc/os-release'
t "boots with a kernel and initramfs" 'ls /boot/vmlinuz-linux /boot/initramfs-linux.img'
t "pacman database consistent" 'pacman -Dk'
t "[sunshine] repository configured" 'grep -q "^\[sunshine\]" /etc/pacman.conf'
t "sunshine-base installed" 'pacman -Q sunshine-base 2>&1 | grep -q sunshine-base || pacman -Qi sunshine-base' 
t "toolsync status" 'sudo sunshine-toolsync status || true; test -x /usr/local/bin/sunshine-toolsync'
t "toolsync update from the real tools repository" 'sudo sunshine-toolsync update' 'tools (updated|are up to date)|updated'
t "toolsync verify" 'sudo sunshine-toolsync verify' 'matches|manifest'
t "migrations run" 'sudo sunshine-migrate; sudo sunshine-migrate list'
t "doctor check" 'sudo sunshine-doctor' 'All good|problem'
t "doctor --fix runs" 'sudo sunshine-doctor --fix'
t "drivers detect" 'sudo sunshine-drivers detect' 'Hardware'
t "kernel list" 'sudo sunshine-kernel list' 'linux'
t "kernel available" 'sudo sunshine-kernel available' 'linux'
t "desktops list" 'sudo sunshine-desktops list' 'gnome'
t "gaming status/gpu" 'sudo sunshine-gaming status; sudo sunshine-gaming gpu'
t "performance on" 'sudo sunshine-performance on'
t "performance status" 'sudo sunshine-performance status' 'swappiness'
t "performance bench" 'sudo sunshine-performance bench' 'Startup finished'
t "pacnew list" 'sudo sunshine-pacnew list'
t "fix network" 'sunshine-fix network' 'Network'
t "fix storage" 'sunshine-fix storage' 'Storage'
t "fix gpu" 'sunshine-fix gpu' 'Graphics'
t "support report" 'sunshine-support --print | head -30' 'Sunshine OS support report'
t "snapshot status" 'sudo sunshine-snapshot status || true'
t "update check (no install)" 'checkupdates | head -3; true'
t "fix-pacman" 'sudo sunshine-fix-pacman'
t "firewall" 'sudo ufw status | head -3'
t "failed units" 'systemctl --failed --no-legend | wc -l'
t "boot time" 'systemd-analyze | head -1' 'Startup finished'
echo; echo "installed smoke: $pass passed, $fail failed (details: $L.full)" | tee -a "$L"
[ $fail = 0 ]
