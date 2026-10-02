--[[
    Azeroth Creature Compendium - Database.lua
    Data storage, Pokédex hierarchy (Zone -> Mob -> [Combat, Loot]),
    calculations, auto-migration, and queries.
]]

local _, addon = ...

-- Quality formatting helpers
function addon:GetQualityHex(quality)
    return self.QUALITY_HEX[quality or 1] or "ffffff"
end

function addon:FormatQualityName(name, quality)
    local hex = self:GetQualityHex(quality)
    return string.format("|cff%s%s|r", hex, name or "Unknown Item")
end

-- Bestiary Progression Ranks
addon.RESEARCH_RANKS = {
    { interactions = 1,   name = "Safari Greenhorn", color = "e0e0e0" },
    { interactions = 35,  name = "Nesingwary's Apprentice", color = "1eff00" },
    { interactions = 100, name = "Master of the Hunt", color = "0070dd" },
    { interactions = 500, name = "The Hemetinator", color = "a335ee" },
}

-- Calculate research rank for a mob
function addon:GetMobResearchRank(mob)
    if not mob then return 0, "Unknown", "888888", 0, 1 end
    local interactions = (mob.kills or 0) + ((mob.loot and mob.loot.totalLoots) or mob.totalLoots or 0) + ((mob.professions and mob.professions.totalHarvests) or 0)

    local currentRank = 0
    local rankName = "Undiscovered"
    local rankColor = "888888"
    local nextThreshold = addon.RESEARCH_RANKS[1].interactions

    for i, rank in ipairs(addon.RESEARCH_RANKS) do
        if interactions >= rank.interactions then
            currentRank = i
            rankName = rank.name
            rankColor = rank.color
            if addon.RESEARCH_RANKS[i+1] then
                nextThreshold = addon.RESEARCH_RANKS[i+1].interactions
            else
                nextThreshold = -1 -- Max rank
            end
        end
    end

    return currentRank, rankName, rankColor, interactions, nextThreshold
end


