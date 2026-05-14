-- Player buffs for Windrose Cheat Menu.
-- Each flag owns a sub-table of attribute writes; per-tick the runtime
-- applies the on-flags and restores the off-flags.

local A = require "attrs"

local P = {}

-- ----- Per-flag attribute targets ---------------------------------------

P.CATEGORIES = {
    unlimited_health = {
        Health    = 5000.0,
        MaxHealth = 5000.0,
    },
    unlimited_stamina = {
        Stamina                    = 5000.0,
        MaxStamina                 = 5000.0,
        StaminaRegenRate           = 5000.0,
        StaminaRegenRateModifier   = 10.0,
        StaminaConsumptionModifier = 0.0,
    },
    super_defense = {
        DefencePower            = 5000.0,
        GlobalDamageTakenResist = 50.0,
        MeleeDamageTakenResist  = 50.0,
        RangeDamageTakenResist  = 50.0,
        CannonDamageTakenResist = 50.0,
    },
    super_armor = {
        Armor                       = 2000.0,
        ArmorModifier               = 10.0,
        FinalDamageReductionByArmor = 2000.0,
    },
    super_damage = {
        -- Attack power
        MainAttackPower                 = 5000.0,
        SecondaryAttackPower            = 5000.0,
        MainScalingDamageModifier       = 50.0,
        SecondaryScalingDamageModifier  = 50.0,
        -- Crit
        CriticalChanceBase              = 50.0,
        CriticalDamageDoneModifier      = 50.0,
        -- Damage done — global + per-type
        GlobalDamageDoneAdded           = 500.0,
        GlobalDamageDoneModifier        = 50.0,
        MeleeDamageDoneAdded            = 500.0,
        MeleeDamageDoneModifier         = 50.0,
        RangeDamageDoneAdded            = 500.0,
        RangeDamageDoneModifier         = 50.0,
        CrudeDamageDoneAdded            = 500.0,
        CrudeDamageDoneModifier         = 50.0,
        SlashDamageDoneAdded            = 500.0,
        SlashDamageDoneModifier         = 50.0,
        PierceDamageDoneAdded           = 500.0,
        PierceDamageDoneModifier        = 50.0,
        BluntDamageDoneAdded            = 500.0,
        BluntDamageDoneModifier         = 50.0,
        -- Armor penetration
        ArmorPenetrationFlatModifier    = 200.0,
        ArmorPenetrationPercentModifier = 1.0,
    },
}

-- ----- Player / attribute-set discovery ----------------------------------

local SCAN_LIMIT      = 32
local PLAYER_CLASSES  = { "R5PlayerCharacter", "R5Character", "R5CharacterBase" }
local ATTR_SET_FIELDS = { "R5AttributeSet", "AttributeSet" }

local function player_score(p)
    if not A.is_valid(p) then return -1 end
    if A.get_field(p, "bSpawnAsBot") == true then return -1 end
    local score = 0
    if A.call_bool(p, "IsPlayerControlled") then score = score + 50 end
    local ctrl = A.get_field(p, "Controller")
    if A.is_valid(ctrl) then
        score = score + 20
        if A.call_bool(ctrl, "IsLocalController")  then score = score + 100 end
        if A.call_bool(ctrl, "IsPlayerController") then score = score + 30  end
    end
    if A.is_valid(A.get_field(p, "PlayerState")) then score = score + 10 end
    return score
end

P.find_player = function()
    if type(FindAllOf) ~= "function" then return nil end
    local best, best_score = nil, -1
    for _, cls in ipairs(PLAYER_CLASSES) do
        local ok, list = pcall(FindAllOf, cls)
        if ok and type(list) == "table" then
            for i, p in ipairs(list) do
                if i > SCAN_LIMIT then break end
                local s = player_score(p)
                if s > best_score then best_score, best = s, p end
            end
        end
    end
    return (best_score >= 0 and A.is_valid(best)) and best or nil
end

P.find_attr_set = function(player)
    if not A.is_valid(player) then return nil end
    for _, name in ipairs(ATTR_SET_FIELDS) do
        local a = A.get_field(player, name)
        if A.is_valid(a) then return a end
    end
    local ps = A.get_field(player, "PlayerState")
    if A.is_valid(ps) then
        for _, name in ipairs(ATTR_SET_FIELDS) do
            local a = A.get_field(ps, name)
            if A.is_valid(a) then return a end
        end
    end
    return nil
end

-- ----- Apply / restore --------------------------------------------------

P.apply = function(attr_set, flag_state)
    if not A.is_valid(attr_set) then return end
    for flag, attrs in pairs(P.CATEGORIES) do
        if flag_state[flag] == true then
            A.apply_table(attr_set, flag, attrs)
        else
            A.restore_flag(flag)
        end
    end
end

return P
