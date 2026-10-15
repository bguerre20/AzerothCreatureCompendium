--[[
    Azeroth Creature Compendium - Config.lua
    Configuration, defaults, spell school mappings, and slash commands.
]]

local ADDON_NAME, addon = ...
_G[ADDON_NAME] = addon
_G["AzerothCreatureCompendium"] = addon
_G["BgLootLogger"] = addon

-- Addon Metadata
addon.NAME = "Azeroth Creature Compendium"
addon.SHORT_NAME = "Compendium"
local tocVersion = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("AzerothCreatureCompendium", "Version"))
    or (GetAddOnMetadata and GetAddOnMetadata("AzerothCreatureCompendium", "Version"))
if not tocVersion or tocVersion:find("@") then
    tocVersion = "1.0.0"
end
addon.VERSION = tocVersion
addon.AUTHOR = "Bryan"
addon.ICON = "Interface\\Icons\\INV_Misc_Book_09"

-- Default Configuration
addon.DEFAULT_SETTINGS = {
    -- Tooltip Triggers & Modes ("SHIFT", "CTRL", "ALT", "ALWAYS", "NEVER")
    modifierKeyLoot = "SHIFT",     -- Loot drops activation mode
    modifierKeyCombat = "CTRL",    -- Combat profile activation mode
    modifierKeyProfession = "ALT", -- Profession loot activation mode
    alwaysShowLoot = false,        -- Kept for backwards compatibility
    alwaysShowCombat = false,      -- Kept for backwards compatibility
    alwaysShowProfession = false,  -- Kept for backwards compatibility

    -- Tooltip Layout & Docking
    separateTooltip = true,        -- Kept for backwards compatibility (true = SIDECAR, false = EMBEDDED)
    tooltipLayout = "SIDECAR",     -- "SIDECAR" or "EMBEDDED"
    sidecarAnchor = "HORIZONTAL",  -- "HORIZONTAL" (Beside: Left/Right dynamic) or "VERTICAL" (Above/Below)
    tooltipAnchor = "BLIZZARD",    -- "BLIZZARD" (Attached to main tooltip) or "CURSOR" (At mouse cursor)

    -- Display Limits & Filters
    maxItems = 8,                  -- Top drops to show in tooltip (5, 10, 999 = all)
    maxSpells = 8,                 -- Top spells to show in combat tooltip
    minQuality = 0,                -- 0: Poor (grey), 1: Common, 2: Uncommon, 3: Rare, 4: Epic
    showMoney = true,              -- Display average coin drop
    showHint = true,               -- Show hotkey hints on mob tooltips
    showNewMobTooltip = true,      -- Show tooltip status/hints on unrecorded creatures
    showSample = true,             -- Show drop occurrences and sample sizes

    -- Minimap
    showMinimap = true,            -- Show minimap button
    minimapAngle = 210,            -- Position angle around minimap

    -- Combat Log Discovery
    trackCombat = true,            -- Monitor combat log for attacks and spells
    trackImmunities = true,        -- Monitor combat log for spell/mechanic immunities

    -- Diagnostics & Error Handling
    debugMode = false,             -- When false (default), suppress unexpected API restriction errors; when true, surface raw Lua errors
}

-- Quality text and colors
addon.QUALITY_HEX = {
    [0] = "9d9d9d", -- Poor (Grey)
    [1] = "ffffff", -- Common (White)
    [2] = "1eff00", -- Uncommon (Green)
    [3] = "0070dd", -- Rare (Blue)
    [4] = "a335ee", -- Epic (Purple)
    [5] = "ff8000", -- Legendary (Orange)
}

addon.QUALITY_NAMES = {
    [0] = "Poor (Grey+)",
    [1] = "Common (White+)",
    [2] = "Uncommon (Green+)",
    [3] = "Rare (Blue+)",
    [4] = "Epic (Purple+)"
}

