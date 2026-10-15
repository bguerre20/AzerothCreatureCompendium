--[[
    Azeroth Creature Compendium - Core.lua
    Event management, unit tracking (level, classification, creature family),
    loot detection, and recording pipeline.
]]

local ADDON_NAME, addon = ...

-- Runtime caches
addon.npcNameCache = addon.npcNameCache or {}
addon.nameToNpcIDCache = addon.nameToNpcIDCache or {}
addon.unitTokenCache = {}
addon.lootedCorpseGUIDs = {}
addon.corpseHistoryList = {}
addon.harvestedCorpseGUIDs = {}
addon.harvestHistoryList = {}
addon.killedCorpseGUIDs = {}
addon.killHistoryList = {}
addon.engagedMobGUIDs = {}
addon.engagedHistoryList = {}
addon.spawnKeyCounter = 0
addon.activeGatherCast = nil
addon.recentProfessionHarvest = nil
addon.lastKilledMob = nil
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

-- Deterministic hash for fallback zone IDs when neither uiMapID nor instanceID is available
local function HashZoneNameToID(name)
    if not name or name == "" then return 0 end
    local hash = 0
    for i = 1, #name do
        hash = (hash * 31 + string.byte(name, i)) % 90000
    end
    return 200000 + hash
end

-- Safe spell name and texture resolver supporting modern C_Spell and classic GetSpellInfo
-- Returns nil, nil if spell information is restricted by Blizzard's secret value system
function addon:ResolveSpellInfo(spellID)
    spellID = self:SafeNumber(spellID, nil)
    if not spellID then return nil, nil end
    local spellName, spellTexture = nil, nil
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and info and not self:IsSecretValue(info) then
            spellName = self:SafeString(info.name, nil)
            spellTexture = self:SafeNumber(info.iconID, nil) or self:SafeString(info.iconID, nil)
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
            spellTexture = spellTexture or self:SafeNumber(icon, nil) or self:SafeString(icon, nil)
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
    spellID = self:SafeNumber(spellID, nil)
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

-- Coordinate and Zone retrieval helper (supports open-world UI maps as well as dungeons, raids, and battlegrounds)
function addon:GetPlayerLocation()
    local inInstance, instType = false, "none"
    if IsInInstance then
        local ok, inInst, iType = pcall(IsInInstance)
        if ok then
            inInstance = self:SafeBool(inInst, false)
            instType = self:SafeString(iType, "none")
        end
    end

    local instanceName, instanceType, instanceID
    if GetInstanceInfo then
        local ok, iName, iType, _, _, _, _, _, iID = pcall(GetInstanceInfo)
        if ok then
            instanceName = self:SafeString(iName, nil)
            instanceType = self:SafeString(iType, instType)
            instanceID = self:SafeNumber(iID, nil)
        end
    end
    instanceType = instanceType or instType

    local isInstance = inInstance or (instanceType and instanceType ~= "none")
    local mapID = nil
    local zoneName = nil
    local coords = nil

    if isInstance then
        zoneName = instanceName
        if not zoneName or zoneName == "" then
            zoneName = (GetRealZoneText and self:SafeString(GetRealZoneText(), nil))
                or (GetZoneText and self:SafeString(GetZoneText(), nil))
                or "Unknown Zone"
        end

        if instanceID and instanceID > 0 then
            mapID = 100000 + instanceID
        elseif C_Map and C_Map.GetBestMapForUnit then
            local okMap, bestMap = pcall(C_Map.GetBestMapForUnit, "player")
            if okMap then
                mapID = self:SafeNumber(bestMap, nil)
            end
        end

        if not mapID then
            mapID = (zoneName ~= "Unknown Zone") and HashZoneNameToID(zoneName) or 0
        end
    else
        if C_Map and C_Map.GetBestMapForUnit then
            local okMap, bestMap = pcall(C_Map.GetBestMapForUnit, "player")
            if okMap then
                mapID = self:SafeNumber(bestMap, nil)
            end
        end

        if mapID and C_Map and C_Map.GetMapInfo then
            local okInfo, mapInfo = pcall(C_Map.GetMapInfo, mapID)
            if okInfo and mapInfo and not self:IsSecretValue(mapInfo) then
                zoneName = self:SafeString(mapInfo.name, nil)
            end
        end

        if not zoneName or zoneName == "" then
            zoneName = (GetRealZoneText and self:SafeString(GetRealZoneText(), nil))
                or (GetZoneText and self:SafeString(GetZoneText(), nil))
                or "Unknown Zone"
        end

        if not mapID then
            mapID = (zoneName ~= "Unknown Zone") and HashZoneNameToID(zoneName) or 0
        elseif mapID > 0 and mapID < 100000 and C_Map and C_Map.GetPlayerMapPosition then
            local okPos, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
            if okPos and pos and not self:IsSecretValue(pos) then
                local px = self:SafeNumber(pos.x, nil)
                local py = self:SafeNumber(pos.y, nil)
                if px and py and (px ~= 0 or py ~= 0) then
                    coords = {
                        x = math.floor(px * 1000 + 0.5) / 10,
                        y = math.floor(py * 1000 + 0.5) / 10
                    }
                end
            end
        end
    end

    local subZone = GetSubZoneText and self:SafeString(GetSubZoneText(), nil) or nil
    if not subZone or subZone == "" then
        subZone = GetMinimapZoneText and self:SafeString(GetMinimapZoneText(), nil) or nil
    end
    if subZone == zoneName or subZone == "" then
        subZone = nil
    end

    return mapID, zoneName, coords, subZone
