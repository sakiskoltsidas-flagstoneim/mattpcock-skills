#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
marketplace_root="${MARKETPLACE_ROOT:-$HOME/dev/my-tools}"
plugin_root="$marketplace_root/plugins/mattpocock-skills"
list_file="$repo_root/curated-list.json"

command -v jq >/dev/null || {
  printf 'error: jq is required\n' >&2
  exit 1
}

command -v rsync >/dev/null || {
  printf 'error: rsync is required\n' >&2
  exit 1
}

if [[ -L "$plugin_root" ]]; then
  rm "$plugin_root"
fi

mkdir -p "$plugin_root/.claude-plugin" "$plugin_root/skills"

while IFS=$'\t' read -r name path; do
  source="$repo_root/skills/$path"
  target="$plugin_root/skills/$name"

  if [[ ! -d "$source" ]]; then
    printf 'error: skill source does not exist: %s\n' "$source" >&2
    exit 1
  fi

  mkdir -p "$target"
  rsync -a --delete "$source/" "$target/"
done < <(jq -r '.skills[] | [.name, .path] | @tsv' "$list_file")

find "$plugin_root/skills" -mindepth 1 -maxdepth 1 -type d -print0 |
  while IFS= read -r -d '' directory; do
    name="$(basename "$directory")"
    if ! jq -e --arg name "$name" '.skills[] | select(.name == $name)' "$list_file" >/dev/null; then
      rm -rf "$directory"
    fi
  done

cat > "$plugin_root/.claude-plugin/plugin.json" <<EOF
{
  "name": "mattp",
  "version": "$(jq -r '.plugin.version' "$list_file")",
  "description": "$(jq -r '.plugin.description' "$list_file")",
  "author": {
    "name": "Matt Pocock",
    "url": "https://www.aihero.dev"
  },
  "homepage": "https://www.aihero.dev/s/skills-newsletter",
  "repository": "https://github.com/mattpocock/skills",
  "license": "MIT",
  "skills": [
$(jq -r '.skills[] | "    \"./skills/\(.name)\""' "$list_file" | paste -sd, -)
  ]
}
EOF

printf 'synced %s curated skills to %s\n' "$(jq '.skills | length' "$list_file")" "$plugin_root"
