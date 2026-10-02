-- .luacheckrc - Configuration for Azeroth Creature Compendium
-- World of Warcraft Classic Lua static analysis rules

std = "max"

-- WoW event callbacks and Blizzard UI handlers often have fixed positional signatures
unused_args = false

-- Disable line length limit (WoW UI strings, color hexes, and formats often exceed 120 chars)
max_line_length = false

-- Allow setting fields on _G
ignore = {
    "122", -- setting read-only field of global
    "142", -- setting read-only field of global
    "143", -- accessing undefined field of global
}

-- Global variable access settings
globals = {
    -- Addon saved variables and global namespaces
    "AzerothCreatureCompendiumDB",
    "BgLootLoggerDB",
    -- Slash command registration globals
    "SLASH_AZEROTHCREATURECOMPENDIUM1",
    "SLASH_AZEROTHCREATURECOMPENDIUM2",
    "SLASH_AZEROTHCREATURECOMPENDIUM3",
    "SLASH_AZEROTHCREATURECOMPENDIUM4",
    "SLASH_AZEROTHCREATURECOMPENDIUM5",
    "SLASH_AZEROTHCREATURECOMPENDIUM6",
    "SLASH_AZEROTHCREATURECOMPENDIUM7",
    "SlashCmdList",
}

read_globals = {
    -- Core WoW & Lua Globals
    "_G",
    "time",
    "date",
    "strtrim",
    "strsplit",
    "wipe",
    "tinsert",
    "tremove",
    "hooksecurefunc",
    "GetTime",

    -- WoW UI & Frame Globals
    "CreateFrame",
    "UIParent",
    "WorldFrame",
    "Minimap",
    "GameTooltip",
    "DEFAULT_CHAT_FRAME",
    "Settings",
    "InterfaceOptionsFrame_OpenToCategory",
    "InterfaceOptions_AddCategory",
    "TooltipDataProcessor",
    "Enum",
    "UISpecialFrames",
    "SetPortraitToTexture",
    "SearchBoxTemplate_OnTextChanged",
    "FauxScrollFrame_OnVerticalScroll",
    "FauxScrollFrame_Update",
    "FauxScrollFrame_GetOffset",
    "IsModifiedClick",
    "ChatEdit_InsertLink",

    -- Font Objects
    "GameFontNormal",
    "GameFontNormalSmall",
    "GameFontNormalLarge",
    "GameFontHighlight",
    "GameFontHighlightSmall",
    "GameFontHighlightLarge",
    "GameFontDisable",
    "GameFontDisableSmall",
    "GameFontGreen",
    "GameFontRed",
    "GameFontYellow",

    -- Sound & Misc
    "PlaySound",
    "SOUNDKIT",

    -- WoW Unit & Map APIs
    "UnitExists",
    "UnitGUID",
    "UnitName",
    "UnitClassification",
    "UnitLevel",
    "UnitCreatureType",
    "UnitReaction",
    "UnitCanAttack",
    "UnitIsDead",
    "UnitIsFriend",
    "UnitHealth",
    "UnitHealthMax",
    "GetSubZoneText",
    "GetRealZoneText",
    "GetZoneText",

    -- WoW Input & Screen APIs
    "GetCursorPosition",
    "GetScreenHeight",
    "GetScreenWidth",
    "IsShiftKeyDown",
    "IsControlKeyDown",
    "IsAltKeyDown",
    "IsMouseButtonDown",

    -- WoW Combat Log APIs & Constants
    "CombatLogGetCurrentEventInfo",
    "CombatLog_Object_IsA",
    "COMBATLOG_OBJECT_REACTION_HOSTILE",
    "COMBATLOG_OBJECT_CONTROL_PLAYER",
    "COMBATLOG_OBJECT_TYPE_NPC",

    -- WoW Item, Spell, Metadata & Loot APIs
    "GetSpellInfo",
    "GetSpellTexture",
    "GetItemInfo",
    "GetItemQualityColor",
    "GetNumLootItems",
    "GetLootSlotInfo",
    "GetLootSlotLink",
    "GetLootSlotType",
    "GetLootSourceInfo",
    "GetCoinTextureString",
    "GetAddOnMetadata",
    "LOOT_SLOT_MONEY",
    "LOOT_SLOT_ITEM",

    -- C-Namespaces
    "C_Map",
    "C_Item",
    "C_Spell",
    "C_CurrencyInfo",
    "C_Timer",
    "C_AddOns",

    -- Modern & Security Globals
    "issecretvalue",
    "InCombatLockdown",
}
