#!/usr/bin/env bash
# Break-and-repair test for an INSTALLED Sunshine OS in a VirtualBox VM: breaks the system on purpose in one way per scenario (test/break/*.sh),
# checks that sunshine-doctor reports it, repairs it, verifies the system is really fine, and rolls the VM back with a snapshot.
#
#   test/break-repair.sh NAME                 run every scenario in test/break/
#   test/break-repair.sh NAME 01 07 fstab     only these (number, or part of the file name)
#   test/break-repair.sh --list               list the scenarios
# Environment: SSH_PORT (default 2223: the NAT forward of the VM to its sshd), SSH_USER/SSH_PASS (default sunshine/sunshine, passwordless sudo),
#              NO_SNAPSHOT=1 (do not take/restore snapshots: the scenarios clean up by hand; for quick iteration only),
#              KEEP=1 (do not roll back after a scenario that failed, so you can look at the broken VM),
#              LIVE_BOOT_TIMEOUT (seconds to wait for a boot, default 420).
# A scenario file (sourced in a fresh subshell) defines:
#   TITLE="..."            short name
#   LIVE=1                 (optional) the repair needs the live ISO: the VM is rebooted into it and `sunshine-rescue repair` is run there
#   DETECT_ONLY=1          (optional) only the detection is tested (nothing to repair automatically, e.g. a pacnew list)
#   precondition()         (optional) return non-zero to SKIP (e.g. "only on btrfs")
#   break()                break the system (use vm / vmr)
#   expect_detect()        print an extended regex that the output of `sunshine-doctor` must match once broken
#   repair()               (optional) default: sudo sunshine-doctor --fix  (LIVE: sunshine-rescue repair)
#   repair_alt()           (optional) another Sunshine tool that should fix it when the doctor does not (reported as "doctor gap")
#   verify()               return 0 when the system is really OK again (use vm / vmr)
# Result per scenario: PASS (detected, repaired, verified, doctor clean), GAP (works only with repair_alt, or the doctor did not detect it),
# FAIL, SKIP. The log is test/tmp/break-NAME.log.
# shellcheck disable=SC1090
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
DIR=test/break
if [ "${1:-}" = --list ]; then for f in "$DIR"/*.sh; do (TITLE=; LIVE=0; . "$f"; printf '%-34s %s%s\n' "$(basename "$f" .sh)" "$TITLE" "$([ "${LIVE:-0}" = 1 ] && echo '  [live ISO]')"); done; exit 0; fi
NAME=${1:?usage: test/break-repair.sh VMNAME [scenario ...]}; shift
SSH_PORT=${SSH_PORT:-2223}; SSH_USER=${SSH_USER:-sunshine}; SSH_PASS=${SSH_PASS:-sunshine}
SNAP=sunshine-break-base
BOOT_TIMEOUT=${LIVE_BOOT_TIMEOUT:-420}
mkdir -p test/tmp; LOG=test/tmp/break-$NAME.log; : > "$LOG"
SSHOPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=8 -o ServerAliveInterval=10 -o ServerAliveCountMax=6 -p "$SSH_PORT")
ANSI=$'s/\x1b\\[[0-9;]*[A-Za-z]//g'
log() { printf '%s\n' "$*" | tee -a "$LOG" >/dev/null; }
say() { printf '%s\n' "$*"; log "$*"; }

# ---- talking to the VM ------------------------------------------------------------------------------------------------------------
vm()  { sshpass -p "$SSH_PASS" ssh "${SSHOPTS[@]}" "$SSH_USER@127.0.0.1" bash -s <<<"$*"; }                 # as the user
vmr() { sshpass -p "$SSH_PASS" ssh "${SSHOPTS[@]}" "$SSH_USER@127.0.0.1" sudo -n bash -s <<<"$*"; }       # as root
vm_su() { { sleep 2; echo "$SSH_PASS"; sleep 90; } | sshpass -p "$SSH_PASS" ssh -tt "${SSHOPTS[@]}" "$SSH_USER@127.0.0.1" "su -c '$*'" 2>&1 | tr -d '\r'; }   # when sudo itself is broken
vm_up() { sshpass -p "$SSH_PASS" ssh "${SSHOPTS[@]}" "$SSH_USER@127.0.0.1" true 2>/dev/null; }
wait_vm() { local i; for ((i=0; i<BOOT_TIMEOUT/5; i++)); do vm_up && return 0; sleep 5; done; return 1; }
doctor_out() { vmr 'sunshine-doctor 2>&1' 2>&1 | sed "$ANSI"; }
bad_count() { printf '%s\n' "$1" | grep -c '✘'; }
export -f vm vmr vm_su 2>/dev/null; export SSH_PORT SSH_USER SSH_PASS
vbox() { VBoxManage "$@" >>"$LOG" 2>&1; }
vm_state() { VBoxManage showvminfo "$NAME" --machinereadable 2>/dev/null | sed -n 's/^VMState="\(.*\)"/\1/p'; }
power_off() { [ "$(vm_state)" = running ] && vbox controlvm "$NAME" poweroff; local i; for i in 1 2 3 4 5 6 7 8 9 10; do [ "$(vm_state)" = running ] || return 0; sleep 2; done; }
power_on() { vbox startvm "$NAME" --type gui; }

for t in sshpass VBoxManage; do command -v "$t" >/dev/null || { echo "missing: $t"; exit 2; }; done
VBoxManage showvminfo "$NAME" >/dev/null 2>&1 || { echo "no such VM: $NAME"; exit 2; }
vm_up || { echo "cannot reach $NAME over ssh on port $SSH_PORT (is it running and installed?)"; exit 2; }

# ---- snapshots --------------------------------------------------------------------------------------------------------------------
snap_take() { [ "${NO_SNAPSHOT:-0}" = 1 ] && return 0; VBoxManage snapshot "$NAME" list 2>/dev/null | grep -q "$SNAP" || vbox snapshot "$NAME" take "$SNAP" --live; }
snap_restore() {
  [ "${NO_SNAPSHOT:-0}" = 1 ] && return 0
  power_off; vbox snapshot "$NAME" restore "$SNAP"; power_on; wait_vm || { say "!! the VM did not come back after the rollback"; return 1; }
}
snap_drop() { [ "${NO_SNAPSHOT:-0}" = 1 ] && return 0; vbox snapshot "$NAME" delete "$SNAP"; }

# ---- the live ISO repair path -----------------------------------------------------------------------------------------------------
live_repair() {   # reboot into the live ISO, run the rescue tool on the installed disk, reboot into the installed system
  power_off; vbox modifyvm "$NAME" --boot1 dvd --boot2 disk; power_on
  wait_vm || { say "!! live ISO did not come up"; vbox modifyvm "$NAME" --boot1 disk --boot2 dvd; return 1; }
  vm 'test -d /run/archiso' || say "!! this is not the live session (is the ISO attached and first in the boot order?)"
  local out; out=$(vmr "${LIVE_CMD:-sunshine-rescue repair} 2>&1" 2>&1 | sed "$ANSI")
  log "---- live repair output"; log "$out"
  power_off; vbox modifyvm "$NAME" --boot1 disk --boot2 dvd; power_on
  wait_vm || { say "!! the installed system did not boot after the repair"; return 1; }
  return 0
}

# ---- one scenario -----------------------------------------------------------------------------------------------------------------
declare -a ROWS
run_scenario() {
  local file=$1 id; id=$(basename "$file" .sh)
  local t0=$SECONDS res=PASS why=
  (
    TITLE=; LIVE=0; DETECT_ONLY=0
    # shellcheck source=/dev/null
    . "$file"
    declare -F break >/dev/null || { echo "SKIP no break()"; exit 0; }
    if declare -F precondition >/dev/null && ! precondition; then echo "SKIP precondition not met"; exit 0; fi
    log; log "================ $id: $TITLE"
    base=$(doctor_out); nb=$(bad_count "$base"); log "baseline doctor: $nb problem(s)"
    # shellcheck disable=SC2105
    break >>"$LOG" 2>&1
    sleep 2
    out=$(doctor_out); log "---- doctor after break"; log "$out"
    pat=$(expect_detect); detect=no; printf '%s\n' "$out" | grep -Eqi -- "$pat" && detect=yes
    log "detect: $detect (expected /$pat/)"
    repaired=no
    if [ "${DETECT_ONLY:-0}" = 1 ]; then echo "$detect:detect-only:-"; exit 0; fi
    if [ "${LIVE:-0}" = 1 ]; then
      live_repair || { echo "FAIL:live repair did not complete"; exit 0; }
    elif declare -F repair >/dev/null; then repair >>"$LOG" 2>&1; else vmr 'sunshine-doctor --fix 2>&1' 2>&1 | sed "$ANSI" >>"$LOG"; fi
    sleep 2
    verify >>"$LOG" 2>&1 && repaired=yes
    alt=no
    if [ "$repaired" = no ] && declare -F repair_alt >/dev/null; then
      log "---- doctor did not repair it: trying the specific tool"
      repair_alt >>"$LOG" 2>&1; sleep 2; verify >>"$LOG" 2>&1 && alt=yes
    fi
    after=$(doctor_out); na=$(bad_count "$after"); log "---- doctor after repair: $na problem(s) (baseline $nb)"; [ "$na" -gt "$nb" ] && log "$after"
    clean=yes; [ "$na" -gt "$nb" ] && clean=no
    echo "$detect:$repaired:$alt:$clean"
  ) > "$LOG.row" 2>>"$LOG"
  local row; row=$(tail -1 "$LOG.row")
  case "$row" in
    SKIP*) res=SKIP; why=${row#SKIP } ;;
    FAIL:*) res=FAIL; why=${row#FAIL:} ;;
    *:detect-only:*) [ "${row%%:*}" = yes ] && res=PASS || { res=GAP; why="doctor does not detect it"; } ;;
    yes:yes:no:yes) res=PASS ;;
    *)
      IFS=: read -r d r a c <<<"$row"
      if [ "$r" = yes ] || [ "$a" = yes ]; then res=GAP; [ "$d" = no ] && why="not detected by the doctor; "; [ "$r" = no ] && [ "$a" = yes ] && why="${why}doctor does not repair it (the specific tool does); "; [ "$c" = no ] && why="${why}doctor reports new problems afterwards; "
      else res=FAIL; why="not repaired (detected=$d)"; fi ;;
  esac
  local title; title=$(TITLE=; . "$file"; echo "$TITLE")
  ROWS+=("$(printf '%-5s %-30s %4ss  %s' "$res" "$id" "$((SECONDS-t0))" "$why")")
  say "$res  $id  ($title)  ${why}"
  if [ "$res" = FAIL ] && [ "${KEEP:-0}" = 1 ]; then say "KEEP=1: the VM stays broken for inspection; stopping."; exit 1; fi
}

# ---- main -------------------------------------------------------------------------------------------------------------------------
files=()
if [ $# -eq 0 ]; then files=("$DIR"/*.sh); else
  for a in "$@"; do for f in "$DIR"/*.sh; do case "$(basename "$f")" in *"$a"*) files+=("$f");; esac; done; done
fi
[ ${#files[@]} -gt 0 ] || { echo "no scenario matches"; exit 2; }
say "break-repair on $NAME (ssh port $SSH_PORT), ${#files[@]} scenario(s), log $LOG"
snap_take || true
for f in "${files[@]}"; do
  run_scenario "$f"
  snap_restore || { say "cannot continue: rollback failed"; break; }
done
snap_drop || true
echo; echo "================ summary"; printf '%s\n' "${ROWS[@]}" | tee -a "$LOG"
p=$(printf '%s\n' "${ROWS[@]}" | grep -c '^PASS'); g=$(printf '%s\n' "${ROWS[@]}" | grep -c '^GAP'); f=$(printf '%s\n' "${ROWS[@]}" | grep -c '^FAIL'); s=$(printf '%s\n' "${ROWS[@]}" | grep -c '^SKIP')
echo "PASS $p   GAP $g   FAIL $f   SKIP $s"; [ "$f" -eq 0 ]
