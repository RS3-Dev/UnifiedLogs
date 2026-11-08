# Patch format

Patches update supported game data between plugin releases. If you need to update a specific boss's logs, create a pull request for `Patches/patch.json` using the format below. Pull requests for JSON patch updates are welcome.

For new features or new logs that require runtime changes, [open an issue](https://github.com/RS3-Dev/UnifiedLogs/issues). Runtime code pull requests are accepted for bug fixes only.

## Files and metadata

Update the existing `patch.json` or `combat-achievements.json` in this directory. The plugin requests those exact filenames from the public repository's `main` branch; it does not discover additional JSON files.

Both files use this metadata:

```json
{
  "format": 1,
  "version": "1.2.0",
  "revision": 2
}
```

- Keep `format` at `1`.
- Use the plugin release version as `version`, expressed as a string.
- Use an integer `revision`, starting at `1` for a new version. Increment it whenever that file's data changes. Each file has its own revision.
- An unchanged version/revision pair makes the plugin ignore changed contents. A patch-only update does not require a new plugin version.
- Version metadata does not restrict a patch to that plugin version. Keep published data compatible with older installed clients.

The metadata-only example is a valid empty boss patch. Combat achievement descriptions require the additional maps described below.

Use valid JSON: double-quoted strings, no comments, no trailing commas, and no duplicate keys. The names in the following examples are illustrative. Replace them with verified client config and variable names before publishing.

## Boss and collection patches: `patch.json`

Publish the complete set of overrides that should remain active. A new download replaces the saved patch; it does not accumulate entries from previous downloads. Keep existing overrides unless you intend to remove them.

For example, this patch supplies a kill-count variable and an item tracking variable for a log:

```json
{
  "format": 1,
  "version": "1.2.0",
  "revision": 2,
  "killCounts": [
    ["Example Boss", [
      ["NM", "BSLAY_KILLS_EXAMPLE_BOSS"]
    ]]
  ],
  "trackingNames": {
    "Example Boss": ["ITEMLOG_ITEM_EXAMPLE_WEAPON"]
  }
}
```

Every data field below is optional. Omit fields you do not need.

- `killCounts`: an array of `[logName, metrics]` groups. Each metric is `[label, variableName]`. A supplied group replaces the bundled kill-count group for that log.
- `records`: an array of `[logName, encounters]` groups. Each encounter is `[encounterName, metrics]`; each metric is `[label, variableName, kind, secondaryVariableName?]`. Use `ticks` for tick-based records or `minutes_seconds` with a secondary seconds variable. A supplied group replaces the bundled records for that log.
- `trackingNames`: an object mapping log names to nonempty arrays of item tracking variable names. Entries replace the bundled tracking-name list for the same log; preserve the item ordering used by that log.
- `extraBossStructs`: an array of boss struct config names to discover in addition to the normal boss enum.
- `extraObjectGroups`: an object mapping log names to nonempty arrays of verified integer object IDs. Entries replace bundled extra object groups with the same name.
- `dropOnly`: an array of log names to include without combat achievement entries.
- `aliases`: an object mapping alternate display names to canonical log names. Entries override aliases for the same name.
- `trackingNameRenames`: an object mapping old item tracking variable names to their replacements. Applies to derived tracking names and names supplied through `trackingNames`; it does not rename variables supplied directly by game metadata, kill-count variables, or record variables.

Example of the nested record format:

```json
{
  "format": 1,
  "version": "1.2.0",
  "revision": 2,
  "records": [
    ["Example Boss", [
      ["Example Boss", [
        ["Normal mode", "BOSS_INSTANCE_SCORES_EXAMPLE_BOSS", "ticks"]
      ]]
    ]]
  ]
}
```

`extraBossStructs` and `dropOnly` add to bundled entries. Other overrides apply to the matching name or group. Adding a kill-count or tracking-name entry alone does not create an entire new log; its collection source must also be discoverable by the runtime. Trophies and new Lua behavior cannot be added through this file.

Malformed rows may be skipped even when the rest of the patch is accepted. Always verify the affected log in the client.

## Description patches: `combat-achievements.json`

Use `descriptions` for text keyed by client achievement config name, and `names` for an exact display-name lookup:

```json
{
  "format": 1,
  "version": "1.2.0",
  "revision": 2,
  "descriptions": {
    "CHEEVO_EXAMPLE_BOSS_TASK": "Defeat Example Boss. ({$BSLAY_KILLS_EXAMPLE_BOSS}/25)"
  },
  "names": {
    "Example task": "CHEEVO_EXAMPLE_BOSS_TASK"
  }
}
```

`descriptions` must be a nonempty object. `names` must be an object and may be empty. All map values must be nonempty strings. Match verified client config names; do not infer them from display names or wiki numeric IDs.

The runtime replaces `{$VARIABLE_NAME}` tokens with live numeric values. If a token cannot be resolved, or no description matches, it uses the client's original text. Descriptions do not change achievement completion or mastery membership.

Maintainers should regenerate this file from the source inputs in the development repository rather than make changes that regeneration would overwrite. Update the inputs under `tools/combat_achievements/`, set the next `REVISION` in `tools/build_combat_achievement_descriptions.js`, then run this from the development repository:

```powershell
node tools/build_combat_achievement_descriptions.js
```

The generator reads the version from `plugin.json`. These development tools are not included in the public repository.

## Validate and publish

1. Preserve all overrides that should remain active, and increment the changed file's revision.
2. Parse the JSON and review the actual data. In the development repository, run the loader and collection tests with Lua 5.4:

   ```powershell
   Get-Content -LiteralPath ./Patches/patch.json -Raw | ConvertFrom-Json | Out-Null
   Get-Content -LiteralPath ./Patches/combat-achievements.json -Raw | ConvertFrom-Json | Out-Null
   ./tools/test.ps1 -Lua "C:\path\to\lua54.exe" -Test boss_patch_test.lua,combat_achievement_descriptions_test.lua,collection_catalog_test.lua
   ```

   Passing existing tests does not prove newly supplied game identifiers are correct; verify those against client data.

3. For an approved patch-only publication, maintainers copy only the changed JSON files to the public repository's `Patches/` directory and publish to `main`. Keep matching source changes in the development repository. Runtime code is published only for plugin version updates.
4. Confirm the raw GitHub response contains the intended metadata, then select **Check for updates** in the plugin and inspect the affected data. The raw URLs are:

   ```text
   https://raw.githubusercontent.com/RS3-Dev/UnifiedLogs/main/Patches/patch.json
   https://raw.githubusercontent.com/RS3-Dev/UnifiedLogs/main/Patches/combat-achievements.json
   ```

Boss patches are checked at startup. Descriptions with a valid saved copy require **Check for updates** to refresh. Failed or invalid downloads leave the previous cached data in place.

## Remove or roll back a patch

To remove a boss override, omit it from the next complete patch and increment the revision. To clear all boss overrides, publish a metadata-only patch using a revision above the last published revision for that version. Never publish a blank file or delete the file to clear saved patches.

To restore original client text for an individual achievement, remove its description override while keeping the description payload valid and incrementing its revision. An empty `descriptions` map is rejected.

For a rollback, restore the previous data with a new revision. When a plugin release incorporates a permanent correction, review remaining patches: saved overrides still take precedence over bundled data.
