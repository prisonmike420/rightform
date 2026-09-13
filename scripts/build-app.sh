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
cp "$source_root/Resources/Rightform.icns" "$resources/Rightform.icns"
cp "$source_root/Resources/plugins.json" "$resources/plugins.json"

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

/usr/bin/codesign --force --deep --sign - "$output_app" >/dev/null 2>&1 || true
/usr/bin/touch "$output_app"
print "Built $output_app"
