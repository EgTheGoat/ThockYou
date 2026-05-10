#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_ICNS="$ROOT_DIR/Resources/AppIcon.icns"
INPUT_PNG="${1:-$ROOT_DIR/docs/icon.png}"

if [ ! -f "$INPUT_PNG" ]; then
  echo "icon source not found: $INPUT_PNG" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ICONSET="$TMP_DIR/AppIcon.iconset"
SOURCE_PNG="$TMP_DIR/icon_1024.png"

mkdir -p "$ICONSET"

sips -z 1024 1024 "$INPUT_PNG" --out "$SOURCE_PNG" >/dev/null

sizes=(16 32 32 64 128 256 256 512 512 1024)
names=(
  "icon_16x16.png"
  "icon_16x16@2x.png"
  "icon_32x32.png"
  "icon_32x32@2x.png"
  "icon_128x128.png"
  "icon_128x128@2x.png"
  "icon_256x256.png"
  "icon_256x256@2x.png"
  "icon_512x512.png"
  "icon_512x512@2x.png"
)

for i in "${!sizes[@]}"; do
  sips -z "${sizes[$i]}" "${sizes[$i]}" "$SOURCE_PNG" --out "$ICONSET/${names[$i]}" >/dev/null
done

mkdir -p "$(dirname "$OUTPUT_ICNS")"
iconutil -c icns "$ICONSET" -o "$OUTPUT_ICNS"
echo "Wrote $OUTPUT_ICNS"
