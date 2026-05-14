-- ImGui checkbox menu for Windrose Cheat Menu (standalone).
-- Renders into UE4SS's ImGui surface — requires GuiConsoleEnabled=1 in
-- UE4SS-settings.ini. Press F8 in-game to toggle.

local M = {}

local visible = false

local function log(msg)
    print(string.format("[WindroseCheatMenu:gui] %s\n", tostring(msg)))
end

-- ----- Visibility --------------------------------------------------------

M.set_visible = function(v) visible = v == true end
M.is_visible  = function() return visible end
M.toggle = function()
    visible = not visible
    log("visible=" .. tostring(visible))
    return visible
end

-- ----- Config helpers ----------------------------------------------------

local function flag_read(name, default)
    local cfg = _G.WindroseCheatMenuConfig
    if type(cfg) ~= "table" then return default end
    local v = cfg[name]
    if v == nil then return default end
    return v == true
end

local function flag_write(name, value)
    _G.WindroseCheatMenuConfig[name] = value == true
end

-- ----- ImGui helpers -----------------------------------------------------

local function imgui_available() return type(ImGui) == "table" end

local function checkbox(label, flag_name)
    local current = flag_read(flag_name, false)
    local changed, new_value = ImGui.Checkbox(label, current)
    if changed then flag_write(flag_name, new_value) end
end

local function section(title)
    ImGui.Separator()
    ImGui.Text(title)
end

-- ----- Draw --------------------------------------------------------------

local function draw_window()
    if not visible then return end
    if not imgui_available() then return end

    local cond_first = (ImGui.Cond and ImGui.Cond.FirstUseEver) or 4
    if ImGui.SetNextWindowSize then
        ImGui.SetNextWindowSize(380, 560, cond_first)
    end

    local is_open = ImGui.Begin("Windrose Cheat Menu")
    if is_open == false then
        ImGui.End()
        return
    end

    ImGui.Text(string.format("v%s — press F8 to hide",
        (_G.WindroseCheatMenu and _G.WindroseCheatMenu.Version) or "?"))

    section("Player")
    checkbox("Unlimited health",   "unlimited_health")
    checkbox("Unlimited stamina",  "unlimited_stamina")
    checkbox("Super defence",      "super_defense")
    checkbox("Super armor",        "super_armor")
    checkbox("Super damage",       "super_damage")

    section("Ship")
    checkbox("Ship invincible",    "ship_invincible")
    checkbox("Ship cannon boost",  "ship_cannon_boost")

    section("Building & Resources")
    checkbox("Free build (no resource cost)", "free_build")
    checkbox("Unlock all build items",        "unlock_all_items")
    checkbox("Infinite inventory stock",      "infinite_inventory")

    section("Actions")
    if ImGui.Button("Apply now") then
        if _G.WindroseCheatMenu.Apply then _G.WindroseCheatMenu.Apply() end
    end
    if ImGui.SameLine then ImGui.SameLine() end
    if ImGui.Button("Re-scan world") then
        if _G.WindroseCheatMenu.Rescan then _G.WindroseCheatMenu.Rescan() end
    end
    if ImGui.SameLine then ImGui.SameLine() end
    if ImGui.Button("Dump inventory") then
        if _G.WindroseCheatMenu.DumpInventory then _G.WindroseCheatMenu.DumpInventory() end
    end

    if ImGui.Button("Disable all") then
        if _G.WindroseCheatMenu.DisableAll then _G.WindroseCheatMenu.DisableAll() end
    end

    ImGui.End()
end

-- ----- Init --------------------------------------------------------------

M.init = function()
    if type(LoopAsync) == "function" then
        LoopAsync(16, function()
            local ok, err = pcall(draw_window)
            if not ok then log("draw error: " .. tostring(err)) end
            return false
        end)
        log("render loop attached (16ms)")
    else
        log("LoopAsync unavailable — GUI cannot render")
    end
end

return M
