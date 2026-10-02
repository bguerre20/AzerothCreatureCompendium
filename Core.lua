--[[
    Azeroth Creature Compendium - Core.lua
    Event management, unit tracking (level, classification, creature family),
    loot detection, and recording pipeline.
]]

local ADDON_NAME, addon = ...

-- Runtime caches
addon.npcNameCache = {}
addon.lootedCorpseGUIDs = {}
addon.corpseHistoryList = {}
addon.harvestedCorpseGUIDs = {}
addon.harvestHistoryList = {}
addon.killedCorpseGUIDs = {}
addon.killHistoryList = {}
addon.activeGatherCast = nil
addon.recentProfessionHarvest = nil
addon.isProcessingLoot = false

-- Known gathering spell IDs (Classic / Retail)
addon.GATHER_SPELL_IDS = {
    -- Skinning
    [8613]  = "Skinning", -- Apprentice
    [8617]  = "Skinning", -- Journeyman
    [8618]  = "Skinning", -- Expert
    [10768] = "Skinning", -- Artisan
    [32678] = "Skinning", -- Master
    [50305] = "Skinning", -- Grand Master

    -- Mining
    [2575]  = "Mining",   -- Apprentice
    [2576]  = "Mining",   -- Journeyman
    [3564]  = "Mining",   -- Expert
    [10248] = "Mining",   -- Artisan
    [29354] = "Mining",   -- Master
    [50310] = "Mining",   -- Grand Master

    -- Herbalism / Herb Gathering
    [2366]  = "Herbalism", -- Apprentice Herb Gathering
    [2368]  = "Herbalism", -- Journeyman
    [3570]  = "Herbalism", -- Expert
    [11993] = "Herbalism", -- Artisan
    [28695] = "Herbalism", -- Master
    [50300] = "Herbalism", -- Grand Master

    -- Engineering / Salvage
    [30427] = "Engineering", -- Extract Gas
    [20222] = "Engineering",
}

-- Safe spell name and texture resolver supporting modern C_Spell and classic GetSpellInfo
-- Returns nil, nil if spell information is restricted by Blizzard's secret value system
function addon:ResolveSpellInfo(spellID)
    if not spellID then return nil, nil end
    local spellName, spellTexture = nil, nil
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and info then
            spellName = self:SafeString(info.name, nil)
            spellTexture = info.iconID
        end
    end
    if not spellName and C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and name then
            spellName = self:SafeString(name, nil)
        end
    end
    if not spellName and GetSpellInfo then
        local ok, name, _, icon = pcall(GetSpellInfo, spellID)
        if ok then
            spellName = self:SafeString(name, nil)
            spellTexture = spellTexture or icon
        end
    end
    return spellName, spellTexture
end

-- Safe spell name resolver
function addon:GetSpellName(spellID)
    local name, _ = self:ResolveSpellInfo(spellID)
    return name
end

-- Identify gathering profession by spell ID or localized name
function addon:IdentifyGatheringSpell(spellID)
    if not spellID then return nil end

    if self.GATHER_SPELL_IDS[spellID] then
        return self.GATHER_SPELL_IDS[spellID]
    end

    local name = self:GetSpellName(spellID)
    if not name or name == "" then return nil end
    local lower = string.lower(name)

    if not self.localizedGatherNames then
        self.localizedGatherNames = {}
        local skin = self:GetSpellName(8613)
        if skin then self.localizedGatherNames[string.lower(skin)] = "Skinning" end
        local mine = self:GetSpellName(2575)
        if mine then self.localizedGatherNames[string.lower(mine)] = "Mining" end
        local herb = self:GetSpellName(2366)
        if herb then self.localizedGatherNames[string.lower(herb)] = "Herbalism" end
    end

    if self.localizedGatherNames[lower] then
        return self.localizedGatherNames[lower]
    end

    if string.find(lower, "skin") or string.find(lower, "kürschner") or string.find(lower, "dépeç") or string.find(lower, "desoll") or string.find(lower, "снятие шкур") or string.find(lower, "剥皮") then
        return "Skinning"
    elseif string.find(lower, "mining") or string.find(lower, "mine") or string.find(lower, "bergbau") or string.find(lower, "minage") or string.find(lower, "горное дело") or string.find(lower, "采矿") then
        return "Mining"
    elseif string.find(lower, "herb") or string.find(lower, "kraut") or string.find(lower, "herbo") or string.find(lower, "травничество") or string.find(lower, "草药") then
        return "Herbalism"
    elseif string.find(lower, "engineer") or string.find(lower, "salvage") or string.find(lower, "disassemble") or string.find(lower, "ingenieur") or string.find(lower, "ingénierie") or string.find(lower, "инженер") or string.find(lower, "工程") then
        return "Engineering"
    end

    return nil
