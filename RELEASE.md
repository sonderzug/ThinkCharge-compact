# Release checklist

1. Update `KPlugin.Version` in `metadata.json` and add the version to
   `CHANGELOG.md`.
2. Run `./scripts/check.sh`.
3. Run `./scripts/build-release.sh`.
4. Install the generated `.plasmoid` in a clean Plasma user session and verify
   profile editing, temporary overrides, AC changes, HDMI changes, and docking.
5. Commit the release, create an annotated tag such as `v2.8.13`, and push it.
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

Battery Charge Limits 2.8.13

## Suggested release notes

Battery Charge Limits 2.8.13 fixes a boot-critical Fedora deadlock introduced
with the charge-limit restoration service in versions 2.8.11 and 2.8.12. The
service no longer blocks the display manager, and both its startup and shutdown
are limited to ten seconds. Users who installed either affected version through
`./install.sh` should update immediately. Recovery instructions are included in
the README. I sincerely apologize to everyone affected; releasing a service
capable of blocking graphical boot was a serious mistake.
See `CHANGELOG.md` for the complete list.