-- Spell Schools (bitmask indices used in combat log)
addon.SCHOOL_MASKS = {
    [1]   = { key = "PHYSICAL", name = "Physical", color = "ffffff", r = 1.0,  g = 1.0,  b = 1.0 },
    [2]   = { key = "HOLY",     name = "Holy",     color = "ffe680", r = 1.0,  g = 0.9,  b = 0.5 },
    [4]   = { key = "FIRE",     name = "Fire",     color = "ff6600", r = 1.0,  g = 0.4,  b = 0.0 },
    [8]   = { key = "NATURE",   name = "Nature",   color = "44ff44", r = 0.27, g = 1.0,  b = 0.27 },
    [16]  = { key = "FROST",    name = "Frost",    color = "80d0ff", r = 0.5,  g = 0.82, b = 1.0 },
    [32]  = { key = "SHADOW",   name = "Shadow",   color = "a335ee", r = 0.64, g = 0.21, b = 0.93 },
    [64]  = { key = "ARCANE",   name = "Arcane",   color = "ff80df", r = 1.0,  g = 0.5,  b = 0.87 },
}

-- Immunity Badge Color Styling
addon.IMMUNITY_COLORS = {
    FIRE      = { hex = "ff5533", text = "Fire Immune",    icon = "Interface\\Icons\\Spell_Fire_Fire" },
    NATURE    = { hex = "44ff44", text = "Nature Immune",  icon = "Interface\\Icons\\Spell_Nature_NatureTouchGrow" },
    FROST     = { hex = "66ccff", text = "Frost Immune",   icon = "Interface\\Icons\\Spell_Frost_FrostBolt02" },
    SHADOW    = { hex = "b366ff", text = "Shadow Immune",  icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt" },
    ARCANE    = { hex = "ff66cc", text = "Arcane Immune",  icon = "Interface\\Icons\\Spell_Holy_MagicalSentry" },
    HOLY      = { hex = "ffe680", text = "Holy Immune",    icon = "Interface\\Icons\\Spell_Holy_HolyBolt" },
    PHYSICAL  = { hex = "e6cc80", text = "Physical Immune",icon = "Interface\\Icons\\Ability_Warrior_ShieldWall" },
    TAUNT     = { hex = "ff9900", text = "Taunt Immune",   icon = "Interface\\Icons\\Spell_Nature_Reincarnation" },
    BLEED     = { hex = "cc0000", text = "Bleed Immune",   icon = "Interface\\Icons\\Ability_Gouge" },
    STUN      = { hex = "ffff44", text = "Stun Immune",    icon = "Interface\\Icons\\Spell_Holy_SealOfMight" },
    POLYMORPH = { hex = "ff99ff", text = "Polymorph Immune", icon = "Interface\\Icons\\Spell_Nature_Polymorph" },
    FEAR      = { hex = "9933ff", text = "Fear Immune",    icon = "Interface\\Icons\\Spell_Shadow_Possession" },
    SNARE     = { hex = "33ccff", text = "Snare/Root Immune", icon = "Interface\\Icons\\Spell_Frost_FrostNova" },
    SILENCE   = { hex = "ffcc66", text = "Silence Immune", icon = "Interface\\Icons\\Spell_Holy_Silence" },
    SLEEP     = { hex = "6699ff", text = "Sleep Immune",   icon = "Interface\\Icons\\Spell_Nature_Sleep" },
    POISON    = { hex = "00ff88", text = "Poison Immune",  icon = "Interface\\Icons\\Ability_Creature_Poison_01" },
}

-- Known Taunt Spells
addon.TAUNT_SPELLS = {
    [355]   = true, -- Taunt (Warrior)
    [1161]  = true, -- Challenging Shout
    [694]   = true, -- Mocking Blow
    [7400]  = true, -- Mocking Blow rank 2
    [7402]  = true, -- Mocking Blow rank 3
    [6795]  = true, -- Growl (Druid)
    [5209]  = true, -- Challenging Roa
    [17735] = true, -- Torment (Warlock Voidwalker)
    [31789] = true, -- Righteous Defense (Paladin)
    [49576] = true, -- Death Grip
    [56222] = true, -- Dark Command
}

-- Secret value detection (WoW 11.0+ / 12.0+ security protection against combat-tainted secret values)
function addon:IsSecretValue(val)
    if issecretvalue then
        local ok, res = pcall(issecretvalue, val)
        if ok and res then
            return true
        end
    end
    if issecrettable and type(val) == "table" then
        local ok, res = pcall(issecrettable, val)
        if ok and res then
            return true
        end
    end
    local okNil, isNil = pcall(function() return val == nil end)
    if not okNil then return true end
    if isNil then return false end

    -- In WoW 11.0+ / 12.0+, secret values error on tostring, comparison, or arithmetic/string operations when tainted
    local ok = pcall(function()
        local _ = tostring(val)
        local _ = (val == val)
    end)
    if not ok then return true end

    local t = type(val)
    if t == "string" then
        local okOps = pcall(function()
            local _ = string.sub(val, 1, 0)
            local _ = (val == "")
        end)
        if not okOps then return true end
    elseif t == "number" then
        local okNum = pcall(function()
            local _ = (val > 0)
            local _ = val + 0
        end)
        if not okNum then return true end
    elseif t == "boolean" then
        local okBool = pcall(function()
            if val then
                local _ = true
            end
        end)
        if not okBool then return true end
    end
    return false
end

-- Safe string coercion returning fallback if val is secret, nil, or invalid
function addon:SafeString(val, fallback)
    if self:IsSecretValue(val) or val == nil then
        return fallback
    end
    if type(val) == "string" then
        return val
    elseif type(val) == "number" then
        return tostring(val)
    end
    return fallback
end

-- Safe number coercion returning fallback if val is secret, nil, or non-numeric
function addon:SafeNumber(val, fallback)
    if self:IsSecretValue(val) or val == nil then
        return fallback
    end
    local ok, num = pcall(tonumber, val)
    if not ok or not num or self:IsSecretValue(num) then
        return fallback
    end
    return num
end

-- Safe boolean coercion returning fallback if val is secret or nil
function addon:SafeBool(val, fallback)
    if self:IsSecretValue(val) or val == nil then
        return fallback or false
    end
    local ok, res = pcall(function()
        return val and true or false
    end)
    if not ok or self:IsSecretValue(res) then
        return fallback or false
    end
    return res
end

-- Check whether developer debug mode is enabled
function addon:IsDebugMode()
    return (self.db and self.db.settings and self.db.settings.debugMode == true) or false
end

-- Execute a function safely: suppresses unexpected errors in normal mode (debugMode == false),
-- or allows real Lua errors to surface when debugMode == true.
function addon:SafeCall(func, ...)
    if self:IsDebugMode() then
        return true, func(...)
    end
    return pcall(func, ...)
end

-- Message printer helper
function addon:Print(msg, ...)
    if select("#", ...) > 0 then
        msg = string.format(msg, ...)
    end
    DEFAULT_CHAT_FRAME:AddMessage("|TInterface\\Icons\\INV_Misc_Book_09:14:14:0:0|t |cff00ff96[Compendium]|r " .. tostring(msg))
end

-- Slash command handle
local function SlashCommandHandler(msg)
    local args = {}
    for word in string.gmatch(msg or "", "%S+") do
        table.insert(args, word)
    end

    local cmd = string.lower(args[1] or "")
    local param = args[2]

    if cmd == "window" or cmd == "browser" or cmd == "pokedex" or cmd == "open" or cmd == "gui" or cmd == "show" or cmd == "" then
        addon:ToggleCompendiumWindow()
    elseif cmd == "options" or cmd == "config" or cmd == "menu" or cmd == "settings" then
        addon:OpenOptions()
    elseif cmd == "minimap" or cmd == "icon" then
        local newState = not addon.db.settings.showMinimap
        if addon.SetMinimapButtonShown then
            addon:SetMinimapButtonShown(newState)
        else
            addon.db.settings.showMinimap = newState
            if addon.minimapButton then
                if newState then addon.minimapButton:Show() else addon.minimapButton:Hide() end
            end
        end
        addon:Print("Minimap button: %s", addon.db.settings.showMinimap and "|cff00ff00Enabled|r" or "|cffff2020Disabled|r")
    elseif cmd == "status" or cmd == "info" then
        addon:PrintStatus()
    elseif cmd == "lootkey" or cmd == "lootmod" then
        local choice = string.upper(param or "")
        if choice == "NONE" then choice = "ALWAYS" end
        if choice == "SHIFT" or choice == "CTRL" or choice == "ALT" or choice == "ALWAYS" or choice == "NEVER" then
            addon.db.settings.modifierKeyLoot = choice
            addon:Print("Loot tooltip activation mode set to: |cffffd100%s|r", choice)
        else
            addon:Print("Invalid mode. Choose: |cffffd100SHIFT|r, |cffffd100CTRL|r, |cffffd100ALT|r, |cffffd100ALWAYS|r, or |cffffd100NEVER|r")
        end
    elseif cmd == "combatkey" or cmd == "combatmod" then
        local choice = string.upper(param or "")
        if choice == "NONE" then choice = "ALWAYS" end
        if choice == "SHIFT" or choice == "CTRL" or choice == "ALT" or choice == "ALWAYS" or choice == "NEVER" then
            addon.db.settings.modifierKeyCombat = choice
            addon:Print("Combat tooltip activation mode set to: |cffffd100%s|r", choice)
        else
            addon:Print("Invalid mode. Choose: |cffffd100SHIFT|r, |cffffd100CTRL|r, |cffffd100ALT|r, |cffffd100ALWAYS|r, or |cffffd100NEVER|r")
        end
    elseif cmd == "profkey" or cmd == "profmod" or cmd == "professionkey" then
        local choice = string.upper(param or "")
        if choice == "NONE" then choice = "ALWAYS" end
        if choice == "SHIFT" or choice == "CTRL" or choice == "ALT" or choice == "ALWAYS" or choice == "NEVER" then
            addon.db.settings.modifierKeyProfession = choice
            addon:Print("Profession tooltip activation mode set to: |cffffd100%s|r", choice)
        else
            addon:Print("Invalid mode. Choose: |cffffd100SHIFT|r, |cffffd100CTRL|r, |cffffd100ALT|r, |cffffd100ALWAYS|r, or |cffffd100NEVER|r")
        end
    elseif cmd == "layout" or cmd == "tooltiplayout" then
        local choice = string.upper(param or "")
        if choice == "SIDECAR" or choice == "SIDECARS" then
            addon.db.settings.tooltipLayout = "SIDECAR"
            addon.db.settings.separateTooltip = true
            addon:Print("Tooltip layout set to: |cffffd100Dedicated Sidecars|r")
        elseif choice == "EMBEDDED" or choice == "EMBED" or choice == "MERGED" then
            addon.db.settings.tooltipLayout = "EMBEDDED"
            addon.db.settings.separateTooltip = false
            addon:Print("Tooltip layout set to: |cffffd100Embedded in Main Tooltip|r")
        else
            addon:Print("Usage: |cffffd100/acc layout <sidecar|embedded>|r")
        end
    elseif cmd == "dock" or cmd == "docking" then
        local choice = string.upper(param or "")
        if choice == "BESIDE" or choice == "HORIZONTAL" or choice == "SIDE" then
            addon.db.settings.sidecarAnchor = "HORIZONTAL"
            addon:Print("Sidecar docking position set to: |cffffd100Beside Main Tooltip (Horizontal)|r")
        elseif choice == "ABOVE" or choice == "VERTICAL" or choice == "STACK" then
            addon.db.settings.sidecarAnchor = "VERTICAL"
            addon:Print("Sidecar docking position set to: |cffffd100Above / Below Main Tooltip (Vertical)|r")
        else
            addon:Print("Usage: |cffffd100/acc dock <beside|above>|r")
        end
    elseif cmd == "anchor" or cmd == "targetanchor" or cmd == "point" then
        local choice = string.upper(param or "")
        if choice == "CURSOR" or choice == "MOUSE" then
            addon.db.settings.tooltipAnchor = "CURSOR"
            addon:Print("Tooltip anchor point set to: |cffffd100At Mouse Cursor|r")
        elseif choice == "BLIZZARD" or choice == "MAIN" or choice == "TOOLTIP" then
            addon.db.settings.tooltipAnchor = "BLIZZARD"
            addon:Print("Tooltip anchor point set to: |cffffd100Attached to Main Tooltip|r")
        else
            addon:Print("Usage: |cffffd100/acc anchor <tooltip|cursor>|r")
        end
    elseif cmd == "newmob" or cmd == "firstencounter" or cmd == "unrecorded" then
        addon.db.settings.showNewMobTooltip = not addon.db.settings.showNewMobTooltip
        addon:Print("Unrecorded creature tooltip info: %s", addon.db.settings.showNewMobTooltip and "|cff00ff00Enabled|r" or "|cffff2020Disabled|r")
    elseif cmd == "debug" or cmd == "debugmode" then
        addon.db.settings.debugMode = not addon.db.settings.debugMode
        addon:Print("Debug mode (show raw Lua errors): %s", addon.db.settings.debugMode and "|cffff8000Enabled|r" or "|cff00ff00Disabled (Safe Mode)|r")
    elseif cmd == "max" or cmd == "top" or cmd == "limit" then
        local num = tonumber(param)
        if num and num >= 1 and num <= 25 then
            addon.db.settings.maxItems = math.floor(num)
            addon:Print("Maximum tooltip items set to: |cffffd100%d|r", math.floor(num))
        else
            addon:Print("Please enter a number between 1 and 25 (e.g., |cffffd100/acc max 8|r)")
        end
    elseif cmd == "lookup" or cmd == "find" or cmd == "search" then
        local query = table.concat(args, " ", 2)
        if query and query ~= "" then
            addon:LookupMob(query)
        else
            addon:Print("Usage: |cffffd100/acc lookup <Mob Name>|r")
        end
    elseif cmd == "reset" or cmd == "clear" then
        if param == "confirm" then
            if AzerothCreatureCompendiumDB then
                AzerothCreatureCompendiumDB.zones = {}
                AzerothCreatureCompendiumDB.npcToZones = {}
            end
            if BgLootLoggerDB then
                BgLootLoggerDB.zones = {}
                BgLootLoggerDB.npcToZones = {}
            end
            addon:Print("|cffff2020Database wiped! All recorded creature, combat, and loot data has been cleared.|r")
        else
            addon:Print("|cffff2020WARNING:|r To permanently erase all recorded data, type: |cffffd100/acc reset confirm|r")
        end
    else
        -- Help display
        addon:Print("Azeroth Creature Compendium Commands (|cffffd100/acc|r, |cffffd100/compendium|r, or |cffffd100/bgl|r):")
        print("  |cffffd100/acc|r - Open the Creature Compendium window")
        print("  |cffffd100/acc minimap|r - Toggle the minimap button icon")
        print("  |cffffd100/acc options|r - Open Settings panel")
        print("  |cffffd100/acc status|r - View database discovery stats")
        print("  |cffffd100/acc lootkey <SHIFT|CTRL|ALT|ALWAYS|NEVER>|r - Set Loot tooltip activation")
        print("  |cffffd100/acc combatkey <SHIFT|CTRL|ALT|ALWAYS|NEVER>|r - Set Combat tooltip activation")
        print("  |cffffd100/acc profkey <SHIFT|CTRL|ALT|ALWAYS|NEVER>|r - Set Profession tooltip activation")
        print("  |cffffd100/acc layout <sidecar|embedded>|r - Toggle dedicated sidecars vs embedded inside GameTooltip")
        print("  |cffffd100/acc anchor <tooltip|cursor>|r - Set tooltip anchor to main tooltip or mouse cursor")
        print("  |cffffd100/acc dock <beside|above>|r - Set sidecar docking orientation")
        print("  |cffffd100/acc newmob|r - Toggle tooltip info on unrecorded creatures")
        print("  |cffffd100/acc debug|r - Toggle Debug Mode (show raw Lua errors vs fail-safe suppression)")
        print("  |cffffd100/acc max <1-25>|r - Max drops shown in tooltip")
        print("  |cffffd100/acc lookup <name>|r - Search recorded creature by name")
        print("  |cffffd100/acc reset confirm|r - Clear all recorded compendium history")
    end
end

-- Primary slash commands
SLASH_AZEROTHCREATURECOMPENDIUM1 = "/acc"
SLASH_AZEROTHCREATURECOMPENDIUM2 = "/compendium"
SLASH_AZEROTHCREATURECOMPENDIUM3 = "/accp"
SLASH_AZEROTHCREATURECOMPENDIUM4 = "/pokedex"
-- Backwards compatibility aliases
SLASH_AZEROTHCREATURECOMPENDIUM5 = "/bgl"
SLASH_AZEROTHCREATURECOMPENDIUM6 = "/bgloot"
SLASH_AZEROTHCREATURECOMPENDIUM7 = "/bglootlogger"
SlashCmdList["AZEROTHCREATURECOMPENDIUM"] = SlashCommandHandler
