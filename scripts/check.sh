#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"

python3 -m json.tool metadata.json >/dev/null
sh -n install.sh uninstall.sh contents/code/battery-threshold-helper \
    contents/code/read-battery-thresholds scripts/build-release.sh scripts/test.sh

test -f contents/images/thinkcharge.svg
cmp -s docs/thinkcharge_logo_thinkpad.svg contents/images/thinkcharge.svg
grep -Fq '"Name": "ThinkCharge"' metadata.json
grep -Fq '"Name": "ThinkCharge contributors"' metadata.json
grep -Fq '"Icon": "/images/thinkcharge.svg"' metadata.json
grep -Fq 'Qt.resolvedUrl("../images/thinkcharge.svg")' contents/ui/main.qml
grep -Fq 'i18n("ThinkCharge")' contents/ui/main.qml
grep -Fq '# ThinkCharge' README.md
grep -Fq 'docs/thinkcharge_logo_thinkpad.svg' README.md
grep -Fq 'archive="dist/ThinkCharge-$version.plasmoid"' scripts/build-release.sh

if grep -Eq 'Battery[[:space:]]+Charge[[:space:]]+Limits' metadata.json contents/ui/*.qml \
        README.md RELEASE.md LICENSE install.sh uninstall.sh; then
    printf 'Legacy product branding is still present.\n' >&2
    exit 1
fi

if grep -Eq 'Conserve[[:space:]]+Mode[[:space:]]+KDE' \
        metadata.json README.md RELEASE.md LICENSE; then
    printf 'Legacy contributor branding is still present.\n' >&2
    exit 1
fi

./scripts/test.sh

grep -q '^Type=oneshot$' packaging/battery-charge-limits.service
grep -q '^ExecStart=/usr/local/libexec/battery-threshold-helper restore$' \
    packaging/battery-charge-limits.service
grep -q '^After=multi-user.target$' packaging/battery-charge-limits.service
grep -q '^TimeoutStartSec=10s$' packaging/battery-charge-limits.service
grep -q '^TimeoutStopSec=10s$' packaging/battery-charge-limits.service
grep -q '^WantedBy=graphical.target$' packaging/battery-charge-limits.service

if grep -Eq '^[[:space:]]*Before[[:space:]]*=.*display-manager\.service' \
        packaging/battery-charge-limits.service; then
    printf 'Service must not block display-manager.service.\n' >&2
    exit 1
fi

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