end

-- Ensure a unit token is a non-secret string before passing to WoW C-APIs (prevents secret value argument errors)
function addon:SanitizeUnitToken(unit)
    unit = self:SafeString(unit, nil)
    if not unit or unit == "" then return nil end
    return unit
end

-- NPC ID extraction from GUID
-- Format: Creature-0-xxxx-xxxx-xxxx-NPCID-SPAWNUID
function addon:GetNPCIDFromGUID(guid)
    guid = self:SafeString(guid, nil)
    if not guid then return nil end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(npcID)
    end
    return nil
end

-- Verify unit is an eligible attackable enemy/neutral creature (excludes players, pets, friendly NPCs, living unattackable NPCs, and critters)
function addon:IsEligibleMobUnit(unit)
    unit = self:SanitizeUnitToken(unit)
    if not unit then return false end
    if not self:SafeBool(UnitExists(unit), false) then return false end
    if self:SafeBool(UnitIsPlayer(unit), false) or self:SafeBool(UnitPlayerControlled(unit), false) then return false end
    if self:SafeBool(UnitIsFriend("player", unit), false) then return false end
    if not self:SafeBool(UnitIsDead(unit), false) and not self:SafeBool(UnitCanAttack("player", unit), false) then return false end
    if self:SafeString(UnitCreatureType(unit), nil) == "Critter" then return false end
    return true
end

-- Resolve a unit's GUID, NPC ID, and display name using live APIs with fallbacks to pre-combat unitTokenCache and nameToNpcIDCache
function addon:ResolveUnitIdentity(unit, knownName)
    unit = self:SanitizeUnitToken(unit)
    local guid = unit and self:SafeString(UnitGUID(unit), nil) or nil
    local npcID = self:GetNPCIDFromGUID(guid)
    local name = (unit and self:SafeString(UnitName(unit), nil)) or self:SafeString(knownName, nil)

    if name == "" or name == "Unknown" then
        name = nil
    end

    local cached = unit and self.unitTokenCache and self.unitTokenCache[unit]
    if cached then
        if guid and cached.guid and guid ~= cached.guid then
            cached = nil
        elseif name and cached.name and name ~= cached.name then
            cached = nil
        end
    end

    if not guid and cached and cached.guid then
        guid = cached.guid
    end
    if not npcID and cached and cached.npcID then
        npcID = cached.npcID
    end
    if not name and cached and cached.name then
        name = cached.name
    end

    if not npcID and name and self.nameToNpcIDCache and self.nameToNpcIDCache[name] then
        npcID = self.nameToNpcIDCache[name]
    end
    if not name and npcID and self.npcNameCache and self.npcNameCache[npcID] then
        name = self.npcNameCache[npcID]
    end

    return guid, npcID, name
end