-- Initialize and migrate database
function addon:InitDatabase()
    -- Initialize primary SavedVariable
    AzerothCreatureCompendiumDB = AzerothCreatureCompendiumDB or {}
    local db = AzerothCreatureCompendiumDB

    db.version = 2
    db.settings = db.settings or {}

    -- Merge defaults
    for k, v in pairs(self.DEFAULT_SETTINGS) do
        if db.settings[k] == nil then
            db.settings[k] = v
        end
    end

    -- Legacy settings migration
    if db.settings.modifierKeyLoot == "NONE" then db.settings.modifierKeyLoot = "ALWAYS" end
    if db.settings.modifierKeyCombat == "NONE" then db.settings.modifierKeyCombat = "ALWAYS" end
    if db.settings.modifierKeyProfession == "NONE" then db.settings.modifierKeyProfession = "ALWAYS" end
    if db.settings.tooltipLayout == nil then
        db.settings.tooltipLayout = (db.settings.separateTooltip == false) and "EMBEDDED" or "SIDECAR"
    end
    if db.settings.sidecarAnchor == nil then
        db.settings.sidecarAnchor = "HORIZONTAL"
    end
    if db.settings.tooltipAnchor == nil then
        db.settings.tooltipAnchor = "BLIZZARD"
    end

    db.zones = db.zones or {}
    db.npcToZones = db.npcToZones or {}

    -- Auto-migration from legacy BgLootLoggerDB if present
    if BgLootLoggerDB and BgLootLoggerDB.zones then
        for mapID, oldZone in pairs(BgLootLoggerDB.zones) do
            if not db.zones[mapID] then
                db.zones[mapID] = {
                    id = mapID,
                    name = oldZone.name or ("Zone " .. mapID),
                    mobs = {}
                }
            end
            local targetZone = db.zones[mapID]

            for npcID, oldMob in pairs(oldZone.mobs or {}) do
                if not targetZone.mobs[npcID] then
                    targetZone.mobs[npcID] = {
                        npcID = npcID,
                        name = oldMob.name or ("Creature " .. npcID),
                        coords = oldMob.coords or {},
                        encounters = oldMob.totalLoots or 0,
                        kills = 0,
                        combat = {
                            attacks = { swings = 0, minDmg = 0, maxDmg = 0, totalDmg = 0, avgDmg = 0 },
                            spells = {},
                            immunities = {}
                        },
                        loot = {
                            totalLoots = oldMob.totalLoots or 0,
                            emptyLoots = oldMob.emptyLoots or 0,
                            totalMoney = oldMob.totalMoney or 0,
                            avgMoney = oldMob.avgMoney or 0,
                            coords = oldMob.coords or {},
                            items = oldMob.items or {}
                        }
                    }
                    -- Backwards compatibility aliases on mob object
                    local m = targetZone.mobs[npcID]
                    m.totalLoots = m.loot.totalLoots
                    m.avgMoney = m.loot.avgMoney
                    m.items = m.loot.items
                end
            end
        end

        if BgLootLoggerDB.npcToZones then
            for npcID, zones in pairs(BgLootLoggerDB.npcToZones) do
                db.npcToZones[npcID] = db.npcToZones[npcID] or {}
                for mapID in pairs(zones) do
                    db.npcToZones[npcID][mapID] = true
                end
            end
        end

        -- Migrate legacy settings if defined
        if BgLootLoggerDB.settings then
            if BgLootLoggerDB.settings.modifierKey and not db.settings.modifierKeyLoot then
                db.settings.modifierKeyLoot = BgLootLoggerDB.settings.modifierKey
            end
        end
    end

    -- Clean up any non-killed, non-looted, and non-harvested mobs from past sessions (e.g. vendors/friendly NPCs)
    for mapID, zone in pairs(db.zones) do
        for npcID, mob in pairs(zone.mobs or {}) do
            if not mob.professions then
                mob.professions = {
                    totalHarvests = 0,
                    emptyHarvests = 0,
                    items = {},
                    bySkill = {},
                }
            end
            local hasLoot = (mob.loot and (mob.loot.totalLoots or 0) > 0) or ((mob.totalLoots or 0) > 0)
            local hasKills = (mob.kills or 0) > 0
            local hasHarvest = (mob.professions and (mob.professions.totalHarvests or 0) > 0)
            local isRare = (mob.classification == "rare" or mob.classification == "rareelite")
            if not hasLoot and not hasKills and not hasHarvest and not isRare then
                zone.mobs[npcID] = nil
            end
        end
    end


    -- Purge legacy demo test mobs if present from previous builds
    for mapID, zone in pairs(db.zones) do
        for npcID, mob in pairs(zone.mobs or {}) do
            local isDemoTimber = (npcID == 1132 and (mob.kills or 0) == 0 and (not mob.loot or (mob.loot.totalLoots or 0) == 0))
            local isDemoVagash = (npcID == 1388 and mob.combat and mob.combat.attacks and mob.combat.attacks.avgDmg == 52 and mob.combat.attacks.totalDmg == 310 and mob.loot and mob.loot.totalMoney == 180 and (not mob.loot.items or next(mob.loot.items) == nil))
            if isDemoTimber or isDemoVagash then
                zone.mobs[npcID] = nil
                if db.npcToZones and db.npcToZones[npcID] then
                    db.npcToZones[npcID][mapID] = nil
                    if next(db.npcToZones[npcID]) == nil then
                        db.npcToZones[npcID] = nil
                    end
                end
            end
        end
        -- Remove empty zones if all mobs were pruned
        if zone.mobs and next(zone.mobs) == nil then
            db.zones[mapID] = nil
        end
    end

    -- Sanitize existing zone, mob, and spell names against tainted/secret strings
    for mapID, zone in pairs(db.zones) do
        zone.name = self:SafeString(zone.name, "Zone " .. mapID)
        for npcID, mob in pairs(zone.mobs or {}) do
            mob.name = self:SafeString(mob.name, "Creature " .. npcID)
            if not mob.subZones then
                mob.subZones = {}
            end
            if not mob.zoneName then
                mob.zoneName = zone.name
            end
            if not mob.mapID then
                mob.mapID = mapID
            end
            if mob.combat and mob.combat.spells then
                for spellID, sp in pairs(mob.combat.spells) do
                    sp.name = self:SafeString(sp.name, "Spell " .. spellID)
                end
            end
        end
    end

    -- Keep BgLootLoggerDB synchronized so existing backups remain valid
    BgLootLoggerDB = db

    self.db = db
end

