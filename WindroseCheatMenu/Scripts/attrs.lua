-- Generic attribute read/write helpers.
-- Windrose gameplay attributes can be either:
--   - a numeric field on a container (e.g. attr_set.Health = 100), or
--   - a wrapper object with BaseValue and CurrentValue properties.
-- These helpers handle both cases plus snapshot/restore for per-flag toggling.

local A = {}

-- ----- Safe field IO ----------------------------------------------------

A.is_valid = function(obj)
    if obj == nil then return false end
    local ok, v = pcall(function() return obj.IsValid and obj:IsValid() end)
    return ok and v == true
end

A.get_field = function(obj, name)
    if obj == nil then return nil end
    local ok, v = pcall(function() return obj[name] end)
    if not ok then return nil end
    return v
end

A.set_field = function(obj, name, value)
    if obj == nil then return false end
    return (pcall(function() obj[name] = value end))
end

A.call_bool = function(obj, name)
    if obj == nil then return false end
    local ok, v = pcall(function()
        local fn = obj[name]
        return type(fn) == "function" and fn(obj)
    end)
    return ok and v == true
end

-- ----- Per-container per-flag snapshot store ----------------------------
-- snapshots[container_key] = { [flag_name] = { [attr_name] = {direct=bool, value=any, base=num, current=num} } }
-- container_key is tostring(container) — unique enough per object across a session.

local snapshots = {}

local function snap_for(container, flag)
    local key = tostring(container)
    snapshots[key] = snapshots[key] or { _container = container, flags = {} }
    snapshots[key].flags[flag] = snapshots[key].flags[flag] or {}
    return snapshots[key].flags[flag]
end

A.snapshot_attr = function(container, flag, attr_name)
    local snap = snap_for(container, flag)
    if snap[attr_name] ~= nil then return end -- already captured

    local attr = A.get_field(container, attr_name)
    if attr == nil then return end

    if type(attr) ~= "table" and type(attr) ~= "userdata" then
        snap[attr_name] = { direct = true, value = attr }
        return
    end

    snap[attr_name] = {
        direct  = false,
        base    = A.get_field(attr, "BaseValue"),
        current = A.get_field(attr, "CurrentValue"),
    }
end

A.write_attr = function(container, flag, attr_name, value)
    if not A.is_valid(container) then return false end
    A.snapshot_attr(container, flag, attr_name)
    local attr = A.get_field(container, attr_name)
    if attr == nil then return false end

    local t = type(attr)
    if t == "table" or t == "userdata" then
        pcall(function() attr.BaseValue    = value end)
        pcall(function() attr.CurrentValue = value end)
    else
        A.set_field(container, attr_name, value)
    end
    return true
end

A.restore_flag = function(flag)
    local restored = 0
    for _, entry in pairs(snapshots) do
        local container = entry._container
        if A.is_valid(container) then
            local flag_snap = entry.flags[flag]
            if flag_snap then
                for attr_name, snap in pairs(flag_snap) do
                    if snap.direct then
                        if A.set_field(container, attr_name, snap.value) then
                            restored = restored + 1
                        end
                    else
                        local attr = A.get_field(container, attr_name)
                        if attr ~= nil then
                            if snap.base    ~= nil then pcall(function() attr.BaseValue    = snap.base    end) end
                            if snap.current ~= nil then pcall(function() attr.CurrentValue = snap.current end) end
                            restored = restored + 1
                        end
                    end
                end
                entry.flags[flag] = nil
            end
        end
    end
    return restored
end

A.restore_all = function()
    local restored = 0
    for flag, _ in pairs({
        unlimited_health=1, unlimited_stamina=1, super_defense=1, super_armor=1, super_damage=1,
        ship_invincible=1, ship_cannon_boost=1,
    }) do
        restored = restored + A.restore_flag(flag)
    end
    return restored
end

A.clear_snapshots = function()
    snapshots = {}
end

A.apply_table = function(container, flag, tbl)
    if not A.is_valid(container) then return 0 end
    local n = 0
    for attr_name, value in pairs(tbl) do
        if A.write_attr(container, flag, attr_name, value) then n = n + 1 end
    end
    return n
end

return A
