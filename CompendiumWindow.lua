--[[
    Azeroth Creature Compendium - CompendiumWindow.lua
    Authentic Classic 1.15 Bronze/Copper Two-Pane Pokédex Window:
    - Left Pane: Searchable Zone and Creature registry tree
    - Right Pane: Creature Pokédex Card with interactive 3D model,
      metadata, and dedicated [Combat & Abilities] and [Loot Table] tabs!
    - Draggable Minimap Button with dynamic HUD scaling.
]]

local _, addon = ...

-- State tracking
addon.zoneExpanded = {}
addon.selectedTab = "COMBAT" -- "COMBAT", "LOOT", or "PROFESSIONS"
addon.searchText = ""

local ROW_HEIGHT = 24
local NUM_LEFT_ROWS = 17
local NUM_RIGHT_ROWS = 8
local RIGHT_ROW_HEIGHT = 28

-------------------------------------------------------------------------------
-- 1. Main Pokédex Browser Window
-------------------------------------------------------------------------------
function addon:CreateCompendiumWindow()
    if self.browserWindow then return self.browserWindow end

    local frame = CreateFrame("Frame", "AzerothCompendiumFrame", UIParent, "ButtonFrameTemplate")
    frame:SetSize(780, 560)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    tinsert(UISpecialFrames, "AzerothCompendiumFrame")

    -- Window Title
    if frame.SetTitle then
        frame:SetTitle("|cff00ff96Azeroth Creature Compendium|r")
    else
        local title = frame.TitleText or _G[frame:GetName() .. "TitleText"]
        if title then
            title:SetText("|cff00ff96Azeroth Creature Compendium|r")
        end
    end

    -- Window Portrait: Golden Tome
    if frame.SetPortraitToAsset then
        frame:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Book_09")
    elseif SetPortraitToTexture and frame.portrait then
        SetPortraitToTexture(frame.portrait, "Interface\\Icons\\INV_Misc_Book_09")
    end

    -- Search Box
    local searchBox = CreateFrame("EditBox", "AzerothCompendiumSearchBox", frame, "SearchBoxTemplate")
    searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 64, -28)
    searchBox:SetSize(210, 22)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("GameFontHighlightSmall")
    searchBox.Instructions:SetText("Search zone, mob, spell, item...")
    searchBox:SetScript("OnTextChanged", function(editBox)
        SearchBoxTemplate_OnTextChanged(editBox)
        addon.searchText = string.lower(strtrim(editBox:GetText() or ""))
        addon:RefreshTreeList()
    end)
    self.searchBox = searchBox

    -- Top Summary Counter
    local summaryText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    summaryText:SetPoint("LEFT", searchBox, "RIGHT", 14, 0)
    summaryText:SetTextColor(0.78, 0.63, 0.42, 1) -- Warm bronze
    summaryText:SetText("0 zones | 0 creatures discovered")
    self.summaryText = summaryText

    -- "Expand All" / "Collapse All" Button
    local toggleAllBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    toggleAllBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, -28)
    toggleAllBtn:SetSize(100, 22)
    toggleAllBtn:SetText("|cffffd100Collapse All|r")
    toggleAllBtn:SetScript("OnClick", function(btn)
        if btn:GetText() == "|cffffd100Collapse All|r" or btn:GetText() == "Collapse All" then
            addon.zoneExpanded = {}
            btn:SetText("|cffffd100Expand All|r")
        else
            for mapID in pairs(addon.db.zones or {}) do
                addon.zoneExpanded[mapID] = true
            end
            btn:SetText("|cffffd100Collapse All|r")
        end
        addon:RefreshTreeList()
    end)
    self.toggleAllBtn = toggleAllBtn

    ---------------------------------------------------------------------------
    -- LEFT PANE: Creature Registry List (Width ~260px)
    ---------------------------------------------------------------------------
    local leftInset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    leftInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -56)
    leftInset:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 14)
    leftInset:SetWidth(260)

    local leftScroll = CreateFrame("ScrollFrame", "AzerothCompendiumLeftScrollFrame", leftInset, "FauxScrollFrameTemplate")
    leftScroll:SetPoint("TOPLEFT", leftInset, "TOPLEFT", 4, -4)
    leftScroll:SetPoint("BOTTOMRIGHT", leftInset, "BOTTOMRIGHT", -26, 4)
    leftScroll:SetScript("OnVerticalScroll", function(scroll, offset)
        FauxScrollFrame_OnVerticalScroll(scroll, offset, ROW_HEIGHT, function()
            addon:UpdateTreeListRows()
        end)
    end)
    self.leftScroll = leftScroll

    -- Left Rows
    self.leftRows = {}
    for i = 1, NUM_LEFT_ROWS do
        local row = CreateFrame("Button", "AzerothCompendiumLeftRow" .. i, leftInset)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("LEFT", leftInset, "LEFT", 4, 0)
        row:SetPoint("RIGHT", leftScroll, "RIGHT", 0, 0)
        row:SetPoint("TOP", leftScroll, "TOP", 0, -((i - 1) * ROW_HEIGHT))

        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 0.85, 0.5, 0.10)

        -- Persistent selection texture
        row.selectTex = row:CreateTexture(nil, "BACKGROUND")
        row.selectTex:SetAllPoints()
        row.selectTex:SetColorTexture(0.2, 0.6, 1.0, 0.20)
        row.selectTex:Hide()

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(14, 14)
        row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)

        row.title = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.title:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.title:SetJustifyH("LEFT")

        row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.value:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.value:SetJustifyH("RIGHT")

        row:SetScript("OnClick", function(btn)
            local data = btn.data
            if not data then return end

            if data.type == "ZONE" then
                addon.zoneExpanded[data.id] = not addon.zoneExpanded[data.id]
                addon:RefreshTreeList()
            elseif data.type == "MOB" then
                addon.selectedMob = data.mob
                addon:RefreshSelectedMobCard()
                addon:UpdateTreeListRows()
            end
        end)

        self.leftRows[i] = row
    end

    ---------------------------------------------------------------------------
    -- RIGHT PANE: Pokédex Entry Card (Width ~484px)
    ---------------------------------------------------------------------------
    local rightInset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    rightInset:SetPoint("TOPLEFT", leftInset, "TOPRIGHT", 6, 0)
    rightInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 14)
    self.rightInset = rightInset

    -- Empty state notice
    local emptyNotice = rightInset:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    emptyNotice:SetPoint("CENTER", rightInset, "CENTER", 0, 20)
    emptyNotice:SetWidth(380)
    emptyNotice:SetJustifyH("CENTER")
    emptyNotice:SetText("|cff888888Select a creature from the registry on the left to inspect its profile, 3D model, combat abilities, immunities, and loot drops.|r")
    self.emptyNotice = emptyNotice

    -- Mob Card Container Frame
    local mobCard = CreateFrame("Frame", nil, rightInset)
    mobCard:SetAllPoints()
    mobCard:Hide()
    self.mobCard = mobCard

    -- 3D Creature Model Container Frame (Clean sliced bronze border, no overlay lines)
    local modelContainer = CreateFrame("Frame", nil, mobCard, "BackdropTemplate")
    modelContainer:SetSize(116, 116)
    modelContainer:SetPoint("TOPLEFT", mobCard, "TOPLEFT", 12, -12)
    modelContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    modelContainer:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
    modelContainer:SetBackdropBorderColor(0.68, 0.52, 0.35, 1) -- Warm classic bronze

    -- 3D Creature Model Frame (Interactive Pokédex Viewer)
    local model = CreateFrame("PlayerModel", "AzerothCompendium3DModel", modelContainer)
    model:SetPoint("TOPLEFT", modelContainer, "TOPLEFT", 4, -4)
    model:SetPoint("BOTTOMRIGHT", modelContainer, "BOTTOMRIGHT", -4, 4)
    model:EnableMouse(true)

    -- Fallback 2D Creature Icon (when 3D model unavailable)
    local fallbackIcon = model:CreateTexture(nil, "ARTWORK")
    fallbackIcon:SetSize(48, 48)
    fallbackIcon:SetPoint("CENTER", model, "CENTER", 0, 0)
    fallbackIcon:SetTexture("Interface\\Icons\\INV_Misc_Head_Dragon_01")
    fallbackIcon:Hide()
    self.modelFallback = fallbackIcon

    -- 360-Degree Interactive Model Rotation on Left Drag
    model:SetScript("OnMouseDown", function(selfModel, button)
        if button == "LeftButton" then
            selfModel.isDragging = true
            local startX, _ = GetCursorPosition()
            selfModel.startX = startX
            selfModel.startFacing = selfModel:GetFacing() or 0
        end
    end)
    model:SetScript("OnMouseUp", function(selfModel, button)
        if button == "LeftButton" then
            selfModel.isDragging = false
        end
    end)
    model:SetScript("OnUpdate", function(selfModel)
        if selfModel.isDragging then
            local currentX, _ = GetCursorPosition()
            local diff = (currentX - selfModel.startX) * 0.015
            selfModel:SetFacing(selfModel.startFacing + diff)
        end
    end)
    self.creatureModel = model
    self.modelContainer = modelContainer

    -- Creature Title & Metadata (Right of 3D Model)
    local mobNameText = mobCard:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    mobNameText:SetPoint("TOPLEFT", modelContainer, "TOPRIGHT", 14, -2)
    mobNameText:SetJustifyH("LEFT")
    self.mobNameText = mobNameText

    local mobMetaText = mobCard:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    mobMetaText:SetPoint("TOPLEFT", mobNameText, "BOTTOMLEFT", 0, -4)
    mobMetaText:SetJustifyH("LEFT")
    self.mobMetaText = mobMetaText

    local mobStatsText = mobCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    mobStatsText:SetPoint("TOPLEFT", mobMetaText, "BOTTOMLEFT", 0, -6)
    mobStatsText:SetTextColor(0.78, 0.63, 0.42, 1)
    mobStatsText:SetJustifyH("LEFT")
    self.mobStatsText = mobStatsText

    local mobCoordsText = mobCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    mobCoordsText:SetPoint("TOPLEFT", mobStatsText, "BOTTOMLEFT", 0, -4)
    mobCoordsText:SetJustifyH("LEFT")
    self.mobCoordsText = mobCoordsText

    -- Model Spin Hint
    local spinHint = mobCard:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    spinHint:SetPoint("TOPLEFT", modelContainer, "BOTTOMLEFT", 0, -4)
    spinHint:SetText("|cff666666(Drag 3D model to rotate)|r")

    -- Divider between header and tab content
    local headerDivider = mobCard:CreateLine()
    headerDivider:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    headerDivider:SetStartPoint("TOPLEFT", modelContainer, "BOTTOMLEFT", 0, -18)
    headerDivider:SetEndPoint("TOPRIGHT", mobCard, "TOPRIGHT", -12, -130)
    headerDivider:SetThickness(1)

    -- Tab Switcher Buttons (Authentic Bronze Style)
    local tabCombat = CreateFrame("Button", nil, mobCard, "UIPanelButtonTemplate")
    tabCombat:SetPoint("TOPLEFT", modelContainer, "BOTTOMLEFT", 0, -26)
    tabCombat:SetSize(145, 24)
    tabCombat:SetText("|cffffd100Combat & Abilities|r")
    tabCombat:Show()

    local tabLoot = CreateFrame("Button", nil, mobCard, "UIPanelButtonTemplate")
    tabLoot:SetPoint("LEFT", tabCombat, "RIGHT", 6, 0)
    tabLoot:SetSize(110, 24)
    tabLoot:SetText("|cffffffffLoot Table|r")
    tabLoot:Show()

    local tabProfessions = CreateFrame("Button", nil, mobCard, "UIPanelButtonTemplate")
    tabProfessions:SetPoint("LEFT", tabLoot, "RIGHT", 6, 0)
    tabProfessions:SetSize(115, 24)
    tabProfessions:SetText("|cffffffffProfessions|r")
    tabProfessions:Show()

    local function UpdateTabHighlight()
        if addon.selectedTab == "COMBAT" then
            tabCombat:SetText("|cffffd100Combat & Abilities|r")
            tabLoot:SetText("|cffffffffLoot Table|r")
            tabProfessions:SetText("|cffffffffProfessions|r")
        elseif addon.selectedTab == "LOOT" then
            tabCombat:SetText("|cffffffffCombat & Abilities|r")
            tabLoot:SetText("|cffffd100Loot Table|r")
            tabProfessions:SetText("|cffffffffProfessions|r")
        elseif addon.selectedTab == "PROFESSIONS" then
            tabCombat:SetText("|cffffffffCombat & Abilities|r")
            tabLoot:SetText("|cffffffffLoot Table|r")
            tabProfessions:SetText("|cffffd100Professions|r")
        end
    end

    tabCombat:SetScript("OnClick", function()
        addon.selectedTab = "COMBAT"
        UpdateTabHighlight()
        addon:RefreshSelectedMobCard()
    end)

    tabLoot:SetScript("OnClick", function()
        addon.selectedTab = "LOOT"
        UpdateTabHighlight()
        addon:RefreshSelectedMobCard()
    end)

    tabProfessions:SetScript("OnClick", function()
        addon.selectedTab = "PROFESSIONS"
        UpdateTabHighlight()
        addon:RefreshSelectedMobCard()
    end)

    self.tabCombatBtn = tabCombat
    self.tabLootBtn = tabLoot
    self.tabProfessionsBtn = tabProfessions
    self.UpdateTabHighlight = UpdateTabHighlight

    -- Sub-header inside Card (Immunities summary / coin info)
    local cardSubHeader = mobCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cardSubHeader:SetPoint("TOPLEFT", tabCombat, "BOTTOMLEFT", 2, -10)
    cardSubHeader:SetJustifyH("LEFT")
    self.cardSubHeader = cardSubHeader

    -- Right Content Scroll Frame
    local rightScroll = CreateFrame("ScrollFrame", "AzerothCompendiumRightScrollFrame", mobCard, "FauxScrollFrameTemplate")
    rightScroll:SetPoint("TOPLEFT", cardSubHeader, "BOTTOMLEFT", 0, -8)
    rightScroll:SetPoint("BOTTOMRIGHT", mobCard, "BOTTOMRIGHT", -26, 8)
    rightScroll:SetScript("OnVerticalScroll", function(scroll, offset)
        FauxScrollFrame_OnVerticalScroll(scroll, offset, RIGHT_ROW_HEIGHT, function()
            addon:UpdateRightCardRows()
        end)
    end)
    self.rightScroll = rightScroll

    -- Right Content Rows (for Spells or Items)
    self.rightRows = {}
    for i = 1, NUM_RIGHT_ROWS do
        local rRow = CreateFrame("Button", "AzerothCompendiumRightRow" .. i, mobCard)
        rRow:SetHeight(RIGHT_ROW_HEIGHT)
        rRow:SetPoint("LEFT", mobCard, "LEFT", 12, 0)
        rRow:SetPoint("RIGHT", rightScroll, "RIGHT", 0, 0)
        rRow:SetPoint("TOP", rightScroll, "TOP", 0, -((i - 1) * RIGHT_ROW_HEIGHT))

        local rHigh = rRow:CreateTexture(nil, "HIGHLIGHT")
        rHigh:SetAllPoints()
        rHigh:SetColorTexture(1, 0.85, 0.5, 0.08)

        rRow.icon = rRow:CreateTexture(nil, "ARTWORK")
        rRow.icon:SetSize(20, 20)
        rRow.icon:SetPoint("LEFT", rRow, "LEFT", 4, 0)

        rRow.title = rRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        rRow.title:SetPoint("LEFT", rRow.icon, "RIGHT", 8, 0)
        rRow.title:SetJustifyH("LEFT")

        rRow.desc = rRow:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        rRow.desc:SetPoint("LEFT", rRow.title, "RIGHT", 8, 0)
        rRow.desc:SetTextColor(0.6, 0.6, 0.6, 1)

        rRow.value = rRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        rRow.value:SetPoint("RIGHT", rRow, "RIGHT", -6, 0)
        rRow.value:SetJustifyH("RIGHT")

        -- Tooltips on Hover
        rRow:SetScript("OnEnter", function(btn)
            local itemData = btn.itemData
            local spellData = btn.spellData
            if itemData and itemData.itemLink then
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(itemData.itemLink)
                GameTooltip:Show()
            elseif spellData and spellData.id then
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                if GameTooltip.SetSpellByID then
                    GameTooltip:SetSpellByID(spellData.id)
                else
                    GameTooltip:AddLine(spellData.name or "Spell", 1, 1, 1)
                end
                GameTooltip:Show()
            end
        end)

        rRow:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        rRow:SetScript("OnClick", function(btn)
            local itemData = btn.itemData
            if itemData and itemData.itemLink and IsModifiedClick("CHATLINK") then
                ChatEdit_InsertLink(itemData.itemLink)
            end
        end)

        self.rightRows[i] = rRow
    end

    self.browserWindow = frame
    return frame