end

-- Coordinate and Zone retrieval helper
function addon:GetPlayerLocation()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        return 0, "Unknown Zone", nil
    end

    local mapInfo = C_Map.GetMapInfo(mapID)
    local zoneName = (mapInfo and mapInfo.name) or "Unknown Zone"

    local coords = nil
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if pos and pos.x and pos.y and (pos.x ~= 0 or pos.y ~= 0) then
        coords = {
            x = math.floor(pos.x * 1000 + 0.5) / 10,
            y = math.floor(pos.y * 1000 + 0.5) / 10
        }
    end

    return mapID, zoneName, coords
end

-- NPC ID extraction from GUID
-- Format: Creature-0-xxxx-xxxx-xxxx-NPCID-SPAWNUID
function addon:GetNPCIDFromGUID(guid)
    if not guid or type(guid) ~= "string" then return nil end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(npcID)
    end
    return nil
end

-- Cache creature name and inspect metadata from a unit
function addon:CacheUnit(unit)
    if not UnitExists(unit) then return end
    local guid = UnitGUID(unit)
    if not guid then return end

    local npcID = self:GetNPCIDFromGUID(guid)
    if not npcID then return end

    local name = self:SafeString(UnitName(unit), nil)
    if name and name ~= "" and name ~= "Unknown" then
        self.npcNameCache[npcID] = name
    end

    -- Store creature metadata in runtime cache
    local classification = self:SafeString(UnitClassification(unit), "normal")
    local creatureType = self:SafeString(UnitCreatureType(unit), nil)
    local level = UnitLevel(unit)

    addon.unitMetaCache[npcID] = {
        name = name,
        level = level,
        classification = classification,
        creatureType = creatureType
    }

    -- Update database if mob exists, OR if it is a hostile/neutral rare spawn (so sightings are recorded!)
    -- This prevents friendly NPCs, vendors, and questgivers from ever being added.
    local mapID, zoneName, coords = self:GetPlayerLocation()
    local isRare = (classification == "rare" or classification == "rareelite")
    local isNotFriend = not UnitIsFriend("player", unit)
    local mobExists = self.db and self.db.zones and self.db.zones[mapID] and self.db.zones[mapID].mobs and self.db.zones[mapID].mobs[npcID]

    if mobExists or (isRare and isNotFriend) then
        self:UpdateUnitMeta(npcID, mapID, zoneName, name, level, classification, creatureType, coords)
    end
end

-- Parse textual money into copper
function addon:ParseMoneyString(str)
    if not str or type(str) ~= "string" then return 0 end
    local gold = tonumber(str:match("(%d+)%s*[Gg]old") or str:match("(%d+)%s*[Gg]") or 0) or 0
    local silver = tonumber(str:match("(%d+)%s*[Ss]ilver") or str:match("(%d+)%s*[Ss]") or 0) or 0
    local copper = tonumber(str:match("(%d+)%s*[Cc]opper") or str:match("(%d+)%s*[Cc]") or 0) or 0
    return (gold * 10000) + (silver * 100) + copper
end

-- Mark corpse as looted to prevent double-counting if window is re-opened
function addon:MarkCorpseLooted(guid)
    if not guid then return end
    if self.lootedCorpseGUIDs[guid] then return end

    self.lootedCorpseGUIDs[guid] = true
    table.insert(self.corpseHistoryList, guid)

    -- Cap history to prevent memory growth over long sessions
    if #self.corpseHistoryList > 400 then
        local oldest = table.remove(self.corpseHistoryList, 1)
        if oldest then
            self.lootedCorpseGUIDs[oldest] = nil
        end
    end
end

function addon:MarkCorpseKilled(guid)
    if not guid then return end
    if self.killedCorpseGUIDs[guid] then return end

    self.killedCorpseGUIDs[guid] = true
    table.insert(self.killHistoryList, guid)

    if #self.killHistoryList > 400 then
        local oldest = table.remove(self.killHistoryList, 1)
        if oldest then
            self.killedCorpseGUIDs[oldest] = nil
        end
    end
end

