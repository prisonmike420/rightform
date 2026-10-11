#!/bin/zsh
# Publish a Rightform release from main: raise VERSION, tag it, build the app,
# attach the ZIP to a GitHub Release and update the Homebrew Cask and tap.
#
# Usage: scripts/release.sh [patch|minor|major|X.Y.Z]    (default: patch)
#   patch  0.18.0 → 0.18.1   fixes
#   minor  0.18.0 → 0.19.0   new features or changed behaviour
#   major  0.18.0 → 1.0.0    the product's first stable release, and breaks

set -euo pipefail

die() { print -u2 "release: $1"; exit 1; }

root="${0:A:h:h}"
cd "$root"

kind="${1:-patch}"

[[ "$(git branch --show-current)" == "main" ]] || die "release from main."
[[ -z "$(git status --porcelain)" ]] || die "commit or stash your changes first."
git fetch --quiet --tags origin
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || die "main must match origin/main; pull or push first."
command -v gh >/dev/null || die "the GitHub CLI (gh) is required."

current="$(<VERSION)"
current="${current//[[:space:]]/}"
[[ "$current" == <->.<->.<-> ]] || die "VERSION must look like 1.2.3, not '$current'."
parts=("${(@s:.:)current}")
major=${parts[1]} minor=${parts[2]} patch=${parts[3]}

case "$kind" in
  patch) next="$major.$minor.$((patch + 1))" ;;
  minor) next="$major.$((minor + 1)).0" ;;
  major) next="$((major + 1)).0.0" ;;
  <->.<->.<->) next="$kind" ;;
  *) die "unknown bump '$kind'; use patch, minor, major or a version." ;;
esac

# The new version has to be higher, and not released yet.
[[ "$(printf '%s\n%s\n' "$current" "$next" | sort -V | tail -1)" == "$next" && "$next" != "$current" ]] \
  || die "$next is not higher than $current."
git rev-parse -q --verify "refs/tags/v$next" >/dev/null && die "v$next already exists."

previous_tag="$(git describe --tags --abbrev=0 2>/dev/null || true)"

print "Rightform $current → $next"
print -n "Publish this release? [y/N] "
read -r answer
[[ "$answer" == [yY] ]] || exit 1

# 1. The release commit and tag.
print -- "$next" > VERSION
parts=("${(@s:.:)next}")
code=$(( parts[1] * 10000 + parts[2] * 100 + parts[3] ))
/usr/libexec/PlistBuddy \
  -c "Set :CFBundleShortVersionString $next" \
  -c "Set :CFBundleVersion $code" \
  Resources/Info.plist
git commit --quiet -m "Release $next" VERSION Resources/Info.plist
git tag "v$next"

# 2. The ZIP Homebrew installs: Rightform/Rightform.app and Rightform/rightform.
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/Rightform"
scripts/build-app.sh "$stage/Rightform/Rightform.app"
cp packaging/homebrew/rightform "$stage/Rightform/rightform"
chmod +x "$stage/Rightform/rightform"
zip="$stage/Rightform-$next.zip"
(cd "$stage" && /usr/bin/ditto -c -k --keepParent Rightform "$zip")
sha="$(/usr/bin/shasum -a 256 "$zip" | cut -d' ' -f1)"

# 3. The Cask points at this ZIP and its checksum.
cask="packaging/homebrew/Casks/rightform.rb.template"
/usr/bin/sed -i '' \
  -e "s/^  version \".*\"/  version \"$next\"/" \
  -e "s/^  sha256 \".*\"/  sha256 \"$sha\"/" \
  "$cask"
git commit --quiet -m "Update Cask for $next" "$cask"
git push --quiet origin main "v$next"

# 4. The GitHub Release, with the changes since the last one.
notes="$stage/notes.md"
{
  print "## Changes\n"
  if [[ -n "$previous_tag" ]]; then
    git log --no-merges --format='- %s' "$previous_tag..v$next" | grep -v '^- Release ' || true
  fi
  print "\n## Install\n"
  print '`brew trust --cask prisonmike420/rightform/rightform`'
  print '`brew upgrade --cask prisonmike420/rightform/rightform`'
} > "$notes"
gh release create "v$next" "$zip" --title "Rightform $next" --notes-file "$notes"

# 5. The tap, where Homebrew reads the Cask.
tap="$(brew --repository prisonmike420/rightform 2>/dev/null || true)"
if [[ -n "$tap" && -d "$tap/.git" ]]; then
  cp "$cask" "$tap/Casks/rightform.rb"
  git -C "$tap" commit --quiet -m "Update Rightform to $next" Casks/rightform.rb
  if git -C "$tap" push --quiet; then
    print "Tap updated."
  else
    print -u2 "The tap commit is ready but couldn't be pushed; push $tap yourself."
  fi
else
  print -u2 "No local tap found; copy $cask to homebrew-rightform/Casks/rightform.rb yourself."
fi

print "Released Rightform $next ($sha)."
