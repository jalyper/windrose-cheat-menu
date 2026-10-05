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
-- Discovered via `dump_object R5BuildingItem`: the real gating fields on
-- this class are plain BoolPropertys. Setting bRequiresBuildingCenter=false
-- removes the "must be near a building center" placement check on every
-- buildable, which is the "build anywhere" half of "free build".
--
-- Resource-cost-free is gated separately: BuildingCost is a
-- SoftObjectProperty referencing a sibling data asset, and the UI uses
-- the same reference to decide what to display in the build menu (so
-- nulling it removes items from the menu rather than zeroing cost).
-- True cost-free likely requires hooking the placement-validation
-- UFUNCTION on the player's build component — that's a v0.2 problem.

W.FREE_BUILD_BOOL_FIELDS = {
    -- "Cheats ON" target values. attrs.write_attr snapshots originals so
    -- toggle-off restores cleanly.
    bRequiresBuildingCenter = false,
}

local last_free_build_state = nil  -- nil until first apply; then true/false

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
        local writes = 0
        for i = 1, #cached_build_items do
            local bi = cached_build_items[i]
            if A.is_valid(bi) then
                for field, target in pairs(W.FREE_BUILD_BOOL_FIELDS) do
                    if A.write_attr(bi, "free_build", field, target) then
                        writes = writes + 1
                    end
                end
            end
        end
        log(string.format("free_build ON: wrote %d fields across %d items (build-anywhere mode)",
            writes, #cached_build_items))
    else
        local n = A.restore_flag("free_build")
        log(string.format("free_build OFF: restored %d originals", n))
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

-- Reflective dump: iterate every UE property on the class hierarchy of the
-- first live instance and log name + type + current value. Use this to
-- discover unknown field names (e.g. stat/talent points) on classes whose
-- schema we don't yet have hardcoded in BUILD_FIELD_MAP.
W.dump_fields = function(cls_name)
    local ok, all = pcall(FindAllOf, cls_name)
    if not ok or type(all) ~= "table" or #all == 0 then
        log(string.format("dump_fields '%s': no instances found", cls_name))
        return 0
    end

    local obj
    for i = 1, #all do
        if A.is_valid(all[i]) then obj = all[i]; break end
    end
    if not obj then
        log(string.format("dump_fields '%s': %d instances, none valid", cls_name, #all))
        return 0
    end

    local full_name = "?"
    pcall(function() full_name = tostring(obj:GetFullName()) end)
    log(string.format("dump_fields '%s' (%d instances) — sampling: %s",
        cls_name, #all, full_name))

    local cls
    pcall(function() cls = obj:GetClass() end)
    if not cls then
        log("  GetClass() returned nil — cannot reflect")
        return 0
    end

    local count = 0
    local seen  = {}
    local s     = cls

    local function level_name(node)
        local n
        pcall(function() n = node:GetFName():ToString() end)
        return n or "?"
    end

    while s do
        log(string.format("  -- properties on %s --", level_name(s)))
        local ok_iter = pcall(function()
            s:ForEachProperty(function(prop)
                local name
                pcall(function() name = prop:GetFName():ToString() end)
                if not name or seen[name] then return end
                seen[name] = true
                count = count + 1

                local type_name = "?"
                pcall(function() type_name = prop:GetClass():GetFName():ToString() end)

                local val_str
                local ok_val, val = pcall(function() return obj[name] end)
                if ok_val then
                    if type(val) == "table" or type(val) == "userdata" then
                        val_str = tostring(val) -- usually "<obj address>"
                    else
                        val_str = tostring(val)
                    end
                else
                    val_str = "<read-error>"
                end

                log(string.format("    .%-44s [%s] = %s", name, type_name, val_str))
            end)
        end)
        if not ok_iter then
            log("    (ForEachProperty unsupported on this class — UE4SS build may lack it)")
            break
        end

        local super
        pcall(function() super = s:GetSuperStruct() end)
        if not super or super == s then break end
        s = super
    end

    log(string.format("dump_fields '%s': %d unique properties across hierarchy",
        cls_name, count))
    return count
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
