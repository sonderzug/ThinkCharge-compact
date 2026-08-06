#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT HUP INT TERM

power_root="$test_root/power_supply"
drm_root="$test_root/drm"
mkdir -p "$power_root/BAT0" "$power_root/AC" \
    "$drm_root/card1-eDP-1" "$drm_root/card1-HDMI-A-1"

printf 'Battery\n' > "$power_root/BAT0/type"
printf '72\n' > "$power_root/BAT0/capacity"
printf 'Discharging\n' > "$power_root/BAT0/status"
printf '75\n' > "$power_root/BAT0/charge_control_start_threshold"
printf '80\n' > "$power_root/BAT0/charge_control_end_threshold"
printf '8600000\n' > "$power_root/BAT0/power_now"
printf '36000000\n' > "$power_root/BAT0/energy_now"
printf '50000000\n' > "$power_root/BAT0/energy_full"
printf 'Mains\n' > "$power_root/AC/type"
printf '0\n' > "$power_root/AC/online"
printf 'connected\n' > "$drm_root/card1-eDP-1/status"
printf 'enabled\n' > "$drm_root/card1-eDP-1/enabled"
printf 'connected\n' > "$drm_root/card1-HDMI-A-1/status"
printf 'enabled\n' > "$drm_root/card1-HDMI-A-1/enabled"

snapshot=$(BATTERY_THRESHOLDS_POWER_SUPPLY_ROOT="$power_root" \
    BATTERY_THRESHOLDS_DRM_ROOT="$drm_root" \
    "$project_dir/contents/code/read-battery-thresholds")

assert_line() {
    expected=$1
    printf '%s\n' "$snapshot" | grep -Fqx "$expected" || {
        printf 'Missing snapshot line: %s\n' "$expected" >&2
        exit 1
    }
}

assert_line 'STATUS|BAT0|72|Discharging|75|80|1|0|1|8600000|36000000|50000000'
assert_line 'DISPLAY|eDP-1|connected|enabled|internal-hint'
assert_line 'DISPLAY|HDMI-A-1|connected|enabled|external-hint'

if "$project_dir/contents/code/battery-threshold-helper" set '../BAT0' 75 80 \
        > /dev/null 2> "$test_root/helper-error"; then
    printf 'Helper accepted an invalid battery name.\n' >&2
    exit 1
fi
grep -Fq 'ERROR|Invalid battery name' "$test_root/helper-error"

if "$project_dir/contents/code/battery-threshold-helper" set BAT0 80 75 \
        > /dev/null 2> "$test_root/helper-error"; then
    printf 'Helper accepted an invalid threshold pair.\n' >&2
    exit 1
fi
grep -Fq 'ERROR|Start threshold must be below end threshold' "$test_root/helper-error"

printf 'Behavior tests passed.\n'