end

-------------------------------------------------------------------------------
-- 2. Tree List & Pokédex Card Refresh
-------------------------------------------------------------------------------

function addon:BuildTreeList()
    local list = {}
    local query = self.searchText or ""
    local totalZones = 0
    local totalMobs = 0
    local totalItems = 0
    local totalSpells = 0

    local sortedZones = {}
    for mapID, zone in pairs(self.db.zones or {}) do
        table.insert(sortedZones, { id = mapID, name = zone.name or "Zone", mobs = zone.mobs or {} })
    end
    table.sort(sortedZones, function(a, b) return a.name < b.name end)

    for _, zone in ipairs(sortedZones) do
        totalZones = totalZones + 1
        local zoneMobs = {}
        for _, mob in pairs(zone.mobs) do
            table.insert(zoneMobs, mob)
        end
        table.sort(zoneMobs, function(a, b) return (a.name or "") < (b.name or "") end)

        local zoneMatches = (query == "" or string.find(string.lower(zone.name), query, 1, true))

        local matchingMobs = {}
        for _, mob in ipairs(zoneMobs) do
            local hasKilled = (mob.kills and mob.kills > 0)
            local hasLooted = (mob.loot and (mob.loot.totalLoots or 0) > 0) or ((mob.totalLoots or 0) > 0)
            local hasHarvested = (mob.professions and (mob.professions.totalHarvests or 0) > 0)

            -- ONLY track mobs the player has killed, looted, or harvested!
            local isRareMob = (mob.classification == "rare" or mob.classification == "rareelite")
            -- Track mobs the player has killed, looted, harvested, or spotted rare spawns!
            if hasKilled or hasLooted or hasHarvested or isRareMob then
                totalMobs = totalMobs + 1
                local mobMatches = zoneMatches or string.find(string.lower(mob.name or ""), query, 1, true)

                -- Check spells and items for search matches
                local matchSpell = false
                if mob.combat and mob.combat.spells then
                    for _, sp in pairs(mob.combat.spells) do
                        totalSpells = totalSpells + 1
                        if string.find(string.lower(sp.name or ""), query, 1, true) then
                            matchSpell = true
                        end
                    end
                end

                local matchItem = false
                local items = (mob.loot and mob.loot.items) or mob.items or {}
                for _, it in pairs(items) do
                    totalItems = totalItems + 1
                    if string.find(string.lower(it.name or ""), query, 1, true) then
                        matchItem = true
                    end
                end

                if mob.professions and mob.professions.items then
                    for _, it in pairs(mob.professions.items) do
                        totalItems = totalItems + 1
                        if string.find(string.lower(it.name or ""), query, 1, true) then
                            matchItem = true
                        end
                    end
                end

                if mobMatches or matchSpell or matchItem then
                    table.insert(matchingMobs, mob)
                end
            end
        end

        if #matchingMobs > 0 then
            local isZoneExp = self.zoneExpanded[zone.id]
            if query ~= "" then isZoneExp = true end

            table.insert(list, {
                type = "ZONE",
                id = zone.id,
                name = zone.name,
                count = #matchingMobs,
                expanded = isZoneExp
            })

            if isZoneExp then
                for _, mob in ipairs(matchingMobs) do
                    table.insert(list, {
                        type = "MOB",
                        id = mob.npcID,
                        name = mob.name,
                        mob = mob,
                    })
                end
            end
        end
    end

    self.treeDisplayList = list

    if self.summaryText then
        self.summaryText:SetText(string.format("%d zones | %d creatures | %d drops | %d spells", totalZones, totalMobs, totalItems, totalSpells))
    end

    -- Auto-select first mob if none selected yet
    if not self.selectedMob and #list > 0 then
        for _, entry in ipairs(list) do
            if entry.type == "MOB" then
                self.selectedMob = entry.mob
                break
            end
        end
    end
