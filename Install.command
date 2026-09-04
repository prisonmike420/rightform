#!/bin/zsh
# Local installer retained for people who download a source archive.

set -euo pipefail

here="${0:A:h}"
app_dir="$HOME/Applications"
app="$app_dir/Rightform.app"

print '\n  Rightform 0.16.0\n'
print '  Installing core image engines…\n'

if ! command -v brew >/dev/null 2>&1; then
  print -u2 'Homebrew is required. Install it from https://brew.sh, then run this installer again.'
  exit 1
fi

brew install jpeg-archive jpeg-turbo pngquant oxipng webp

stage_root="$(mktemp -d)"
trap 'rm -rf "$stage_root"' EXIT
stage_app="$stage_root/Rightform.app"

"$here/scripts/build-app.sh" "$stage_app"
mkdir -p "$app_dir"
rm -rf "$app"
mv "$stage_app" "$app"

print "\nRightform 0.16.0 is installed at $app"
open "$app"
