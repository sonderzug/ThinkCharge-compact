# Changelog

All notable changes to this project are documented here.

## Unreleased

## 2.8.14 — 2026-08-13

- Rename the project to ThinkCharge and use its bundled logo consistently in
  Plasma, the panel, installation messages, release assets, and documentation.
- Add per-charge-profile automatic screen refresh-rate switching for battery
  and AC power, applied through `kscreen-doctor`, plus a temporary "Max
  refresh rate" override.
- Add desktop notifications for automatic power-profile and refresh-rate
  changes, manual profile switches, saves, docking transitions, temporary
  charge overrides, the power-profile override, and Keep awake; combine
  notifications that land together into a single one instead of spamming.
- Add per-charge-profile screen-off and sleep idle timeouts.
- Add a Keep awake toggle that blocks sleep and screen locking on demand.
- Reassert the last persisted charge thresholds around every suspend/hibernate
  transition via a `systemd-sleep` hook, independent of whether a Plasma
  session is running.
- Group the power-profile, idle-timeout, refresh-rate, and docking detail
  controls in the popup behind collapsible sections to reduce visual clutter.
- Fix a `ReferenceError` in the popup that broke the Docking section and the
  Keep awake switch by adding the missing `org.kde.plasma.plasmoid` import.
- Fix automatic refresh-rate switching getting stuck indefinitely: apply the
  change optimistically instead of waiting for `kscreen-doctor`'s completion
  signal, which the executable data engine does not reliably deliver for this
  command.
- Stop double-sampling AC/battery state right after a power-profile change,
  which could apply two different refresh rates in quick succession.
- Reject `battery-threshold-helper set`/`apply` invocations with the wrong
  number of arguments instead of reading past the end of the argument list.

## 2.8.13 — 2026-08-07

- Prevent a Fedora boot deadlock by no longer ordering the charge-limit restore
  before the display manager, and bound both service startup and shutdown to
  ten seconds.

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