-- Core factory: ensures Zone and Mob exist with the new Pokédex structure
function addon:GetOrCreateMob(mapID, zoneName, npcID, mobName, subZone)
    if not npcID or npcID <= 0 then return nil end
    if not self.db then self:InitDatabase() end
    mapID = mapID or 0
    zoneName = self:SafeString(zoneName, "Unknown Zone")
    mobName = self:SafeString(mobName, "Creature " .. npcID)

    -- 1. Ensure Zone exists
    local zone = self.db.zones[mapID]
    if not zone then
        zone = {
            id = mapID,
            name = zoneName,
            mobs = {}
        }
        self.db.zones[mapID] = zone
    elseif zoneName ~= "Unknown Zone" and (zone.name == "Unknown Zone" or not zone.name) then
        zone.name = zoneName
    end

    -- 2. Reverse index NPC to Zone for cross-zone queries
    self.db.npcToZones[npcID] = self.db.npcToZones[npcID] or {}
    self.db.npcToZones[npcID][mapID] = true

    -- 3. Ensure Mob exists
    local mob = zone.mobs[npcID]
    if not mob then
        mob = {
            npcID = npcID,
            name = mobName,
            classification = "normal",
            creatureType = nil,
            minLevel = nil,
            maxLevel = nil,
            encounters = 0,
            kills = 0,
            firstSeen = time(),
            lastSeen = time(),
            coords = {},
            subZones = {},
            zoneName = zone.name,
            mapID = mapID,
            -- Sibling Child 1: Combat
            combat = {
                attacks = {
                    swings = 0,
                    minDmg = 0,
                    maxDmg = 0,
                    totalDmg = 0,
                    avgDmg = 0,
                    school = 1,
                },
                spells = {},
                immunities = {},
            },
            -- Sibling Child 2: Loot
            loot = {
                totalLoots = 0,
                emptyLoots = 0,
                totalMoney = 0,
                avgMoney = 0,
                coords = {},
                items = {},
            },
            -- Sibling Child 3: Professions (Skinning, Mining, Herbalism, Engineering)
            professions = {
                totalHarvests = 0,
                emptyHarvests = 0,
                items = {},
                bySkill = {},
            },
        }
        zone.mobs[npcID] = mob
    else
        if mobName and mobName ~= "" and not string.find(mobName, "^Creature %d+") then
            mob.name = mobName
        end
        mob.lastSeen = time()
    end

    -- Structure guarantee
    if not mob.subZones then
        mob.subZones = {}
    end
    if not mob.zoneName then
        mob.zoneName = zone.name
    end
    if not mob.mapID then
        mob.mapID = mapID
    end
    if not mob.combat then
        mob.combat = {
            attacks = { swings = 0, minDmg = 0, maxDmg = 0, totalDmg = 0, avgDmg = 0, school = 1 },
            spells = {},
            immunities = {},
        }
    end
    if not mob.loot then
        mob.loot = {
            totalLoots = mob.totalLoots or 0,
            emptyLoots = mob.emptyLoots or 0,
            totalMoney = mob.totalMoney or 0,
            avgMoney = mob.avgMoney or 0,
            coords = mob.coords or {},
            items = mob.items or {},
        }
    end
    if not mob.professions then
        mob.professions = {
            totalHarvests = 0,
            emptyHarvests = 0,
            items = {},
            bySkill = {},
        }
    end

    if subZone then
        self:RecordSubZone(mob, subZone)
    end

    -- Backward compatibility mirrors
    mob.totalLoots = mob.loot.totalLoots
    mob.avgMoney = mob.loot.avgMoney
    mob.items = mob.loot.items

    return mob, zone
end

-- Helper to record rare spawn coordinate sighting (only for rare spawns!)
function addon:RecordCoordinates(mob, coords)
    if not mob or not coords or not coords.x or not coords.y then return end
    local isRare = (mob.classification == "rare" or mob.classification == "rareelite")
    if not isRare then return end

    mob.coords = { { x = coords.x, y = coords.y, time = time() } }
    if mob.loot then
        mob.loot.coords = mob.coords
    end
end

-- Helper to record creature sighting in a local subzone
function addon:RecordSubZone(mob, subZone)
    if not mob or not subZone or type(subZone) ~= "string" or subZone == "" then return end
    subZone = self:SafeString(subZone, nil)
    if not subZone or subZone == "" then return end

    if not mob.subZones then
        mob.subZones = {}
    end

    mob.subZones[subZone] = true
end

-- Returns sorted list of subzone names
function addon:GetMobSubZones(mob)
    if not mob or not mob.subZones then return {} end
    local list = {}
    if type(mob.subZones) == "table" then
        for k, v in pairs(mob.subZones) do
            if type(k) == "string" and v then
                table.insert(list, k)
            elseif type(v) == "string" then
                table.insert(list, v)
            end
        end
    end
    table.sort(list)
    return list
end

-- Formats creature location string (e.g. "Coldridge Pass", "Coldridge Valley and Kharanos", or fallback to zone name)
function addon:FormatMobLocationString(mob, defaultZoneName)
    local subZones = self:GetMobSubZones(mob)
    local count = #subZones

    if count == 1 then
        return subZones[1]
    elseif count == 2 then
        return string.format("%s and %s", subZones[1], subZones[2])
    elseif count > 2 then
        local allButLast = table.concat(subZones, ", ", 1, count - 1)
        return string.format("%s, and %s", allButLast, subZones[count])
    end

    if defaultZoneName and defaultZoneName ~= "" and defaultZoneName ~= "Unknown Zone" then
        return defaultZoneName
    end

    return nil
end

-- Update creature metadata from unit inspection (target, mouseover, nameplates)
function addon:UpdateUnitMeta(npcID, mapID, zoneName, mobName, level, classification, creatureType, coords, subZone)
    classification = self:SafeString(classification, nil)
    creatureType = self:SafeString(creatureType, nil)
    local mob = self:GetOrCreateMob(mapID, zoneName, npcID, mobName, subZone)
    if not mob then return end

    if classification and classification ~= "" then
        mob.classification = classification
    end

    if creatureType and creatureType ~= "" then
        mob.creatureType = creatureType
    end

    if level and level > 0 then
        if not mob.minLevel or level < mob.minLevel then
            mob.minLevel = level
        end
        if not mob.maxLevel or level > mob.maxLevel then
            mob.maxLevel = level
        end
    end

    if coords and coords.x and coords.y then
        self:RecordCoordinates(mob, coords)
    end