-- Mark mob as engaged in combat (bounded 400-entry FIFO ring buffer)
function addon:MarkMobEngaged(key)
    key = self:SafeString(key, nil)
    if not key or key == "" then return end
    if self.engagedMobGUIDs[key] then return end

    self.engagedMobGUIDs[key] = true
    table.insert(self.engagedHistoryList, key)

    if #self.engagedHistoryList > 400 then
        local oldest = table.remove(self.engagedHistoryList, 1)
        if oldest then
            self.engagedMobGUIDs[oldest] = nil
        end
    end
end

-- Cache creature name and inspect metadata from a unit
function addon:CacheUnit(unit)
    unit = self:SanitizeUnitToken(unit)
    if not unit then return end
    if not self:SafeBool(UnitExists(unit), false) then
        if self.unitTokenCache then
            self.unitTokenCache[unit] = nil
        end
        return
    end

    if not self:IsEligibleMobUnit(unit) then
        if self.unitTokenCache then
            self.unitTokenCache[unit] = nil
        end
        return
    end

    local guid, npcID, name = self:ResolveUnitIdentity(unit)
    local classification = self:SafeString(UnitClassification(unit), "normal")
    local creatureType = self:SafeString(UnitCreatureType(unit), nil)
    local level = self:SafeNumber(UnitLevel(unit), nil)
    local isDead = self:SafeBool(UnitIsDead(unit), false)
    local inCombat = self:SafeBool(UnitAffectingCombat and UnitAffectingCombat(unit), false) or self:SafeBool(InCombatLockdown and InCombatLockdown(), false)

    -- Update runtime unit token cache for combat/instance fallback
    local prevCache = self.unitTokenCache[unit]
    local sameUnit = prevCache and ((guid and prevCache.guid == guid) or ( not guid and name and prevCache.name == name))
    local spawnKey = (sameUnit and prevCache.spawnKey) or guid
    if not spawnKey then
        self.spawnKeyCounter = (self.spawnKeyCounter or 0) + 1
        spawnKey = string.format("token-%s-%d", unit, self.spawnKeyCounter)
    end
    local engaged = (sameUnit and prevCache.engaged) or (not isDead and (unit == "target" or inCombat))

    self.unitTokenCache[unit] = {
        guid = guid,
        npcID = npcID,
        name = name,
        level = level,
        classification = classification,
        creatureType = creatureType,
        spawnKey = spawnKey,
        engaged = engaged,
        time = GetTime(),
    }

    if engaged then
        self:MarkMobEngaged(guid or spawnKey)
    end

    if not npcID then return end

    if name and name ~= "" and name ~= "Unknown" then
        self.npcNameCache[npcID] = name
        self.nameToNpcIDCache[name] = npcID
    end

    -- Store creature metadata in runtime cache
    addon.unitMetaCache[npcID] = {
        name = name or self.npcNameCache[npcID],
        level = level or (addon.unitMetaCache[npcID] and addon.unitMetaCache[npcID].level),
        classification = classification or (addon.unitMetaCache[npcID] and addon.unitMetaCache[npcID].classification) or "normal",
        creatureType = creatureType or (addon.unitMetaCache[npcID] and addon.unitMetaCache[npcID].creatureType),
    }

    -- Update database if mob exists, OR if it is an eligible attackable rare spawn (so sightings are recorded!)
    -- This prevents friendly NPCs, vendors, and questgivers from ever being added.
    local mapID, zoneName, coords, subZone = self:GetPlayerLocation()
    local isRare = (classification == "rare" or classification == "rareelite")
    local mobExists = self.db and self.db.zones and self.db.zones[mapID] and self.db.zones[mapID].mobs and self.db.zones[mapID].mobs[npcID]

    if mobExists or isRare then
        self:UpdateUnitMeta(npcID, mapID, zoneName, name, level, classification, creatureType, coords, subZone)
    end

    if isDead and (engaged or unit == "target") then
        self:TryRecordUnitKill(unit, unit == "target")
    end
end

