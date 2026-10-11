#!/usr/bin/env bash
set -euo pipefail

# Builds one engine from a pinned upstream release into a package Stou can
# install without Homebrew: a self-contained arm64 build, the licence text,
# and a SOURCE.txt; for GPL and AGPL engines also a copy of the exact source.
#
#   scripts/build-engine.sh <engine> <output-dir>
#
# Writes <output-dir>/<engine>-<version>-arm64.zip (and, for GPL and AGPL engines,
# <engine>-<version>-source.tar.gz) and appends their checksums to SHA256SUMS. Engines are listed in
# packaging/engines/engines.sh.

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <engine> <output-dir>" >&2
  exit 2
fi
engine="$1"
out="$(mkdir -p "$2" && cd "$2" && pwd)"
here="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=../packaging/engines/engines.sh
source "$here/packaging/engines/engines.sh"
VERSION_ARG=--version
SHIP_SOURCE=no
engine_define "$engine"   # sets VERSION, SOURCE_URL, SOURCE_SHA256, LICENSE, LICENSE_FILE, TOOLS

# Everything is built for the macOS Stou itself targets.
export MACOSX_DEPLOYMENT_TARGET=26.0

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The download is kept next to the package only where the licence asks Stou to
# provide source (GPL, AGPL); otherwise it is just what the build used.
source_tar="$work/$engine-$VERSION-source.tar.gz"
curl -fsSL -o "$source_tar" "$SOURCE_URL"
actual="$(shasum -a 256 "$source_tar" | cut -d' ' -f1)"
if [[ "$actual" != "$SOURCE_SHA256" ]]; then
  echo "Source checksum mismatch for $engine $VERSION: expected $SOURCE_SHA256, got $actual" >&2
  exit 1
fi

mkdir "$work/src"
tar -xzf "$source_tar" -C "$work/src" --strip-components=1

package="$work/$engine"
mkdir -p "$package/bin" "$package/LICENSES"
engine_build "$work/src" "$package/bin"

if [[ "$SHIP_SOURCE" == yes ]]; then
  source_note="The same source archive is published next to this package as $(basename "$source_tar")."
else
  source_note="Upstream publishes this source at the address above."
fi

cp "$work/src/$LICENSE_FILE" "$package/LICENSES/$engine.txt"
cat > "$package/SOURCE.txt" <<TXT
$engine $VERSION ($LICENSE)

Built by the Stou project from the unmodified upstream source:
$SOURCE_URL
SHA-256 $SOURCE_SHA256

$source_note
The build script is scripts/build-engine.sh in https://github.com/prisonmike420/stou.
TXT

for tool in $TOOLS; do
  binary="$package/bin/$tool"
  # A build that modified the binary leaves it unsigned, and Apple silicon
  # refuses to run unsigned code.
  /usr/bin/codesign --force --sign - "$binary"
  /usr/bin/codesign --verify "$binary"

  # Self-contained means nothing outside the system: a Homebrew or build-tree
  # path here would fail on every Mac that doesn't have it.
  stray="$(/usr/bin/otool -L "$binary" | tail -n +2 | awk '{print $1}' | grep -v -E '^(/usr/lib/|/System/)' || true)"
  if [[ -n "$stray" ]]; then
    echo "$tool links libraries outside the system:" >&2
    echo "$stray" >&2
    exit 1
  fi
  [[ "$(/usr/bin/lipo -archs "$binary")" == "arm64" ]] || { echo "$tool is not arm64 only" >&2; exit 1; }
  "$binary" "$VERSION_ARG" >/dev/null
done

archive="$out/$engine-$VERSION-arm64.zip"
rm -f "$archive"
(cd "$work" && /usr/bin/ditto -c -k --keepParent "$engine" "$archive")

if [[ "$SHIP_SOURCE" == yes ]]; then cp "$source_tar" "$out/"; fi
(cd "$out" && shasum -a 256 "$engine-$VERSION"-* >> SHA256SUMS)
echo "Built $archive"
