# Release checklist

1. Update `KPlugin.Version` in `metadata.json` and add the version to
   `CHANGELOG.md`.
2. Run `./scripts/check.sh`.
3. Run `./scripts/build-release.sh`.
4. Install the generated `.plasmoid` in a clean Plasma user session and verify
   profile editing, temporary overrides, AC changes, HDMI changes, and docking.
5. Commit the release, create an annotated tag such as `v2.8.11`, and push it.
6. Create the Git hosting release from that tag and attach the `.plasmoid` and
   `.sha256` files from `dist/`.
7. For the store.kde.org listing, state prominently that **Get New Widgets only
   installs the unprivileged widget**. Users who want to change charge limits
   must also download the source package and run `./install.sh` as their regular
   desktop user. Use `docs/screenshots/popup.png` as the primary image.

## Suggested store requirements

KDE Plasma 6 and a Linux battery driver exposing
`charge_control_start_threshold` and `charge_control_end_threshold` are
required. Installation through Get New Widgets provides status and
power-profile features only. To change charge limits, download the source
package and run `./install.sh` as your regular desktop user; it installs a
narrowly scoped root helper, PolicyKit rule, and boot restoration service and
will ask for `sudo` once.

## Suggested release title

Battery Charge Limits 2.8.11

## Suggested release notes

Battery Charge Limits 2.8.11 adds reliable boot-time restoration of normal
charge thresholds through a systemd oneshot service. Temporary Full and Safe
full actions remain session-only, and the panel battery indicator now uses the
normal Plasma icon color while discharging, reserving green for active charging.
The regular status poll no longer processes DRM EDID data, and the validation
suite now includes behavior tests using simulated battery and display devices.
The popup is narrower and the temporary override controls use the same aligned
label-and-control layout as the remaining settings.
See `CHANGELOG.md` for the complete list.
