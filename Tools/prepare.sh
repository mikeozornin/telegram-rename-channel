#!/bin/sh
# Regenerates the vendored inputs from the Telegram sources (read-only use of R/submodules):
#  1. Vendor/DisplayPatched: copies of two Display files whose iOS 27.1 SDK calls (UIView.reservedRegions, only
#     relevant to iPhone Duo) are stubbed out, so Display builds with the Xcode 26 SDK.
#  2. Resources/Assets.xcassets: only the imagesets the prototype uses, copied from TelegramUI/Images.xcassets with
#     their namespaced folders.
set -e
HERE="$(cd "$(dirname "$0")/.." && pwd)"
S="$HERE/../../submodules"
sed 's/return view.reservedRegions(kind: .occlusion).filter(\\.isActive).map(\\.frame)/return []/' \
  "$S/Display/Source/ReservedArea.swift" > "$HERE/Vendor/DisplayPatched/ReservedArea.swift"
sed 's/return self.eventView.reservedRegions(kind: .division).first(where: \\.isActive)?.frame/return nil/' \
  "$S/Display/Source/WindowContent.swift" > "$HERE/Vendor/DisplayPatched/WindowContent.swift"
SRC="$S/TelegramUI/Images.xcassets"
DST="$HERE/Resources/Assets.xcassets"
rm -rf "$DST"; mkdir -p "$DST"; cp "$SRC/Contents.json" "$DST/"
while IFS= read -r name; do
  [ -z "$name" ] && continue
  case "$name" in \#*) continue;; esac
  dir="$(dirname "$name")"
  # copy each namespace folder's Contents.json along the way
  p=""; IFS_OLD="$IFS"; IFS="/"
  for part in $dir; do p="${p:+$p/}$part"; mkdir -p "$DST/$p"; [ -f "$SRC/$p/Contents.json" ] && cp "$SRC/$p/Contents.json" "$DST/$p/"; done
  IFS="$IFS_OLD"
  cp -R "$SRC/$name.imageset" "$DST/$dir/"
done < "$HERE/Tools/assets.txt"
echo "prepared: $(find "$DST" -name '*.imageset' | wc -l | tr -d ' ') imagesets"
