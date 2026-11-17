#!/usr/bin/env bash
# Gwenview becomes the default viewer for pictures and videos.
# args: id user home   (runs as root)
ID=$1; U=$2; H=$3
for m in image/jpeg image/png image/gif image/webp image/bmp image/svg+xml image/tiff image/avif image/heif image/x-icon \
         video/mp4 video/x-matroska video/webm video/x-msvideo video/quicktime video/mpeg video/ogg; do
  sudo -u "$U" env HOME="$H" xdg-mime default org.kde.gwenview.desktop "$m"
done
