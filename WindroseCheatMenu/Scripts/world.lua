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

-- ----- Free build -------------------------------------------------------

local function find_build_settings()
    if A.is_valid(cached_build_settings) then return cached_build_settings end
    cached_build_settings = nil
    local ok, all = pcall(FindAllOf, "R5BuildingSettings")
    if ok and type(all) == "table" then
        for i = 1, #all do
            if A.is_valid(all[i]) then
                cached_build_settings = all[i]
                return cached_build_settings
            end
        end
    end
    return nil
end

W.apply_free_build = function(state)
    local bs = find_build_settings()
    if not bs then return false end
    pcall(function()
        bs.bBuildingResourcesValidation  = not state
        bs.bSkipBuildingCenterValidation = state
    end)
    pcall(function()
        local cdo = StaticFindObject("/Script/R5.Default__R5BuildingSettings")
        if cdo and cdo:IsValid() then
            cdo.bBuildingResourcesValidation  = not state
            cdo.bSkipBuildingCenterValidation = state
        end
    end)
    return true
end

-- ----- Unlock all build items -------------------------------------------

local function refresh_build_items()
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
