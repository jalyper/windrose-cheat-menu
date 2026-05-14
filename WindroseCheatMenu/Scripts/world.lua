-- World/building cheats for Windrose Cheat Menu.
-- Owns: free_build, unlock_all_items, infinite_inventory.
-- These don't run through attr_set snapshots — they patch settings or
-- numeric fields directly, with their own per-flag revert logic.

local A = require "attrs"

local W = {}

local cached_build_settings = nil
local cached_build_items    = nil
local cached_inventories    = nil
local last_inventory_search = -999

local UNLOCK_REFRESH_INTERVAL   = 10
local INVENTORY_SEARCH_INTERVAL = 30
local INVENTORY_TOPUP_TARGET    = 9999
local INVENTORY_TOPUP_THRESHOLD = 100

local function log(msg)
    print(string.format("[WindroseCheatMenu:world] %s\n", tostring(msg)))
end

-- Forward declaration so apply_free_build_per_item (defined earlier in the
-- file) can call refresh_build_items (defined later). Lua resolves locals
-- by lexical scope at compile time; without this, the name is treated as
-- a global and resolves to nil at call time.
local refresh_build_items

-- ----- Free build -------------------------------------------------------

-- Class-name candidates for build-cost gating. The first one with live
-- instances wins. Add more here as we discover them via `wcm probe`.
W.BUILD_SETTINGS_CANDIDATES = {
    "R5BuildingSettings",
    "R5BuildSettings",
    "R5BuildingSystemSettings",
    "R5BuildingConfig",
    "R5BuildingManager",
    "R5BuildSystemConfig",
    "R5BuildController",
    "R5BuildingPlacer",
    "R5BuildSystem",
}

-- Field-name candidates we'll toggle on whichever class is live.
-- When state=true (cheats ON), the *Validation flags should be false (skip checks).
W.BUILD_FIELD_MAP = {
    bBuildingResourcesValidation     = false,  -- inverted (set to false when free_build=on)
    bSkipBuildingCenterValidation    = true,   -- direct
    bRequireResources                = false,
    bConsumeResources                = false,
    bResourceValidation              = false,
    bSkipResourceCheck               = true,
    bFreeBuild                       = true,
    bUnlimitedResources              = true,
}

local first_probe_done = false