-- Record a kill when an eligible engaged or targeted mob dies (deduplicated per corpse GUID)
function addon:TryRecordUnitKill(unit, allowDeadTarget)
    unit = self:SanitizeUnitToken(unit)
    if not unit then return end
    if not self:SafeBool(UnitExists(unit), false) then return end
    if not self:SafeBool(UnitIsDead(unit), false) then return end
    if not self:IsEligibleMobUnit(unit) then return end

    local guid, npcID, mobName = self:ResolveUnitIdentity(unit)
    if not npcID then return end

    local cached = self.unitTokenCache and self.unitTokenCache[unit]
    local dedupKey = guid or (cached and cached.spawnKey)
    if not dedupKey then return end

    if self.killedCorpseGUIDs[dedupKey] or (guid and self.killedCorpseGUIDs[guid]) then
        return
    end

    local wasEngaged = (guid and self.engagedMobGUIDs[guid])
        or (dedupKey and self.engagedMobGUIDs[dedupKey])
        or (cached and cached.engaged)
        or allowDeadTarget

    if not wasEngaged then return end

    self:MarkCorpseKilled(dedupKey)
    if guid and guid ~= dedupKey then
        self:MarkCorpseKilled(guid)
    end

    mobName = mobName or ("Creature " .. npcID)
    local mapID, zoneName, coords, subZone = self:GetPlayerLocation()
    self:RecordKill(mapID, zoneName, npcID, mobName, coords, subZone)

    local meta = self.unitMetaCache and self.unitMetaCache[npcID]
    if meta then
        self:UpdateUnitMeta(npcID, mapID, zoneName, mobName, meta.level, meta.classification, meta.creatureType, coords, subZone)
    end

    self.lastKilledMob = {
        guid = guid,
        dedupKey = dedupKey,
        npcID = npcID,
        name = mobName,
        mapID = mapID,
        zoneName = zoneName,
        time = GetTime(),
    }
end

-- Parse textual money into copper
function addon:ParseMoneyString(str)
    str = self:SafeString(str, nil)
    if not str then return 0 end
    local gold = tonumber(str:match("(%d+)%s*[Gg]old") or str:match("(%d+)%s*[Gg]") or 0) or 0
    local silver = tonumber(str:match("(%d+)%s*[Ss]ilver") or str:match("(%d+)%s*[Ss]") or 0) or 0
    local copper = tonumber(str:match("(%d+)%s*[Cc]opper") or str:match("(%d+)%s*[Cc]") or 0) or 0
    return (gold * 10000) + (silver * 100) + copper
end

