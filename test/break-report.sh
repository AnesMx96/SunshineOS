#!/usr/bin/env bash
# Turns the log of test/break-repair.sh into a Markdown report.
#   test/break-report.sh [LOG] > docs/team/reports/break-repair-results.md
# For every scenario: result line, then the part of the doctor output that matters (problem lines after the break, problem lines after the repair).
cd "$(dirname "$0")/.." || exit 2
LOG=${1:-test/tmp/break-Sol-inst.log}
[ -f "$LOG" ] || { echo "no log: $LOG" >&2; exit 2; }
sed 's/\x1b\[[0-9;]*[A-Za-z]//g' "$LOG" > /tmp/break-report.clean
echo "# Break-and-repair results ($(date '+%Y-%m-%d %H:%M'))"
echo
echo "VM and log: $LOG"
echo
echo "## Summary"
echo
echo '```'
sed -n '/^================ summary/,$p' /tmp/break-report.clean | tail -n +2
echo '```'
echo
echo "PASS = detected by the doctor, repaired, verified, doctor clean. GAP = works only with a specific tool, or the doctor did not detect it. FAIL = not repaired. SKIP = precondition not met."
echo
echo "## Per scenario"
awk '
/^================ [0-9][0-9]-/ { if (id) flush(); id=$2; title=$0; sub(/^================ [^ ]+ /,"",title); section="break"; det=""; after=""; detect=""; next }
/^---- doctor after break/ { section="break"; next }
/^---- doctor did not repair/ { section="alt"; next }
/^---- doctor after repair/ { section="after"; print_after=$0; after_line=$0; next }
/^---- live repair output/ { section="live"; next }
/^detect:/ { detect=$0; next }
/^baseline doctor:/ { base=$0; next }
{ if (section=="break" && $0 ~ /✘|problem\(s\) found|^  !/) det=det "\n    " $0
  else if (section=="after" && $0 ~ /✘|problem\(s\) found/) after=after "\n    " $0
  else if (section=="live" && $0 ~ /✘|failed|Repair finished|step\(s\) failed/) live=live "\n    " $0 }
function flush() { printf "\n### %s: %s\n\n%s\n%s\n", id, title, base, detect; if (det!="") printf "\nDoctor after the break:\n```%s\n```\n", det; if (live!="") printf "\nLive repair:\n```%s\n```\n", live; if (after!="") printf "\nDoctor after the repair:\n```%s\n```\n", after; live=""; det=""; after="" }
END { if (id) flush() }' /tmp/break-report.clean
