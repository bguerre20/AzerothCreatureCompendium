--[[
    Azeroth Creature Compendium - CombatLog.lua
    Taint-free discovery engine using public unit & combat events.
    (Completely avoids restricted COMBAT_LOG_EVENT_UNFILTERED).
]]

local ADDON_NAME, addon = ...

-- Runtime caches
addon.lastPlayerSpell = nil
addon.unitMetaCache = addon.unitMetaCache or {}

-- Mechanic patterns for immunity detection
local MECHANIC_PATTERNS = {
    { key = "TAUNT",     name = "Taunt",          patterns = { "taunt", "growl", "torment", "mocking blow", "righteous defense", "challenging shout", "challenging roar", "dark command", "death grip" } },
    { key = "BLEED",     name = "Bleed",          patterns = { "rend", "deep wounds", "rupture", "garrote", "rake", "rip", "lacerate" } },
    { key = "STUN",      name = "Stun",           patterns = { "hammer of justice", "cheap shot", "kidney shot", "bash", "concussion blow", "charge stun", "intercept stun", "impact" } },
    { key = "POLYMORPH", name = "Polymorph",      patterns = { "polymorph", "sap", "gouge", "blind", "hibernate", "banish", "repentance", "freezing trap" } },
    { key = "FEAR",      name = "Fear",           patterns = { "fear", "psychic scream", "intimidating shout", "howl of terror", "scare beast", "seduction" } },
    { key = "SNARE",     name = "Snare/Root",     patterns = { "frost nova", "entangling roots", "hamstring", "crippling poison", "wing clip", "chains of ice", "piercing howl" } },
    { key = "SILENCE",   name = "Silence",        patterns = { "silence", "shield bash - silenced", "strangulate", "gag order" } },
    { key = "SLEEP",     name = "Sleep",          patterns = { "sleep", "wyvern sting" } },
    { key = "POISON",    name = "Poison",         patterns = { "deadly poison", "instant poison", "wound poison", "mind-numbing poison", "serpent sting" } },
}

-- Known school names in lowercase
local SCHOOL_NAMES = {
    fire     = { key = "FIRE",    name = "Fire",    school = 4 },
    frost    = { key = "FROST",   name = "Frost",   school = 16 },
    nature   = { key = "NATURE",  name = "Nature",  school = 8 },
    shadow   = { key = "SHADOW",  name = "Shadow",  school = 32 },
    arcane   = { key = "ARCANE",  name = "Arcane",  school = 64 },
    holy     = { key = "HOLY",    name = "Holy",    school = 2 },
    physical = { key = "PHYSICAL",name = "Physical",school = 1 },
}

local function MatchMechanicByName(spellName)
    if not spellName then return nil, nil end
    local lower = string.lower(spellName)

    for _, entry in ipairs(MECHANIC_PATTERNS) do
        for _, pat in ipairs(entry.patterns) do
            if string.find(lower, pat, 1, true) then
                return entry.key, entry.name
            end
        end
    end
    return nil, nil
end

local function InferSpellSchool(spellName)
    if not spellName then return 1, "PHYSICAL", "Physical" end
    local lower = string.lower(spellName)

    if string.find(lower, "fire") or string.find(lower, "pyro") or string.find(lower, "flame") or string.find(lower, "scorch") or string.find(lower, "immolate") then
        return 4, "FIRE", "Fire"
    elseif string.find(lower, "frost") or string.find(lower, "blizzard") or string.find(lower, "ice") or string.find(lower, "cold") then
        return 16, "FROST", "Frost"
    elseif string.find(lower, "nature") or string.find(lower, "lightning") or string.find(lower, "earth") or string.find(lower, "poison") or string.find(lower, "wrath") then
        return 8, "NATURE", "Nature"
    elseif string.find(lower, "shadow") or string.find(lower, "curse") or string.find(lower, "drain") or string.find(lower, "corruption") or string.find(lower, "death") or string.find(lower, "pain") then
        return 32, "SHADOW", "Shadow"
    elseif string.find(lower, "arcane") or string.find(lower, "moonfire") or string.find(lower, "starfire") then
        return 64, "ARCANE", "Arcane"
    elseif string.find(lower, "holy") or string.find(lower, "smite") or string.find(lower, "heal") or string.find(lower, "light") or string.find(lower, "judgment") or string.find(lower, "judgement") then
        return 2, "HOLY", "Holy"
    end

    return 1, "PHYSICAL", "Physical"