end

function addon:RefreshTreeList()
    self:BuildTreeList()
    self:UpdateTreeListRows()
    self:RefreshSelectedMobCard()
end

function addon:UpdateTreeListRows()
    if not self.treeDisplayList or not self.leftScroll then return end

    local count = #self.treeDisplayList
    FauxScrollFrame_Update(self.leftScroll, count, NUM_LEFT_ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(self.leftScroll)

    for i = 1, NUM_LEFT_ROWS do
        local row = self.leftRows[i]
        local index = offset + i

        if index <= count then
            local data = self.treeDisplayList[index]
            row.data = data

            if data.type == "ZONE" then
                row.icon:SetTexture(data.expanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
                row.icon:SetSize(14, 14)
                row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)

                row.title:SetText(string.format("|cffffd100%s|r", data.name))
                row.title:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
                row.value:SetText(string.format("|cffc7a16b(%d)|r", data.count))
                row.selectTex:Hide()

            elseif data.type == "MOB" then
                row.icon:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
                row.icon:SetSize(12, 12)
                row.icon:SetPoint("LEFT", row, "LEFT", 22, 0)

                local mob = data.mob
                local isRareMob = (mob.classification == "rare" or mob.classification == "rareelite")
                local isEliteMob = (mob.classification == "elite" or mob.classification == "worldboss")
                -- Silver for rarespawns, Gold for elites, Bronze for normal mobs
                local col = isRareMob and "|cffe0e0e0" or (isEliteMob and "|cffffd100" or "|cffe5a558")

                local coordTag = ""
                if isRareMob and mob.coords and mob.coords[1] then
                    coordTag = string.format(" |cffaaaaaa(%0.1f, %0.1f)|r", mob.coords[1].x, mob.coords[1].y)
                end
                row.title:SetText(string.format("%s%s|r%s", col, data.name, coordTag))
                row.title:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)

                local killsOrLoots
                if isRareMob and (not mob.kills or mob.kills == 0) and (not mob.loot or not mob.loot.totalLoots or mob.loot.totalLoots == 0) then
                    killsOrLoots = "|cffe0e0e0[Rare]|r"
                elseif mob.kills and mob.kills > 0 then
                    killsOrLoots = mob.kills .. " kills"
                elseif mob.loot and mob.loot.totalLoots and mob.loot.totalLoots > 0 then
                    killsOrLoots = mob.loot.totalLoots .. " loots"
                elseif mob.professions and mob.professions.totalHarvests and mob.professions.totalHarvests > 0 then
                    killsOrLoots = mob.professions.totalHarvests .. " harvests"
                else
                    killsOrLoots = "0 loots"
                end
                row.value:SetText(string.format("|cff888888%s|r", killsOrLoots))

                if self.selectedMob and self.selectedMob.npcID == mob.npcID then
                    row.selectTex:Show()
                else
                    row.selectTex:Hide()
                end
            end

            row:Show()
        else
            row:Hide()
        end
    end
