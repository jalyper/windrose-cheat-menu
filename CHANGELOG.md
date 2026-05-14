# Changelog

All notable changes to Windrose Cheat Menu will be documented here. Format
loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