-- Mark corpse as looted to prevent double-counting if window is re-opened
function addon:MarkCorpseLooted(guid)
    guid = self:SafeString(guid, nil)
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
    guid = self:SafeString(guid, nil)
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
    guid = self:SafeString(guid, nil)
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
    local numItems = self:SafeNumber(GetNumLootItems(), 0) or 0

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

    -- 1. Identify source creature GUID and NPC ID
    local sourceGUID = nil
    local npcID = nil
    local fallbackName = nil

    if GetLootSourceInfo and numItems > 0 then
        for i = 1, numItems do
            local ok, rawGuid = pcall(GetLootSourceInfo, i)
            local guid = ok and self:SafeString(rawGuid, nil) or nil
            if guid and self:GetNPCIDFromGUID(guid) then
                sourceGUID = guid
                npcID = self:GetNPCIDFromGUID(guid)
                break
            end
        end
    end

    if not npcID and isProfessionHarvest and addon.recentProfessionHarvest and addon.recentProfessionHarvest.targetGUID then
        local profGuid = self:SafeString(addon.recentProfessionHarvest.targetGUID, nil)
        if profGuid and self:GetNPCIDFromGUID(profGuid) then
            sourceGUID = profGuid
            npcID = self:GetNPCIDFromGUID(profGuid)
        end
    end

    if not npcID and self:SafeBool(UnitExists("target"), false) and self:SafeBool(UnitIsDead("target"), false) then
        local tGuid, tNpcID, tName = self:ResolveUnitIdentity("target")
        if tNpcID then
            sourceGUID = tGuid or (self.unitTokenCache["target"] and self.unitTokenCache["target"].spawnKey)
            npcID = tNpcID
            fallbackName = tName
        end
    end

    if not npcID and self:SafeBool(UnitExists("mouseover"), false) and self:SafeBool(UnitIsDead("mouseover"), false) then
        local moGuid, moNpcID, moName = self:ResolveUnitIdentity("mouseover")
        if moNpcID then
            sourceGUID = moGuid or (self.unitTokenCache["mouseover"] and self.unitTokenCache["mouseover"].spawnKey)
            npcID = moNpcID
            fallbackName = moName
        end
    end

    if not npcID and self.lastKilledMob and (GetTime() - self.lastKilledMob.time) < 15.0 then
        sourceGUID = self.lastKilledMob.guid or self.lastKilledMob.dedupKey
        npcID = self.lastKilledMob.npcID
        fallbackName = self.lastKilledMob.name
    end

    if not sourceGUID or not npcID then return end

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
    local mobName = fallbackName
    if not mobName and self:SafeBool(UnitExists("target"), false) then
        local targetGUID = self:SafeString(UnitGUID("target"), nil)
        if targetGUID and targetGUID == sourceGUID then
            mobName = self:SafeString(UnitName("target"), nil)
        end
    end
    if not mobName and self:SafeBool(UnitExists("mouseover"), false) then
        local moGUID = self:SafeString(UnitGUID("mouseover"), nil)
        if moGUID and moGUID == sourceGUID then
            mobName = self:SafeString(UnitName("mouseover"), nil)
        end
    end

    if not mobName or mobName == "" then
        mobName = self:SafeString(self.npcNameCache[npcID], nil)
    end

    if not mobName or mobName == "" then
        mobName = "Creature " .. npcID
    else
        self.npcNameCache[npcID] = mobName
        self.nameToNpcIDCache[mobName] = npcID
    end

    -- 3. Parse items and coins
    local itemsLooted = {}
    local moneyCopper = 0

    local LOOT_MONEY = LOOT_SLOT_MONEY or 2
    local LOOT_ITEM = LOOT_SLOT_ITEM or 1

    for slot = 1, numItems do
        local slotType = self:SafeNumber(GetLootSlotType(slot), nil)

        if slotType == LOOT_MONEY then
            local _, rawName, rawQuantity = GetLootSlotInfo(slot)
            local name = self:SafeString(rawName, nil)
            local quantity = self:SafeNumber(rawQuantity, 0) or 0
            local parsed = self:ParseMoneyString(name)
            if parsed > 0 then
                moneyCopper = moneyCopper + parsed
            elseif quantity > 1 then
                moneyCopper = moneyCopper + quantity
            end
        elseif slotType == LOOT_ITEM or slotType == 0 then
            local rawIcon, rawName, rawQuantity, _, rawQuality = GetLootSlotInfo(slot)
            local icon = self:SafeNumber(rawIcon, nil) or self:SafeString(rawIcon, nil)
            local name = self:SafeString(rawName, nil)
            local quantity = self:SafeNumber(rawQuantity, 1) or 1
            local quality = self:SafeNumber(rawQuality, 1) or 1
            local itemLink = self:SafeString(GetLootSlotLink(slot), nil)
            local itemID = nil

            if itemLink then
                itemID = tonumber(itemLink:match("item:(%d+)"))
            end

            if itemID then
                if not itemsLooted[itemID] then
                    itemsLooted[itemID] = {
                        name = name or ("Item " .. itemID),
                        quality = quality,
                        icon = icon,
                        itemLink = itemLink,
                        quantity = 0
                    }
                end
                itemsLooted[itemID].quantity = itemsLooted[itemID].quantity + quantity
            end
        end
    end

    -- 4. Get player location and record to DB
    local mapID, zoneName, coords, subZone = self:GetPlayerLocation()

    if isProfessionHarvest then
        self:RecordProfessionLoot(mapID, zoneName, npcID, mobName, harvestProf or "Skinning", itemsLooted, coords, subZone)
        addon.recentProfessionHarvest = nil
        addon.activeGatherCast = nil
    else
        self:RecordLoot(mapID, zoneName, npcID, mobName, itemsLooted, moneyCopper, coords, subZone)

        -- Avoid double-counting kill if the mob died moments ago with a secret GUID token
        local alreadyKilled = self.killedCorpseGUIDs[sourceGUID]
        if not alreadyKilled and self.lastKilledMob and self.lastKilledMob.npcID == npcID and not self.lastKilledMob.guid and (GetTime() - self.lastKilledMob.time) < 15.0 then
            self.lastKilledMob.guid = sourceGUID
            self:MarkCorpseKilled(sourceGUID)
            alreadyKilled = true
        end

        if not alreadyKilled then
            self:MarkCorpseKilled(sourceGUID)
            self:RecordKill(mapID, zoneName, npcID, mobName, coords, subZone)
        end

        local meta = self.unitMetaCache[npcID]
        if meta then
            self:UpdateUnitMeta(npcID, mapID, zoneName, mobName, meta.level, meta.classification, meta.creatureType, coords, subZone)
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
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("UNIT_FLAGS")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