-- Mark corpse as harvested to prevent double-counting if harvest window is re-opened
function addon:MarkCorpseHarvested(guid)
    if not guid then return end
    if self.harvestedCorpseGUIDs[guid] then return end

    self.harvestedCorpseGUIDs[guid] = true
    table.insert(self.harvestHistoryList, guid)

    -- Cap history to prevent memory growth over long sessions
    if #self.harvestHistoryList > 400 then
        local oldest = table.remove(self.harvestHistoryList, 1)
        if oldest then
            self.harvestedCorpseGUIDs[oldest] = nil
        end
    end
end

-- Process loot window contents
function addon:ProcessLoot()
    local numItems = GetNumLootItems()

    -- Check if this loot opening is the result of a profession gathering cast
    local isProfessionHarvest = false
    local harvestProf = nil
    if addon.recentProfessionHarvest and (GetTime() - addon.recentProfessionHarvest.time) < 3.0 then
        isProfessionHarvest = true
        harvestProf = addon.recentProfessionHarvest.profession
    elseif addon.activeGatherCast and (GetTime() - addon.activeGatherCast.time) < 4.0 then
        isProfessionHarvest = true
        harvestProf = addon.activeGatherCast.profession
    end

    -- 1. Identify source creature GUID
    local sourceGUID = nil

    if GetLootSourceInfo and numItems > 0 then
        for i = 1, numItems do
            local guid = GetLootSourceInfo(i)
            if guid and self:GetNPCIDFromGUID(guid) then
                sourceGUID = guid
                break
            end
        end
    end

    if not sourceGUID and isProfessionHarvest and addon.recentProfessionHarvest and addon.recentProfessionHarvest.targetGUID then
        if self:GetNPCIDFromGUID(addon.recentProfessionHarvest.targetGUID) then
            sourceGUID = addon.recentProfessionHarvest.targetGUID
        end
    end

    if not sourceGUID and UnitExists("target") and UnitIsDead("target") then
        local targetGUID = UnitGUID("target")
        if self:GetNPCIDFromGUID(targetGUID) then
            sourceGUID = targetGUID
        end
    end

    if not sourceGUID and UnitExists("mouseover") and UnitIsDead("mouseover") then
        local moGUID = UnitGUID("mouseover")
        if self:GetNPCIDFromGUID(moGUID) then
            sourceGUID = moGUID
        end
    end

    if not sourceGUID then return end

    local npcID = self:GetNPCIDFromGUID(sourceGUID)
    if not npcID then return end

    -- Check duplicate loot window opens
    if isProfessionHarvest then
        if self.harvestedCorpseGUIDs[sourceGUID] then
            return
        end
        self:MarkCorpseHarvested(sourceGUID)
    else
        if self.lootedCorpseGUIDs[sourceGUID] then
            return
        end
        self:MarkCorpseLooted(sourceGUID)
    end

    -- 2. Resolve mob display name
    local mobName = nil
    if UnitExists("target") and UnitGUID("target") == sourceGUID then
        mobName = self:SafeString(UnitName("target"), nil)
    elseif UnitExists("mouseover") and UnitGUID("mouseover") == sourceGUID then
        mobName = self:SafeString(UnitName("mouseover"), nil)
    end

    if not mobName or mobName == "" then
        mobName = self:SafeString(self.npcNameCache[npcID], nil)
    end

    if not mobName or mobName == "" then
        mobName = "Creature " .. npcID
    else
        self.npcNameCache[npcID] = mobName
    end

    -- 3. Parse items and coins
    local itemsLooted = {}
    local moneyCopper = 0

    local LOOT_MONEY = LOOT_SLOT_MONEY or 2
    local LOOT_ITEM = LOOT_SLOT_ITEM or 1

    for slot = 1, numItems do
        local slotType = GetLootSlotType(slot)

        if slotType == LOOT_MONEY then
            local _, name, quantity = GetLootSlotInfo(slot)
            local parsed = self:ParseMoneyString(name)
            if parsed > 0 then
                moneyCopper = moneyCopper + parsed
            elseif quantity and quantity > 1 then
                moneyCopper = moneyCopper + quantity
            end
        elseif slotType == LOOT_ITEM or slotType == 0 then
            local icon, name, quantity, _, quality = GetLootSlotInfo(slot)
            local itemLink = GetLootSlotLink(slot)
            local itemID = nil

            if itemLink then
                itemID = tonumber(itemLink:match("item:(%d+)"))
            end

            if itemID then
                if not itemsLooted[itemID] then
                    itemsLooted[itemID] = {
                        name = name or ("Item " .. itemID),
                        quality = quality or 1,
                        icon = icon,
                        itemLink = itemLink,
                        quantity = 0
                    }
                end
                itemsLooted[itemID].quantity = itemsLooted[itemID].quantity + (quantity or 1)
            end
        end
    end

    -- 4. Get player location and record to DB
    local mapID, zoneName, coords = self:GetPlayerLocation()

    if isProfessionHarvest then
        self:RecordProfessionLoot(mapID, zoneName, npcID, mobName, harvestProf or "Skinning", itemsLooted, coords)
        addon.recentProfessionHarvest = nil
        addon.activeGatherCast = nil
    else
        self:RecordLoot(mapID, zoneName, npcID, mobName, itemsLooted, moneyCopper, coords)
        if not self.killedCorpseGUIDs[sourceGUID] then
            self:MarkCorpseKilled(sourceGUID)
            self:RecordKill(mapID, zoneName, npcID, mobName, coords)
        end

        local meta = self.unitMetaCache[npcID]
        if meta then
            self:UpdateUnitMeta(npcID, mapID, zoneName, mobName, meta.level, meta.classification, meta.creatureType, coords)
        end

        self.lastLootedMob = {
            mapID = mapID,
            npcID = npcID,
            time = GetTime(),
            moneyRecorded = (moneyCopper > 0)
        }
    end