end

-- Records a loot encounter for a mob in a zone
function addon:RecordLoot(mapID, zoneName, npcID, mobName, itemsLooted, moneyCopper, coords, subZone)
    local mob = self:GetOrCreateMob(mapID, zoneName, npcID, mobName, subZone)
    if not mob then return end

    itemsLooted = itemsLooted or {}
    moneyCopper = moneyCopper or 0

    local loot = mob.loot
    loot.totalLoots = (loot.totalLoots or 0) + 1
    mob.totalLoots = loot.totalLoots

    local hasAnyItem = next(itemsLooted) ~= nil

    if not hasAnyItem and moneyCopper == 0 then
        loot.emptyLoots = (loot.emptyLoots or 0) + 1
    end

    -- Record Money
    if moneyCopper > 0 then
        loot.totalMoney = (loot.totalMoney or 0) + moneyCopper
        loot.avgMoney = math.floor(loot.totalMoney / loot.totalLoots)
        mob.avgMoney = loot.avgMoney
    end

    -- Record Coordinates (store up to 5 points)
    if coords and coords.x and coords.y then
        loot.coords = loot.coords or {}
        local isDuplicate = false
        for _, pt in ipairs(loot.coords) do
            if math.abs(pt.x - coords.x) < 0.8 and math.abs(pt.y - coords.y) < 0.8 then
                isDuplicate = true
                break
            end
        end
        if not isDuplicate then
            table.insert(loot.coords, 1, { x = coords.x, y = coords.y, time = time() })
            if #loot.coords > 5 then
                table.remove(loot.coords)
            end
        end
    end

    -- Record Items Looted
    for itemID, itemData in pairs(itemsLooted) do
        local item = loot.items[itemID]
        if not item then
            item = {
                id = itemID,
                name = itemData.name or ("Item " .. itemID),
                quality = itemData.quality or 1,
                icon = itemData.icon,
                itemLink = itemData.itemLink,
                dropLootCount = 0,
                totalQuantity = 0,
                dropRatePercent = 0.0,
                dropRateDecimal = 0.0,
                dropChance = "0.0%"
            }
            loot.items[itemID] = item
        else
            if itemData.itemLink then item.itemLink = itemData.itemLink end
            if itemData.icon then item.icon = itemData.icon end
            if itemData.quality then item.quality = itemData.quality end
            if itemData.name then item.name = itemData.name end
        end

        item.dropLootCount = (item.dropLootCount or 0) + 1
        item.totalQuantity = (item.totalQuantity or 0) + (itemData.quantity or 1)
    end

    -- Recalculate drop percentages
    for _, it in pairs(loot.items) do
        local count = it.dropLootCount or 0
        local rateDec = count / loot.totalLoots
        local ratePct = rateDec * 100

        it.dropRateDecimal = tonumber(string.format("%.3f", rateDec))
        it.dropRatePercent = tonumber(string.format("%.1f", ratePct))
        it.dropChance = string.format("%.1f%%", it.dropRatePercent)
    end

    mob.items = loot.items
    return mob
end

-- Records a profession harvest (skinning, mining, herbalism, engineering) for a mob
function addon:RecordProfessionLoot(mapID, zoneName, npcID, mobName, professionName, itemsLooted, coords, subZone)
    local mob = self:GetOrCreateMob(mapID, zoneName, npcID, mobName, subZone)
    if not mob then return end

    professionName = professionName or "Skinning"
    itemsLooted = itemsLooted or {}

    local prof = mob.professions
    if not prof then
        prof = {
            totalHarvests = 0,
            emptyHarvests = 0,
            items = {},
            bySkill = {},
        }
        mob.professions = prof
    end

    prof.totalHarvests = (prof.totalHarvests or 0) + 1
    prof.bySkill = prof.bySkill or {}
    prof.bySkill[professionName] = prof.bySkill[professionName] or { totalHarvests = 0, emptyHarvests = 0 }
    prof.bySkill[professionName].totalHarvests = prof.bySkill[professionName].totalHarvests + 1

    local hasAnyItem = next(itemsLooted) ~= nil

    if not hasAnyItem then
        prof.emptyHarvests = (prof.emptyHarvests or 0) + 1
        prof.bySkill[professionName].emptyHarvests = prof.bySkill[professionName].emptyHarvests + 1
    end

    -- Record Coordinates (store up to 5 points)
    if coords and coords.x and coords.y then
        mob.coords = mob.coords or {}
        local isDuplicate = false
        for _, pt in ipairs(mob.coords) do
            if math.abs(pt.x - coords.x) < 0.8 and math.abs(pt.y - coords.y) < 0.8 then
                isDuplicate = true
                break
            end
        end
        if not isDuplicate then
            table.insert(mob.coords, 1, { x = coords.x, y = coords.y, time = time() })
            if #mob.coords > 5 then
                table.remove(mob.coords)
            end
        end
    end

    -- Record Items Harvested
    for itemID, itemData in pairs(itemsLooted) do
        local item = prof.items[itemID]
        if not item then
            item = {
                id = itemID,
                name = itemData.name or ("Item " .. itemID),
                quality = itemData.quality or 1,
                icon = itemData.icon,
                itemLink = itemData.itemLink,
                dropLootCount = 0,
                harvestCount = 0,
                totalQuantity = 0,
                dropRatePercent = 0.0,
                dropRateDecimal = 0.0,
                dropChance = "0.0%",
                profession = professionName,
            }
            prof.items[itemID] = item
        else
            if itemData.itemLink then item.itemLink = itemData.itemLink end
            if itemData.icon then item.icon = itemData.icon end
            if itemData.quality then item.quality = itemData.quality end
            if itemData.name then item.name = itemData.name end
            item.profession = professionName
        end

        item.harvestCount = (item.harvestCount or 0) + 1
        item.dropLootCount = item.harvestCount
        item.totalQuantity = (item.totalQuantity or 0) + (itemData.quantity or 1)
    end

    -- Recalculate drop percentages
    for _, it in pairs(prof.items) do
        local count = it.dropLootCount or 0
        local rateDec = count / prof.totalHarvests
        local ratePct = rateDec * 100

        it.dropRateDecimal = tonumber(string.format("%.3f", rateDec))
        it.dropRatePercent = tonumber(string.format("%.1f", ratePct))
        it.dropChance = string.format("%.1f%%", it.dropRatePercent)
    end

    mob.lastSeen = time()
    return mob
