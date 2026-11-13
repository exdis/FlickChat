date = os.date
-- lua tools/tests/smoke_test.lua <addon dir>: loads every file the toc lists under stubbed game frames, then
-- drives the keyboard through its own stick and button handlers and checks what comes of it.
local dir = arg[1]
math.atan2 = math.atan2 or math.atan
local now = 100
function GetTime() return now end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return "enUS" end
function GetBindingText(key) return "[" .. key .. "]" end
function IsUsingGamepad() return true end
focus = nil
function GetCurrentKeyBoardFocus() return focus end
function GetNumGroupMembers() return 2 end
function IsInRaid() return false end
function UnitName(u) if u == "party1" then return "Arthas" end end
function IsInGuild() return false end
function GetZoneText() return "Elwynn Forest" end
function GetSubZoneText() return "Goldshire" end
issecretvalue = function() return false end
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
NUM_CHAT_WINDOWS = 1
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior" }
SlashCmdList = {}
GameFontNormal = {}
Enum = Enum or { UITextureSliceMode = { Stretched = 0 } }
C_Texture = { GetAtlasInfo = function() return { width = 32, height = 32 } end }
MinimalSliderWithSteppersMixin = { Label = { Right = 2 }, Event = { OnValueChanged = "OnValueChanged" } }
SOUNDKIT = {}
function PlaySound() end
local cvars = { GamePadEnable = "1", GamePadEmulateCtrl = "PADRSHOULDER", GamePadEmulateShift = "NONE" }
function GetCVar(k) return cvars[k] end
function GetCVarBool(k) return cvars[k] == "1" end
bindings = { ["CTRL-PADBACK"] = "TOGGLEWORLDMAP" }
function GetBindingAction(k) return bindings[k] or "" end
function GetBindingKey(a) local out = {} for k, v in pairs(bindings) do if v == a then out[#out + 1] = k end end return unpack(out) end
function SetBinding(k, a) bindings[k] = a end
function SaveBindings() end
function GetCurrentBindingSet() return 1 end
function InCombatLockdown() return false end
overrides = {}
function hooksecurefunc(name, fn) if type(name) == 'string' then local old = _G[name] _G[name] = function(...) old(...) fn(...) end end end
function ClearOverrideBindings() overrides = {} end
function SetOverrideBindingClick(owner, priority, key, button) overrides[key] = button end
unpack = unpack or table.unpack
local timers = {}
C_Timer = {
    After = function(_, fn) timers[#timers + 1] = fn end,
    NewTimer = function(_, fn) local t = { fn = fn, Cancel = function(self) self.dead = true end } timers[#timers + 1] = t return t end,
    NewTicker = function(_, fn) lastTick = fn return { Cancel = function() end } end,
}
padDown = {}
C_GamePad = { ButtonBindingToIndex = function(b) return ({ PADBACK = 4, PADLSHOULDER = 9, PADRSHOULDER = 10 })[b] end,
    GetDeviceMappedState = function() return { buttons = padDown } end }
C_FriendList = { GetNumFriends = function() return 1 end,
    GetFriendInfoByIndex = function() return { name = "Arnold-Realm", connected = true } end }
function BNGetNumFriends() return 1 end
C_BattleNet = { GetFriendAccountInfo = function() return { battleTag = "Aragorn#1234", accountName = "|Kq1|k",
    gameAccountInfo = { isOnline = true, characterName = "Strider" } } end }
LE_PARTY_CATEGORY_INSTANCE = 2
function IsInGroup() return false end
function UnitIsPlayer(u) return u == "target" end
function UnitIsUnit() return false end
function GetUnitName() return "Varian" end
function GetChannelList() return 1, "General", false, 2, "Trade", false, 3, "Muted", true end
CHAT_MSG_SAY, CHAT_MSG_PARTY, CHAT_MSG_GUILD, CHAT_MSG_RAID = "Say", "Party", "Guild", "Raid"
local tells = { "Jaina", "Thrall" }
ChatFrameUtil = {
    GetLastTellTarget = function() return tells[1], "WHISPER" end,
    GetNextTellTarget = function(name)
        for i, t in ipairs(tells) do if t == name then return tells[i + 1], tells[i + 1] and "WHISPER" end end
    end,
}

local openedCategory
Settings = {
    RegisterVerticalLayoutCategory = function(name)
        return { name = name, GetID = function() return 77 end }, { AddInitializer = function() end }
    end,
    RegisterCanvasLayoutSubcategory = function(category, frame) category.frame = frame end,
    RegisterCanvasLayoutCategory = function(frame, name) return { name = name, frame = frame } end,
    RegisterProxySetting = function(_, variable, kind, name, default, get, set)
        local key = variable:match("_(%a+)$")
        Settings.rows[key] = { tbl = setmetatable({}, { __index = function() return get() end,
            __newindex = function(_, _, v) set(v) end }) }
        return Settings.rows[key]
    end,
    rows = {},
    CreateCheckbox = function() end, CreateDropdown = function() end, CreateSlider = function() end,
    CreateSliderOptions = function() return { SetLabelFormatter = function() end } end,
    CreateControlTextContainer = function() return { Add = function() end, GetData = function() return {} end } end,
    RegisterAddOnCategory = function(category) Settings.registered = category end,
    OpenToCategory = function(id) openedCategory = id end,
}
C_AddOns = { GetAddOnMetadata = function() return "FlickChat" end }

local frames = {}
local generic = {}
function generic.SetScript(self, name, fn) self.scripts[name] = fn end
function generic.GetScript(self, name) return self.scripts[name] end
function generic.HookScript(self, name, fn) self.hooks = self.hooks or {}; self.hooks[name] = fn end
function generic.Show(self) if not self.shown then self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end end
function generic.Hide(self) if self.shown then self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end end
function generic.IsShown(self) return self.shown end
function generic.SetText(self, t) self.text = t end
function generic.SetShown(self, on) if on then generic.Show(self) else generic.Hide(self) end end
function generic.SetVerticalScroll(self, v) self.scrolled = v end
function generic.GetVerticalScroll(self) return self.scrolled or 0 end
function generic.GetText(self) return self.text end
function generic.GetStringWidth(self) return #(self.text or "") * 12 end
function generic.GetStringHeight(self) return 16 end
function generic.GetUnboundedStringWidth(self) return #(self.text or "") * 12 end
function generic.GetFontString(self) self.fs = self.fs or setmetatable({ text = "" }, { __index = generic }) return self.fs end
function generic.SetChecked(self, v) self.checked = v end
function generic.GetChecked(self) return self.checked end
function generic.SetValue(self, v) self.value = v end
function generic.SetWidth(self, w) assert(type(w) == "number", "SetWidth " .. tostring(w)) self.w = w end
function generic.SetHeight(self, h) assert(type(h) == "number", "SetHeight " .. tostring(h)) self.h = h end
function generic.SetSize(self, w, h) generic.SetWidth(self, w) generic.SetHeight(self, h) end
function generic.GetWidth(self) return self.w or 100 end
function generic.GetEffectiveScale() return 1 end
function generic.GetScale() return 1 end
function generic.CreateAnimationGroup(self)
    local anim = { played = false }
    local piece = setmetatable({}, { __index = function() return function() end end })
    return setmetatable(anim, { __index = function(t, k)
        if k == "CreateAnimation" then return function() return piece end end
        if k == "Play" then return function(a) a.played = true end end
        if k == "Stop" then return function(a) a.played = false end end
        return function() end
    end })
end
function generic.GetHeight(self) return self.h or 20 end
function generic.GetTop() return 300 end
function generic.GetLeft() return 0 end
function generic.GetBottom() return 0 end
function generic.GetFrameLevel() return 1 end
function generic.GetCenter() return 300, 100 end
function generic.GetParent(self) return self.parent end
function generic.SetFont(self, f, size) assert(type(size) == "number") self.font = true end
function generic.SetPoint(self, ...) for i = 1, select("#", ...) do local v = select(i, ...) assert(v ~= nil or i > 1, "nil point arg") end end
function generic.SetTextColor(self, r, g, b) assert(r and g and b, "color") end
local function Obj(parent)
    local o = { scripts = {}, shown = false, text = "", parent = parent }
    return setmetatable(o, { __index = function(t, k)
        if generic[k] then return generic[k] end
        if k == "CreateTexture" or k == "CreateFontString" or k == "CreateMaskTexture" then
            return function(self) local c = Obj(self) c.shown = true return c end
        end
        if k:match("^%u") then return function() end end
    end })
end
function CreateSettingsButtonInitializer() return {} end
function CreateFrame(_, name, parent)
    local f = Obj(parent)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = Obj()
function UIParent.GetWidth() return 1920 end
function UIParent.GetHeight() return 1080 end
function generic.HasFocus(self) return focus == self end

local sent = {}
local box = Obj(UIParent)
box.shown = false
box.scripts.OnEnterPressed = function(self) sent[#sent + 1] = self.text; self.text = ""; generic.Hide(self) end
box.scripts.OnEscapePressed = function(self) if (self.text or "") ~= "" then self.text = "" else generic.Hide(self) end end
function box.HighlightText(self, a, b) self.hl = { a, b } end
box.attr = { chatType = "SAY" }
function box.SetChatType(self, v) self.attr.chatType = v end
function box.GetChatType(self) return self.attr.chatType end
function box.SetTellTarget(self, v) self.attr.tellTarget = v end
function box.GetTellTarget(self) return self.attr.tellTarget end
function box.SetChannelTarget(self, v) self.attr.channelTarget = v end
function box.GetChannelTarget(self) return self.attr.channelTarget or 0 end
function box.UpdateHeader(self) self.header = self.attr.chatType .. ":" .. tostring(self.attr.tellTarget or self.attr.channelTarget or "") end
ChatFrame1EditBox = box
-- the game's controller cursor, there before the addon loads
SmartNavigation = Obj(UIParent)

local ns = {}
-- every file the toc lists, in its order
local loaded = 0
for line in io.lines(dir .. "/FlickChat.toc") do
    line = line:gsub("\r", ""):gsub("\\", "/")
    if line ~= "" and line:sub(1, 1) ~= "#" then
        assert(loadfile(dir .. "/" .. line))("FlickChat", ns)
        loaded = loaded + 1
    end
end
assert(loaded >= 5, "the toc lists too few files")
ns.events.scripts.OnEvent(ns.events, "ADDON_LOADED", "FlickChat")
ns.db.lessonDone = true

local function Open()
    box.text = ""
    generic.Show(box)
    focus = box
    box.hooks.OnEditFocusGained(box)
end
local kb = _G.FlickChatKeyboard
local function Hidden()
    focus = nil
    box.hooks.OnEditFocusLost(box)
end
box.scripts.OnHide = Hidden

local VEC = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } }
local function Flick(digit)
    local d = tonumber(digit)
    local stick = d <= 4 and "Left" or "Right"
    local v = VEC[(d - 1) % 4 + 1]
    local kbf = _G.FlickChatKeyboard
    now = now + 0.05
    kbf.scripts.OnGamePadStick(kbf, stick, v[1] * 0.5, v[2] * 0.5, 0.5)
    kbf.scripts.OnGamePadStick(kbf, stick, v[1], v[2], 1)
    now = now + 0.05
    kbf.scripts.OnGamePadStick(kbf, stick, 0, 0, 0)
    now = now + 0.2
end
local function Type(word) for d in ns.Dict.KeyOf(word):gmatch("%d") do Flick(d) end end
local function Press(b)
    local kbf = _G.FlickChatKeyboard
    lastTick = nil
    kbf.scripts.OnGamePadButtonDown(kbf, b)
    -- View: one look with it down, then let go
    if b == "PADBACK" and lastTick then padDown[4] = true lastTick() padDown[4] = nil lastTick() end
    kbf.scripts.OnGamePadButtonUp(kbf, b)
end

local failed = 0
local function Is(what, got, want)
    if got == want then
        print("ok    " .. what)
    else
        failed = failed + 1
        print(("FAIL  %s: got %s, wanted %s"):format(what, tostring(got), tostring(want)))
    end
end
local function Has(what, text, piece)
    Is(what .. " (" .. piece .. ")", tostring(text):find(piece, 1, true) ~= nil, true)
end
local function Down(b) kb.scripts.OnGamePadButtonDown(kb, b) end
local function Up(b) kb.scripts.OnGamePadButtonUp(kb, b) end
local function Told() return (kb.hint.text or ""):gsub("%s*\n%s*", " / ") end
local T = ns.DevTools()
local function SlotOf(word)
    for i = 1, 4 do
        if (T.state.slots[i] or ""):lower() == word then return ({ "PADDUP", "PADDLEFT", "PADDRIGHT", "PADDDOWN" })[i] end
    end
end
-- the left stick along the rim from one angle to another, then let go
local function Roll(from, to)
    for deg = from, to, to > from and 15 or -15 do
        local r = math.rad(deg)
        kb.scripts.OnGamePadStick(kb, "Left", math.cos(r), math.sin(r), 1)
        now = now + 0.03
    end
    kb.scripts.OnGamePadStick(kb, "Left", 0, 0, 0)
    now = now + 0.2
end

-- the typing line belongs to a chat window, with the game's own controller footer on it
local legend = setmetatable({ scripts = {}, shown = true, hooks = {} }, { __index = function(_, k) return generic[k] or function() end end })
legend.HookScript = function(self, name, fn) self.hooks[name] = fn end
legend.IsForbidden = function() return false end
box.chatFrame = setmetatable({ footer = { inputLegend = legend, isShown = true } }, { __index = function(_, k)
    if k == "IsForbidden" then return function() return false end end
    if k == "GetFrameStrata" then return function() return "LOW" end end
    return generic[k] or function() end
end })

-- a word, kept, sent
Open()
kb = _G.FlickChatKeyboard
Is("the keyboard comes with chat", kb.shown, true)
Type("hello")
Is("flicks spell a word", box.text, "Hello")
Press("PADRTRIGGER")
Is("RT keeps it with a space", box.text, "Hello ")
Type("there")
Press("PAD1")
Is("A sends the line", sent[#sent], "Hello there")

-- a word off the d-pad before it is fully flicked
Open()
local key = ns.Dict.KeyOf("anyone")
for i = 1, #key do
    if SlotOf("anyone") then break end
    Flick(key:sub(i, i))
end
Is("a long word reaches the d-pad early", SlotOf("anyone") ~= nil and #T.state.flicks < #key, true)
Press(SlotOf("anyone") or "PADDUP")
Is("the d-pad takes it", box.text, "Anyone ")

-- B keeps an unsent message; View clears it
Press("PAD2")
Is("B closes the keyboard", kb.shown, false)
Open()
Is("the unsent message is back", box.text, "Anyone ")
Press("PADBACK")
Is("View clears the line", box.text, "")

-- quick phrases chained while A is held go as one message
local count = #sent
Down("PAD1")
Flick(1)
Flick(2)
Is("phrases held back while A is down", #sent, count)
Up("PAD1")
Is("they send together on letting go", #sent, count + 1)

-- a box only passed through on a swing across is read as maybe not meant
local words = table.concat(ns.Dict.Decode("321432", "<s>", 5), " "):lower()
Has("the word finder drops a passed-through box", words, "heal")

-- the lesson: a wrong word kept is pointed out, and the chaining drill holds to one move
Hidden()
ns.db.lessonDone = false
Open()
Is("the lesson starts", T.state.lesson ~= nil, true)
Flick(1) Flick(5) Flick(8)
Press("PADRTRIGGER")
Has("a word that is not in the line is pointed out", Told(), "not in the line")
for _ = 1, 4 do Press("PADLTRIGGER") end
T.state.lesson.at = 4
Press("PADBACK")
Flick(3) Flick(2)
Is("two flicks apart do not pass the drill", T.state.lesson.stage or 1, 1)
Roll(-90, 0)
Is("one move passes its first stage", T.state.lesson.stage, 2)
Roll(-90, 180)
Is("and its second", T.state.lesson.stage, 3)
Roll(-90, 180)
Flick(2)
Is("the last stage ends on the swing across", T.state.lesson.chained, true)
ns.db.lessonDone = true

-- typing practice scores a right word and a wrong one, and sends nothing
Hidden()
count = #sent
SlashCmdList.FLICKCHAT("practice")
Open()
local pane = _G.FlickChatPractice
Is("practice opens over chat", pane ~= nil and pane.shown, true)
local first = (pane.words.text or ""):match("|cfff0e342(%a+)|r")
ns.practice.Typed(first)
Has("a right word counts", pane.foot.text, "100%")
ns.practice.Typed("zzz")
Has("a wrong one halves it", pane.foot.text, "50%")
Press("PAD2")
Is("B ends practice", ns.practice, nil)
Is("nothing was sent", #sent, count)

-- the first-login window comes up with the keyboard under it as the preview
Hidden()
InputUtil = { IsGamepadUIEnabled = function() return true end }
cvars.chatStyle = "im"
ns.db.welcomed = nil
ns.events.scripts.OnEvent(ns.events, "PLAYER_LOGIN")
Is("a new player gets the window", _G.FlickChatNotice ~= nil and _G.FlickChatNotice.shown, true)
Is("with the keyboard as the preview", kb.shown, true)
generic.Hide(_G.FlickChatNotice)
Is("closing it puts the preview away", kb.shown, false)
Is("and it is not shown twice", ns.db.welcomed, true)

-- the settings are a window of the addon's own, worked by the pad; nothing goes on the game's Settings window
Is("no row on the game's Settings window", next(Settings.rows), nil)
local listed = Settings.registered
Is("its name is on the game's AddOns list, a page of its own", listed ~= nil and listed.frame ~= nil, true)
-- that page shown (the game's cursor picked the name): the settings window opens over it
listed.frame.IsVisible = function() return true end
generic.Show(listed.frame)
local soon = timers[#timers]
if type(soon) == "function" then soon() end
local own = _G.FlickChatOptions
Is("picking it there opens the settings", own ~= nil and own.shown, true)
generic.Hide(own)
generic.Hide(listed.frame)
SlashCmdList.FLICKCHAT("options")
Is("/flick options opens them too", own.shown, true)
local was = ns.db.lowercase
own.scripts.OnGamePadButtonDown(own, "PAD1")
Is("A flips the first box", ns.db.lowercase == true, not was)
own.scripts.OnGamePadButtonDown(own, "PAD1")
local size = ns.db.size
for _ = 1, 7 do own.scripts.OnGamePadButtonDown(own, "PADDDOWN") end
own.scripts.OnGamePadButtonDown(own, "PADDRIGHT")
Is("d-pad down to the size, right adds to it", ns.db.size, size + 5)
own.scripts.OnGamePadButtonDown(own, "PADDLEFT")
own.scripts.OnGamePadButtonDown(own, "PAD2")
Is("B shuts it", own.shown, false)

-- a chat window whose controller focus function another addon replaced: said once, naming who the game blames
local said = {}
local realPrint = print
FloatingChatFrameMixin = { SetGamepadFocus = function() end }
ChatFrame1 = { SetGamepadFocus = function() end }
function issecurevariable() return false, "SomeChatAddon" end
print = function(text) said[#said + 1] = text end
ns.events.scripts.OnEvent(ns.events, "GAME_PAD_ACTIVE_CHANGED", true)
timers[#timers]()
ns.events.scripts.OnEvent(ns.events, "GAME_PAD_ACTIVE_CHANGED", true)
timers[#timers]()
print = realPrint
Is("the switched-off menu Chat is said once", #said, 1)
Has("naming the addon the game blames", said[1], "SomeChatAddon")

-- a text box that is not chat (mail's To line): focused by the game's cursor, the keyboard comes up for it
Hidden()
generic.Hide(kb)
local mail = Obj(UIParent)
mail.shown = true
function mail.IsObjectType(_, kind) return kind == "EditBox" end
function mail.IsForbidden() return false end
SmartNavigation.hooks.OnShow(SmartNavigation)
local seek = lastTick
focus = mail
seek()
Is("the keyboard opens for another text box", kb.shown, true)
function mail.ClearFocus() focus = nil end
Is("nothing is hooked on such a box", mail.hooks, nil)
mail.scripts.OnEnterPressed = function(self) self.entered = true end
mail.scripts.OnEscapePressed = function(self) self.escaped = true end
Type("hi")
Press("PAD1")
Is("A keeps the text in the box", mail.text, "Hi")
Is("lets the box go, so the game's cursor is where it was", kb.shown, false)
Is("and never presses the box's Enter", mail.entered, nil)
-- back in, more typed, then B: what it held comes back
seek()
focus = mail
seek()
Type("no")
Press("PAD2")
Is("B puts back what the box held", mail.text, "Hi")
Is("and lets go without the box's Escape", kb.shown == false and mail.escaped == nil, true)
-- the game's cursor leaving the box (its focus gone by the game's hand) shuts the keyboard on the next look
seek()
focus = mail
seek()
Is("up again on the next Select", kb.shown, true)
focus = nil
seek()
Is("and gone when the game takes the focus away", kb.shown, false)

print(failed == 0 and "all checks passed" or (failed .. " check(s) failed"))
os.exit(failed == 0 and 0 or 1)
