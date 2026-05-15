# Changelog

All notable changes to Windrose Cheat Menu will be documented here. Format
loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] — 2026-05-14

UE4SS-build reality check + honest scope.

### Added

- `wcm` console command exposed in the in-game F10 console (UE engine console)
  as the primary UI for this UE4SS build, which does not expose Lua-side ImGui
  bindings. Subcommands: `status`, `<flag>`, `<flag> on|off|toggle`,
  `player|ship|building|all on|off`, `apply`, `rescan`, `dump`, `probe`,
  `setfield`. Friendly aliases for every flag.
- Diagnostic helpers `WindroseCheatMenu.Probe(class)` and `.SetField` exposed
  via the `wcm` console for runtime UE class introspection.

### Changed

- **`free_build` now means "build anywhere"** — writes
  `bRequiresBuildingCenter = false` on every `R5BuildingItem` (862 in the
  tested build). Confirmed working via `dump_object R5BuildingItem` + direct
  test with the bundled `set` command. Toggle-off restores the originals.
- README and Nexus page text updated to be honest: "Free build" removes the
  building-center placement constraint but does NOT yet remove resource cost.
  True cost-free placement requires hooking the placement-validation UFUNCTION
  on the player's build component (v0.2 work).

### Removed

- ImGui checkbox window stubs from the default UX path. `gui.lua` remains in
  the source tree and will activate automatically on a UE4SS build that
  exposes ImGui to Lua (none of the current Latest Experimental builds do).
- Bogus `bFreeBuild` / `bConsumeResources` / `bUnlimitedResources` / etc.
  field writes. Investigation revealed UE4SS's `obj[fieldname]` returns a
  null UObject wrapper for any unknown property name, which made our
  probes appear to find these fields when they don't actually exist on
  either `R5BuildingItem` or `CheatManager` as UPROPERTYs.

### Known limitations

- `free_build` only skips the building-center requirement; resources are
  still consumed. Removing resource cost is deferred to v0.2.
- `infinite_inventory` remains diagnostic-only. The class-name probe list
  hasn't matched anything in this build; run `wcm dump` in-game and share
  the log lines if you'd like to help refine it.
- Tested on Windrose buildid 23065453 (May 2026) with UE4SS Latest
  Experimental `g06474186`. Field/class names may change with future
  Windrose patches.

## [0.1.0] — 2026-05-14

Initial release.

### Added

- In-game ImGui checkbox menu (toggle with **F8**).
- Per-feature flags, each independently toggleable with per-container
  snapshot/restore on toggle off:
  - Player: `unlimited_health`, `unlimited_stamina`, `super_defense`,
    `super_armor`, `super_damage`
  - Ship: `ship_invincible`, `ship_cannon_boost`
  - World/building: `free_build`, `unlock_all_items`,
    `infinite_inventory` (best-effort)
- Public Lua API on `WindroseCheatMenu` global: `Set`, `Get`, `GetFlags`,
  `Apply`, `Rescan`, `DumpInventory`, `DisableAll`, `Toggle`, `Show`, `Hide`.
- `Dump inventory` action button — logs UE inventory class candidates and
  numeric field values to `UE4SS.log` for diagnostic refinement.
- README with installation, usage, save-data warning, and project layout.

### Known limitations

- `infinite_inventory` uses heuristic class-name probing. If your save's
  resource counters don't change, run **Dump inventory** and file an issue
  with the resulting log lines so we can add the correct class names to the
  candidate list.
- Tested on Windrose buildid 23065453 (May 2026). UE attribute names may
  change with future patches.
