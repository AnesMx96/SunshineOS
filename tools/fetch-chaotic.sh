#!/usr/bin/env bash
# Chaotic-AUR is a repository of prebuilt AUR packages. Its keyring and mirror list are not in the Arch repos or the AUR, so they are
# downloaded from the Chaotic CDN into ./repo (the build repository), like the packages build-aur.sh makes. Idempotent.
set -euo pipefail
cd "$(dirname "$0")/.."; mkdir -p repo
for p in chaotic-keyring chaotic-mirrorlist; do
  ls repo | grep -qE "^$p-[^-]+-[0-9]+-any\.pkg\.tar\.zst$" && continue
  tmp=$(mktemp); curl -fsSL --retry 3 -o "$tmp" "https://cdn-mirror.chaotic.cx/chaotic-aur/$p.pkg.tar.zst"
  ver=$(bsdtar -xOf "$tmp" .PKGINFO | sed -n 's/^pkgver = //p'); mv "$tmp" "repo/$p-$ver-any.pkg.tar.zst"; chmod 644 "repo/$p-$ver-any.pkg.tar.zst"
  echo "fetched $p $ver"
done
cd repo && rm -f sunshine.db* sunshine.files* && repo-add -q sunshine.db.tar.gz $(ls ./*.pkg.tar.zst | grep -v -- "-debug-")