end

-- Refresh the Right-hand Pokédex Entry Card
function addon:RefreshSelectedMobCard()
    local mob = self.selectedMob
    if not mob then
        self.emptyNotice:Show()
        self.mobCard:Hide()
        return
    end

    self.emptyNotice:Hide()
    self.mobCard:Show()

    -- 1. Setup 3D Creature Model
    local modelLoaded = false
    if self.creatureModel then
        self.creatureModel:ClearModel()
        if self.creatureModel.SetCreature then
            pcall(function()
                self.creatureModel:SetCreature(mob.npcID)
                self.creatureModel:SetFacing(0.2)
                modelLoaded = true
            end)
        end
    end

    if modelLoaded then
        self.creatureModel:Show()
        self.modelFallback:Hide()
    else
        self.creatureModel:Hide()
        self.modelFallback:Show()
    end

    -- 2. Header Text
    local isRareMob = (mob.classification == "rare" or mob.classification == "rareelite")
    local isEliteMob = (mob.classification == "elite" or mob.classification == "worldboss")
    local nameCol = isRareMob and "|cffe0e0e0" or (isEliteMob and "|cffffd100" or "|cffe5a558")
    self.mobNameText:SetText(string.format("%s%s|r", nameCol, mob.name or ("Creature " .. mob.npcID)))

    local classificationName = ""
    if mob.classification == "rare" then
        classificationName = "|cffe0e0e0Rare|r"
    elseif mob.classification == "rareelite" then
        classificationName = "|cffe0e0e0Rare Elite|r"
    elseif mob.classification == "elite" then
        classificationName = "|cffffd100Elite|r"
    elseif mob.classification == "worldboss" then
        classificationName = "|cffff2020Boss|r"
    end

    local levelStr = "Level " .. (mob.minLevel and (mob.minLevel == mob.maxLevel and mob.minLevel or (mob.minLevel .. "-" .. mob.maxLevel)) or "??")
    local typeStr = mob.creatureType or "Unknown Family"
    if classificationName ~= "" then
        self.mobMetaText:SetText(string.format("|cffffffff%s|r %s |cffffffff%s|r", levelStr, classificationName, typeStr))
    else
        self.mobMetaText:SetText(string.format("|cffffffff%s %s|r", levelStr, typeStr))
    end

    local lootsCount = (mob.loot and mob.loot.totalLoots) or mob.totalLoots or 0
    local killsCount = mob.kills or 0
    local harvestsCount = (mob.professions and mob.professions.totalHarvests) or 0
    self.mobStatsText:SetText(string.format("Kills: |cffffffff%d|r   Loot: |cffffffff%d|r   Harvests: |cffffffff%d|r   NPC ID: |cffffffff%d|r", killsCount, lootsCount, harvestsCount, mob.npcID))

    -- Coordinates Line: ONLY displayed for rare spawns!
    if self.mobCoordsText then
        if isRareMob and mob.coords and #mob.coords > 0 then
            local pt = mob.coords[1]
            self.mobCoordsText:SetText(string.format("|cffe0e0e0Coords:|r |cffffffff(%0.1f, %0.1f)|r", pt.x, pt.y))
            self.mobCoordsText:Show()
        elseif isRareMob then
            self.mobCoordsText:SetText("|cffe0e0e0Coords:|r |cff888888(Target to record)|r")
            self.mobCoordsText:Show()
        else
            self.mobCoordsText:Hide()
        end
    end

    -- 3. Populate Active Tab Content
    if self.UpdateTabHighlight then
        self:UpdateTabHighlight()
    end

    if self.selectedTab == "COMBAT" then
        self:PopulateRightCombatTab(mob)
    elseif self.selectedTab == "LOOT" then
        self:PopulateRightLootTab(mob)
    elseif self.selectedTab == "PROFESSIONS" then
        self:PopulateRightProfessionsTab(mob)
    end
