-- F10 in-game console command interface for Windrose Cheat Menu.
-- Registered as `wcm` via UE4SS's RegisterConsoleCommandHandler.
--
-- Usage from inside the F10 console:
--   wcm                       -> show help
--   wcm status                -> print current flag states
--   wcm <flag>                -> show single flag's state
--   wcm <flag> on/off/toggle  -> set a single flag
--   wcm <group> on/off        -> bulk toggle (player, ship, building, all)
--   wcm apply                 -> force one tick of apply
--   wcm rescan                -> clear cached player/ship/build refs
--   wcm dump                  -> log inventory class candidates
--
-- Friendly aliases let you say `wcm health on` instead of
-- `wcm unlimited_health on`. See ALIASES below.

local C = {}

local function logf(msg)
    print(string.format("[WindroseCheatMenu:console] %s\n", tostring(msg)))
end

-- ----- Output helpers ---------------------------------------------------
-- Ar is the FOutputDevice passed by UE4SS — writes appear in the F10 console.
-- Always also print to UE4SS.log so the user can verify after the fact.

local function writeline(ar, line)
    if ar and type(ar.Log) == "function" then
        pcall(function() ar:Log(line) end)
    end
    print(string.format("[WindroseCheatMenu:console] %s\n", line))
end

-- ----- Flag registry ----------------------------------------------------

C.PLAYER_FLAGS  = { "unlimited_health", "unlimited_stamina", "super_defense",
                    "super_armor", "super_damage" }
C.SHIP_FLAGS    = { "ship_invincible", "ship_cannon_boost" }
C.BUILD_FLAGS   = { "free_build", "unlock_all_items", "infinite_inventory" }

C.ALL_FLAGS = {}
for _, t in ipairs({ C.PLAYER_FLAGS, C.SHIP_FLAGS, C.BUILD_FLAGS }) do
    for _, f in ipairs(t) do table.insert(C.ALL_FLAGS, f) end
end

-- Short aliases the user can type instead of the canonical flag name
C.ALIASES = {
    health           = "unlimited_health",
    hp               = "unlimited_health",
    stamina          = "unlimited_stamina",
    stam             = "unlimited_stamina",
    defense          = "super_defense",
    defence          = "super_defense",
    def              = "super_defense",
    armor            = "super_armor",
    armour           = "super_armor",
    damage           = "super_damage",
    dmg              = "super_damage",
    ship_hull        = "ship_invincible",
    invincible       = "ship_invincible",
    cannon           = "ship_cannon_boost",
    ship_cannon      = "ship_cannon_boost",
    freebuild        = "free_build",
    build            = "free_build",
    unlock           = "unlock_all_items",
    items            = "unlock_all_items",
    inventory        = "infinite_inventory",
    inv              = "infinite_inventory",
    stock            = "infinite_inventory",
}

-- Map a user-typed token to a canonical flag name (or nil if unknown).
local function resolve_flag(token)
    if not token then return nil end
    token = tostring(token):lower()
    if C.ALIASES[token] then return C.ALIASES[token] end
    for _, name in ipairs(C.ALL_FLAGS) do
        if name == token then return name end
    end
    return nil
end

-- Parse the third arg into a boolean op: "on"/"off"/"toggle".
-- Returns ("set", true/false) or ("toggle") or nil if not recognized.
local function parse_op(token)
    if not token then return nil end
    token = tostring(token):lower()
    if token == "on" or token == "true" or token == "1" or token == "enable" then
        return "set", true
    end
    if token == "off" or token == "false" or token == "0" or token == "disable" then
        return "set", false
    end
    if token == "toggle" or token == "t" then
        return "toggle"
    end
    return nil
end

-- ----- Config IO --------------------------------------------------------

local function get(flag)
    return _G.WindroseCheatMenuConfig[flag] == true
end

local function set(flag, value)
    _G.WindroseCheatMenuConfig[flag] = value == true
    if _G.WindroseCheatMenu and _G.WindroseCheatMenu.Apply then
        _G.WindroseCheatMenu.Apply()
    end
end

local function toggle(flag)
    set(flag, not get(flag))
    return get(flag)
