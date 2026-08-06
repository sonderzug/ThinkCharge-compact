#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
helper_source="$project_dir/contents/code/battery-threshold-helper"
rule_template="$project_dir/packaging/49-battery-thresholds.rules.in"
helper_target=/usr/local/libexec/battery-threshold-helper
rule_target=/etc/polkit-1/rules.d/49-battery-thresholds.rules
package_id=org.kde.plasma.batterythresholds
install_user=$(id -un)

case "$install_user" in
    *[!A-Za-z0-9._-]*|'')
        printf 'Unsupported user name: %s\n' "$install_user" >&2
        exit 1
        ;;
esac

for program in kpackagetool6 sudo sed install mktemp; do
    command -v "$program" >/dev/null 2>&1 || {
        printf 'Missing required command: %s\n' "$program" >&2
        exit 1
    }
done

rule_tmp=$(mktemp)
trap 'rm -f "$rule_tmp"' EXIT HUP INT TERM
sed "s/@AUTHORIZED_USER@/$install_user/g" "$rule_template" > "$rule_tmp"

printf 'Installing privileged threshold helper for user %s…\n' "$install_user"
sudo install -D -m 0755 "$helper_source" "$helper_target"
sudo install -D -m 0644 "$rule_tmp" "$rule_target"

if kpackagetool6 --type Plasma/Applet --show "$package_id" >/dev/null 2>&1; then
    printf 'Upgrading Plasma widget…\n'
    kpackagetool6 --type Plasma/Applet --upgrade "$project_dir"
else
    printf 'Installing Plasma widget…\n'
    kpackagetool6 --type Plasma/Applet --install "$project_dir"
fi

printf '\nInstallation complete. Add “Battery Charge Limits” from the Plasma widget browser.\n'
printf 'If an existing widget does not refresh, log out and back in once.\n'