end

-- Populate Combat Tab Rows
function addon:PopulateRightCombatTab(mob)
    local imms = self:GetMobImmunities(mob)
    local subHeaderText

    if #imms > 0 then
        subHeaderText = "|cffffd100Immunities:|r "
        for _, imm in ipairs(imms) do
            local info = addon.IMMUNITY_COLORS[imm.key]
            local hex = (info and info.hex) or "ffffff"
            subHeaderText = subHeaderText .. string.format("|cff%s[%s]|r ", hex, imm.name)
        end
    else
        subHeaderText = "|cffffd100Immunities:|r |cff888888None observed in combat yet|r"
    end

    self.cardSubHeader:SetText(subHeaderText)

    -- Build spells list
    local spells = self:GetSortedSpellList(mob, 999)
    self.rightDisplayItems = {}
    for _, sp in ipairs(spells) do
        table.insert(self.rightDisplayItems, { type = "SPELL", spell = sp })
    end

    self:UpdateRightCardRows()
end

-- Populate Loot Tab Rows
function addon:PopulateRightLootTab(mob)
    local loot = mob.loot or {}
    local coinStr = (loot.avgMoney and loot.avgMoney > 0) and self:FormatCoinString(loot.avgMoney) or "0c"
    self.cardSubHeader:SetText(string.format("|cffffd100Loot Sessions:|r |cffffffff%d|r  (|cff888888%d empty|r)   |cffffd100Avg Coin:|r %s",
        loot.totalLoots or 0, loot.emptyLoots or 0, coinStr))

    local items = self:GetSortedItemList(mob, 999, 0)
    self.rightDisplayItems = {}
    for _, it in ipairs(items) do
        table.insert(self.rightDisplayItems, { type = "ITEM", item = it })
    end

    self:UpdateRightCardRows()