end

-- ----- Subcommand implementations ---------------------------------------

local function cmd_help(ar)
    writeline(ar, "Windrose Cheat Menu commands (type these in this console):")
    writeline(ar, "  wcm status                       - show all flag states")
    writeline(ar, "  wcm <flag>                       - show one flag state")
    writeline(ar, "  wcm <flag> on|off|toggle         - change one flag")
    writeline(ar, "  wcm player on|off                - bulk toggle player flags")
    writeline(ar, "  wcm ship on|off                  - bulk toggle ship flags")
    writeline(ar, "  wcm building on|off              - bulk toggle building+inventory flags")
    writeline(ar, "  wcm all on|off                   - bulk toggle every flag")
    writeline(ar, "  wcm apply                        - force one apply pass")
    writeline(ar, "  wcm rescan                       - clear cached player/ship refs")
    writeline(ar, "  wcm dump                         - log inventory class candidates")
    writeline(ar, "  wcm probe <ClassName>            - log instance count + first object fields")
    writeline(ar, "  wcm setfield <Class> <field> on/off - try writing one boolean field directly")
    writeline(ar, "")
    writeline(ar, "Flag aliases: health, stamina, defense, armor, damage,")
    writeline(ar, "  invincible, cannon, freebuild, unlock, inventory")
end

local function cmd_status(ar)
    writeline(ar, "Windrose Cheat Menu status:")
    writeline(ar, "  Player:")
    for _, f in ipairs(C.PLAYER_FLAGS) do
        writeline(ar, string.format("    [%s] %s", get(f) and "x" or " ", f))
    end
    writeline(ar, "  Ship:")
    for _, f in ipairs(C.SHIP_FLAGS) do
        writeline(ar, string.format("    [%s] %s", get(f) and "x" or " ", f))
    end
    writeline(ar, "  Building & Inventory:")
    for _, f in ipairs(C.BUILD_FLAGS) do
        writeline(ar, string.format("    [%s] %s", get(f) and "x" or " ", f))
    end
end

local function cmd_set_one(ar, flag, op, value)
    if op == "toggle" then
        toggle(flag)
    else
        set(flag, value)
    end
    writeline(ar, string.format("%s = %s", flag, tostring(get(flag))))
end

local function cmd_show_one(ar, flag)
    writeline(ar, string.format("%s = %s", flag, tostring(get(flag))))
end

