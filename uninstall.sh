#!/bin/sh
set -eu

package_id=org.kde.plasma.batterythresholds
helper_target=/usr/local/libexec/battery-threshold-helper
sleep_hook_target=/usr/lib/systemd/system-sleep/battery-thresholds
rule_target=/etc/polkit-1/rules.d/49-battery-thresholds.rules
service_target=/etc/systemd/system/battery-charge-limits.service
config_target=/etc/battery-charge-limits.conf

kpackagetool6 --type Plasma/Applet --remove "$package_id"
sudo systemctl disable --now battery-charge-limits.service 2>/dev/null || true
sudo rm -f -- "$helper_target" "$sleep_hook_target" "$rule_target" "$service_target" "$config_target"
sudo systemctl daemon-reload

printf 'ThinkCharge was removed. Saved Plasma configuration is left intact.\n'