end

-- Records Melee / Auto-Attacks performed by creature
function addon:RecordMeleeAttack(mapID, zoneName, npcID, mobName, amount, school, subZone)
    local mob = self:GetOrCreateMob(mapID, zoneName, npcID, mobName, subZone)
    if not mob then return end

    local atk = mob.combat.attacks
    atk.swings = (atk.swings or 0) + 1
    school = school or 1
    atk.school = school

    amount = math.floor(amount or 0)
    if amount > 0 then
        if atk.minDmg == 0 or amount < atk.minDmg then
            atk.minDmg = amount
        end
        if amount > atk.maxDmg then
            atk.maxDmg = amount
        end
        atk.totalDmg = (atk.totalDmg or 0) + amount
        atk.avgDmg = math.floor(atk.totalDmg / atk.swings)
    end
end

-- Records a spell cast by creature
function addon:RecordSpellCast(mapID, zoneName, npcID, mobName, spellId, spellName, spellSchool, icon, subZone)
    if not spellId then return end
    spellId = tonumber(spellId)
    if not spellId then return end

    zoneName = self:SafeString(zoneName, "Unknown Zone")
    mobName = self:SafeString(mobName, "Creature " .. npcID)
    spellName = self:SafeString(spellName, nil)

    local mob = self:GetOrCreateMob(mapID, zoneName, npcID, mobName, subZone)
    if not mob then return end

    local spell = mob.combat.spells[spellId]
    if not spell then
        spell = {
            id = spellId,
            name = spellName or ("Spell " .. spellId),
            icon = icon or (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellId)) or GetSpellTexture(spellId) or "Interface\\Icons\\Spell_Holy_MagicalSentry",
            school = spellSchool or 1,
            casts = 0,
            minDmg = 0,
            maxDmg = 0,
            totalDmg = 0,
            avgDmg = 0,
            isHeal = false,
            isBuff = false,
            isDebuff = false,
        }
        mob.combat.spells[spellId] = spell
    end

    spell.casts = (spell.casts or 0) + 1
    if spellName and spellName ~= "" then spell.name = spellName end
    if icon then spell.icon = icon end
    if spellSchool and spellSchool > 1 then spell.school = spellSchool end
end

-- Records spell damage dealt by creature
function addon:RecordSpellDamage(mapID, zoneName, npcID, mobName, spellId, spellName, spellSchool, amount, overkill, isPeriodic, icon, subZone)
    if not spellId then return end
    spellId = tonumber(spellId)
    if not spellId then return end

    zoneName = self:SafeString(zoneName, "Unknown Zone")
    mobName = self:SafeString(mobName, "Creature " .. npcID)
    spellName = self:SafeString(spellName, nil)

    local mob = self:GetOrCreateMob(mapID, zoneName, npcID, mobName, subZone)
    if not mob then return end

    self:RecordSpellCast(mapID, zoneName, npcID, mobName, spellId, spellName, spellSchool, icon, subZone)
    local spell = mob.combat.spells[spellId]
    if not spell then return end

    amount = math.floor(amount or 0)
    if amount > 0 then
        if spell.minDmg == 0 or amount < spell.minDmg then
            spell.minDmg = amount
        end
        if amount > spell.maxDmg then
            spell.maxDmg = amount
        end
        spell.totalDmg = (spell.totalDmg or 0) + amount
        local hitCount = (spell.hits or 0) + 1
        spell.hits = hitCount
        spell.avgDmg = math.floor(spell.totalDmg / hitCount)
    end
end

