-- Tick orchestrator for Windrose Cheat Menu (standalone).
-- Each tick: read flags, find player/ship, delegate per-flag apply/restore
-- to player.lua / ship.lua / world.lua.

local A      = require "attrs"
local player = require "player"
local ship   = require "ship"
local world  = require "world"

local M = {}

local function log(msg)
    print(string.format("[WindroseCheatMenu:runtime] %s\n", tostring(msg)))
end

-- ----- Tick cadences ----------------------------------------------------

local TICK_MS               = 1000
local PLAYER_SEARCH_FAST    = 1
local PLAYER_SEARCH_SLOW    = 5
local PLAYER_APPLY_INTERVAL = 1
local SHIP_SEARCH_INTERVAL  = 3
local SHIP_APPLY_INTERVAL   = 1
local TELEMETRY_INTERVAL    = 60

local tick_count            = 0
local cached_player         = nil
local cached_attr_set       = nil
local cached_ship           = nil
local cached_ship_attr      = nil
local last_player_search    = -999
local last_ship_search      = -999
local last_telemetry        = -999

-- ----- Flag snapshot ----------------------------------------------------

local function flags()
    local cfg = _G.WindroseCheatMenuConfig
    if type(cfg) ~= "table" then return {} end
    return {
        unlimited_health   = cfg.unlimited_health   == true,
        unlimited_stamina  = cfg.unlimited_stamina  == true,
        super_defense      = cfg.super_defense      == true,
        super_armor        = cfg.super_armor        == true,
        super_damage       = cfg.super_damage       == true,
        ship_invincible    = cfg.ship_invincible    == true,
        ship_cannon_boost  = cfg.ship_cannon_boost  == true,
        free_build         = cfg.free_build         == true,
        unlock_all_items   = cfg.unlock_all_items   == true,
        infinite_inventory = cfg.infinite_inventory == true,
    }
end

local function any_player_flag(f)
    return f.unlimited_health or f.unlimited_stamina or
           f.super_defense or f.super_armor or f.super_damage
end

local function any_ship_flag(f)
    return f.ship_invincible or f.ship_cannon_boost
end

-- ----- Tick body --------------------------------------------------------

local function tick()
    tick_count = tick_count + 1
    local f = flags()

    -- World cheats run regardless of player/ship presence.
    world.apply_free_build(f.free_build)
    if (tick_count % 5) == 0 then
        world.apply_unlock_items(f.unlock_all_items, tick_count)
    end
    if f.infinite_inventory and (tick_count % 2) == 0 then
        world.apply_infinite_inventory(true, tick_count)
    end

    -- Player buffs
    if any_player_flag(f) then
        if not A.is_valid(cached_player) or not A.is_valid(cached_attr_set) then
            local interval = (cached_attr_set == nil) and PLAYER_SEARCH_FAST or PLAYER_SEARCH_SLOW
            if tick_count - last_player_search >= interval then
                last_player_search = tick_count
                cached_player     = player.find_player()
                cached_attr_set   = cached_player and player.find_attr_set(cached_player) or nil
            end
        end
        if A.is_valid(cached_attr_set) and (tick_count % PLAYER_APPLY_INTERVAL) == 0 then
            player.apply(cached_attr_set, f)
        end
    else
        -- If all player flags are off, run a one-time restore.
        A.restore_flag("unlimited_health")
        A.restore_flag("unlimited_stamina")
        A.restore_flag("super_defense")
        A.restore_flag("super_armor")
        A.restore_flag("super_damage")
    end

    -- Ship buffs
    if any_ship_flag(f) then
        if not A.is_valid(cached_ship) or not A.is_valid(cached_ship_attr) then
            if tick_count - last_ship_search >= SHIP_SEARCH_INTERVAL then
                last_ship_search = tick_count
                if A.is_valid(cached_player) then
                    cached_ship, cached_ship_attr = ship.resolve_ship_from_player(cached_player)
                end
                if not A.is_valid(cached_ship) then
                    cached_ship = ship.find_ship()
                    cached_ship_attr = cached_ship and ship.find_ship_attr(cached_ship) or nil
                end
            end
        end
        if A.is_valid(cached_ship_attr) and (tick_count % SHIP_APPLY_INTERVAL) == 0 then
            ship.apply(cached_ship_attr, f)
        end
    else
        A.restore_flag("ship_invincible")
        A.restore_flag("ship_cannon_boost")
    end

    -- Telemetry log every TELEMETRY_INTERVAL ticks
    if tick_count - last_telemetry >= TELEMETRY_INTERVAL then
        last_telemetry = tick_count
        local on_flags = {}
        for k, v in pairs(f) do
            if v then table.insert(on_flags, k) end
        end
        if #on_flags > 0 then
            log("active flags: " .. table.concat(on_flags, ", "))
        end
    end
end

-- ----- Public API -------------------------------------------------------

M.apply = function()
    -- Force an immediate tick — useful for "Apply now" button after world changes
    local ok, err = pcall(tick)
    if not ok then log("manual tick error: " .. tostring(err)) end
    return ok
end

M.rescan = function()
    cached_player      = nil
    cached_attr_set    = nil
    cached_ship        = nil
    cached_ship_attr   = nil
    last_player_search = -999
    last_ship_search   = -999
    world.rescan()
    log("rescan: caches cleared")
end

M.dump_inventory = function()
    return world.dump_inventory()
end

M.probe_class = function(name)
    return world.probe_class(name)
end

M.set_field_on_class = function(cls, field, value)
    return world.set_field_on_class(cls, field, value)
end

M.init = function()
    if type(LoopAsync) ~= "function" then
        log("LoopAsync unavailable — runtime cannot tick")
        return
    end
    LoopAsync(TICK_MS, function()
        local ok, err = pcall(tick)
        if not ok then log("tick error: " .. tostring(err)) end
        return false
    end)
    log("tick loop attached (" .. tostring(TICK_MS) .. "ms)")
end

return M
