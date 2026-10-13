#!/bin/zsh
# Builds Stou's branded disk image from a built Stou.app:
#   scripts/build-dmg.sh /absolute/path/to/Stou.app /absolute/path/to/Stou.dmg
# Needs dmgbuild (pip install dmgbuild==1.6.5); set DMGBUILD to its path when
# it isn't on PATH. The window's layout is in packaging/dmg/settings.py.
set -euo pipefail

app="${1:?usage: build-dmg.sh /path/to/Stou.app /path/to/Stou.dmg}"
dmg="${2:?usage: build-dmg.sh /path/to/Stou.app /path/to/Stou.dmg}"
dmgbuild="${DMGBUILD:-dmgbuild}"
root="${0:A:h:h}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# One background for every screen: the @2x image as is, and a 1x copy at
# half the size, so Finder picks the sharp one on Retina.
cp "$root/packaging/dmg/dmg-background.png" "$work/background@2x.png"
sips --resampleWidth 836 "$work/background@2x.png" --out "$work/background.png" >/dev/null
sips -s dpiWidth 72 -s dpiHeight 72 "$work/background.png" >/dev/null
tiffutil -cathidpicheck "$work/background.png" "$work/background@2x.png" -out "$work/background.tiff" >/dev/null 2>&1

rm -f "$dmg"
"$dmgbuild" -s "$root/packaging/dmg/settings.py" \
  -D app="$app" -D background="$work/background.tiff" \
  Stou "$dmg"