-- Records spell healing done by creature
function addon:RecordSpellHeal(mapID, zoneName, npcID, mobName, spellId, spellName, spellSchool, amount, icon, subZone)
    if not spellId then return end
    spellId = tonumber(spellId)
    if not spellId then return end

    zoneName = self:SafeString(zoneName, "Unknown Zone")
    mobName = self:SafeString(mobName, "Creature " .. npcID)
    spellName = self:SafeString(spellName, nil)

    local mob = self:GetOrCreateMob(mapID, zoneName, npcID, mobName, subZone)
    if not mob then return end

    self:RecordSpellCast(mapID, zoneName, npcID, mobName, spellId, spellName, spellSchool, icon, subZone)
    local spell = mob.combat.spells[spellId]
    if not spell then return end

    spell.isHeal = true
    amount = math.floor(amount or 0)
    if amount > 0 then
        if spell.minDmg == 0 or amount < spell.minDmg then
            spell.minDmg = amount
        end
        if amount > spell.maxDmg then
            spell.maxDmg = amount
        end
        spell.totalDmg = (spell.totalDmg or 0) + amount
        local healCount = (spell.heals or 0) + 1
        spell.heals = healCount
        spell.avgDmg = math.floor(spell.totalDmg / healCount)
    end
end

-- Records aura application by creature
function addon:RecordSpellAura(mapID, zoneName, npcID, mobName, spellId, spellName, spellSchool, auraType, icon, subZone)
    if not spellId then return end
    spellId = tonumber(spellId)
    if not spellId then return end

    zoneName = self:SafeString(zoneName, "Unknown Zone")
    mobName = self:SafeString(mobName, "Creature " .. npcID)
    spellName = self:SafeString(spellName, nil)

    local mob = self:GetOrCreateMob(mapID, zoneName, npcID, mobName, subZone)
    if not mob then return end

    self:RecordSpellCast(mapID, zoneName, npcID, mobName, spellId, spellName, spellSchool, icon, subZone)
    local spell = mob.combat.spells[spellId]
    if not spell then return end

    if auraType == "BUFF" then
        spell.isBuff = true
    elseif auraType == "DEBUFF" then
        spell.isDebuff = true
    end
end

-- Records an observed immunity on a creature
function addon:RecordImmunity(mapID, zoneName, npcID, mobName, immunityKey, immunityType, immunityName, school, subZone)
    immunityKey = self:SafeString(immunityKey, nil)
    if not immunityKey or immunityKey == "" then return end
    zoneName = self:SafeString(zoneName, "Unknown Zone")
    mobName = self:SafeString(mobName, "Creature " .. npcID)
    immunityName = self:SafeString(immunityName, immunityKey)

    local mob = self:GetOrCreateMob(mapID, zoneName, npcID, mobName, subZone)
    if not mob then return end

    local imm = mob.combat.immunities[immunityKey]
    if not imm then
        imm = {
            key = immunityKey,
            type = immunityType or "SCHOOL",
            name = immunityName,
            school = school,
            count = 0,
            firstSeen = time(),
            lastSeen = time(),
        }
        mob.combat.immunities[immunityKey] = imm
    end

    imm.count = (imm.count or 0) + 1
    imm.lastSeen = time()
end

-- Records a kill
function addon:RecordKill(mapID, zoneName, npcID, mobName, coords, subZone)
    local mob = self:GetOrCreateMob(mapID, zoneName, npcID, mobName, subZone)
    if not mob then return end
    mob.kills = (mob.kills or 0) + 1
    if coords and coords.x and coords.y then
        self:RecordCoordinates(mob, coords)
    end
end

local function ResolveMobSpells(mob)
    if not mob or not mob.combat or not mob.combat.spells then return end
    for spellID, sp in pairs(mob.combat.spells) do
        if not sp.name or string.find(sp.name, "^Spell %d+") then
            local rName, rIcon = addon:ResolveSpellInfo(spellID)
            if rName and not string.find(rName, "^Spell %d+") then
                sp.name = rName
                if addon.InferSpellSchool then
                    local sNum = addon:InferSpellSchool(rName)
                    if sNum and sNum > 1 then
                        sp.school = sNum
                    end
                end
                if rIcon then
                    sp.icon = rIcon
                end
            end
        end
    end
end

-- Retrieve mob data (current zone first, then cross-zone fallback)
function addon:GetMobData(npcID, mapID)
    if not npcID or not self.db or not self.db.zones then
        return nil, nil, false
    end

    mapID = mapID or 0

    -- Current zone check
    if self.db.zones[mapID] and self.db.zones[mapID].mobs and self.db.zones[mapID].mobs[npcID] then
        local mob = self.db.zones[mapID].mobs[npcID]
        ResolveMobSpells(mob)
        return mob, self.db.zones[mapID].name, true
    end

    -- Fallback: check cross-zone registry
    if self.db.npcToZones and self.db.npcToZones[npcID] then
        local bestMob = nil
        local bestZoneName = "Other Zone"
        local maxActivity = -1

        for otherMapID in pairs(self.db.npcToZones[npcID]) do
            local otherZone = self.db.zones[otherMapID]
            if otherZone and otherZone.mobs and otherZone.mobs[npcID] then
                local candidate = otherZone.mobs[npcID]
                local activity = (candidate.loot and candidate.loot.totalLoots or 0) + (candidate.kills or 0)
                if activity > maxActivity then
                    maxActivity = activity
                    bestMob = candidate
                    bestZoneName = otherZone.name or ("Zone " .. otherMapID)
                end
            end
        end

        if bestMob then
            ResolveMobSpells(bestMob)
            return bestMob, bestZoneName, false
        end
    end

    return nil, nil, false
