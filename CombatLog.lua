--[[
    Azeroth Creature Compendium - CombatLog.lua
    Taint-free discovery engine using public unit & combat events.
    (Completely avoids restricted COMBAT_LOG_EVENT_UNFILTERED).
]]

local _, addon = ...

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


local function MatchMechanicByName(spellName)
    spellName = addon:SafeString(spellName, nil)
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
addon.MatchMechanicByName = MatchMechanicByName

local function InferSpellSchool(spellName)
    spellName = addon:SafeString(spellName, nil)
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
addon.InferSpellSchool = InferSpellSchool

-- Process deferred spell name resolutions once out of combat
function addon:ProcessPendingSpellResolutions()
    if not self.pendingSpellResolutions or not next(self.pendingSpellResolutions) then
        return
    end

    for spellID in pairs(self.pendingSpellResolutions) do
        local resolvedName, resolvedIcon = self:ResolveSpellInfo(spellID)
        if resolvedName and not string.find(resolvedName, "^Spell %d+") then
            local schoolNum = InferSpellSchool(resolvedName)
            if self.db and self.db.zones then
                for _, zone in pairs(self.db.zones) do
                    if zone.mobs then
                        for _, mob in pairs(zone.mobs) do
                            if mob.combat and mob.combat.spells and mob.combat.spells[spellID] then
                                local sp = mob.combat.spells[spellID]
                                sp.name = resolvedName
                                if schoolNum and schoolNum > 1 then
                                    sp.school = schoolNum
                                end
                                if resolvedIcon then
                                    sp.icon = resolvedIcon
                                end
                            end
                        end
                    end
                end
            end
            self.pendingSpellResolutions[spellID] = nil
        end
    end
end

-- Create public, unrestricted Event Frame
local combatFrame = CreateFrame("Frame", "AzerothCompendiumCombatListenerFrame")
combatFrame:RegisterEvent("UNIT_SPELLCAST_START")
combatFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
combatFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
combatFrame:RegisterEvent("UNIT_SPELLCAST_SENT")
combatFrame:RegisterEvent("UI_ERROR_MESSAGE")
combatFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

combatFrame:SetScript("OnEvent", function(self, event, ...)
    if not addon.db or not addon.db.settings or not addon.db.settings.trackCombat then
        return
    end

    ---------------------------------------------------------------------------
    -- 1. Unit Spellcast Tracking (Enemy Casts)
    ---------------------------------------------------------------------------
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit, _, spellID = ...
        if unit and UnitExists(unit) and UnitCanAttack("player", unit) then
            local guid = UnitGUID(unit)
            local npcID = addon:GetNPCIDFromGUID(guid)
            spellID = tonumber(spellID)
            if npcID and spellID then
                local mobName = addon:SafeString(UnitName(unit), "Creature " .. npcID)
                local mapID, zoneName, _ = addon:GetPlayerLocation()

                local spellName, spellTexture = addon:ResolveSpellInfo(spellID)
                local schoolNum = 1
                if spellName then
                    schoolNum = InferSpellSchool(spellName)
                else
                    -- Spell name is secret/restricted right now during combat; defer resolution until out of combat
                    addon.pendingSpellResolutions = addon.pendingSpellResolutions or {}
                    addon.pendingSpellResolutions[spellID] = true
                end

                addon:RecordSpellCast(mapID, zoneName, npcID, mobName, spellID, spellName, schoolNum, spellTexture)
            end
        end

    ---------------------------------------------------------------------------
    -- 2. Player Spell Sent (To associate with "Target is immune" errors)
    ---------------------------------------------------------------------------
    elseif event == "UNIT_SPELLCAST_SENT" then
        local unit, _, _, spellID = ...
        if unit == "player" and spellID then
            local spellName = addon:ResolveSpellInfo(spellID)

            addon.lastPlayerSpell = {
                id = spellID,
                name = spellName or ("Spell " .. spellID),
                time = GetTime()
            }
        end

    ---------------------------------------------------------------------------
    -- 3. Immunity Detection via Game Error Message
    ---------------------------------------------------------------------------
    elseif event == "UI_ERROR_MESSAGE" then
        local _, msg = ...
        local safeMsg = addon:SafeString(msg, "")
        local lowerMsg = string.lower(safeMsg)

        if string.find(lowerMsg, "immune", 1, true) then
            if UnitExists("target") and UnitCanAttack("player", "target") then
                local guid = UnitGUID("target")
                local npcID = addon:GetNPCIDFromGUID(guid)
                if npcID then
                    local mobName = addon:SafeString(UnitName("target"), "Creature " .. npcID)
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
            if npcID and not addon.killedCorpseGUIDs[guid] then
                local mobName = addon:SafeString(UnitName("target"), "Creature " .. npcID)
                local mapID, zoneName, coords = addon:GetPlayerLocation()
                addon:MarkCorpseKilled(guid)
                addon:RecordKill(mapID, zoneName, npcID, mobName, coords)
            end
        end

    ---------------------------------------------------------------------------
    -- 5. Out of Combat: Resolve Deferred Spells
    ---------------------------------------------------------------------------
    elseif event == "PLAYER_REGEN_ENABLED" then
        addon:ProcessPendingSpellResolutions()
    end
end)