local function find_build_settings_any()
    if A.is_valid(cached_build_settings) then return cached_build_settings end
    cached_build_settings = nil
    for _, cls in ipairs(W.BUILD_SETTINGS_CANDIDATES) do
        local ok, all = pcall(FindAllOf, cls)
        if ok and type(all) == "table" then
            for i = 1, #all do
                if A.is_valid(all[i]) then
                    if not first_probe_done then
                        first_probe_done = true
                        log(string.format("find_build_settings: matched class '%s' (instance count=%d)",
                            cls, #all))
                        pcall(function()
                            log("  first instance full name: " .. tostring(all[i]:GetFullName()))
                        end)
                    end
                    cached_build_settings = all[i]
                    return cached_build_settings
                end
            end
        end
    end
    if not first_probe_done then
        first_probe_done = true
        log("find_build_settings: no instances found for any candidate class. " ..
            "Run 'wcm probe <ClassName>' to test alternates.")
        log("  candidates tried: " .. table.concat(W.BUILD_SETTINGS_CANDIDATES, ", "))
    end
    return nil
end

local function apply_field_map(container, state)
    if not A.is_valid(container) then return 0 end
    local touched = 0
    for field, direct in pairs(W.BUILD_FIELD_MAP) do
        pcall(function()
            local current = container[field]
            if current == nil then return end -- field doesn't exist on this class
            local target
            if direct then
                target = state
            else
                target = not state
            end
            container[field] = target
            touched = touched + 1
        end)
    end
    return touched
end

W.apply_free_build = function(state)
    -- Legacy path retained for diagnostic-only purposes; the real apply
    -- lives in apply_free_build_per_item, which writes gameplay attributes
    -- on each R5BuildingItem (the actual gate per `wcm probe R5BuildingItem`).
    return W.apply_free_build_per_item(state)
end

-- ----- Per-item free-build (the real implementation) -------------------
-- The R5BuildingItem class (862 instances in this build) carries each
-- buildable's resource-cost gating as gameplay-attribute UObjects, not
-- direct bool fields. attrs.write_attr handles BaseValue/CurrentValue
-- writes and snapshots originals so toggle-off cleanly restores.

-- attr name -> target numeric value when free_build is ON
-- (0 disables a "require/validate" check; 1 enables a "skip/free/unlimited" override)
W.FREE_BUILD_ATTR_TARGETS = {
    bConsumeResources             = 0,
    bResourceValidation           = 0,
    bBuildingResourcesValidation  = 0,
    bRequireResources             = 0,
    bSkipResourceCheck            = 1,
    bFreeBuild                    = 1,
    bUnlimitedResources           = 1,
    bSkipBuildingCenterValidation = 1,
}

local last_free_build_state  = nil  -- nil until first apply; then true/false
local free_build_diag_logged = false

local function free_build_diagnostic(item)
    log("free_build first-apply diagnostic:")
    pcall(function() log("  item: " .. tostring(item:GetFullName())) end)
    for attr_name in pairs(W.FREE_BUILD_ATTR_TARGETS) do
        local attr = A.get_field(item, attr_name)
        local t = type(attr)
        log(string.format("  .%s type=%s", attr_name, t))
        if t == "userdata" or t == "table" then
            pcall(function() log(string.format("      .BaseValue    = %s", tostring(attr.BaseValue))) end)
            pcall(function() log(string.format("      .CurrentValue = %s", tostring(attr.CurrentValue))) end)
            pcall(function() log(string.format("      class         = %s", tostring(attr:GetClass():GetFullName()))) end)
        else
            log(string.format("      value = %s", tostring(attr)))
        end
    end
end

W.apply_free_build_per_item = function(state)
    -- Idempotent: no-op if state hasn't changed since last apply.
    if last_free_build_state == state then return true end

    if not cached_build_items or #cached_build_items == 0 then
        refresh_build_items()
    end
    if not cached_build_items or #cached_build_items == 0 then
        log("apply_free_build: no R5BuildingItem instances cached")
        return false
    end

    if state == true then
        if not free_build_diag_logged then
            free_build_diag_logged = true
            local first = cached_build_items[1]
            if A.is_valid(first) then pcall(function() free_build_diagnostic(first) end) end
        end

        local writes = 0
        for i = 1, #cached_build_items do
            local bi = cached_build_items[i]
            if A.is_valid(bi) then
                for attr_name, target in pairs(W.FREE_BUILD_ATTR_TARGETS) do
                    if A.write_attr(bi, "free_build", attr_name, target) then
                        writes = writes + 1
                    end
                end
            end
        end
        log(string.format("free_build ON: wrote %d attrs across %d items",
            writes, #cached_build_items))
    else
        local n = A.restore_flag("free_build")
        log(string.format("free_build OFF: restored %d original attrs", n))
    end

    last_free_build_state = state
    return true
end

-- Probe an arbitrary UE class by name. Logs instance count + first
-- instance's full name + boolean field values. Returns the count.
W.probe_class = function(cls_name)
    local ok, all = pcall(FindAllOf, cls_name)
    if not ok or type(all) ~= "table" then
        log(string.format("probe '%s': FindAllOf failed or returned non-table", cls_name))
        return 0
    end
    local n = #all
    log(string.format("probe '%s': %d instances", cls_name, n))
    for i = 1, math.min(n, 3) do
        local obj = all[i]
        if A.is_valid(obj) then
            pcall(function() log("  [" .. i .. "] " .. tostring(obj:GetFullName())) end)
            -- List all known fields with their current values
            for field, _ in pairs(W.BUILD_FIELD_MAP) do
                pcall(function()
                    local v = obj[field]
                    if v ~= nil then
                        log(string.format("        .%s = %s", field, tostring(v)))
                    end
                end)
            end
        end
    end
    return n
end

-- Try setting a single field on the first instance of a class.
W.set_field_on_class = function(cls_name, field, value)
    local ok, all = pcall(FindAllOf, cls_name)
    if not ok or type(all) ~= "table" or #all == 0 then
        log(string.format("set_field: no instances of %s", cls_name))
        return false
    end
    for i = 1, #all do
        local obj = all[i]
        if A.is_valid(obj) then
            local was = nil
            pcall(function() was = obj[field] end)
            local ok2 = pcall(function() obj[field] = value end)
            log(string.format("set_field %s.%s: was=%s set=%s ok=%s",
                cls_name, field, tostring(was), tostring(value), tostring(ok2)))
            return ok2
        end
    end
    return false
end

-- ----- Unlock all build items -------------------------------------------

refresh_build_items = function()
    local ok, all = pcall(FindAllOf, "R5BuildingItem")
    if ok and type(all) == "table" then
        cached_build_items = all
    else
        cached_build_items = nil
    end
    return cached_build_items
end

W.apply_unlock_items = function(state, tick_count)
    if (not cached_build_items) or (tick_count and (tick_count % UNLOCK_REFRESH_INTERVAL) == 0) then
        refresh_build_items()
    end
    if not cached_build_items then return false end
    local n = 0
    for i = 1, #cached_build_items do
        local bi = cached_build_items[i]
        if A.is_valid(bi) then
            pcall(function()
                if bi.DrawData ~= nil then
                    bi.DrawData.bLockedByRecipe = not state
                end
            end)
            n = n + 1
        end
    end
    return n > 0
end

-- ----- Infinite inventory (best-effort) ---------------------------------

-- These are educated guesses at Windrose class names. The "Dump inventory"
-- action button in the GUI logs what we actually found so this list can
-- be refined over time.

W.INVENTORY_CLASS_CANDIDATES = {
    "R5ResourceInventoryComponent",
    "R5PlayerInventoryComponent",
    "R5InventoryComponent",
    "R5ShipInventoryComponent",
    "R5BuildingInventoryComponent",
    "R5StorageInventoryComponent",
    "R5ResourceInventory",
    "R5PlayerInventory",
    "R5InventoryActor",
    "R5InventoryStorage",
    "R5Inventory",
}

W.NUMERIC_FIELD_CANDIDATES = {
    "Quantity", "Amount", "Count", "Stack", "StackSize",
    "CurrentQuantity", "CurrentAmount", "CurrentCount",
    "Capacity",
}

local function find_inventories(tick_count)
    if tick_count and tick_count - last_inventory_search < INVENTORY_SEARCH_INTERVAL
       and cached_inventories ~= nil and #cached_inventories > 0
       and A.is_valid(cached_inventories[1]) then
        return cached_inventories
    end
    last_inventory_search = tick_count or 0
    cached_inventories = {}
    for _, cls in ipairs(W.INVENTORY_CLASS_CANDIDATES) do
        local ok, all = pcall(FindAllOf, cls)
        if ok and type(all) == "table" then
            for i = 1, #all do
                if A.is_valid(all[i]) then
                    table.insert(cached_inventories, all[i])
                end
            end
        end
    end
    return cached_inventories
end

W.apply_infinite_inventory = function(state, tick_count)
    if not state then return false end
    local invs = find_inventories(tick_count)
    if not invs or #invs == 0 then return false end
    local touched = 0
    for i = 1, #invs do
        local inv = invs[i]
        if A.is_valid(inv) then
            for _, field in ipairs(W.NUMERIC_FIELD_CANDIDATES) do
                pcall(function()
                    local cur = inv[field]
                    if type(cur) == "number" and cur < INVENTORY_TOPUP_THRESHOLD then
                        inv[field] = INVENTORY_TOPUP_TARGET
                        touched = touched + 1
                    end
                end)
            end
        end
    end
    return touched > 0
end

W.dump_inventory = function()
    log("=== dump_inventory: probing classes ===")
    local total = 0
    for _, cls in ipairs(W.INVENTORY_CLASS_CANDIDATES) do
        local ok, all = pcall(FindAllOf, cls)
        local n = (ok and type(all) == "table") and #all or 0
        if n > 0 then
            log(string.format("  found %d instances of %s", n, cls))
            total = total + n
            for i = 1, math.min(n, 3) do
                local obj = all[i]
                if A.is_valid(obj) then
                    local class_name = "?"
                    pcall(function() class_name = obj:GetClass():GetFullName() end)
                    log(string.format("    [%d] class=%s", i, tostring(class_name)))
                    for _, field in ipairs(W.NUMERIC_FIELD_CANDIDATES) do
                        pcall(function()
                            local v = obj[field]
                            if v ~= nil then
                                log(string.format("        .%s = %s (%s)", field, tostring(v), type(v)))
                            end
                        end)
                    end
                end
            end
        end
    end
    log(string.format("=== dump_inventory: %d total candidates ===", total))
    return total
end

W.rescan = function()
    cached_build_settings = nil
    cached_build_items    = nil
    cached_inventories    = nil
    last_inventory_search = -999
end

return W