end

-- Backward compatibility function for loot queries
function addon:GetMobLootData(npcID, mapID)
    return self:GetMobData(npcID, mapID)
end

-- Sorted Item List Helper
function addon:GetSortedItemList(mob, maxItems, minQuality)
    if not mob then return {} end
    local items = (mob.loot and mob.loot.items) or mob.items
    if not items then return {} end

    maxItems = maxItems or (self.db and self.db.settings.maxItems) or 8
    minQuality = minQuality or (self.db and self.db.settings.minQuality) or 0

    local list = {}
    for _, item in pairs(items) do
        if (item.quality or 0) >= minQuality then
            table.insert(list, item)
        end
    end

    table.sort(list, function(a, b)
        local rateA = a.dropRatePercent or 0
        local rateB = b.dropRatePercent or 0
        if rateA ~= rateB then
            return rateA > rateB
        end
        local qtyA = a.totalQuantity or 0
        local qtyB = b.totalQuantity or 0
        if qtyA ~= qtyB then
            return qtyA > qtyB
        end
        return (a.quality or 0) > (b.quality or 0)
    end)

    local result = {}
    for i = 1, math.min(#list, maxItems) do
        table.insert(result, list[i])
    end

    return result, #list
end

-- Sorted Profession Item List Helper
function addon:GetSortedProfessionItemList(mob, maxItems, minQuality)
    if not mob or not mob.professions then return {} end
    local items = mob.professions.items
    if not items then return {} end

    maxItems = maxItems or (self.db and self.db.settings.maxItems) or 999
    minQuality = minQuality or (self.db and self.db.settings.minQuality) or 0

    local list = {}
    for _, item in pairs(items) do
        if (item.quality or 0) >= minQuality then
            table.insert(list, item)
        end
    end

    table.sort(list, function(a, b)
        local rateA = a.dropRatePercent or 0
        local rateB = b.dropRatePercent or 0
        if rateA ~= rateB then
            return rateA > rateB
        end
        local qtyA = a.totalQuantity or 0
        local qtyB = b.totalQuantity or 0
        if qtyA ~= qtyB then
            return qtyA > qtyB
        end
        return (a.quality or 0) > (b.quality or 0)
    end)

    local result = {}
    for i = 1, math.min(#list, maxItems) do
        table.insert(result, list[i])
    end

    return result, #list
end

-- Sorted Spell List Helper (Always includes Auto Attack)
function addon:GetSortedSpellList(mob, maxSpells)
    if not mob or not mob.combat then return {} end
    maxSpells = maxSpells or (self.db and self.db.settings.maxSpells) or 8

    local list = {}

    -- Auto Attack entry
    table.insert(list, {
        id = 6603,
        name = "Auto Attack",
        icon = "Interface\\Icons\\Ability_MeleeAttack",
        school = 1,
        schoolName = "Physical",
        isAutoAttack = true,
        casts = (mob.combat.attacks and mob.combat.attacks.swings and mob.combat.attacks.swings > 0 and mob.combat.attacks.swings) or 1,
    })

    for _, spell in pairs(mob.combat.spells or {}) do
        table.insert(list, spell)
    end

    table.sort(list, function(a, b)
        if a.isAutoAttack then return true end
        if b.isAutoAttack then return false end
        local castsA = a.casts or 0
        local castsB = b.casts or 0
        if castsA ~= castsB then
            return castsA > castsB
        end
        return (a.avgDmg or 0) > (b.avgDmg or 0)
    end)

    local result = {}
    for i = 1, math.min(#list, maxSpells) do
        table.insert(result, list[i])
    end

    return result, #list
end

-- Immunities List Helper
function addon:GetMobImmunities(mob)
    if not mob or not mob.combat or not mob.combat.immunities then return {} end
    local list = {}
    for _, imm in pairs(mob.combat.immunities) do
        table.insert(list, imm)
    end
    table.sort(list, function(a, b) return (a.count or 0) > (b.count or 0) end)
    return list
end

-- Prints overall database status
function addon:PrintStatus()
    local totalZones = 0
    local totalMobs = 0
    local totalLoots = 0
    local totalKills = 0
    local totalItems = 0
    local totalSpells = 0
    local totalImmunities = 0
    local totalHarvests = 0
    local seenItems = {}

    for _, zone in pairs(self.db.zones or {}) do
        totalZones = totalZones + 1
        for _, mob in pairs(zone.mobs or {}) do
            totalMobs = totalMobs + 1
            totalKills = totalKills + (mob.kills or 0)
            if mob.loot then
                totalLoots = totalLoots + (mob.loot.totalLoots or 0)
                for itemID in pairs(mob.loot.items or {}) do
                    if not seenItems[itemID] then
                        seenItems[itemID] = true
                        totalItems = totalItems + 1
                    end
                end
            end
            if mob.professions then
                totalHarvests = (totalHarvests or 0) + (mob.professions.totalHarvests or 0)
                for itemID in pairs(mob.professions.items or {}) do
                    if not seenItems[itemID] then
                        seenItems[itemID] = true
                        totalItems = totalItems + 1
                    end
                end
            end
            if mob.combat then
                for _ in pairs(mob.combat.spells or {}) do
                    totalSpells = totalSpells + 1
                end
                for _ in pairs(mob.combat.immunities or {}) do
                    totalImmunities = totalImmunities + 1
                end
            end
        end
    end

    self:Print("Creature Compendium Status:")
    print(string.format("  Zones Logged: |cffffd100%d|r", totalZones))
    print(string.format("  Creatures Registered: |cffffd100%d|r", totalMobs))
    print(string.format("  Creature Kills Tracked: |cffffd100%d|r", totalKills))
    print(string.format("  Loot Sessions: |cffffd100%d|r", totalLoots))
    print(string.format("  Profession Harvests: |cffffd100%d|r", totalHarvests or 0))
    print(string.format("  Distinct Items Tracked: |cffffd100%d|r", totalItems))
    print(string.format("  Unique Spells Discovered: |cffffd100%d|r", totalSpells))
    print(string.format("  Mob Immunities Verified: |cffffd100%d|r", totalImmunities))
    print(string.format("  Loot Mod: |cffffd100%s|r  |  Combat Mod: |cffffd100%s|r  |  Prof Mod: |cffffd100%s|r",
        self.db.settings.modifierKeyLoot or "SHIFT",
        self.db.settings.modifierKeyCombat or "CTRL",
        self.db.settings.modifierKeyProfession or "ALT"))
end

-- Search database for a mob by name and print stats to chat
function addon:LookupMob(query)
    query = string.lower(strtrim(query or ""))
    if query == "" then return end

    local matchesFound = 0
    self:Print("Compendium search results for: |cffffd100%s|r", query)

    for mapID, zone in pairs(self.db.zones or {}) do
        for npcID, mob in pairs(zone.mobs or {}) do
            local name = string.lower(mob.name or "")
            if string.find(name, query, 1, true) then
                matchesFound = matchesFound + 1
                local meta = string.format("Level %s %s",
                    mob.minLevel and (mob.minLevel == mob.maxLevel and mob.minLevel or (mob.minLevel .. "-" .. mob.maxLevel)) or "?",
                    mob.classification and mob.classification ~= "normal" and ("[" .. mob.classification .. "]") or "")

                print(string.format("  |cff00ff96%s|r (%s) in |cffffd100%s|r:", mob.name, meta, zone.name or "Zone"))

                -- Immunities
                local imms = self:GetMobImmunities(mob)
                if #imms > 0 then
                    local immStr = "    Immunities: "
                    for _, imm in ipairs(imms) do
                        local info = addon.IMMUNITY_COLORS[imm.key]
                        local hex = info and info.hex or "ffffd100"
                        immStr = immStr .. string.format("|cff%s[%s]|r ", hex, imm.name)
                    end
                    print(immStr)
                end

                -- Top Spells
                local spells = self:GetSortedSpellList(mob, 3)
                if #spells > 0 then
                    local spellStr = "    Spells: "
                    for _, sp in ipairs(spells) do
                        spellStr = spellStr .. string.format("|cffffffff%s|r (%d casts) ", sp.name, sp.casts or 1)
                    end
                    print(spellStr)
                end

                -- Top Items
                local items = self:GetSortedItemList(mob, 3, 0)
                if #items > 0 then
                    local itemStr = "    Top Drops: "
                    for _, it in ipairs(items) do
                        itemStr = itemStr .. string.format("%s (%s) ", addon:FormatQualityName(it.name, it.quality), it.dropChance or "0%")
                    end
                    print(itemStr)
                end

                -- Top Profession Drops
                local profItems = self:GetSortedProfessionItemList(mob, 3, 0)
                if #profItems > 0 then
                    local profStr = "    Professions: "
                    for _, it in ipairs(profItems) do
                        profStr = profStr .. string.format("[%s] %s (%s) ", it.profession or "Skinning", addon:FormatQualityName(it.name, it.quality), it.dropChance or "0%")
                    end
                    print(profStr)
                end

                if matchesFound >= 5 then
                    print("  |cff888888...more results truncated.|r")
                    return
                end
            end
        end
    end

    if matchesFound == 0 then
        print("  |cffff2020No recorded creatures matching that name found.|r")
    end
end
