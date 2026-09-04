#!/bin/zsh
# Build an Rightform.app bundle from the checked-out Swift source.
# Usage: scripts/build-app.sh /absolute/path/to/Rightform.app

set -euo pipefail

if (( $# != 1 )); then
  print -u2 "Usage: $0 /absolute/path/to/Rightform.app"
  exit 64
fi

source_root="${0:A:h:h}"
output_app="${1:A}"
contents="$output_app/Contents"
macos="$contents/MacOS"
resources="$contents/Resources"

if [[ "${output_app:t}" != "Rightform.app" || "$output_app" == "/Rightform.app" ]]; then
  print -u2 "Output must be a non-root Rightform.app bundle."
  exit 64
fi

if ! /usr/bin/xcrun --find swiftc >/dev/null 2>&1; then
  print -u2 "Apple Command Line Tools are required. Run: xcode-select --install"
  exit 1
fi

# Keep Swift's module cache inside a disposable directory. It makes the build
# work in sandboxed environments too, and avoids relying on a writable home
# directory during Homebrew builds.
module_cache="$(mktemp -d)"
trap 'rm -rf "$module_cache"' EXIT
export CLANG_MODULE_CACHE_PATH="$module_cache"

rm -rf "$output_app"
mkdir -p "$macos" "$resources"

cp "$source_root/Resources/Info.plist" "$contents/Info.plist"
cp "$source_root/Resources/AppIcon.png" "$resources/AppIcon.png"

/usr/bin/xcrun swiftc \
  -swift-version 5 \
  -parse-as-library \
  -O \
  -framework SwiftUI \
  -framework AppKit \
  -framework UniformTypeIdentifiers \
  -framework ImageIO \
  -framework CoreGraphics \
  -framework PDFKit \
  "$source_root/Sources/Rightform.swift" \
  -o "$macos/Rightform"

chmod +x "$macos/Rightform"

iconset="$output_app.iconset"
mkdir -p "$iconset"
function make_icon() {
  /usr/bin/sips -s format png -z "$1" "$1" "$resources/AppIcon.png" --out "$iconset/$2" >/dev/null
}
make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png
/usr/bin/iconutil -c icns "$iconset" -o "$resources/Rightform.icns"
rm -rf "$iconset"

/usr/bin/codesign --force --deep --sign - "$output_app" >/dev/null 2>&1 || true
/usr/bin/touch "$output_app"
print "Built $output_app"