local isLoaded = false
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = addon:SafeString(..., nil)
        if (name == ADDON_NAME or name == "AzerothCreatureCompendium" or name == "BgLootLogger") and not isLoaded then
            isLoaded = true
            addon:InitDatabase()
            addon:Print("Loaded. Type |cffffd100/acc|r for Compendium window or |cffffd100/acc options|r for settings.")
        end
    elseif event == "UNIT_SPELLCAST_START" then
        local rawUnit, _, eventSpellID = ...
        local unit = addon:SanitizeUnitToken(rawUnit)
        if unit == "player" and eventSpellID then
            local spellID = eventSpellID
            if addon:IsSecretValue(spellID) then
                local _, _, _, _, _, _, _, _, castID = UnitCastingInfo(unit)
                if not castID then _, _, _, _, _, _, _, castID = UnitChannelInfo(unit) end
                spellID = castID
            end
            spellID = addon:SafeNumber(spellID, nil)
            if not spellID then return end

            local prof = addon:IdentifyGatheringSpell(spellID)
            if prof then
                addon.activeGatherCast = {
                    profession = prof,
                    spellID = spellID,
                    time = GetTime(),
                    targetGUID = addon:SafeString(UnitGUID("target"), nil) or addon:SafeString(UnitGUID("mouseover"), nil)
                }
            end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local rawUnit, _, eventSpellID = ...
        local unit = addon:SanitizeUnitToken(rawUnit)
        if unit == "player" and eventSpellID then
            local spellID = addon:SafeNumber(eventSpellID, nil)
            if not spellID and not addon.activeGatherCast then return end

            local prof = addon:IdentifyGatheringSpell(spellID) or (addon.activeGatherCast and addon.activeGatherCast.profession)
            if prof then
                local targetGUID = (addon.activeGatherCast and addon.activeGatherCast.targetGUID)
                    or addon:SafeString(UnitGUID("target"), nil)
                    or addon:SafeString(UnitGUID("mouseover"), nil)
                addon.recentProfessionHarvest = {
                    profession = prof,
                    spellID = spellID or (addon.activeGatherCast and addon.activeGatherCast.spellID),
                    time = GetTime(),
                    targetGUID = targetGUID,
                }
                addon.activeGatherCast = nil
            end
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        local unit = addon:SanitizeUnitToken(...)
        if unit == "player" then
            addon.activeGatherCast = nil
        end
    elseif event == "CHAT_MSG_MONEY" then
        local msg = addon:SafeString(..., nil)
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
        local unit = addon:SanitizeUnitToken(...)
        if unit then
            addon:CacheUnit(unit)
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = addon:SanitizeUnitToken(...)
        if unit and addon.unitTokenCache then
            addon.unitTokenCache[unit] = nil
        end
    elseif event == "UNIT_HEALTH" or event == "UNIT_FLAGS" then
        local unit = addon:SanitizeUnitToken(...)
        if unit and (unit == "target" or unit == "mouseover" or string.find(unit, "^nameplate%d+")) then
            if addon:SafeBool(UnitExists(unit), false) then
                if addon:SafeBool(UnitIsDead(unit), false) then
                    addon:TryRecordUnitKill(unit, unit == "target")
                elseif unit == "target" or addon:SafeBool(UnitAffectingCombat and UnitAffectingCombat(unit), false) then
                    if addon.unitTokenCache and addon.unitTokenCache[unit] then
                        addon.unitTokenCache[unit].engaged = true
                        local key = addon.unitTokenCache[unit].guid or addon.unitTokenCache[unit].spawnKey
                        if key then
                            addon:MarkMobEngaged(key)
                        end
                    else
                        addon:CacheUnit(unit)
                    end
                end
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Re-evaluate target and active nameplates once combat restrictions lift
        addon:CacheUnit("target")
        for i = 1, 40 do
            local npUnit = "nameplate" .. i
            if addon:SafeBool(UnitExists(npUnit), false) then
                addon:CacheUnit(npUnit)
            end
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
