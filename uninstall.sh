#!/bin/sh
set -eu

package_id=org.kde.plasma.batterythresholds
helper_target=/usr/local/libexec/battery-threshold-helper
rule_target=/etc/polkit-1/rules.d/49-battery-thresholds.rules
service_target=/etc/systemd/system/battery-charge-limits.service
config_target=/etc/battery-charge-limits.conf

kpackagetool6 --type Plasma/Applet --remove "$package_id"
sudo systemctl disable --now battery-charge-limits.service 2>/dev/null || true
sudo rm -f -- "$helper_target" "$rule_target" "$service_target" "$config_target"
sudo systemctl daemon-reload

printf 'Battery Charge Limits was removed. Saved Plasma configuration is left intact.\n'
