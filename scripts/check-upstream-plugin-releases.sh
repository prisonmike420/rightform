#!/usr/bin/env bash
set -euo pipefail

# Checks only GitHub release/tag metadata. It does not clone repositories,
# download source archives, inspect branch commits, or build plugins unless a
# later release workflow explicitly handles an update.

catalog_path="${1:-Resources/plugins.json}"
state_path="${2:-.github/plugin-monitor-state.json}"
report_path="${3:-.github/plugin-monitor-report.md}"
output_path="${GITHUB_OUTPUT:-/dev/null}"

command -v gh >/dev/null || { echo "GitHub CLI is required." >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required." >&2; exit 1; }
jq -e '.schemaVersion == 2 and (.plugins | type == "array")' "$catalog_path" >/dev/null

mkdir -p "$(dirname "$state_path")" "$(dirname "$report_path")"
if [[ ! -f "$state_path" ]]; then
  printf '{"schemaVersion":1,"plugins":[]}\n' > "$state_path"
fi
jq -e '.schemaVersion == 1 and (.plugins | type == "array")' "$state_path" >/dev/null

has_previous="false"
if [[ "$(jq '.plugins | length' "$state_path")" -gt 0 ]]; then
  has_previous="true"
fi

observed="$(mktemp)"
updates="$(mktemp)"
trap 'rm -f "$observed" "$updates"' EXIT

while IFS=$'\t' read -r plugin_id component_id repository; do
  id="$plugin_id/$component_id"
  repo="${repository#https://github.com/}"
  repo="${repo%.git}"
  if ! version="$(gh api "repos/$repo/releases/latest" --jq '.tag_name' 2>/dev/null)"; then
    version=""
  fi
  if [[ -z "$version" || "$version" == "null" ]]; then
    if ! version="$(gh api "repos/$repo/tags?per_page=1" --jq '.[0].name // empty' 2>/dev/null)"; then
      version=""
    fi
  fi
  if [[ -z "$version" ]]; then
    printf 'Could not read an upstream release or tag for %s (%s).\n' "$id" "$repository" >&2
    # A transient GitHub/API failure must never erase a known version and turn
    # the next successful check into a misleading new baseline.
    jq -c --arg id "$id" '.plugins[]? | select(.id == $id)' "$state_path" >> "$observed"
    continue
  fi

  previous="$(jq -r --arg id "$id" '.plugins[]? | select(.id == $id) | .version // empty' "$state_path")"
  if [[ "$has_previous" == "true" && -n "$previous" && "$previous" != "$version" ]]; then
    jq -n --arg id "$id" --arg repository "$repository" --arg previous "$previous" --arg version "$version" \
      '{id: $id, repository: $repository, previous: $previous, version: $version}' >> "$updates"
  fi
  jq -n --arg id "$id" --arg repository "$repository" --arg version "$version" \
    '{id: $id, repository: $repository, version: $version}' >> "$observed"
done < <(jq -r '
  .plugins[] |
  .id as $plugin |
  if (.components | type == "array" and length > 0) then
    .components[] | [$plugin, .id, .repository] | @tsv
  else
    [$plugin, $plugin, .repository] | @tsv
  end
' "$catalog_path")

jq -s --arg checkedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{schemaVersion: 1, checkedAt: $checkedAt, plugins: .}' "$observed" > "$state_path"

if [[ "$has_previous" == "false" ]]; then
  printf '# Plugin monitor initialized\n\nThe first run records current upstream versions and intentionally does not create an update notification.\n' > "$report_path"
  printf 'initialized=true\nupdates=false\n' >> "$output_path"
  exit 0
fi

if [[ ! -s "$updates" ]]; then
  printf '# No upstream plugin updates\n' > "$report_path"
  printf 'initialized=false\nupdates=false\n' >> "$output_path"
  exit 0
fi

{
  printf '# Upstream plugin updates detected\n\n'
  printf 'These are source updates only. They are not published to Rightform until a plugin-specific build and verification step creates a signed archive and updates `Resources/plugins.json`.\n\n'
  printf '| Plugin | Previous | Upstream | Source |\n| --- | --- | --- | --- |\n'
  jq -r '"| \(.id) | \(.previous) | \(.version) | [source](\(.repository)) |"' "$updates"
} > "$report_path"

printf 'initialized=false\nupdates=true\n' >> "$output_path"
