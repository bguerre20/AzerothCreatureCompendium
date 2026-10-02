--[[
    Azeroth Creature Compendium - Tooltip.lua
    Dual companion sidecar tooltips:
    1. Loot Tooltip (Default: SHIFT) - Drop rates %, coins, sample counts
    2. Combat Tooltip (Default: CTRL) - Attacks, spells cast, and verified immunities
    Real-time modifier key detection and intelligent multi-panel positioning.
]]

local _, addon = ...

-- Formatted coin display helper
function addon:FormatCoinString(copper)
    if not copper or copper <= 0 then return "0c" end

    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        local str = C_CurrencyInfo.GetCoinTextureString(copper)
        if str and str ~= "" then return str end
    end

    if GetCoinTextureString then
        local str = GetCoinTextureString(copper)
        if str and str ~= "" then return str end
    end

    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = math.floor(copper % 100)

    local str = ""
    if g > 0 then str = str .. string.format("|cffffd700%dg|r ", g) end
    if s > 0 then str = str .. string.format("|cffc7c7cf%ds|r ", s) end
    if c > 0 or str == "" then str = str .. string.format("|cffeda55f%dc|r", c) end
    return str
end

-------------------------------------------------------------------------------
-- Companion Sidecar Frames
-------------------------------------------------------------------------------

-- 1. Dedicated Loot Tooltip Frame
local lootTooltip = CreateFrame("GameTooltip", "AzerothCompendiumLootTooltip", UIParent, "GameTooltipTemplate")
lootTooltip:SetFrameStrata("TOOLTIP")
lootTooltip:SetClampedToScreen(true)
addon.lootTooltip = lootTooltip

-- 2. Dedicated Combat & Immunities Tooltip Frame
local combatTooltip = CreateFrame("GameTooltip", "AzerothCompendiumCombatTooltip", UIParent, "GameTooltipTemplate")
combatTooltip:SetFrameStrata("TOOLTIP")
combatTooltip:SetClampedToScreen(true)
addon.combatTooltip = combatTooltip

-- 3. Dedicated Profession Tooltip Frame
local professionTooltip = CreateFrame("GameTooltip", "AzerothCompendiumProfessionTooltip", UIParent, "GameTooltipTemplate")
professionTooltip:SetFrameStrata("TOOLTIP")
professionTooltip:SetClampedToScreen(true)
addon.professionTooltip = professionTooltip

-- Check key modifier state
local function CheckModifier(modKey, alwaysShow)
    if modKey == "NEVER" then return false end
    if modKey == "ALWAYS" or modKey == "NONE" or alwaysShow then return true end
    modKey = modKey or "SHIFT"
    if modKey == "SHIFT" then return IsShiftKeyDown() end
    if modKey == "CTRL" then return IsControlKeyDown() end
    if modKey == "ALT" then return IsAltKeyDown() end
    return false
end

function addon:IsEmbeddedLayout()
    local s = self.db and self.db.settings
    if not s then return false end
    if s.tooltipLayout == "EMBEDDED" then return true end
    if s.separateTooltip == false then return true end
    return false
end

function addon:GetTooltipHintText(showLoot, showCombat, showProf)
    if not self.db or not self.db.settings or not self.db.settings.showHint then
        return nil
    end

    local lootKey = self.db.settings.modifierKeyLoot or "SHIFT"
    local combatKey = self.db.settings.modifierKeyCombat or "CTRL"
    local profKey = self.db.settings.modifierKeyProfession or "ALT"

    local hintParts = {}
    if lootKey ~= "ALWAYS" and lootKey ~= "NEVER" and not showLoot then
        table.insert(hintParts, string.format("[|cffffd100%s|r] Loot", lootKey))
    end
    if combatKey ~= "ALWAYS" and combatKey ~= "NEVER" and not showCombat then
        table.insert(hintParts, string.format("[|cffffd100%s|r] Combat", combatKey))
    end
    if profKey ~= "ALWAYS" and profKey ~= "NEVER" and not showProf then
        table.insert(hintParts, string.format("[|cffffd100%s|r] Prof", profKey))
    end

    if #hintParts > 0 then
        return "|cff00ff96[Compendium]|r |cff888888Hold " .. table.concat(hintParts, "  ") .. "|r"
    end
    return nil
end

function addon:IsLootModActive()
    local s = self.db and self.db.settings
    return CheckModifier(s and s.modifierKeyLoot, s and s.alwaysShowLoot)
