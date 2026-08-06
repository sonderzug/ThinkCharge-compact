# Release checklist

1. Update `KPlugin.Version` in `metadata.json` and add the version to
   `CHANGELOG.md`.
2. Run `./scripts/check.sh`.
3. Run `./scripts/build-release.sh`.
4. Install the generated `.plasmoid` in a clean Plasma user session and verify
   profile editing, temporary overrides, AC changes, HDMI changes, and docking.
5. Commit the release, create an annotated tag such as `v2.8.9`, and push it.
6. Create the Git hosting release from that tag and attach the `.plasmoid` and
   `.sha256` files from `dist/`.

## Suggested release title

Battery Charge Limits 2.8.9

## Suggested release notes

Battery Charge Limits 2.8.9 adds live charging statistics, a layered battery
indicator, automatic KDE power-profile switching, per-profile configuration,
temporary overrides, and a reorganized Plasma 6 popup. See `CHANGELOG.md` for
the complete list.
