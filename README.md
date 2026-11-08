# Unified Logs

This repository contains the released plugin runtime and JSON patches. Runtime code is updated when a new plugin version is released; patches can be updated between releases.

## Patches

The files in `Patches/` provide data updates without requiring a new plugin release:

- `patch.json` adds or corrects supported boss and collection log data, including kill counts, personal bests, and item tracking.
- `combat-achievements.json` updates combat achievement descriptions. It does not change achievement completion or requirements.

The plugin checks for boss patches when it starts. Combat achievement descriptions are downloaded when no saved copy exists. To check both files manually, select **Check for updates** in the plugin panel. Valid downloads are saved locally and remain available offline.

Maintainers publish patch updates to this repository with an updated version/revision. Each changed file needs a new revision so existing installations recognize the update. Changes to plugin behavior or the interface require a plugin release.

See the [patch format guide](Patches/README.md) for supported fields, examples, validation, and publishing rules.

## Contributing

To update a specific boss's logs, open a pull request for `Patches/patch.json` using the [patch format guide](Patches/README.md). Pull requests for JSON patch updates are welcome.

[Open an issue](https://github.com/RS3-Dev/UnifiedLogs/issues) for feature requests, new logs that require runtime changes, or bug reports. Runtime code pull requests are accepted for bug fixes only.