end

-- Main Event Frame
local eventFrame = CreateFrame("Frame", "AzerothCompendiumEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("LOOT_READY")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
eventFrame:RegisterEvent("CHAT_MSG_MONEY")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")

local isLoaded = false
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if (name == ADDON_NAME or name == "AzerothCreatureCompendium" or name == "BgLootLogger") and not isLoaded then
            isLoaded = true
            addon:InitDatabase()
            addon:Print("Loaded. Type |cffffd100/acc|r for Compendium window or |cffffd100/acc options|r for settings.")
        end
    elseif event == "UNIT_SPELLCAST_START" then
        local unit, _, spellID = ...
        if unit == "player" and spellID then
            local prof = addon:IdentifyGatheringSpell(spellID)
            if prof then
                addon.activeGatherCast = {
                    profession = prof,
                    spellID = spellID,
                    time = GetTime(),
                    targetGUID = UnitGUID("target") or UnitGUID("mouseover")
                }
            end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" and spellID then
            local prof = addon:IdentifyGatheringSpell(spellID) or (addon.activeGatherCast and addon.activeGatherCast.profession)
            if prof then
                local targetGUID = (addon.activeGatherCast and addon.activeGatherCast.targetGUID) or UnitGUID("target") or UnitGUID("mouseover")
                addon.recentProfessionHarvest = {
                    profession = prof,
                    spellID = spellID,
                    time = GetTime(),
                    targetGUID = targetGUID,
                }
                addon.activeGatherCast = nil
            end
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        local unit = ...
        if unit == "player" then
            addon.activeGatherCast = nil
        end
    elseif event == "CHAT_MSG_MONEY" then
        local msg = ...
        if msg and addon.lastLootedMob and (GetTime() - addon.lastLootedMob.time) < 2.5 then
            local copper = addon:ParseMoneyString(msg)
            if copper > 0 and not addon.lastLootedMob.moneyRecorded then
                addon.lastLootedMob.moneyRecorded = true
                local zone = addon.db.zones[addon.lastLootedMob.mapID]
                if zone and zone.mobs and zone.mobs[addon.lastLootedMob.npcID] then
                    local mob = zone.mobs[addon.lastLootedMob.npcID]
                    local loot = mob.loot
                    if loot then
                        loot.totalMoney = (loot.totalMoney or 0) + copper
                        loot.avgMoney = math.floor(loot.totalMoney / math.max(1, loot.totalLoots or 1))
                        mob.avgMoney = loot.avgMoney
                    end
                end
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        addon:CacheUnit("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        addon:CacheUnit("mouseover")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        if unit then
            addon:CacheUnit(unit)
        end
    elseif event == "LOOT_OPENED" or event == "LOOT_READY" then
        if not addon.isProcessingLoot then
            addon.isProcessingLoot = true
            addon:ProcessLoot()
        end
    elseif event == "LOOT_CLOSED" then
        addon.isProcessingLoot = false
    end
end)
