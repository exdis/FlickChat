std = "lua51"
max_line_length = 120
exclude_files = { "tools/**" }

globals = {
    "FallensGamepadChatDB",
    "SlashCmdList",
    "SLASH_FALLENSGAMEPADCHAT1",
}

read_globals = {
    "CreateFrame", "UIParent", "GetLocale", "GetBindingText", "IsUsingGamepad", "GetNumGroupMembers", "IsInRaid",
    "UnitName", "issecretvalue", "wipe", "NUM_CHAT_WINDOWS", "C_Timer", "GetTime", "STANDARD_TEXT_FONT",
    "C_FriendList", "IsInGuild", "GetNumGuildMembers", "GetGuildRosterInfo", "GetZoneText", "GetSubZoneText",
    "LOCALIZED_CLASS_NAMES_MALE", "IsInGroup", "LE_PARTY_CATEGORY_INSTANCE", "ChatFrameUtil", "UnitIsPlayer",
    "UnitIsUnit", "GetUnitName", "GetChannelList", "BNGetNumFriends", "C_BattleNet",
    "GetCurrentKeyBoardFocus",
}
