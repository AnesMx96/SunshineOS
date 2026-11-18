#!/usr/bin/env bash
# Static checks of the sources: no ISO, no VM, a few seconds. Run before every build:   test/static.sh
# Catches the kind of mistakes that reached a release before: a Python tool that crashes on its first line, a shell library function that
# shadows a coreutils command, $variables in a Calamares command, two copies of a tool that drifted apart.
cd "$(dirname "$0")/.."
fail=0; ok() { printf '  ok   %s\n' "$*"; }; bad() { printf '  FAIL %s\n' "$*"; fail=1; }
echo "== shell syntax"
n=0; while IFS= read -r f; do
  head -1 "$f" 2>/dev/null | grep -qE '^#!.*(bash|/sh)' || continue
  n=$((n+1)); bash -n "$f" 2>/tmp/static.err || { bad "$f: $(head -1 /tmp/static.err)"; }
done < <(git ls-files overlay profile/airootfs profile/grub tools test make-iso.sh build.sh build-aur.sh 2>/dev/null | grep -v -E '\.(png|svg|pf2|json|toml|qml|css|conf|cfg|desktop|service|timer|path|hook|tsv|md|txt|xml|ini|colors|kvconfig)$')
ok "$n shell scripts parse"
echo "== python tools start (Qt offscreen, 3 s)"
for t in sunshine-welcome sunshine-toolbox sunshine-pet sunshine-pods; do
  f=overlay/system/usr/local/bin/$t; [ -f "$f" ] || f=profile/airootfs/usr/local/bin/$t
  out=$(SUNSHINE_I18N="$PWD/overlay/system/usr/share/sunshine/i18n" QT_QPA_PLATFORM=offscreen timeout 3 python3 "$f" 2>&1); rc=$?
  if [ $rc -eq 124 ]; then ok "$t starts"; elif python3 -c 'import PyQt6' 2>/dev/null; then bad "$t exited with $rc: $(printf '%s' "$out" | tail -1)"; else ok "$t skipped (PyQt6 missing)"; fi
done
echo "== the store"
for m in backend index themes windows appimage; do (cd profile/airootfs/usr/lib/sunshine-store && python3 -c "import sys; sys.path.insert(0,'.'); import $m" 2>/tmp/static.err) && ok "store module $m imports" || bad "store module $m: $(tail -1 /tmp/static.err)"; done
out=$(cd profile/airootfs/usr/lib/sunshine-store && QT_QPA_PLATFORM=offscreen timeout 4 python3 app.py 2>&1); rc=$?
[ $rc -eq 124 ] && ok "sunshine-store starts" || { python3 -c 'import PyQt6' 2>/dev/null && bad "sunshine-store exited with $rc: $(printf '%s' "$out" | tail -1)" || ok "sunshine-store skipped (PyQt6 missing)"; }
for f in $(git ls-files 'overlay/**/*.py' 'profile/airootfs/**/*.py' 'tools/*.py'); do python3 -m py_compile "$f" 2>/tmp/static.err && ok "$f" || bad "$f: $(tail -1 /tmp/static.err)"; done
echo "== the shell library must not shadow system commands"
shadow=$(bash -c '. overlay/system/usr/local/lib/sunshine/ui.sh; for f in $(declare -F | cut -d" " -f3); do p=$(type -P "$f"); [ -n "$p" ] && echo "$f"; done' 2>/dev/null)
[ -z "$shadow" ] && ok "ui.sh defines no function named like an installed command" || bad "ui.sh shadows: $shadow"
echo "== Calamares commands carry no \$variables of their own"
for f in profile/airootfs/etc/calamares/modules/shellprocess-*.conf; do
  v=$(grep -E '^\s*-\s*command:' "$f" | grep -oE '\$\{?[A-Za-z_][A-Za-z0-9_]*' | grep -v -E '^\$\{?(ROOT|USER)$' | sort -u | tr '\n' ' ')
  [ -z "$v" ] && ok "$(basename "$f")" || bad "$f uses $v (Calamares substitutes these: move the logic into a script)"
done
echo "== copies of the same file agree (overlay/system is the source of truth)"
d=0; while IFS= read -r f; do [ -e "profile/airootfs/$f" ] && ! cmp -s "overlay/system/$f" "profile/airootfs/$f" && { bad "drift: $f (run: cp -a overlay/system/. profile/airootfs/)"; d=1; }; done < <(cd overlay/system && find . -type f -not -path '*__pycache__*' | sed 's|^\./||')
[ $d = 0 ] && ok "no drift between overlay/system and profile/airootfs"
echo "== word list"
awk -F'\t' 'NF!=2 {print FILENAME": line "NR" has "NF" fields"; bad=1} END {exit bad}' overlay/system/usr/share/sunshine/i18n/uk.tsv && ok "uk.tsv is two columns" || bad "uk.tsv malformed"
echo "== boot parameters"
for f in profile/grub/grub.cfg profile/grub/loopback.cfg profile/syslinux/archiso_sys-linux.cfg profile/efiboot/loader/entries/01-archiso-linux.conf; do grep -q cow_spacesize "$f" && ok "$f: cow_spacesize" || bad "$f: no cow_spacesize (the live overlay would be 256 MiB)"; done
echo
[ $fail = 0 ] && echo "static checks passed" || echo "static checks FAILED"
exit $fail