end

-- Populate Professions Tab Rows
function addon:PopulateRightProfessionsTab(mob)
    local prof = mob.professions or {}
    local totalHarvests = prof.totalHarvests or 0
    local emptyHarvests = prof.emptyHarvests or 0

    local skillSummary = ""
    if prof.bySkill then
        for skillName, skillData in pairs(prof.bySkill) do
            if skillData.totalHarvests and skillData.totalHarvests > 0 then
                skillSummary = skillSummary .. string.format("   |cffffd100%s:|r |cffffffff%d|r", skillName, skillData.totalHarvests)
            end
        end
    end

    if totalHarvests > 0 then
        self.cardSubHeader:SetText(string.format("|cffffd100Total Harvests:|r |cffffffff%d|r  (|cff888888%d empty|r)%s",
            totalHarvests, emptyHarvests, skillSummary))
    else
        self.cardSubHeader:SetText("|cffffd100Professions:|r |cff888888No gathering or skinning recorded for this creature yet|r")
    end

    local items = self:GetSortedProfessionItemList(mob, 999, 0)
    self.rightDisplayItems = {}
    for _, it in ipairs(items) do
        table.insert(self.rightDisplayItems, { type = "PROFESSION_ITEM", item = it })
    end

    self:UpdateRightCardRows()
