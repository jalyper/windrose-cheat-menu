# Windrose Cheat Menu

In-game ImGui checkbox menu for [Windrose](https://store.steampowered.com/app/3041230/Windrose/) with per-feature toggles for player buffs, ship buffs, free building, item unlocks, and infinite inventory stock.

Standalone UE4SS mod — no other mod required.

![menu mockup](docs/menu-mockup.png) <!-- screenshot to be added after first release -->

## Features

| Section | Toggle | Effect |
|---------|--------|--------|
| Player | Unlimited health | Health and MaxHealth set to 5000 |
| Player | Unlimited stamina | Stamina pool, regen rate, and consumption modifier maxed |
| Player | Super defence | Defence power + all damage-taken resists buffed |
| Player | Super armor | Armor, armor modifier, and final damage reduction by armor maxed |
| Player | Super damage | Attack power, all damage-done types, crit chance + multiplier, armor penetration |
| Ship | Ship invincible | Hull / sail health, hull armor + cannon damage-taken resist buffed |
| Ship | Ship cannon boost | Cannon damage-done flat + multiplier buffed |
| Building | Free build | "Build anywhere": writes `bRequiresBuildingCenter = false` on every `R5BuildingItem`, removing the must-be-near-a-building-center placement check. Does NOT yet remove resource cost — that's deferred to v0.2 (needs hooking the placement-validation UFUNCTION). |
| Building | Unlock all build items | All `R5BuildingItem` entries unlocked regardless of recipe gating (via `DrawData.bLockedByRecipe`) |
| Inventory | Infinite inventory stock | **Diagnostic-only in v0.1.x.** The mod doesn't yet know which UE class actually holds player resource counts in your build. Run `wcm dump` in-game and the `R5InventoryComponent`/similar class names found will be logged — share to help refine v0.2. |

Each flag is independently toggleable and reversible. Toggling a flag off restores the original values it wrote (per-container, per-flag snapshot).

## Requirements

- **Windrose** (Steam AppID 3041230) — tested against buildid 23065453 (May 2026 patch).
- **UE4SS** Latest Experimental build (g06474186 or later recommended). Download from <https://github.com/UE4SS-RE/RE-UE4SS/releases>.
- Windows 10/11, 64-bit.

## Installation

1. Install UE4SS into `<Windrose install>\R5\Binaries\Win64\` if you haven't already (extract the zip there so `dwmapi.dll` sits next to `Windrose-Win64-Shipping.exe`).
2. Extract `WindroseCheatMenu-<version>.zip` into `<Windrose install>\R5\Binaries\Win64\ue4ss\Mods\` so you have:
   ```
   ...\Win64\ue4ss\Mods\WindroseCheatMenu\
       enabled.txt
       Scripts\
           main.lua
           gui.lua
           runtime.lua
           player.lua
           ship.lua
           world.lua
           attrs.lua
   ```
3. Open `<Windrose install>\R5\Binaries\Win64\ue4ss\UE4SS-settings.ini` and set:
   ```ini
   ConsoleEnabled    = 1
   GuiConsoleEnabled = 1
   GuiConsoleVisible = 0
   ```
   This gives the menu an ImGui rendering surface. `GuiConsoleVisible = 0` keeps the UE4SS console window hidden by default; F8 will still toggle the cheat menu.
4. (Optional) Edit `<Windrose install>\R5\Binaries\Win64\ue4ss\Mods\mods.txt` and add `WindroseCheatMenu : 1` above the `; Built-in keybinds` line.
5. Launch Windrose via Steam. Press **F10** in-game to open the UE console, then type `wcm` to see commands.

## Usage

Primary UI is the in-game **F10 console**. Type `wcm` for help. Example session:

```
wcm status                       show every flag's state
wcm health on                    enable unlimited_health
wcm all on                       enable every flag in one line
wcm freebuild on                 enable "build anywhere" (bRequiresBuildingCenter=false)
wcm unlock on                    unlock every R5BuildingItem (bypass recipe gating)
wcm dump                         log inventory class candidates to UE4SS.log
wcm probe <ClassName>            log first 3 instances + known boolean field values
wcm setfield <Class> <field> on  write a single boolean field (diagnostic)
```

Friendly aliases supported: `health`, `stamina`, `defense`, `armor`, `damage`, `invincible`, `cannon`, `freebuild`, `unlock`, `inventory`.

### Hotkey (legacy / future ImGui builds)

- **F8** — toggle the (currently inert) ImGui menu. Will activate automatically on a UE4SS build that exposes ImGui to Lua. Latest Experimental `g06474186` does not, so for now use the F10 `wcm` console instead.
- **Apply now** button — force an immediate re-application of every active flag (useful after loading a new world)
- **Re-scan world** button — clear cached player/ship/build references; useful if cheats stop applying after a long session
- **Dump inventory** button — log every inventory class candidate to `UE4SS.log` for diagnostic purposes (helps refine the infinite-inventory implementation for new game patches)
- **Disable all** button — clear every flag in one click

## Lua API

The mod exposes a global `WindroseCheatMenu` table:

```lua
WindroseCheatMenu.Set("unlimited_health", true)   -- toggle a single flag
WindroseCheatMenu.Get("unlimited_health")         -- read a flag
WindroseCheatMenu.GetFlags()                      -- whole config table
WindroseCheatMenu.Apply()                         -- force one tick
WindroseCheatMenu.Rescan()                        -- clear caches
WindroseCheatMenu.DumpInventory()                 -- diagnostic log
WindroseCheatMenu.DisableAll()                    -- clear every flag + apply
WindroseCheatMenu.Toggle()                        -- show/hide menu
WindroseCheatMenu.Show() / WindroseCheatMenu.Hide()
```

## Save data warning

Windrose autosaves continuously (see `<game>\R5\SaveWorkflow.md`). Any cheats active when the game autosaves will have their buffed values persisted to RocksDB. Before activating any cheats:

```
copy "%LOCALAPPDATA%\R5\Saved\SaveProfiles\<your_steam_id>\" to a safe location
```

The game itself also keeps `_Latest`-marked backups at `<save_root>\RocksDB_v2_Backups\` — useful if you forget to back up first, though they're overwritten on every autosave.

## Project layout

```
windrose-cheat-menu/
├── README.md              this file
├── LICENSE                MIT
├── CHANGELOG.md           release history
├── nexus-page.md          mod page description draft for Nexus upload
├── WindroseCheatMenu/     installable mod folder (zip contents)
│   ├── enabled.txt
│   └── Scripts/
│       ├── main.lua       entry point — public API + hotkey + boot
│       ├── gui.lua        ImGui checkbox menu
│       ├── runtime.lua    tick loop, delegates to per-module appliers
│       ├── attrs.lua      attribute read/write + snapshot/restore helpers
│       ├── player.lua     per-flag player attribute tables + finder
│       ├── ship.lua       per-flag ship attribute tables + finder
│       └── world.lua      free_build, unlock_all_items, infinite_inventory
└── dist/                  built release zips
    └── WindroseCheatMenu-<version>.zip
```

## Building a release

Manual:
```powershell
cd C:\Users\keato\repos\windrose-cheat-menu
Compress-Archive -Path WindroseCheatMenu -DestinationPath dist\WindroseCheatMenu-0.1.0.zip -Force
```

Or use the helper that also publishes the GitHub Release:
```powershell
# one-time
gh auth login

# every release (builds zip if missing, creates the Release, attaches zip)
.\scripts\publish-release.ps1 -Version 0.1.0
```

The release zip should contain a single top-level `WindroseCheatMenu/` folder — that's what users drop into `<game>\R5\Binaries\Win64\ue4ss\Mods\`.

## Credits & prior art

- Inspired by **Windrose Cheat Suite** by [original author] (Nexus mod 171) — different code, similar problem space. Cheat Suite was the first published cheat mod for Windrose and informed several class-name / attribute-name choices in this implementation.
- Built on top of [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) by the UE4SS contributors.

## License

MIT — see `LICENSE`.
