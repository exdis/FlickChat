std = "lua51"
max_line_length = false
exclude_files = { "tools/**", "dev/**" }

ignore = {
    "431",  -- shadowing upvalue
    "432",  -- shadowing upvalue argument
}

globals = {
    "FlickChatDB",
    "FlickChat_AttachDevTools",
    "SlashCmdList",
    "SLASH_FLICKCHAT1", "SLASH_FLICKCHAT2", "SLASH_FLICKCHAT3",
}

read_globals = {
    "CreateFrame", "UIParent", "C_Timer", "Settings", "wipe", "InputUtil", "STANDARD_TEXT_FONT", "issecretvalue",
    "SOUNDKIT", "InCombatLockdown", "GetBindingText", "C_Texture", "C_FriendList", "GetCVar", "IsInGuild", "GetTime",
    "GetLocale", "GetBindingAction", "ChatFrameUtil", "UnitIsUnit", "SetBinding", "IsInRaid", "GetUnitName",
    "GetNumGuildMembers", "GetCurrentKeyBoardFocus", "GameFontNormal", "GameFontHighlight", "C_AddOns", "UnitName",
    "UnitIsPlayer", "SaveBindings", "PlaySound", "NineSliceUtil", "NineSliceLayouts", "IsInGroup", "hooksecurefunc",
    "GetNumGroupMembers", "GetGuildRosterInfo", "GetCurrentBindingSet", "CreateSettingsListSectionHeaderInitializer",
    "CreateSettingsButtonInitializer", "ChatFrame1", "ChatFrame1EditBox", "C_GamePad", "BNGetNumFriends",
    "C_BattleNet", "SetOverrideBindingClick", "ClearOverrideBindings", "NUM_CHAT_WINDOWS", "FloatingChatFrameMixin", "SmartNavigation", "issecurevariable",
    "MinimalSliderWithSteppersMixin", "LOCALIZED_CLASS_NAMES_MALE", "LE_PARTY_CATEGORY_INSTANCE", "GetZoneText",
    "GetSubZoneText", "GetChannelList", "GENERAL_CHAT_DOCK", "GamepadPersistentInputLegend", "FCFDock_SelectWindow",
    "Enum", "debugstack", "IsUsingGamepad", "OKAY", "GetNumFriends", "date",
}
