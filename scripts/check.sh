#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"

python3 -m json.tool metadata.json >/dev/null
sh -n install.sh uninstall.sh contents/code/battery-threshold-helper \
    contents/code/read-battery-thresholds scripts/build-release.sh

if command -v xmllint >/dev/null 2>&1; then
    xmllint --noout contents/config/main.xml contents/images/*.svg
fi

if command -v qmllint6 >/dev/null 2>&1; then
    qmllint6 contents/ui/*.qml
elif command -v qmllint >/dev/null 2>&1; then
    qmllint contents/ui/*.qml
else
    printf 'Note: qmllint is unavailable; QML lint was skipped.\n'
fi

printf 'Checks passed.\n'
