#!/bin/zsh
# Builds Stou's branded disk image from a built Stou.app:
#   scripts/build-dmg.sh /absolute/path/to/Stou.app /absolute/path/to/Stou.dmg
# Needs dmgbuild (pip install dmgbuild==1.6.7); set DMGBUILD to its path when
# it isn't on PATH. The window's layout is in packaging/dmg/settings.py; its
# background is a 1672 × 940 PNG at 144 DPI, which Finder shows at 836 × 470
# points, sharp on Retina.
set -euo pipefail

app="${1:?usage: build-dmg.sh /path/to/Stou.app /path/to/Stou.dmg}"
dmg="${2:?usage: build-dmg.sh /path/to/Stou.app /path/to/Stou.dmg}"
dmgbuild="${DMGBUILD:-dmgbuild}"
root="${0:A:h:h}"

rm -f "$dmg"
"$dmgbuild" -s "$root/packaging/dmg/settings.py" \
  -D app="$app" -D background="$root/packaging/dmg/dmg-background.png" \
  Stou "$dmg"
