# Nexus mod page draft — Windrose Cheat Menu

Paste these fields into the Nexus upload form. Wrap in BBCode where Nexus
expects it (Description → "Source" toggle in the editor — most of the markup
below maps cleanly).

---

## Title

Windrose Cheat Menu

## Tagline (short summary)

In-game checkbox menu with per-feature toggles — player buffs, ship buffs, free build, item unlocks, infinite inventory. Standalone, no other mod required.

## Categories

- Gameplay
- Cheats

## Description (long-form)

[size=5]Windrose Cheat Menu[/size]

A standalone UE4SS mod that puts an in-game ImGui menu over your Windrose session, with a checkbox for each cheat so you can toggle features independently — no all-or-nothing master switch.

[size=4]Features[/size]

[b]Player[/b]
[list]
[*] Unlimited health — Health and MaxHealth set to 5000
[*] Unlimited stamina — pool, regen rate, regen modifier maxed; consumption zeroed
[*] Super defence — Defence Power and all damage-taken resists buffed
[*] Super armor — Armor, armor modifier, and final damage reduction by armor maxed
[*] Super damage — every damage type (Global, Melee, Range, Crude, Slash, Pierce, Blunt) + crit chance + crit damage + armor penetration
[/list]

[b]Ship[/b]
[list]
[*] Ship invincible — hull/sail health and armor + cannon damage-taken resist buffed
[*] Ship cannon boost — cannon damage flat bonus + multiplier
[/list]

[b]Building & Inventory[/b]
[list]
[*] Free build — disables resource cost validation when placing structures
[*] Unlock all build items — bypasses recipe gating on R5BuildingItem
[*] Infinite inventory stock — best-effort: tops up numeric resource counters
[/list]

Each flag is independently toggleable. Toggling a flag OFF restores the original values it wrote — per-container, per-flag snapshot.

[size=4]Requirements[/size]

[list]
[*] [b]UE4SS[/b] (Latest Experimental recommended) — [url=https://github.com/UE4SS-RE/RE-UE4SS/releases]download here[/url]
[/list]

No other mods required.

[size=4]Installation[/size]

[list=1]
[*] Install UE4SS into your Windrose folder ([font=Courier New]<Windrose install>\R5\Binaries\Win64\[/font]) per the UE4SS instructions.
[*] Extract this zip into [font=Courier New]<Windrose install>\R5\Binaries\Win64\ue4ss\Mods\[/font] so you have a [font=Courier New]WindroseCheatMenu\[/font] folder there.
[*] Open [font=Courier New]<Windrose install>\R5\Binaries\Win64\ue4ss\UE4SS-settings.ini[/font] and set:
[code]ConsoleEnabled    = 1
GuiConsoleEnabled = 1
GuiConsoleVisible = 0[/code]
[*] Launch Windrose via Steam.
[*] Press [b]F8[/b] in-game to open the menu.
[/list]

[size=4]Save warning[/size]

Windrose autosaves continuously — any cheats active when the game autosaves get their buffed values persisted to your save database. [b]Back up your save folder before activating cheats:[/b]

[code]%LOCALAPPDATA%\R5\Saved\SaveProfiles\<your_steam_id>\[/code]

[size=4]Hotkeys & API[/size]

[list]
[*] [b]F8[/b] — toggle the cheat menu
[*] [b]Apply now[/b] button — re-apply all active flags immediately
[*] [b]Re-scan world[/b] button — clear cached player/ship references
[*] [b]Dump inventory[/b] button — log inventory class candidates to UE4SS.log (useful if Infinite Inventory isn't working for you — share the log lines in the Posts tab so I can add your class names)
[*] [b]Disable all[/b] button — clear every flag in one click
[/list]

Lua API available on the [font=Courier New]WindroseCheatMenu[/font] global if you want to script it: [font=Courier New]Set(flag, bool)[/font], [font=Courier New]Get(flag)[/font], [font=Courier New]GetFlags()[/font], [font=Courier New]Apply()[/font], [font=Courier New]Rescan()[/font], [font=Courier New]DumpInventory()[/font], [font=Courier New]DisableAll()[/font].

[size=4]Credits[/size]

Inspired by [url=https://www.nexusmods.com/windrose/mods/171]Windrose Cheat Suite[/url] — the first published cheat mod for Windrose. Different code, similar problem space.

Built on [url=https://github.com/UE4SS-RE/RE-UE4SS]UE4SS[/url] by the UE4SS contributors.

Source on GitHub: [url=https://github.com/jalyper/windrose-cheat-menu]jalyper/windrose-cheat-menu[/url] (update link after pushing)

[size=4]License[/size]

MIT.

---

## Permissions (Nexus form)

- Upload permission: Other users CAN upload this file to other sites
- Modification permission: Other users CAN modify this file
- Conversion permission: Other users CAN convert this file
- Asset use permission: Other users CAN use assets from this mod
- Asset use in mods/files that earn donation points: Allowed

(Adjust to taste before publishing — the above is the most permissive MIT-aligned set.)

## Tags

UE4SS, Lua, Cheat, Menu, ImGui, Standalone, Building, Inventory, Ship

## Version (for upload form)

0.1.0

## Changelog (for upload form)

Initial release. Per-feature checkbox menu for player buffs, ship buffs, free build, item unlock, and infinite inventory stock. F8 toggle. See README for details.
