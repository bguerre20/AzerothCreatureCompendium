--[[
    Azeroth Creature Compendium - Options.lua
    In-game graphical settings panel integrated into Blizzard Interface Options.
    Taint-free implementation with native toggle buttons and zero DropDownList taint.
]]

local ADDON_NAME, addon = ...

local panel = CreateFrame("Frame", "AzerothCompendiumOptionsPanel", UIParent)
panel.name = "Creature Compendium"
addon.optionsPanel = panel

local function InitializeOptions()
    -- Addon Icon
    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("TOPLEFT", 16, -16)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    title:SetText("|cff00ff96Azeroth Creature Compendium|r")

    -- Version and author
    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    local displayVer = addon.VERSION or "1.0.0"
    if not displayVer:match("^v") then displayVer = "v" .. displayVer end
    version:SetText(displayVer .. " by " .. (addon.AUTHOR or "Bryan"))

    -- Subtitle / Description
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Configure mouseover creature tooltips, activation hotkeys, and combat discovery.")

    local divider = panel:CreateLine()
    divider:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    divider:SetStartPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -10)
    divider:SetEndPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 560, -10)
    divider:SetThickness(1)

    ---------------------------------------------------------------------------
    -- Section 1: Activation Hotkeys (Taint-Free Native Button Groups)
    ---------------------------------------------------------------------------
    local hotkeyHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    hotkeyHeader:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -20)
    hotkeyHeader:SetText("Tooltip Activation Hotkeys")

    local hotkeyChoices = { "SHIFT", "CTRL", "ALT", "NONE" }
    local ROW_LABEL_WIDTH = 150

    -- Loot Tooltip Hotkey Group
    local lootKeyLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lootKeyLabel:SetPoint("TOPLEFT", hotkeyHeader, "BOTTOMLEFT", 4, -14)
    lootKeyLabel:SetSize(ROW_LABEL_WIDTH, 20)
    lootKeyLabel:SetJustifyH("LEFT")
    lootKeyLabel:SetText("Loot Tooltip Key:")

    local lootButtons = {}
    for idx, keyVal in ipairs(hotkeyChoices) do
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(58, 22)
        if idx == 1 then
            btn:SetPoint("LEFT", lootKeyLabel, "RIGHT", 10, 0)
        else
            btn:SetPoint("LEFT", lootButtons[idx - 1], "RIGHT", 6, 0)
        end
        btn:SetText(keyVal)
        btn:SetScript("OnClick", function()
            addon.db.settings.modifierKeyLoot = keyVal
            addon:RefreshOptionsHotkeys()
        end)
        lootButtons[idx] = btn
    end

    -- Combat Tooltip Hotkey Group
    local combatKeyLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    combatKeyLabel:SetPoint("TOPLEFT", lootKeyLabel, "BOTTOMLEFT", 0, -8)
    combatKeyLabel:SetSize(ROW_LABEL_WIDTH, 20)
    combatKeyLabel:SetJustifyH("LEFT")
    combatKeyLabel:SetText("Combat Tooltip Key:")

    local combatButtons = {}
    for idx, keyVal in ipairs(hotkeyChoices) do
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(58, 22)
        if idx == 1 then
            btn:SetPoint("LEFT", combatKeyLabel, "RIGHT", 10, 0)
        else
            btn:SetPoint("LEFT", combatButtons[idx - 1], "RIGHT", 6, 0)
        end
        btn:SetText(keyVal)
        btn:SetScript("OnClick", function()
            addon.db.settings.modifierKeyCombat = keyVal
            addon:RefreshOptionsHotkeys()
        end)
        combatButtons[idx] = btn
    end

    -- Profession Tooltip Hotkey Group
    local profKeyLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    profKeyLabel:SetPoint("TOPLEFT", combatKeyLabel, "BOTTOMLEFT", 0, -8)
    profKeyLabel:SetSize(ROW_LABEL_WIDTH, 20)
    profKeyLabel:SetJustifyH("LEFT")
    profKeyLabel:SetText("Profession Tooltip Key:")

    local profButtons = {}
    for idx, keyVal in ipairs(hotkeyChoices) do
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(58, 22)
        if idx == 1 then
            btn:SetPoint("LEFT", profKeyLabel, "RIGHT", 10, 0)
        else
            btn:SetPoint("LEFT", profButtons[idx - 1], "RIGHT", 6, 0)
        end
        btn:SetText(keyVal)
        btn:SetScript("OnClick", function()
            addon.db.settings.modifierKeyProfession = keyVal
            addon:RefreshOptionsHotkeys()
        end)
        profButtons[idx] = btn
    end

    function addon:RefreshOptionsHotkeys()
        local currentLoot = (self.db and self.db.settings and self.db.settings.modifierKeyLoot) or "SHIFT"
        local currentCombat = (self.db and self.db.settings and self.db.settings.modifierKeyCombat) or "CTRL"
        local currentProf = (self.db and self.db.settings and self.db.settings.modifierKeyProfession) or "ALT"

        for idx, keyVal in ipairs(hotkeyChoices) do
            local lBtn = lootButtons[idx]
            if lBtn then
                if keyVal == currentLoot then
                    lBtn:SetText("|cffffd100[" .. keyVal .. "]|r")
                else
                    lBtn:SetText("|cffffffff" .. keyVal .. "|r")
                end
            end

            local cBtn = combatButtons[idx]
            if cBtn then
                if keyVal == currentCombat then
                    cBtn:SetText("|cffffd100[" .. keyVal .. "]|r")
                else
                    cBtn:SetText("|cffffffff" .. keyVal .. "|r")
                end
            end

            local pBtn = profButtons[idx]
            if pBtn then
                if keyVal == currentProf then
                    pBtn:SetText("|cffffd100[" .. keyVal .. "]|r")
                else
                    pBtn:SetText("|cffffffff" .. keyVal .. "|r")
                end
            end
        end
    end

    -- Divider 2
    local divider2 = panel:CreateLine()
    divider2:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    divider2:SetStartPoint("TOPLEFT", profKeyLabel, "BOTTOMLEFT", -4, -14)
    divider2:SetEndPoint("TOPLEFT", profKeyLabel, "BOTTOMLEFT", 560, -14)
    divider2:SetThickness(1)

    ---------------------------------------------------------------------------
    -- Section 2: Tooltip Appearance & Details
    ---------------------------------------------------------------------------
    local appearanceHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    appearanceHeader:SetPoint("TOPLEFT", profKeyLabel, "BOTTOMLEFT", -4, -26)
    appearanceHeader:SetText("Tooltip Appearance & Discovery")

    -- Checkbox: Separate companion tooltips
    local separateCheck = CreateFrame("CheckButton", "AzerothCompendiumSeparateCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    separateCheck:SetPoint("TOPLEFT", appearanceHeader, "BOTTOMLEFT", 0, -8)
    local separateLabel = separateCheck.Text or _G[separateCheck:GetName() .. "Text"]
    if separateLabel then
        separateLabel:SetText("Display in dedicated companion sidecar tooltips")
        separateLabel:SetFontObject("GameFontHighlight")
    end
    separateCheck:SetScript("OnClick", function(self)
        addon.db.settings.separateTooltip = self:GetChecked()
    end)

    -- Checkbox: Show hotkey hint
    local hintCheck = CreateFrame("CheckButton", "AzerothCompendiumHintCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    hintCheck:SetPoint("TOPLEFT", separateCheck, "BOTTOMLEFT", 0, -4)
    local hintLabel = hintCheck.Text or _G[hintCheck:GetName() .. "Text"]
    if hintLabel then
        hintLabel:SetText("Show '[Hold Shift Loot / Ctrl Combat]' hotkey hint line on mobs")
        hintLabel:SetFontObject("GameFontHighlight")
    end
    hintCheck:SetScript("OnClick", function(self)
        addon.db.settings.showHint = self:GetChecked()
    end)

    -- Checkbox: Show average money dropped
    local moneyCheck = CreateFrame("CheckButton", "AzerothCompendiumMoneyCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    moneyCheck:SetPoint("TOPLEFT", hintCheck, "BOTTOMLEFT", 0, -4)
    local moneyLabel = moneyCheck.Text or _G[moneyCheck:GetName() .. "Text"]
    if moneyLabel then
        moneyLabel:SetText("Show average coin dropped by creature")
        moneyLabel:SetFontObject("GameFontHighlight")
    end
    moneyCheck:SetScript("OnClick", function(self)
        addon.db.settings.showMoney = self:GetChecked()
    end)

    -- Checkbox: Track Combat Log (Attacks, Spells, Immunities)
    local combatLogCheck = CreateFrame("CheckButton", "AzerothCompendiumCombatLogCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    combatLogCheck:SetPoint("TOPLEFT", moneyCheck, "BOTTOMLEFT", 0, -4)
    local combatLogLabel = combatLogCheck.Text or _G[combatLogCheck:GetName() .. "Text"]
    if combatLogLabel then
        combatLogLabel:SetText("Track mob attacks, spells, and immunities via Combat Log")
        combatLogLabel:SetFontObject("GameFontHighlight")
    end
    combatLogCheck:SetScript("OnClick", function(self)
        addon.db.settings.trackCombat = self:GetChecked()
    end)

    -- Checkbox: Show Minimap Button
    local minimapCheck = CreateFrame("CheckButton", "AzerothCompendiumMinimapCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", combatLogCheck, "BOTTOMLEFT", 0, -4)
    local minimapLabel = minimapCheck.Text or _G[minimapCheck:GetName() .. "Text"]
    if minimapLabel then
        minimapLabel:SetText("Show Minimap compendium tome button")
        minimapLabel:SetFontObject("GameFontHighlight")
    end
    minimapCheck:SetScript("OnClick", function(self)
        local val = self:GetChecked()
        addon.db.settings.showMinimap = val
        if addon.minimapButton then
            if val then addon.minimapButton:Show() else addon.minimapButton:Hide() end
        end
    end)

    -- Quick Action: Open Pokédex Window
    local openWinBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openWinBtn:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 4, -14)
    openWinBtn:SetSize(190, 26)
    openWinBtn:SetText("|cffffd100Open Compendium Window|r")
    openWinBtn:SetScript("OnClick", function()
        addon:ToggleCompendiumWindow()
    end)

    -- Status Text at bottom
    local statusText = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    statusText:SetPoint("BOTTOMLEFT", 16, 20)

    -- Panel OnShow Synchronization
    panel:SetScript("OnShow", function()
        if not addon.db or not addon.db.settings then return end
        local s = addon.db.settings

        addon:RefreshOptionsHotkeys()

        separateCheck:SetChecked(s.separateTooltip ~= false)
        hintCheck:SetChecked(s.showHint ~= false)
        moneyCheck:SetChecked(s.showMoney ~= false)
        combatLogCheck:SetChecked(s.trackCombat ~= false)
        minimapCheck:SetChecked(s.showMinimap ~= false)

        local mobCount = 0
        local zoneCount = 0
        local lootsCount = 0
        local spellsCount = 0
        local immCount = 0

        for _, zone in pairs(addon.db.zones or {}) do
            zoneCount = zoneCount + 1
            for _, mob in pairs(zone.mobs or {}) do
                mobCount = mobCount + 1
                lootsCount = lootsCount + (mob.loot and mob.loot.totalLoots or mob.totalLoots or 0)
                if mob.combat then
                    for _ in pairs(mob.combat.spells or {}) do spellsCount = spellsCount + 1 end
                    for _ in pairs(mob.combat.immunities or {}) do immCount = immCount + 1 end
                end
            end
        end

        statusText:SetText(string.format("Compendium: %d Zones | %d Creatures | %d Loots | %d Spells | %d Immunities",
            zoneCount, mobCount, lootsCount, spellsCount, immCount))
    end)
end

-- Open options helper
function addon:OpenOptions()
    if Settings and Settings.OpenToCategory and addon.settingsCategory then
        Settings.OpenToCategory(addon.settingsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

-- Register panel with Blizzard Settings UI
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event)
    InitializeOptions()

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        addon.settingsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    self:UnregisterEvent("PLAYER_LOGIN")
end)