end

-- Create public, unrestricted Event Frame
local combatFrame = CreateFrame("Frame", "AzerothCompendiumCombatListenerFrame")
combatFrame:RegisterEvent("UNIT_SPELLCAST_START")
combatFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
combatFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
combatFrame:RegisterEvent("UNIT_SPELLCAST_SENT")
combatFrame:RegisterEvent("UI_ERROR_MESSAGE")
combatFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

combatFrame:SetScript("OnEvent", function(self, event, ...)
    if not addon.db or not addon.db.settings or not addon.db.settings.trackCombat then
        return
    end

    ---------------------------------------------------------------------------
    -- 1. Unit Spellcast Tracking (Enemy Casts)
    ---------------------------------------------------------------------------
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit, castGUID, spellID = ...
        if unit and UnitExists(unit) and UnitCanAttack("player", unit) then
            local guid = UnitGUID(unit)
            local npcID = addon:GetNPCIDFromGUID(guid)
            if npcID and spellID then
                local mobName = UnitName(unit) or ("Creature " .. npcID)
                local mapID, zoneName, _ = addon:GetPlayerLocation()

                local spellName, spellTexture = nil, nil
                if C_Spell and C_Spell.GetSpellInfo then
                    local info = C_Spell.GetSpellInfo(spellID)
                    if info then
                        spellName = info.name
                        spellTexture = info.iconID
                    end
                elseif GetSpellInfo then
                    spellName, _, spellTexture = GetSpellInfo(spellID)
                end

                if spellName then
                    local schoolNum = InferSpellSchool(spellName)
                    addon:RecordSpellCast(mapID, zoneName, npcID, mobName, spellID, spellName, schoolNum, spellTexture)
                end
            end
        end

    ---------------------------------------------------------------------------
    -- 2. Player Spell Sent (To associate with "Target is immune" errors)
    ---------------------------------------------------------------------------
    elseif event == "UNIT_SPELLCAST_SENT" then
        local unit, target, castGUID, spellID = ...
        if unit == "player" then
            local spellName = nil
            if C_Spell and C_Spell.GetSpellInfo then
                local info = C_Spell.GetSpellInfo(spellID)
                if info then spellName = info.name end
            elseif GetSpellInfo then
                spellName = GetSpellInfo(spellID)
            end

            addon.lastPlayerSpell = {
                id = spellID,
                name = spellName or "Spell",
                time = GetTime()
            }
        end

    ---------------------------------------------------------------------------
    -- 3. Immunity Detection via Game Error Message
    ---------------------------------------------------------------------------
    elseif event == "UI_ERROR_MESSAGE" then
        local errorType, msg = ...
        local lowerMsg = string.lower(msg or "")

        if string.find(lowerMsg, "immune", 1, true) then
            if UnitExists("target") and UnitCanAttack("player", "target") then
                local guid = UnitGUID("target")
                local npcID = addon:GetNPCIDFromGUID(guid)
                if npcID then
                    local mobName = UnitName("target") or ("Creature " .. npcID)
                    local mapID, zoneName, _ = addon:GetPlayerLocation()

                    -- Check what spell player recently cast
                    local last = addon.lastPlayerSpell
                    if last and (GetTime() - last.time) < 3.0 then
                        -- Check mechanic immunity
                        local mKey, mName = MatchMechanicByName(last.name)
                        if mKey then
                            addon:RecordImmunity(mapID, zoneName, npcID, mobName, mKey, "MECHANIC", mName)
                        end

                        -- Check school immunity
                        local sNum, sKey, sName = InferSpellSchool(last.name)
                        if sKey and sKey ~= "PHYSICAL" then
                            addon:RecordImmunity(mapID, zoneName, npcID, mobName, sKey, "SCHOOL", sName, sNum)
                        end
                    end
                end
            end
        end

    ---------------------------------------------------------------------------
    -- 4. Target Death & Kill Tracking
    ---------------------------------------------------------------------------
    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitExists("target") and UnitIsDead("target") and UnitCanAttack("player", "target") then
            local guid = UnitGUID("target")
            local npcID = addon:GetNPCIDFromGUID(guid)
            if npcID and not addon.lootedCorpseGUIDs[guid] then
                local mobName = UnitName("target") or ("Creature " .. npcID)
                local mapID, zoneName, coords = addon:GetPlayerLocation()
                addon:RecordKill(mapID, zoneName, npcID, mobName, coords)
            end
        end
    end
end)
