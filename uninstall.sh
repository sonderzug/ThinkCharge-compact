#!/bin/sh
set -eu

package_id=org.kde.plasma.batterythresholds
helper_target=/usr/local/libexec/battery-threshold-helper
rule_target=/etc/polkit-1/rules.d/49-battery-thresholds.rules

kpackagetool6 --type Plasma/Applet --remove "$package_id"
sudo rm -f -- "$helper_target" "$rule_target"

printf 'Battery Charge Limits was removed. Saved Plasma configuration is left intact.\n'