local function cmd_bulk(ar, group, value)
    local list
    if     group == "player"   then list = C.PLAYER_FLAGS
    elseif group == "ship"     then list = C.SHIP_FLAGS
    elseif group == "building" then list = C.BUILD_FLAGS
    elseif group == "all"      then list = C.ALL_FLAGS
    end
    if not list then return false end
    for _, f in ipairs(list) do
        _G.WindroseCheatMenuConfig[f] = value == true
    end
    if _G.WindroseCheatMenu and _G.WindroseCheatMenu.Apply then
        _G.WindroseCheatMenu.Apply()
    end
    writeline(ar, string.format("%s -> %s (%d flags)",
        group, value and "on" or "off", #list))
    return true
end

local function cmd_apply(ar)
    if _G.WindroseCheatMenu and _G.WindroseCheatMenu.Apply then
        _G.WindroseCheatMenu.Apply()
        writeline(ar, "applied")
    else
        writeline(ar, "Apply unavailable")
    end
end

local function cmd_rescan(ar)
    if _G.WindroseCheatMenu and _G.WindroseCheatMenu.Rescan then
        _G.WindroseCheatMenu.Rescan()
        writeline(ar, "rescanned (caches cleared)")
    else
        writeline(ar, "Rescan unavailable")
    end
end

local function cmd_dump(ar)
    if _G.WindroseCheatMenu and _G.WindroseCheatMenu.DumpInventory then
        local n = _G.WindroseCheatMenu.DumpInventory()
        writeline(ar, string.format("dump_inventory wrote %d candidates to UE4SS.log",
            tonumber(n) or 0))
    else
        writeline(ar, "DumpInventory unavailable")
    end
end

local function cmd_probe(ar, class_name)
    if not class_name or class_name == "" then
        writeline(ar, "Usage: wcm probe <ClassName>  (e.g. wcm probe R5BuildingSettings)")
        return
    end
    if _G.WindroseCheatMenu and _G.WindroseCheatMenu.Probe then
        local n = _G.WindroseCheatMenu.Probe(class_name)
        writeline(ar, string.format("probed '%s' -> %d instances (details in UE4SS.log)",
            class_name, tonumber(n) or 0))
    else
        writeline(ar, "Probe unavailable")
    end
end

local function parse_bool(token)
    if not token then return nil end
    token = tostring(token):lower()
    if token == "true" or token == "on" or token == "1" then return true end
    if token == "false" or token == "off" or token == "0" then return false end
    return nil
end

local function cmd_setfield(ar, class_name, field, value_token)
    if not class_name or not field or not value_token then
        writeline(ar, "Usage: wcm setfield <ClassName> <field> <true|false>")
        return
    end
    local value = parse_bool(value_token)
    if value == nil then
        writeline(ar, "Value must be true|false|on|off|1|0")
        return
    end
    if _G.WindroseCheatMenu and _G.WindroseCheatMenu.SetField then
        local ok = _G.WindroseCheatMenu.SetField(class_name, field, value)
        writeline(ar, string.format("setfield %s.%s = %s -> ok=%s (details in UE4SS.log)",
            class_name, field, tostring(value), tostring(ok)))
    else
        writeline(ar, "SetField unavailable")
    end
end

-- ----- Main dispatcher --------------------------------------------------

local function handle(full_command, parameters, ar)
    if not parameters or #parameters == 0 then
        cmd_help(ar)
        return true
    end

    local arg1 = tostring(parameters[1]):lower()
    local arg2 = parameters[2] and tostring(parameters[2]):lower() or nil

    if arg1 == "help" or arg1 == "?"        then cmd_help(ar);   return true end
    if arg1 == "status" or arg1 == "list"   then cmd_status(ar); return true end
    if arg1 == "apply"                      then cmd_apply(ar);  return true end
    if arg1 == "rescan"                     then cmd_rescan(ar); return true end
    if arg1 == "dump"                       then cmd_dump(ar);   return true end
    if arg1 == "probe"                      then cmd_probe(ar, parameters[2]); return true end
    if arg1 == "setfield" then
        cmd_setfield(ar, parameters[2], parameters[3], parameters[4])
        return true
    end

    -- Bulk groups
    if arg1 == "player" or arg1 == "ship" or arg1 == "building" or arg1 == "all" then
        if not arg2 then
            writeline(ar, "Need on/off — e.g. 'wcm " .. arg1 .. " on'")
            return true
        end
        local op, value = parse_op(arg2)
        if op ~= "set" then
            writeline(ar, "Use 'on' or 'off' for bulk groups")
            return true
        end
        cmd_bulk(ar, arg1, value)
        return true
    end

    -- Single flag
    local flag = resolve_flag(arg1)
    if not flag then
        writeline(ar, string.format("Unknown flag or command: %s", arg1))
        writeline(ar, "Type 'wcm help' for the full list.")
        return true
    end

    if not arg2 then
        cmd_show_one(ar, flag)
        return true
    end

    local op, value = parse_op(arg2)
    if not op then
        writeline(ar, string.format("Unknown operation: %s (use on/off/toggle)", arg2))
        return true
    end
    cmd_set_one(ar, flag, op, value)
    return true
end

-- ----- Registration -----------------------------------------------------

C.init = function()
    if type(RegisterConsoleCommandHandler) ~= "function" then
        logf("RegisterConsoleCommandHandler unavailable — wcm command not registered")
        return false
    end
    RegisterConsoleCommandHandler("wcm", function(full, params, ar)
        local ok, err = pcall(handle, full, params, ar)
        if not ok then
            writeline(ar, "internal error: " .. tostring(err))
            logf("handler error: " .. tostring(err))
        end
        return true
    end)
    logf("'wcm' console command registered — type 'wcm' in the F10 console for help")
    return true
end

return C
