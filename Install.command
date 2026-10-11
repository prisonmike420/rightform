#!/bin/zsh
# Local installer retained for people who download a source archive.

set -euo pipefail

here="${0:A:h}"
version="$(<"$here/VERSION")"
version="${version//[[:space:]]/}"
app_dir="$HOME/Applications"
app="$app_dir/Rightform.app"

print "\n  Rightform $version\n"
print '  Installing Rightform…\n'

stage_root="$(mktemp -d)"
trap 'rm -rf "$stage_root"' EXIT
stage_app="$stage_root/Rightform.app"

"$here/scripts/build-app.sh" "$stage_app"
mkdir -p "$app_dir"
rm -rf "$app"
mv "$stage_app" "$app"

print "\nRightform $version is installed at $app"
print 'Open Plugins in the rail and install the ones you need.'
open "$app"
