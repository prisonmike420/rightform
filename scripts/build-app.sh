#!/bin/zsh
# Build an STOU.app bundle from the checked-out Swift source.
# Usage: scripts/build-app.sh /absolute/path/to/STOU.app

set -euo pipefail

if (( $# != 1 )); then
  print -u2 "Usage: $0 /absolute/path/to/STOU.app"
  exit 64
fi

source_root="${0:A:h:h}"
output_app="${1:A}"
contents="$output_app/Contents"
macos="$contents/MacOS"
resources="$contents/Resources"

if [[ "${output_app:t}" != "STOU.app" || "$output_app" == "/STOU.app" ]]; then
  print -u2 "Output must be a non-root STOU.app bundle."
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

# The version comes from VERSION (or STOU_VERSION, which the release
# workflow sets); the build number rises by itself: the
# version as a number (0.18.0 → 1800) plus, in a git checkout, the number of
# commits, so every new build is higher than the last.
version="${STOU_VERSION:-$(<"$source_root/VERSION")}"
version="${version//[[:space:]]/}"
parts=("${(@s:.:)version}")
if (( ${#parts} != 3 )) || [[ "$version" != <->.<->.<-> ]]; then
  print -u2 "VERSION must look like 1.2.3, not '$version'."
  exit 1
fi
build=$(( parts[1] * 10000 + parts[2] * 100 + parts[3] ))
if commits="$(/usr/bin/git -C "$source_root" rev-list --count HEAD 2>/dev/null)"; then
  build="$build.$commits"
fi
/usr/libexec/PlistBuddy \
  -c "Set :CFBundleShortVersionString $version" \
  -c "Set :CFBundleVersion $build" \
  "$contents/Info.plist"
# The icon's source is the Xcode asset Resources/AppIcon.appiconset. iconutil
# wants iconset names (icon_16x16.png, not icon_16x16@1x.png), so stage a copy.
iconset="$(mktemp -d)/STOU.iconset"
mkdir -p "$iconset"
for png in "$source_root"/Resources/AppIcon.appiconset/icon_*.png; do
  cp "$png" "$iconset/${${png:t}/@1x/}"
done
/usr/bin/iconutil -c icns "$iconset" -o "$resources/STOU.icns"
rm -rf "${iconset:h}"
cp "$source_root/Resources/plugins.json" "$resources/plugins.json"

sources=("$source_root"/Sources/**/*.swift(N))
if (( ${#sources} == 0 )); then
  print -u2 "No Swift sources found in $source_root/Sources."
  exit 1
fi

# STOU targets the current macOS release only.
/usr/bin/xcrun swiftc \
  -swift-version 5 \
  -target "$(/usr/bin/uname -m)-apple-macos26.0" \
  -parse-as-library \
  -O \
  -framework SwiftUI \
  -framework AppKit \
  -framework UniformTypeIdentifiers \
  -framework ImageIO \
  -framework CoreGraphics \
  -framework PDFKit \
  "${sources[@]}" \
  -o "$macos/STOU"

chmod +x "$macos/STOU"

/usr/bin/codesign --force --deep --sign - "$output_app" >/dev/null 2>&1 || true
/usr/bin/touch "$output_app"
print "Built $output_app ($version, build $build)"
