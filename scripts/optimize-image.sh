#!/usr/bin/env bash
# Optimize a brand image into AVIF + WebP for the site.
# This is the ONLY way images enter assets/ — see "Images" in README.md.
#
#   Usage:   scripts/optimize-image.sh <source-image> <output-basename> <max-width-px>
#   Example: scripts/optimize-image.sh assets/masters/armory-banner.png armory-banner 1600
#
# Writes assets/<basename>.avif and assets/<basename>.webp, each resized to
# <max-width-px> (never upscaled). Pick width ≈ 2× the largest CSS size the image renders at.
# Keep the source PNG master in assets/masters/; reference the output with the <picture>
# block documented in README.md.
#
# Requires: ImageMagick (magick) + libavif (avifenc).
set -euo pipefail

src="${1:?source image required}"
name="${2:?output basename required}"
width="${3:?max width in px required}"

out="assets"
QUALITY_WEBP=82   # 0–100
QUALITY_AVIF=60   # 0–100 (≈ WebP 82)
AVIF_SPEED=4      # 0 slowest/best … 10 fastest

mkdir -p "$out"
tmp="$(mktemp --suffix=.png)"
trap 'rm -f "$tmp"' EXIT

# Resize once from the source master, then encode both formats from that intermediate.
magick "$src" -resize "${width}x>" -strip "$tmp"
magick "$tmp" -quality "$QUALITY_WEBP" -define webp:method=6 "$out/$name.webp"
avifenc -q "$QUALITY_AVIF" -s "$AVIF_SPEED" "$tmp" "$out/$name.avif" >/dev/null

printf '%s  →  %s avif · %s webp  (%s)\n' "$name" \
  "$(du -h "$out/$name.avif" | cut -f1)" \
  "$(du -h "$out/$name.webp" | cut -f1)" \
  "$(magick identify -format '%wx%h' "$out/$name.webp")"
