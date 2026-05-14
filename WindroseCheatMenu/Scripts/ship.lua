-- Ship buffs for Windrose Cheat Menu.
-- Two flags: ship_invincible (defensive) and ship_cannon_boost (offensive).

local A = require "attrs"

local S = {}

S.CATEGORIES = {
    ship_invincible = {
        Health                     = 20000.0,
        MaxHealth                  = 20000.0,
        SailHealth                 = 5000.0,
        SailMaxHealth              = 5000.0,
        HullThicknessArmor         = 2000.0,
        HullThicknessArmorModifier = 50.0,
        CannonDamageTakenResist    = 100.0,
    },
    ship_cannon_boost = {
        CannonDamageDoneAdded    = 500.0,
        CannonDamageDoneModifier = 5.0,
    },
}

local SCAN_LIMIT      = 32
local SHIP_CLASSES    = { "R5ShipPawnBase", "R5ShipPhysicalPawn" }
local ATTR_SET_FIELDS = { "R5AttributeSet", "AttributeSet" }
local PLAYER_SHIP_FIELDS = {
    "ShipPawn", "CurrentShip", "ControlledShip",
    "BoardedShip", "ObservedShipPawn", "Ship",
}

local function ship_score(s)
    if not A.is_valid(s) then return -1 end
    if A.get_field(s, "bIsBotControlled") == true then return -1 end
    local score = 0
    local ctrl = A.get_field(s, "Controller")
    if A.is_valid(ctrl) then
        if A.call_bool(ctrl, "IsLocalController") and A.call_bool(ctrl, "IsPlayerController") then
            score = score + 150
        else
            score = score + 10
        end
    end
    if A.is_valid(A.get_field(s, "Owner")) then score = score + 40 end
    return score
end

S.find_ship = function()
    if type(FindAllOf) ~= "function" then return nil end
    local best, best_score = nil, -1
    for _, cls in ipairs(SHIP_CLASSES) do
        local ok, list = pcall(FindAllOf, cls)
        if ok and type(list) == "table" then
            for i, s in ipairs(list) do
                if i > SCAN_LIMIT then break end
                local sc = ship_score(s)
                if sc > best_score then best_score, best = sc, s end
            end
        end
    end
    return (best_score >= 0 and A.is_valid(best)) and best or nil
end

S.find_ship_attr = function(ship)
    if not A.is_valid(ship) then return nil end
    for _, name in ipairs(ATTR_SET_FIELDS) do
        local a = A.get_field(ship, name)
        if A.is_valid(a) then return a end
    end
    return nil
end

S.resolve_ship_from_player = function(player)
    if not A.is_valid(player) then return nil, nil end
    local ctrl = A.get_field(player, "Controller")
    if A.is_valid(ctrl) then
        local pawn = A.get_field(ctrl, "Pawn") or A.get_field(ctrl, "AcknowledgedPawn")
        if A.is_valid(pawn) then
            local a = S.find_ship_attr(pawn)
            if A.is_valid(a) then return pawn, a end
        end
    end
    for _, field in ipairs(PLAYER_SHIP_FIELDS) do
        local candidate = A.get_field(player, field)
        if A.is_valid(candidate) then
            local a = S.find_ship_attr(candidate)
            if A.is_valid(a) then return candidate, a end
        end
    end
    return nil, nil
end

S.apply = function(attr_set, flag_state)
    if not A.is_valid(attr_set) then return end
    for flag, attrs in pairs(S.CATEGORIES) do
        if flag_state[flag] == true then
            A.apply_table(attr_set, flag, attrs)
        else
            A.restore_flag(flag)
        end
    end
end

return S
