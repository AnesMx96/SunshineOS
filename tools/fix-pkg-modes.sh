#!/usr/bin/env bash
# Repairs packages in ./repo whose files are not readable by normal users (mode rwxr-x--- and the like). Cause: a package assembled in a
# directory that carries a restrictive default ACL (a bind mount from a host with 770/660 defaults) gets those modes for every file, and
# then the Darkly style, GTK themes, icons, `uni`, the browser ... exist on the system but only root can read them. Idempotent: only packages
# with such entries are rewritten (modes get "other" read, plus execute where the owner has it; owner and everything else are unchanged).
# usage: tools/fix-pkg-modes.sh [repo-dir]      (Docker; the sunshineos-builder image)
set -euo pipefail
cd "$(dirname "$0")/.."
R=${1:-repo}; [ -d "$R" ] || { echo "no $R"; exit 1; }
docker run --rm -v "$PWD/$R:/repo" -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" sunshineos-builder bash -c '
  set -e; cd /repo; fixed=0
  for f in *.pkg.tar.zst; do
    case "$f" in *-debug-*) continue;; esac
    n=$(bsdtar -tvf "$f" | awk '"'"'substr($1,1,1)!="l" && substr($1,8,1)!="r" {c++} END{print c+0}'"'"')
    [ "$n" -gt 0 ] || continue
    t=$(mktemp -d); bsdtar -xpf "$f" -C "$t"
    ( cd "$t"; find . -mindepth 1 -not -path "./.*" -not -type l -exec chmod go+rX {} + )
    rm -f "$t/.MTREE"    # it records the old modes; pacman works without it
    ( cd "$t"; bsdtar --zstd -cf "/repo/$f.new" .PKGINFO $(ls -A | grep -v "^\.PKGINFO$") )
    mv -f "/repo/$f.new" "/repo/$f"; rm -rf "$t"; fixed=$((fixed+1)); echo "fixed modes in $f ($n entries)"
  done
  if [ "$fixed" -gt 0 ]; then rm -f sunshine.db* sunshine.files*; repo-add -q sunshine.db.tar.gz $(ls *.pkg.tar.zst | grep -v -- "-debug-"); fi
  chown -R "$HOST_UID:$HOST_GID" /repo; echo "modes: $fixed package(s) repaired"'