end

function addon:IsCombatModActive()
    local s = self.db and self.db.settings
    return CheckModifier(s and s.modifierKeyCombat, s and s.alwaysShowCombat)
end

function addon:IsProfessionModActive()
    local s = self.db and self.db.settings
    return CheckModifier(s and s.modifierKeyProfession, s and s.alwaysShowProfession)
end

-------------------------------------------------------------------------------
-- Tooltip Content Renderers
-------------------------------------------------------------------------------

-- Render Loot Content
function addon:PopulateLootContent(tip, mob)
    local loot = mob.loot or {}
    local items, totalAvailable = self:GetSortedItemList(mob, self.db.settings.maxItems, self.db.settings.minQuality)

    if #items == 0 then
        tip:AddLine(string.format("  |cff888888No item drops recorded (%d empty loots)|r", loot.emptyLoots or 0))
    else
        for _, item in ipairs(items) do
            local iconStr = ""
            if item.icon then
                iconStr = string.format("|T%s:14:14:0:0|t ", item.icon)
            end

            local nameColored = self:FormatQualityName(item.name, item.quality)
            local leftCol = iconStr .. nameColored

            local rightCol
            if self.db.settings.showSample and item.dropLootCount then
                rightCol = string.format("|cffffffff%s|r |cff888888(%d)|r", item.dropChance or "0%", item.dropLootCount)
            else
                rightCol = string.format("|cffffffff%s|r", item.dropChance or "0%")
            end

            tip:AddDoubleLine(leftCol, rightCol)
        end

        if totalAvailable > #items then
            tip:AddLine(string.format("  |cff888888...and %d more items|r", totalAvailable - #items))
        end
    end

    if self.db.settings.showMoney and (loot.avgMoney or 0) > 0 then
        local coinDisplay = self:FormatCoinString(loot.avgMoney)
        tip:AddDoubleLine("  |cffccccccAvg Coin:|r", coinDisplay, 0.8, 0.8, 0.8, 1, 1, 1)
    end
end

-- Render Profession Harvest Content
function addon:PopulateProfessionContent(tip, mob)
    local prof = mob.professions or {}
    local items, totalAvailable = self:GetSortedProfessionItemList(mob, self.db.settings.maxItems, self.db.settings.minQuality)

    if #items == 0 then
        tip:AddLine(string.format("  |cff888888No gathering drops recorded (%d empty harvests)|r", prof.emptyHarvests or 0))
    else
        for _, item in ipairs(items) do
            local iconStr = ""
            if item.icon then
                iconStr = string.format("|T%s:14:14:0:0|t ", item.icon)
            end

            local profTag = ""
            if item.profession then
                local col = "c7a16b"
                if item.profession == "Skinning" then col = "cc9966"
                elseif item.profession == "Mining" then col = "70b0ff"
                elseif item.profession == "Herbalism" then col = "55ee77"
                elseif item.profession == "Engineering" then col = "ffaa33"
                end
                profTag = string.format("|cff%s[%s]|r ", col, item.profession)
            end

            local nameColored = self:FormatQualityName(item.name, item.quality)
            local leftCol = iconStr .. profTag .. nameColored

            local rightCol
            if self.db.settings.showSample and (item.dropLootCount or item.harvestCount) then
                rightCol = string.format("|cffffffff%s|r |cff888888(%d)|r", item.dropChance or "0%", item.dropLootCount or item.harvestCount or 0)
            else
                rightCol = string.format("|cffffffff%s|r", item.dropChance or "0%")
            end

            tip:AddDoubleLine(leftCol, rightCol)
        end

        if totalAvailable > #items then
            tip:AddLine(string.format("  |cff888888...and %d more harvest items|r", totalAvailable - #items))
        end
    end

    -- Skill breakdown if multiple skills recorded
    if prof.bySkill then
        local parts = {}
        for sName, sData in pairs(prof.bySkill) do
            if sData.totalHarvests and sData.totalHarvests > 0 then
                table.insert(parts, string.format("|cffffd100%s:|r %d", sName, sData.totalHarvests))
            end
        end
        if #parts > 0 then
            tip:AddLine(" ")
            tip:AddLine("  " .. table.concat(parts, "  "))
        end
    end
end

-- Render Combat & Immunities Content
function addon:PopulateCombatContent(tip, mob)
    local combat = mob.combat or {}

    -- 1. Creature Classification & Subtitle
    local metaParts = {}
    if mob.minLevel then
        if mob.minLevel == mob.maxLevel then
            table.insert(metaParts, "Level " .. mob.minLevel)
        else
            table.insert(metaParts, string.format("Level %d-%d", mob.minLevel, mob.maxLevel))
        end
    end
    if mob.classification and mob.classification ~= "normal" then
        table.insert(metaParts, string.upper(mob.classification:sub(1,1)) .. mob.classification:sub(2))
    end
    if mob.creatureType then
        table.insert(metaParts, mob.creatureType)
    end

    if #metaParts > 0 then
        tip:AddLine(string.format("|cffc7a16b%s|r", table.concat(metaParts, " ")))
        tip:AddLine(" ")
    end

    -- 2. Immunities Badges
    local imms = self:GetMobImmunities(mob)
    if #imms > 0 then
        tip:AddLine("|cffffd100Known Immunities:|r")
        local immBadges = ""
        for _, imm in ipairs(imms) do
            local info = addon.IMMUNITY_COLORS[imm.key]
            local hex = (info and info.hex) or "ffffff"
            local text = (info and info.text) or imm.name or imm.key
            local iconStr = ""
            if info and info.icon then
                iconStr = string.format("|T%s:12:12:0:0|t", info.icon)
            end
            immBadges = immBadges .. string.format(" %s|cff%s[%s]|r", iconStr, hex, text)
        end
        tip:AddLine(" " .. immBadges)
        tip:AddLine(" ")
    end

    -- 3. Melee / Auto-Attacks
    local atk = combat.attacks
    if atk and (atk.swings or 0) > 0 then
        local dmgStr
        if atk.minDmg > 0 and atk.maxDmg > 0 then
            dmgStr = string.format("|cffffffff%d - %d|r (avg |cffffd100%d|r)", atk.minDmg, atk.maxDmg, atk.avgDmg)
        else
            dmgStr = "|cff888888Observed in combat|r"
        end
        tip:AddDoubleLine("|cffffd100Melee Swing:|r", dmgStr)
    end

    -- 4. Spells & Special Abilities
    local spells = self:GetSortedSpellList(mob, self.db.settings.maxSpells or 8)
    if #spells > 0 then
        tip:AddLine("|cffffd100Abilities & Spells:|r")
        for _, sp in ipairs(spells) do
            local iconStr = ""
            if sp.icon then
                iconStr = string.format("|T%s:14:14:0:0|t ", sp.icon)
            end

            -- Color spell name by school
            local schoolInfo = addon.SCHOOL_MASKS[sp.school or 1]
            local schoolHex = schoolInfo and schoolInfo.color or "ffffff"
            local spellNameCol = string.format("|cff%s%s|r", schoolHex, sp.name or ("Spell " .. sp.id))
            local leftCol = "  " .. iconStr .. spellNameCol

            local rightCol
            if sp.avgDmg and sp.avgDmg > 0 then
                rightCol = string.format("|cffffffff%d-%d|r |cff888888(%d casts)|r", sp.minDmg or sp.avgDmg, sp.maxDmg or sp.avgDmg, sp.casts or 1)
            elseif sp.isHeal then
                rightCol = string.format("|cff44ff44Heal|r |cff888888(%d casts)|r", sp.casts or 1)
            elseif sp.isBuff then
                rightCol = string.format("|cff71d5ffBuff|r |cff888888(%d casts)|r", sp.casts or 1)
            elseif sp.isDebuff then
                rightCol = string.format("|cffff5533Debuff|r |cff888888(%d casts)|r", sp.casts or 1)
            else
                rightCol = string.format("|cff888888%d casts|r", sp.casts or 1)
            end

            tip:AddDoubleLine(leftCol, rightCol)
        end
    end

    if #imms == 0 and (not atk or (atk.swings or 0) == 0) and #spells == 0 then
        tip:AddLine("  |cff888888No combat data recorded yet.|r")
    end

    -- 5. Kills and encounters footer
    if (mob.kills or 0) > 0 or (mob.encounters or 0) > 0 then
        tip:AddLine(" ")
        local statsStr = string.format("|cff888888Kills: |r|cffffffff%d|r", mob.kills or 0)
        if (mob.loot and mob.loot.totalLoots or 0) > 0 then
            statsStr = statsStr .. string.format("  |cff888888Loots: |r|cffffffff%d|r", mob.loot.totalLoots)
        end
        tip:AddLine("  " .. statsStr)
    end
end

-------------------------------------------------------------------------------
-- Dual Companion Sidecar Positioning & Layout Engine
-------------------------------------------------------------------------------

function addon:UpdateCompanionTooltips(mob, unrecordedName)
    if self:IsEmbeddedLayout() or ((not mob and not unrecordedName) or not GameTooltip:IsShown()) then
        lootTooltip:Hide()
        combatTooltip:Hide()
        professionTooltip:Hide()
        return
    end

    local showLoot = self:IsLootModActive()
    local showCombat = self:IsCombatModActive()
    local showProf = self:IsProfessionModActive()

    local activeTooltips = {}
    local tipAnchor = (self.db and self.db.settings and self.db.settings.tooltipAnchor) or "BLIZZARD"

    local function PrepareSidecar(tip, isShown)
        if not isShown then
            tip:Hide()
            return false
        end
        local isLead = (tipAnchor == "CURSOR" and #activeTooltips == 0)
        if isLead then
            tip:SetOwner(UIParent, "ANCHOR_CURSOR")
        else
            tip:SetOwner(UIParent, "ANCHOR_NONE")
            tip:ClearAllPoints()
        end
        tip:ClearLines()
        return true
    end

    -- 1. Setup Loot Tooltip
    if PrepareSidecar(lootTooltip, showLoot) then
        if mob then
            local lootsCount = (mob.loot and mob.loot.totalLoots) or mob.totalLoots or 0
            lootTooltip:AddLine(string.format("|cff00ff96Compendium - Loot|r |cff888888(%d loots)|r", lootsCount))
            lootTooltip:AddLine(" ")
            self:PopulateLootContent(lootTooltip, mob)
        else
            lootTooltip:AddLine("|cff00ff96Compendium - Loot|r")
            lootTooltip:AddLine(" ")
            lootTooltip:AddLine("  |cff888888You have not encountered this creature yet.|r")
            lootTooltip:AddLine("  |cff888888Defeat and loot to record item drops.|r")
        end

        lootTooltip:Show()
        table.insert(activeTooltips, lootTooltip)
    end

    -- 2. Setup Combat Tooltip
    if PrepareSidecar(combatTooltip, showCombat) then
        combatTooltip:AddLine("|cffe5c158Compendium - Combat|r")
        if mob then
            self:PopulateCombatContent(combatTooltip, mob)
        else
            combatTooltip:AddLine(" ")
            combatTooltip:AddLine("  |cff888888You have not encountered this creature yet.|r")
            combatTooltip:AddLine("  |cff888888Engage in combat to discover attacks, spells, and immunities.|r")
        end

        combatTooltip:Show()
        table.insert(activeTooltips, combatTooltip)
    end

    -- 3. Setup Profession Tooltip
    if PrepareSidecar(professionTooltip, showProf) then
        if mob then
            local harvestsCount = (mob.professions and mob.professions.totalHarvests) or 0
            professionTooltip:AddLine(string.format("|cffc7a16bCompendium - Professions|r |cff888888(%d harvests)|r", harvestsCount))
            professionTooltip:AddLine(" ")
            self:PopulateProfessionContent(professionTooltip, mob)
        else
            professionTooltip:AddLine("|cffc7a16bCompendium - Professions|r")
            professionTooltip:AddLine(" ")
            professionTooltip:AddLine("  |cff888888You have not encountered this creature yet.|r")
            professionTooltip:AddLine("  |cff888888Gather or skin this creature to discover profession loot.|r")
        end

        professionTooltip:Show()
        table.insert(activeTooltips, professionTooltip)
    end

    -- 4. Position active tooltips based on configured docking orientation and anchor type
    if #activeTooltips == 0 then return end

    local anchorMode = (self.db and self.db.settings and self.db.settings.sidecarAnchor) or "HORIZONTAL"
    local prevTip = (tipAnchor == "CURSOR") and activeTooltips[1] or GameTooltip
    local startIndex = (tipAnchor == "CURSOR") and 2 or 1

    if anchorMode == "VERTICAL" then
        -- Vertical Stacking (Above or Below)
        local tipTop
        if tipAnchor == "CURSOR" then
            local curY = select(2, GetCursorPosition()) / (UIParent:GetEffectiveScale() or 1)
            tipTop = curY + 50
        else
            tipTop = GameTooltip:GetTop() or 0
        end

        local screenHeight = GetScreenHeight() or 1080
        local stackBelow = tipTop > (screenHeight - 220)

        for idx = startIndex, #activeTooltips do
            local tip = activeTooltips[idx]
            tip:ClearAllPoints()
            if stackBelow then
                tip:SetPoint("TOPLEFT", prevTip, "BOTTOMLEFT", 0, -4)
            else
                tip:SetPoint("BOTTOMLEFT", prevTip, "TOPLEFT", 0, 4)
            end
            prevTip = tip
        end
    else
        -- Horizontal Stacking (Beside: Left/Right dynamic clamp)
        local rightEdge
        if tipAnchor == "CURSOR" then
            local curX = GetCursorPosition() / (UIParent:GetEffectiveScale() or 1)
            rightEdge = curX + 220
        else
            rightEdge = GameTooltip:GetRight() or 0
        end

        local screenWidth = GetScreenWidth() or 1920
        local placeOnLeft = rightEdge > (screenWidth - 280)

        for idx = startIndex, #activeTooltips do
            local tip = activeTooltips[idx]
            tip:ClearAllPoints()
            if placeOnLeft then
                tip:SetPoint("TOPRIGHT", prevTip, "TOPLEFT", -4, 0)
            else
                tip:SetPoint("TOPLEFT", prevTip, "TOPRIGHT", 4, 0)
            end
            prevTip = tip
        end
    end
end

-------------------------------------------------------------------------------
-- Tooltip Unit Inspection Hooks
-------------------------------------------------------------------------------

function addon:OnTooltipSetUnit(tooltip, data)
    if not tooltip or not self.db then return end

    local _, unit = tooltip:GetUnit()
    local guid = nil

    if unit and UnitExists(unit) then
        guid = UnitGUID(unit)
    elseif data and data.guid then
        guid = data.guid
    end

    if not guid then
        lootTooltip:Hide()
        combatTooltip:Hide()
        professionTooltip:Hide()
        return
    end

    local npcID = self:GetNPCIDFromGUID(guid)
    if not npcID then
        lootTooltip:Hide()
        combatTooltip:Hide()
        professionTooltip:Hide()
        return
    end

    -- Fetch recorded creature data
    local mapID = C_Map.GetBestMapForUnit("player") or 0
    local mob = self:GetMobData(npcID, mapID)

    -- Resolve creature name
    local unitName = (unit and UnitExists(unit) and self:SafeString(UnitName(unit), nil))
    if not unitName and tooltip.GetUnit then
        local ok, tipName = pcall(function() return select(1, tooltip:GetUnit()) end)
        if ok and tipName then
            unitName = self:SafeString(tipName, nil)
        end
    end
    unitName = unitName or (mob and mob.name) or "Creature"

    local showLoot = self:IsLootModActive()
    local showCombat = self:IsCombatModActive()
    local showProf = self:IsProfessionModActive()

    -- Check if player selected Embedded layout mode (single merged tooltip)
    if self:IsEmbeddedLayout() then
        lootTooltip:Hide()
        combatTooltip:Hide()
        professionTooltip:Hide()

        local hintText = self:GetTooltipHintText(showLoot, showCombat, showProf)

        if not mob then
            tooltip:AddLine("|cff00ff96[Compendium]|r |cff888888New creature — No encounters recorded yet|r")
            if hintText then
                tooltip:AddLine(hintText)
            end

            if showLoot then
                tooltip:AddLine(" ")
                tooltip:AddLine("|cff00ff96Compendium - Loot|r")
                tooltip:AddLine("  |cff888888You have not encountered this creature yet.|r")
                tooltip:AddLine("  |cff888888Defeat and loot to record item drops.|r")
            end
            if showCombat then
                tooltip:AddLine(" ")
                tooltip:AddLine("|cffe5c158Compendium - Combat|r")
                tooltip:AddLine("  |cff888888You have not encountered this creature yet.|r")
                tooltip:AddLine("  |cff888888Engage in combat to discover attacks, spells, and immunities.|r")
            end
            if showProf then
                tooltip:AddLine(" ")
                tooltip:AddLine("|cffc7a16bCompendium - Professions|r")
                tooltip:AddLine("  |cff888888You have not encountered this creature yet.|r")
                tooltip:AddLine("  |cff888888Gather or skin this creature to discover profession loot.|r")
            end

            if self.db.settings.tooltipAnchor == "CURSOR" then
                local curX, curY = GetCursorPosition()
                local effScale = UIParent:GetEffectiveScale() or 1
                tooltip:ClearAllPoints()
                tooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (curX / effScale) + 16, (curY / effScale) + 16)
            end

            tooltip:Show()
            return
        end

        if hintText then
            tooltip:AddLine(hintText)
        end

        if showLoot then
            tooltip:AddLine(" ")
            local lootsCount = (mob.loot and mob.loot.totalLoots) or mob.totalLoots or 0
            tooltip:AddLine(string.format("|cff00ff96Compendium - Loot|r |cff888888(%d loots)|r", lootsCount))
            self:PopulateLootContent(tooltip, mob)
        end
        if showCombat then
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffe5c158Compendium - Combat|r")
            self:PopulateCombatContent(tooltip, mob)
        end
        if showProf then
            tooltip:AddLine(" ")
            local harvestsCount = (mob.professions and mob.professions.totalHarvests) or 0
            tooltip:AddLine(string.format("|cffc7a16bCompendium - Professions|r |cff888888(%d harvests)|r", harvestsCount))
            self:PopulateProfessionContent(tooltip, mob)
        end

        if self.db.settings.tooltipAnchor == "CURSOR" then
            local curX, curY = GetCursorPosition()
            local effScale = UIParent:GetEffectiveScale() or 1
            tooltip:ClearAllPoints()
            tooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (curX / effScale) + 16, (curY / effScale) + 16)
        end

        tooltip:Show()
        return
    end

    -- Dedicated Sidecars Layout Mode
    if not mob then
        -- First mob encounter - inform player and render discovery status
        tooltip:AddLine("|cff00ff96[Compendium]|r |cff888888New creature — No encounters recorded yet|r")

        local hintText = self:GetTooltipHintText(showLoot, showCombat, showProf)
        if hintText then
            tooltip:AddLine(hintText)
        end

        self:UpdateCompanionTooltips(nil, unitName)
        return
    end

    -- Add dynamic hint line to GameTooltip if hints enabled and hotkeys remain to be pressed
    local hintText = self:GetTooltipHintText(showLoot, showCombat, showProf)
    if hintText then
        tooltip:AddLine(hintText)
    end

    self:UpdateCompanionTooltips(mob)
end

-- Tooltip OnHide cleanup
GameTooltip:HookScript("OnHide", function()
    if lootTooltip then lootTooltip:Hide() end
    if combatTooltip then combatTooltip:Hide() end
    if professionTooltip then professionTooltip:Hide() end
end)

-- Register Tooltip PostCall / Script hook
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
        addon:OnTooltipSetUnit(tooltip, data)
    end)
else
    GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
        addon:OnTooltipSetUnit(tooltip)
    end)
end

-- Real-time Tooltip Refresh on Modifier Key State Changes
local modWatcher = CreateFrame("Frame", "AzerothCompendiumModWatcher")
modWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
modWatcher:SetScript("OnEvent", function(self, event)
    if not GameTooltip:IsShown() then
        if lootTooltip then lootTooltip:Hide() end
        if combatTooltip then combatTooltip:Hide() end
        if professionTooltip then professionTooltip:Hide() end
        return
    end

    local _, unit = GameTooltip:GetUnit()
    if not unit and UnitExists("mouseover") then
        unit = "mouseover"
    end

    if unit and UnitExists(unit) then
        local guid = UnitGUID(unit)
        local npcID = addon:GetNPCIDFromGUID(guid)
        if not npcID then
            lootTooltip:Hide()
            combatTooltip:Hide()
            professionTooltip:Hide()
            return
        end

        local mapID = C_Map.GetBestMapForUnit("player") or 0
        local mob = addon:GetMobData(npcID, mapID)
        local unitName = addon:SafeString(UnitName(unit), (mob and mob.name) or "Creature")

        if addon:IsEmbeddedLayout() then
            if not addon.isRefreshingTip then
                addon.isRefreshingTip = true
                GameTooltip:SetUnit(unit)
                addon.isRefreshingTip = false
            end
        else
            addon:UpdateCompanionTooltips(mob, unitName)
        end
    else
        lootTooltip:Hide()
        combatTooltip:Hide()
        professionTooltip:Hide()
    end
end)
