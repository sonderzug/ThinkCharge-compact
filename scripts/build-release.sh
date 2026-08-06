#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"

command -v zip >/dev/null 2>&1 || {
    printf 'Missing required command: zip\n' >&2
    exit 1
}

./scripts/check.sh
version=$(sed -n 's/.*"Version": "\([^"]*\)".*/\1/p' metadata.json)
[ -n "$version" ] || {
    printf 'Could not read the version from metadata.json\n' >&2
    exit 1
}

mkdir -p dist
archive="dist/org.kde.plasma.batterythresholds-$version.plasmoid"
rm -f -- "$archive" "$archive.sha256"
zip -X -q -r "$archive" metadata.json contents
sha256sum "$archive" > "$archive.sha256"

printf 'Created %s and %s\n' "$archive" "$archive.sha256"