end

function addon:UpdateRightCardRows()
    if not self.rightDisplayItems or not self.rightScroll then return end

    local count = #self.rightDisplayItems
    FauxScrollFrame_Update(self.rightScroll, count, NUM_RIGHT_ROWS, RIGHT_ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(self.rightScroll)

    for i = 1, NUM_RIGHT_ROWS do
        local row = self.rightRows[i]
        local index = offset + i

        if index <= count then
            local data = self.rightDisplayItems[index]
            row.itemData = nil
            row.spellData = nil

            if data.type == "SPELL" then
                local sp = data.spell
                row.spellData = sp
                row.icon:SetTexture(sp.icon or "Interface\\Icons\\Spell_Holy_MagicalSentry")

                local schoolInfo = addon.SCHOOL_MASKS[sp.school or 1]
                local schoolColor = schoolInfo and schoolInfo.color or "ffffff"
                row.title:SetText(string.format("|cff%s%s|r", schoolColor, sp.name or ("Spell " .. sp.id)))

                local extraTag = sp.isAutoAttack and "|cffffffff[Melee]|r" or (sp.isHeal and "|cff44ff44[Heal]|r" or (sp.isBuff and "|cff71d5ff[Buff]|r" or (sp.isDebuff and "|cffff5533[Debuff]|r" or "")))
                row.desc:SetText(extraTag)

                local valStr
                if sp.isAutoAttack then
                    valStr = "|cffffffffPhysical Attack|r"
                elseif sp.avgDmg and sp.avgDmg > 0 then
                    valStr = string.format("|cffffffff%d-%d dmg|r |cff888888(%d casts)|r", sp.minDmg or sp.avgDmg, sp.maxDmg or sp.avgDmg, sp.casts or 1)
                else
                    valStr = string.format("|cff888888%d casts|r", sp.casts or 1)
                end
                row.value:SetText(valStr)

            elseif data.type == "ITEM" then
                local it = data.item
                row.itemData = it
                row.icon:SetTexture(it.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

                local coloredName = addon:FormatQualityName(it.name, it.quality)
                row.title:SetText(coloredName)
                row.desc:SetText(string.format("|cffc7a16b(%d/%d drops)|r", it.dropLootCount or 0, (addon.selectedMob and addon.selectedMob.loot and addon.selectedMob.loot.totalLoots) or 1))
                row.value:SetText(string.format("|cffffffff%s|r", it.dropChance or "0%"))

            elseif data.type == "PROFESSION_ITEM" then
                local it = data.item
                row.itemData = it
                row.icon:SetTexture(it.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

                local coloredName = addon:FormatQualityName(it.name, it.quality)
                row.title:SetText(coloredName)

                local profTag = ""
                if it.profession then
                    local profColor = "c7a16b"
                    if it.profession == "Skinning" then profColor = "cc9966"
                    elseif it.profession == "Mining" then profColor = "70b0ff"
                    elseif it.profession == "Herbalism" then profColor = "55ee77"
                    elseif it.profession == "Engineering" then profColor = "ffaa33"
                    end
                    profTag = string.format("|cff%s[%s]|r ", profColor, it.profession)
                end

                local totalHarvests = (addon.selectedMob and addon.selectedMob.professions and addon.selectedMob.professions.totalHarvests) or 1
                row.desc:SetText(string.format("%s|cffc7a16b(%d/%d drops)|r", profTag, it.dropLootCount or it.harvestCount or 0, totalHarvests))
                row.value:SetText(string.format("|cffffffff%s|r", it.dropChance or "0%"))
            end

            row:Show()
        else
            row:Hide()
        end
    end
end

-- Toggle window
function addon:ToggleCompendiumWindow()
    local win = self:CreateCompendiumWindow()
    if win:IsShown() then
        win:Hide()
    else
        win:Show()
        self:RefreshTreeList()
    end
end

-- Backward compatibility alias
function addon:ToggleLootWindow()
    self:ToggleCompendiumWindow()
end

-------------------------------------------------------------------------------
-- 3. Draggable Minimap Button with Bronze Theme & Scaling
-------------------------------------------------------------------------------

local function GetMinimapRadius()
    if not Minimap then return 80 end
    local width = Minimap:GetWidth() or 140
    local height = Minimap:GetHeight() or 140
    return ((width + height) / 4) + 4
end

local function UpdateMinimapButtonPosition(btn, angle)
    if not Minimap or not btn then return end
    local rad = math.rad(angle or 210)
    local radius = GetMinimapRadius()

    local x = math.cos(rad) * radius
    local y = math.sin(rad) * radius

    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function addon:CreateMinimapButton()
    if self.minimapButton then return self.minimapButton end

    local btn = CreateFrame("Button", "AzerothCompendiumMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    -- Solid dark background
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(22, 22)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetVertexColor(0.12, 0.10, 0.08, 1)
    bg:SetPoint("CENTER", btn, "CENTER", 0, 0)

    -- Tome icon
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)

    -- Circular mask
    if btn.CreateMaskTexture then
        local mask = btn:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetSize(19, 19)
        mask:SetPoint("CENTER", btn, "CENTER", 0, 0)
        icon:AddMaskTexture(mask)
    end

    -- Warm bronze tracking border ring
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    border:SetVertexColor(0.92, 0.76, 0.48)

    -- Dragging
    btn:SetScript("OnDragStart", function(b)
        b.isDragging = true
        b:SetScript("OnUpdate", function(selfBtn)
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            local angle = math.deg(math.atan2(py - my, px - mx))
            addon.db.settings.minimapAngle = angle
            UpdateMinimapButtonPosition(selfBtn, angle)
        end)
    end)

    btn:SetScript("OnDragStop", function(b)
        b.isDragging = false
        b:SetScript("OnUpdate", nil)
    end)

    -- Tooltip on Hover
    btn:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff00ff96Azeroth Creature Compendium|r")
        GameTooltip:AddLine("|cffffffffLeft-Click:|r Open Creature Compendium", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffffffffRight-Click:|r Addon Settings", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffc7a16b(Drag left click to move)|r", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Click handler
    btn:SetScript("OnClick", function(b, button)
        if button == "RightButton" then
            addon:OpenOptions()
        else
            addon:ToggleCompendiumWindow()
        end
    end)

    self.minimapButton = btn



    local savedAngle = (self.db and self.db.settings and self.db.settings.minimapAngle) or 210
    UpdateMinimapButtonPosition(btn, savedAngle)

    if self.db and self.db.settings and self.db.settings.showMinimap == false then
        btn:Hide()
    else
        btn:Show()
    end

    return btn
end

-- Initialize on PLAYER_LOGIN
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    addon:CreateMinimapButton()
    self:UnregisterEvent("PLAYER_LOGIN")
end)
