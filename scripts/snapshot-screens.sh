#!/bin/zsh
# Save PNG snapshots of Stou's screens, to check layout without driving the
# app (no clicks, no Accessibility permission needed).
# Usage: scripts/snapshot-screens.sh [output folder]   (default: build/snapshots)
#
# It compiles the app's sources, minus Sources/App/StouApp.swift (which holds
# @main), with scripts/snapshot/Harness.swift, and renders each screen in an
# offscreen window. Liquid Glass doesn't render offscreen, so the rail's
# capsules and the panel's glass are missing from the snapshots. The harness
# has its own defaults domain: the real app's settings are neither read nor
# changed.

set -euo pipefail

source_root="${0:A:h:h}"
output="${1:-$source_root/build/snapshots}"
output="${output:A}"

if ! /usr/bin/xcrun --find swiftc >/dev/null 2>&1; then
  print -u2 "Apple Command Line Tools are required. Run: xcode-select --install"
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export CLANG_MODULE_CACHE_PATH="$work/module-cache"

sources=("$source_root"/Sources/**/*.swift(N))
sources=(${sources:#*/Sources/App/StouApp.swift})
if (( ${#sources} == 0 )); then
  print -u2 "No Swift sources found in $source_root/Sources."
  exit 1
fi

# The same flags as scripts/build-app.sh, unoptimised: it builds faster.
/usr/bin/xcrun swiftc \
  -swift-version 5 \
  -target "$(/usr/bin/uname -m)-apple-macos26.0" \
  -parse-as-library \
  -Onone \
  -framework SwiftUI \
  -framework AppKit \
  -framework UniformTypeIdentifiers \
  -framework ImageIO \
  -framework CoreGraphics \
  -framework PDFKit \
  "${sources[@]}" \
  "$source_root/scripts/snapshot/Harness.swift" \
  -o "$work/stou-snapshots"

mkdir -p "$output"
"$work/stou-snapshots" "$output" "$source_root/brand/icon/stou-icon-1024.png"
print "Snapshots in $output"
