# Changelog

All notable changes to this project are documented here.

## 2.8.12 — 2026-08-06

- Run automatic docking detection only while Automatic mode switching is
  enabled; keep HDMI-based power-profile detection independent.
- Immediately leave Docked mode and restore the saved normal profile when
  automatic docking is disabled.
- Persist the automatic-docking switch through the existing Plasma
  configuration across widget and Plasma restarts.

## 2.8.11 — 2026-08-06

- Persist normal charge limits in a root-owned configuration and restore them
  during boot with a systemd oneshot service, before the display manager starts.
- Keep temporary Full and Safe full overrides out of the persisted boot state.
- Use the normal Plasma icon color for the current battery level while
  discharging; reserve green for active charging.
- Stop reading and converting DRM EDID bytes during the regular status poll;
  connector names provide all information required for docking detection.
- Add behavior tests for status parsing against a simulated sysfs tree and for
  privileged-helper input validation.
- Narrow the popup and align the temporary charge and power-profile controls
  with the other labeled settings.

## 2.8.10 — 2026-08-06

- Rename the docking toggle to clarify that it enables or disables automatic
  Normal/Docked mode switching rather than forcing Docked mode.

## 2.8.9 — 2026-08-06

- Show current charge, configured limit, charge/discharge power, and estimated
  remaining time in the Plasma panel.
- Add a two-layer battery glyph with charge-limit and current-level colors plus
  a charging indicator.
- Show a standalone icon for the active KDE power profile.
- Add saved charge profiles with staged Save and Revert editing.
- Add automatic Power Save, Balanced, and Performance selection for battery,
  AC, and HDMI operation, configurable per charge profile.
- Preserve manual power-profile overrides until Automatic is selected again.
- Add Full and Safe full temporary charging actions.
- Add optional automatic docking-profile selection.
- Improve popup grouping, sizing, and dropdown behavior.
- Add release, installation, validation, and packaging documentation.

## 2.0.0

- Initial Plasma 6 implementation with generic Linux charge thresholds.
