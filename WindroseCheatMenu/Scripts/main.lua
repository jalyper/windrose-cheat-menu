-- Windrose Cheat Menu — standalone UE4SS mod for Windrose.
-- In-game ImGui checkbox menu with per-feature toggles for player buffs,
-- ship buffs, building, and inventory.
--
-- Author : jalyper
-- License: MIT
-- Requires UE4SS (Latest Experimental recommended). No other mod required.

local MOD_NAME    = "WindroseCheatMenu"
local MOD_VERSION = "0.1.1"

local function log(msg)
    print(string.format("[%s] %s\n", MOD_NAME, tostring(msg)))
end

-- ----- Config ------------------------------------------------------------
-- All flags default OFF. Toggle via the in-game menu (F8) or via the public
-- API (_G.WindroseCheatMenu.Set(flag, true/false)). Each flag is gated
-- independently by the runtime modules; toggling one off restores the
-- originals it wrote.

_G.WindroseCheatMenu       = _G.WindroseCheatMenu or {}
_G.WindroseCheatMenuConfig = _G.WindroseCheatMenuConfig or {
    -- Player
    unlimited_health   = false,
    unlimited_stamina  = false,
    super_defense      = false,
    super_armor        = false,
    super_damage       = false,
    -- Ship
    ship_invincible    = false,
    ship_cannon_boost  = false,
    -- Building / world
    free_build         = false,
    unlock_all_items   = false,
    infinite_inventory = false,
}

-- ----- Module loading ----------------------------------------------------

local gui_ok,     gui     = pcall(require, "gui")
local runtime_ok, runtime = pcall(require, "runtime")
local console_ok, console = pcall(require, "console")

if not gui_ok     then log("failed to load gui.lua: "     .. tostring(gui))     end
if not runtime_ok then log("failed to load runtime.lua: " .. tostring(runtime)) end
if not console_ok then log("failed to load console.lua: " .. tostring(console)) end

-- ----- Public API --------------------------------------------------------

_G.WindroseCheatMenu.Version = MOD_VERSION

_G.WindroseCheatMenu.Show    = function() if gui_ok then gui.set_visible(true)  end end
_G.WindroseCheatMenu.Hide    = function() if gui_ok then gui.set_visible(false) end end
_G.WindroseCheatMenu.Toggle  = function()
    if gui_ok then return gui.toggle() end
    return false
end
_G.WindroseCheatMenu.IsVisible = function()
    if gui_ok then return gui.is_visible() end
    return false
end

_G.WindroseCheatMenu.Set = function(flag, value)
    if type(flag) ~= "string" then return false end
    _G.WindroseCheatMenuConfig[flag] = value == true
    return true
end

_G.WindroseCheatMenu.Get = function(flag)
    return _G.WindroseCheatMenuConfig[flag] == true
end

_G.WindroseCheatMenu.GetFlags = function()
    return _G.WindroseCheatMenuConfig
end

_G.WindroseCheatMenu.DisableAll = function()
    for k, _ in pairs(_G.WindroseCheatMenuConfig) do
        _G.WindroseCheatMenuConfig[k] = false
    end
    if runtime_ok and runtime.apply then runtime.apply() end
end

_G.WindroseCheatMenu.Apply   = function() if runtime_ok and runtime.apply         then return runtime.apply()         end end
_G.WindroseCheatMenu.Rescan  = function() if runtime_ok and runtime.rescan        then return runtime.rescan()        end end
_G.WindroseCheatMenu.DumpInventory = function()
    if runtime_ok and runtime.dump_inventory then return runtime.dump_inventory() end
end

_G.WindroseCheatMenu.Probe = function(class_name)
    if runtime_ok and runtime.probe_class then return runtime.probe_class(class_name) end
    return 0
end

_G.WindroseCheatMenu.SetField = function(class_name, field, value)
    if runtime_ok and runtime.set_field_on_class then
        return runtime.set_field_on_class(class_name, field, value)
    end
    return false
end

-- ----- Hotkey ------------------------------------------------------------

local function register_menu_hotkey()
    if type(Key) ~= "table" or Key.F8 == nil then
        log("Key.F8 unavailable — menu hotkey not bound")
        return
    end

    local cb = function() _G.WindroseCheatMenu.Toggle() end

    if type(RegisterKeyBindAsync) == "function" then
        local ok = pcall(function() RegisterKeyBindAsync(Key.F8, cb) end)
        if ok then log("F8 registered as menu toggle (async)") return end
    end

    if type(RegisterKeyBind) == "function" then
        local ok = pcall(function() RegisterKeyBind(Key.F8, cb) end)
        if ok then log("F8 registered as menu toggle (sync fallback)") return end
    end

    log("F8 hotkey registration failed — use _G.WindroseCheatMenu.Toggle()")
end

-- ----- Boot --------------------------------------------------------------

if gui_ok     and gui.init     then pcall(gui.init)     end
if runtime_ok and runtime.init then pcall(runtime.init) end
if console_ok and console.init then pcall(console.init) end

register_menu_hotkey()

log(string.format("loader online (v%s) — type 'wcm' in F10 console for cheats", MOD_VERSION))
