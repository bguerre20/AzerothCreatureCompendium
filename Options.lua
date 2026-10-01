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
    -- Section 1: Activation Hotkeys & Modes (Taint-Free Native Button Groups)
    ---------------------------------------------------------------------------
    local hotkeyHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    hotkeyHeader:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -20)
    hotkeyHeader:SetText("Tooltip Activation Modes")

    local hotkeyChoices = { "SHIFT", "CTRL", "ALT", "ALWAYS", "NEVER" }
    local ROW_LABEL_WIDTH = 130
    local BTN_WIDTH = 62
    local BTN_HEIGHT = 22
    local BTN_GAP = 5

    local function FormatKeyText(keyVal, isSelected)
        if not isSelected then
            return "|cffffffff" .. keyVal .. "|r"
        end
        if keyVal == "ALWAYS" then
            return "|cff00ff96[" .. keyVal .. "]|r"
        elseif keyVal == "NEVER" then
            return "|cffff4444[" .. keyVal .. "]|r"
        else
            return "|cffffd100[" .. keyVal .. "]|r"
        end
    end

    -- Loot Tooltip Hotkey Group
    local lootKeyLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lootKeyLabel:SetPoint("TOPLEFT", hotkeyHeader, "BOTTOMLEFT", 4, -14)
    lootKeyLabel:SetSize(ROW_LABEL_WIDTH, 20)
    lootKeyLabel:SetJustifyH("LEFT")
    lootKeyLabel:SetText("Loot Drops:")

    local lootButtons = {}
    for idx, keyVal in ipairs(hotkeyChoices) do
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(BTN_WIDTH, BTN_HEIGHT)
        if idx == 1 then
            btn:SetPoint("LEFT", lootKeyLabel, "RIGHT", 10, 0)
        else
            btn:SetPoint("LEFT", lootButtons[idx - 1], "RIGHT", BTN_GAP, 0)
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
    combatKeyLabel:SetText("Combat Profile:")

    local combatButtons = {}
    for idx, keyVal in ipairs(hotkeyChoices) do
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(BTN_WIDTH, BTN_HEIGHT)
        if idx == 1 then
            btn:SetPoint("LEFT", combatKeyLabel, "RIGHT", 10, 0)
        else
            btn:SetPoint("LEFT", combatButtons[idx - 1], "RIGHT", BTN_GAP, 0)
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
    profKeyLabel:SetText("Profession Loot:")

    local profButtons = {}
    for idx, keyVal in ipairs(hotkeyChoices) do
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(BTN_WIDTH, BTN_HEIGHT)
        if idx == 1 then
            btn:SetPoint("LEFT", profKeyLabel, "RIGHT", 10, 0)
        else
            btn:SetPoint("LEFT", profButtons[idx - 1], "RIGHT", BTN_GAP, 0)
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
            if lBtn then lBtn:SetText(FormatKeyText(keyVal, keyVal == currentLoot)) end

            local cBtn = combatButtons[idx]
            if cBtn then cBtn:SetText(FormatKeyText(keyVal, keyVal == currentCombat)) end

            local pBtn = profButtons[idx]
            if pBtn then pBtn:SetText(FormatKeyText(keyVal, keyVal == currentProf)) end
        end
    end

    -- Divider 2
    local divider2 = panel:CreateLine()
    divider2:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    divider2:SetStartPoint("TOPLEFT", profKeyLabel, "BOTTOMLEFT", -4, -14)
    divider2:SetEndPoint("TOPLEFT", profKeyLabel, "BOTTOMLEFT", 560, -14)
    divider2:SetThickness(1)

    ---------------------------------------------------------------------------
    -- Section 2: Tooltip Layout & Docking
    ---------------------------------------------------------------------------
    local appearanceHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    appearanceHeader:SetPoint("TOPLEFT", profKeyLabel, "BOTTOMLEFT", -4, -26)
    appearanceHeader:SetText("Tooltip Layout & Appearance")

    -- Row 1: Layout Mode (Sidecar vs Embedded)
    local layoutLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    layoutLabel:SetPoint("TOPLEFT", appearanceHeader, "BOTTOMLEFT", 4, -14)
    layoutLabel:SetSize(ROW_LABEL_WIDTH, 20)
    layoutLabel:SetJustifyH("LEFT")
    layoutLabel:SetText("Layout Mode:")

    local sidecarBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    sidecarBtn:SetSize(155, 22)
    sidecarBtn:SetPoint("LEFT", layoutLabel, "RIGHT", 10, 0)
    sidecarBtn:SetText("Dedicated Sidecars")
    sidecarBtn:SetScript("OnClick", function()
        addon.db.settings.tooltipLayout = "SIDECAR"
        addon.db.settings.separateTooltip = true
        addon:RefreshOptionsLayout()
    end)

    local embeddedBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    embeddedBtn:SetSize(185, 22)
    embeddedBtn:SetPoint("LEFT", sidecarBtn, "RIGHT", 6, 0)
    embeddedBtn:SetText("Embedded in Main Tooltip")
    embeddedBtn:SetScript("OnClick", function()
        addon.db.settings.tooltipLayout = "EMBEDDED"
        addon.db.settings.separateTooltip = false
        addon:RefreshOptionsLayout()
    end)

    -- Row 2: Sidecar Docking Orientation
    local dockLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    dockLabel:SetPoint("TOPLEFT", layoutLabel, "BOTTOMLEFT", 0, -8)
    dockLabel:SetSize(ROW_LABEL_WIDTH, 20)
    dockLabel:SetJustifyH("LEFT")
    dockLabel:SetText("Sidecar Docking:")

    local dockBesideBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    dockBesideBtn:SetSize(155, 22)
    dockBesideBtn:SetPoint("LEFT", dockLabel, "RIGHT", 10, 0)
    dockBesideBtn:SetText("Beside (Left/Right)")
    dockBesideBtn:SetScript("OnClick", function()
        addon.db.settings.sidecarAnchor = "HORIZONTAL"
        addon:RefreshOptionsLayout()
    end)

    local dockAboveBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    dockAboveBtn:SetSize(185, 22)
    dockAboveBtn:SetPoint("LEFT", dockBesideBtn, "RIGHT", 6, 0)
    dockAboveBtn:SetText("Above / Below (Vertical)")
    dockAboveBtn:SetScript("OnClick", function()
        addon.db.settings.sidecarAnchor = "VERTICAL"
        addon:RefreshOptionsLayout()
    end)

    function addon:RefreshOptionsLayout()
        local s = self.db and self.db.settings
        local layout = (s and s.tooltipLayout) or "SIDECAR"
        local anchor = (s and s.sidecarAnchor) or "HORIZONTAL"

        if layout == "SIDECAR" then
            sidecarBtn:SetText("|cff00ff96[Dedicated Sidecars]|r")
            embeddedBtn:SetText("|cffffffffEmbedded in Main Tooltip|r")

            dockLabel:SetAlpha(1.0)
            dockBesideBtn:Enable()
            dockBesideBtn:SetAlpha(1.0)
            dockAboveBtn:Enable()
            dockAboveBtn:SetAlpha(1.0)

            if anchor == "HORIZONTAL" then
                dockBesideBtn:SetText("|cffffd100[Beside (Left/Right)]|r")
                dockAboveBtn:SetText("|cffffffffAbove / Below (Vertical)|r")
            else
                dockBesideBtn:SetText("|cffffffffBeside (Left/Right)|r")
                dockAboveBtn:SetText("|cffffd100[Above / Below (Vertical)]|r")
            end
        else
            sidecarBtn:SetText("|cffffffffDedicated Sidecars|r")
            embeddedBtn:SetText("|cff00ff96[Embedded in Main Tooltip]|r")

            dockLabel:SetAlpha(0.4)
            dockBesideBtn:Disable()
            dockBesideBtn:SetAlpha(0.4)
            dockAboveBtn:Disable()
            dockAboveBtn:SetAlpha(0.4)
            dockBesideBtn:SetText("|cff888888Beside (Left/Right)|r")
            dockAboveBtn:SetText("|cff888888Above / Below (Vertical)|r")
        end
    end

    -- Checkbox: Show hotkey hint
    local hintCheck = CreateFrame("CheckButton", "AzerothCompendiumHintCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    hintCheck:SetPoint("TOPLEFT", dockLabel, "BOTTOMLEFT", -4, -10)
    local hintLabel = hintCheck.Text or _G[hintCheck:GetName() .. "Text"]
    if hintLabel then
        hintLabel:SetText("Show hotkey hint line on creature tooltips")
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
        addon:RefreshOptionsLayout()

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
