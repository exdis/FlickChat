local addonName, ns = ...

-- Strings: each locale file fills its own; a missing one shows English, never its key.
ns.L = setmetatable({}, { __index = function(_, key) return ns.EN and ns.EN[key] or key end })

-- learned: word -> times sent; pairs: "word next" -> times ("<s>" starts a message); forms: a word's own capitals;
-- uses: how often each hint's action was used (a hint goes once learned); arm/rearm: a flick's tilt out and back;
-- phrases: the player's own quick phrases by slot (an empty slot is the language's default).
local DEFAULTS = { enabled = true, learned = {}, pairs = {}, forms = {}, forgot = {}, uses = {}, layout = "letters", size = 100,
    arm = 0.55, rearm = 0.3, lessonDone = false, phrases = {}, wheelSize = 100, wordRoom = 100 }
local DB_VERSION = 1
local LEARN_CAP, PAIR_CAP = 2000, 4000
local WHISPERS_KEPT = 10

ns.whispers = {}

-- 0 (the ring keyboard) carries over as is: its learned counts keep their meaning.
local function Migrate(db)
    db.dbVersion = DB_VERSION
end

ns.events = CreateFrame("Frame")
ns.events:RegisterEvent("ADDON_LOADED")
ns.events:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "GAME_PAD_ACTIVE_CHANGED" then
        if ns.PadActive then ns.PadActive(arg1) end
        return
    end
    if event == "PLAYER_LOGIN" then
        -- A pad chord an earlier build bound to Open Chat is let go (the game's controller mode opens chat itself).
        local db = ns.db
        if db.chatChord and not InCombatLockdown() then
            if GetBindingAction(db.chatChord) == "OPENCHAT" then
                SetBinding(db.chatChord)
                SaveBindings(GetCurrentBindingSet())
            end
            db.chatChord, db.chatChordOffered = nil, nil
        end
        -- The game's controller mode shows chat's typing line only with the IM chat style: a notice says so.
        db.imStyleTold = nil
        -- Every new player once, in the game's controller mode: the keyboard's size, and the chat style if it
        -- is the one the keyboard cannot open in. That one is told at each login until it is changed.
        local controller = InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled()
        if ns.NeedsIMStyle() or (controller and not db.welcomed) then ns.StyleNotice() end
        return
    end
    if event == "CHAT_MSG_WHISPER" then
        local name = type(arg2) == "string" and not (issecretvalue and issecretvalue(arg2)) and arg2:match("^[^%-]+")
        if name then
            for i = #ns.whispers, 1, -1 do
                if ns.whispers[i] == name then table.remove(ns.whispers, i) end
            end
            table.insert(ns.whispers, 1, name)
            ns.whispers[WHISPERS_KEPT + 1] = nil
        end
        return
    end
    if event ~= "ADDON_LOADED" or arg1 ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    FlickChatDB = FlickChatDB or {}
    local db = FlickChatDB
    Migrate(db)
    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then db[key] = type(value) == "table" and {} or value end
    end
    ns.db = db
    ns.BuildOptions()
    self:RegisterEvent("CHAT_MSG_WHISPER")
    self:RegisterEvent("GAME_PAD_ACTIVE_CHANGED")
    self:RegisterEvent("PLAYER_LOGIN")
    if ns.Ready then ns.Ready() end
end)

-- Over its cap a count table halves: rare entries go, the player's habits stay.
local function Trim(counts, cap)
    local n = 0
    for _ in pairs(counts) do n = n + 1 end
    if n <= cap then return end
    for key, count in pairs(counts) do
        counts[key] = count > 1 and math.floor(count / 2) or nil
    end
end

-- A word dropped off the d-pad: its counts go and it is never guessed, until the player spells it out again.
function ns.Forget(word)
    local db, low = ns.db, word:lower()
    db.forgot[low] = true
    db.learned[low], db.forms[low] = nil, nil
    for pair in pairs(db.pairs) do
        local prev, after = pair:match("^(%S+) (%S+)$")
        if prev == low or after == low then db.pairs[pair] = nil end
    end
end

-- The keyboard's place and size: set with the sticks the next time it opens.
function ns.MoveNext(button)
    ns.moveNext = true
    ns.Tell(ns.L["MOVE_NEXT"], button)
end

function ns.ForgottenBack()
    wipe(ns.db.forgot)
    ns.Say(ns.L["FORGOT_BACK"])
end

-- A sent message's words and word pairs, so guesses learn the player's words and how they follow each other.
function ns.Learn(text)
    local db = ns.db
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h.-|h", " "):gsub("{.-}", " ")
    local prev, first = "<s>", true
    for word in text:gmatch("[%a\128-\255']+") do
        word = word:gsub("^'+", ""):gsub("'+$", "")
        if word ~= "" then
            local low = word:lower()
            if not first and word ~= low and not ns.Dict.Known(low) then db.forms[low] = word end
            db.learned[low] = (db.learned[low] or 0) + 1
            local pair = prev .. " " .. low
            db.pairs[pair] = (db.pairs[pair] or 0) + 1
            prev, first = low, false
        end
    end
    Trim(db.learned, LEARN_CAP)
    Trim(db.pairs, PAIR_CAP)
end

function ns.Say(text) print("|cffffd100" .. ns.L["TITLE"] .. "|r " .. text) end

-- What a settings button set going: a chat line, and the pressed button's own text says it where the player is
-- looking. Never a dialog: a StaticPopup shown by addon code over the Settings window leaves the game's
-- controller bindings tainted, and closing the window is then refused.
function ns.Tell(text, button)
    ns.Say(text)
    if button and button.SetText then button:SetText(ns.L["OPT_ARMED"]) end
end

-- Quick phrases by slot (1-4 the left stick's up, right, down, left; 5-8 the right's): the player's own, else the
-- language's default. A phrase emptied or set back to its default is the default again.
local function DefaultPhrase(slot)
    local i = 0
    for phrase in ns.L["PHRASES"]:gmatch("[^|]+") do
        i = i + 1
        if i == slot then return phrase end
    end
end

function ns.Phrase(slot) return ns.db.phrases[slot] or DefaultPhrase(slot) end

function ns.SetPhrase(slot, text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" or text == DefaultPhrase(slot) then text = nil end
    ns.db.phrases[slot] = text
end

function ns.ResetPhrases() wipe(ns.db.phrases) end

-- In the game's controller mode its Menu wheel's Chat shows the typing line (and so the keyboard) only with the IM
-- chat style; with Classic nothing opens, the game's own chat included.
function ns.NeedsIMStyle()
    local controller = InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled()
    return controller == true and GetCVar("chatStyle") ~= "im"
end

-- The settings: rows on the game's own Settings window, AddOns tab.
local options = {}

local function HidesBar() return ns.db.hintsToggle == nil or ns.db.hintsToggle == "bar" end
local function HidesGuide() return ns.db.hintsToggle == nil or ns.db.hintsToggle == "guide" end

local function SetHides(bar, guide)
    if bar and guide then
        ns.db.hintsToggle = nil
    else
        ns.db.hintsToggle = bar and "bar" or guide and "guide" or "none"
    end
end

-- What each row reads and writes, over the saved settings' own shapes (nil for off, the hidden flag turned round).
local ROWS = {
    lowercase = { function() return ns.db.lowercase == true end, function(on) ns.db.lowercase = on or nil end },
    -- What the right stick press hides: hintsToggle is nil for both, "bar", "guide" or "none".
    -- IM style's typing line out of sight until chat opens, as Classic style's is.
    hideLine = { function() return ns.db.hideLine == true end, function(on)
        ns.db.hideLine = on or nil
        if ns.FadeLines then ns.FadeLines() end
    end },
    stickTips = { function() return not ns.db.stickTipsOff end, function(on)
        if on then ns.db.stickTipsOff = nil else ns.db.stickTipsOff = true end
    end },
    phraseSend = { function() return not ns.db.phraseFill end, function(on)
        if on then ns.db.phraseFill = nil else ns.db.phraseFill = true end
    end },
    matureFilter = { function() return ns.db.matureFilter == true end, function(on) ns.db.matureFilter = on or nil end },
    hideBar = { function() return HidesBar() end, function(on) SetHides(on, HidesGuide()) end },
    hideGuide = { function() return HidesGuide() end, function(on) SetHides(HidesBar(), on) end },
    size = { function() return ns.db.size end, function(value)
        ns.db.size = value
        if ns.Restyle then ns.Restyle() end
    end },
    wordRoom = { function() return ns.db.wordRoom end, function(value)
        ns.db.wordRoom = value
        if ns.Restyle then ns.Restyle() end
    end },
    wheelSize = { function() return ns.db.wheelSize end, function(value) ns.db.wheelSize = value end },
}

-- On the game's AddOns page: the game's own rows, which its controller cursor steps through (a row is the cursor's
-- stop, its inner controls are not). Check boxes, sliders and buttons only: a drop-down's menu is built by our
-- function and the game refuses its close.
local function Row(category, key, kind, name, default)
    return Settings.RegisterProxySetting(category, addonName .. "_" .. key, kind, name, default, ROWS[key][1], ROWS[key][2])
end

local function Percent(value) return ns.L["SIZE_VALUE"]:format(value) end

local function SizeRow(category, key, name, low, high)
    local range = Settings.CreateSliderOptions(low, high, 5)
    range:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, Percent)
    Settings.CreateSlider(category, Row(category, key, "number", name, 100), range)
end

-- The player's own words for the guesses: letters and apostrophes, a space between, each once.
function ns.SetMyWords(text)
    local seen, list = {}, {}
    for word in text:gmatch("[%a\128-\255']+") do
        if not seen[word:lower()] and #list < 60 then
            seen[word:lower()] = true
            list[#list + 1] = word
        end
    end
    ns.db.myWords = #list > 0 and table.concat(list, " ") or nil
end

function ns.MyWordsText()
    local words = ns.db.myWords
    return words and words ~= "" and words or ns.L["WORDS_NONE"]
end

-- One box for whichever phrase row was pressed: exactly over that row's button and opaque, so the phrase is typed
-- in the button's place.
local function EditPhrase(button, slot)
    local edit = options.phraseEdit
    if not edit then
        edit = CreateFrame("EditBox", nil, UIParent)
        edit:SetAutoFocus(false)
        edit:SetMaxLetters(120)
        edit:SetFrameStrata("FULLSCREEN_DIALOG")
        edit:SetFontObject(GameFontHighlight)
        edit:SetTextInsets(8, 8, 0, 0)
        local rim = edit:CreateTexture(nil, "BACKGROUND", nil, -2)
        rim:SetAllPoints()
        rim:SetColorTexture(1, 0.82, 0, 1)
        local fill = edit:CreateTexture(nil, "BACKGROUND", nil, -1)
        fill:SetPoint("TOPLEFT", 1, -1)
        fill:SetPoint("BOTTOMRIGHT", -1, 1)
        fill:SetColorTexture(0.05, 0.05, 0.06, 1)
        edit:SetScript("OnEnterPressed", function(self)
            if self.slot == "words" then
                ns.SetMyWords(self:GetText())
            else
                ns.SetPhrase(self.slot, self:GetText())
            end
            if self.button:IsVisible() then self.button:SetText(self.shows()) end
            self:Hide()
        end)
        edit:SetScript("OnEscapePressed", edit.Hide)
        edit:SetScript("OnEditFocusLost", edit.Hide)
        ns.Watch(edit)
        options.phraseEdit = edit
    end
    edit.slot, edit.button = slot, button
    edit.shows = slot == "words" and ns.MyWordsText or function() return ns.Phrase(slot) or "" end
    edit:SetMaxLetters(slot == "words" and 400 or 120)
    edit:ClearAllPoints()
    edit:SetAllPoints(button)
    edit:SetText(slot == "words" and (ns.db.myWords or "") or ns.Phrase(slot) or "")
    edit:Show()
    edit:SetFocus()
    edit:HighlightText()
end

function ns.BuildOptions()
    if options.category or not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
    local L = ns.L
    local category, layout = Settings.RegisterVerticalLayoutCategory(C_AddOns.GetAddOnMetadata(addonName, "Title"))
    local function Head(text)
        if CreateSettingsListSectionHeaderInitializer then
            layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
        end
    end
    local function Button(name, text, press, tip)
        layout:AddInitializer(CreateSettingsButtonInitializer(name, text, press, tip, true))
    end
    -- Every check box together, first.
    Head(L["OPT_HEAD_OPTIONS"])
    Settings.CreateCheckbox(category, Row(category, "lowercase", "boolean", L["OPT_LOWERCASE"], false))
    Settings.CreateCheckbox(category, Row(category, "matureFilter", "boolean", L["OPT_MATURE"], false))
    Settings.CreateCheckbox(category, Row(category, "phraseSend", "boolean", L["OPT_PHRASE_SEND"], true))
    Settings.CreateCheckbox(category, Row(category, "hideLine", "boolean", L["OPT_HIDE_LINE"], false))
    Settings.CreateCheckbox(category, Row(category, "hideBar", "boolean", L["OPT_HIDE_BAR"], true))
    Settings.CreateCheckbox(category, Row(category, "hideGuide", "boolean", L["OPT_HIDE_GUIDE"], true))
    Settings.CreateCheckbox(category, Row(category, "stickTips", "boolean", L["OPT_STICK_TIPS"], true))
    Head(L["OPT_HEAD_SIZE"])
    SizeRow(category, "size", L["OPT_SIZE"], 70, 200)
    SizeRow(category, "wordRoom", L["OPT_WORD_ROOM"], 70, 160)
    SizeRow(category, "wheelSize", L["OPT_WHEEL_SIZE"], 50, 150)
    Button(L["OPT_MOVE"], L["OPT_MOVE_BUTTON"], function(button) ns.MoveNext(button) end, L["OPT_MOVE_TIP"])
    Head(L["OPT_HEAD_PRACTICE"])
    Button(L["OPT_PRACTICE"], L["OPT_PRACTICE_BUTTON"], function(button) ns.PracticeNext(button) end, L["OPT_PRACTICE_TIP"])
    Button(L["OPT_LESSON"], L["OPT_LESSON_BUTTON"], function(button) ns.RunLessonAgain(button) end)
    Head(L["OPT_HEAD_WORDS"])
    Button(L["OPT_WORDS"], ns.MyWordsText, function(button) EditPhrase(button, "words") end, L["OPT_WORDS_TIP"])
    Button(L["OPT_FORGOT"], L["OPT_FORGOT_BUTTON"], function() ns.ForgottenBack() end, L["OPT_FORGOT_TIP"])
    -- The quick phrases: a row each, its button showing the phrase; pressed, a box over the button takes the typing
    -- (the game's rows have no text box), by keys or by the keyboard.
    Head(L["OPT_HEAD_PHRASES"])
    for slot = 1, 8 do
        Button(L["PHRASE_SLOT_" .. slot], function() return ns.Phrase(slot) or "" end,
            function(button) EditPhrase(button, slot) end, L["OPT_PHRASE_TIP"])
    end
    Button(L["OPT_PHRASES"], L["OPT_RESET"], function(button)
        ns.ResetPhrases()
        -- The phrase rows in sight show the defaults at once: their buttons' text only, the rows are the game's.
        for _, row in ipairs({ button:GetParent():GetParent():GetChildren() }) do
            local data = row.data
            if data and type(data.buttonText) == "function" and row.Button then row.Button:SetText(data.buttonText()) end
        end
    end)
    Head(L["OPT_HEAD_CONTROLLER"])
    Button(L["OPT_CHAT_KEY"], ns.ChatKeyText, function(button)
        ns.NextChatKey()
        button:SetText(ns.ChatKeyText())
    end, L["OPT_CHAT_KEY_TIP"])
    Settings.RegisterAddOnCategory(category)
    options.category = category
end

-- A pad button on the game's own Open Chat binding, the player's pick: a button the bindings leave free, or a
-- modifier the player set on the pad (the buttons standing in for Ctrl, Shift, Alt) with one. It is added beside
-- the keys already there (Enter stays); only a key this addon bound is ever taken off again.
local MODIFIERS = { { "CTRL", "GamePadEmulateCtrl" }, { "SHIFT", "GamePadEmulateShift" }, { "ALT", "GamePadEmulateAlt" } }
local FREE_BUTTONS = { "PADSOCIAL", "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4" }
local CHORD_BUTTONS = { "PADBACK", "PADFORWARD", "PADLSTICK", "PADRSTICK", "PADSOCIAL" }

local function ChatKeys()
    local list = {}
    for _, button in ipairs(FREE_BUTTONS) do list[#list + 1] = { key = button, button = button } end
    for _, mod in ipairs(MODIFIERS) do
        local pad = GetCVar(mod[2])
        if pad and pad:find("^PAD") then
            for _, button in ipairs(CHORD_BUTTONS) do
                if button ~= pad then list[#list + 1] = { key = mod[1] .. "-" .. button, pad = pad, button = button } end
            end
        end
    end
    return list
end

function ns.ChatKeyText()
    local key = ns.db.chatKey
    if not key or GetBindingAction(key) ~= "OPENCHAT" then return ns.L["CHAT_KEY_NONE"] end
    for _, each in ipairs(ChatKeys()) do
        if each.key == key then
            local button = GetBindingText(each.button, 1)
            return each.pad and GetBindingText(each.pad, 1) .. " + " .. button or button
        end
    end
    return GetBindingText(key, 1)
end

-- The next free key after ours takes Open Chat; past the last, none does. Out of combat only.
function ns.NextChatKey()
    if InCombatLockdown() then return end
    local list, now, start = ChatKeys(), ns.db.chatKey, 1
    for i, each in ipairs(list) do
        if each.key == now then start = i + 1 end
    end
    if now and GetBindingAction(now) == "OPENCHAT" then SetBinding(now) end
    ns.db.chatKey = nil
    for i = start, #list do
        if GetBindingAction(list[i].key) == "" then
            SetBinding(list[i].key, "OPENCHAT")
            ns.db.chatKey = list[i].key
            break
        end
    end
    SaveBindings(GetCurrentBindingSet())
end

-- The first-time typing lesson comes back the next time the keyboard opens.
function ns.RunLessonAgain(button)
    ns.db.lessonDone = false
    ns.Tell(ns.L["LESSON_AGAIN"], button)
end

-- Where the settings are, in a chat line. The game's Settings window opened by addon code is ours from then on:
-- its other pages' protected calls are refused, so it is left to the player to open.
function ns.OpenOptions()
    if not options.category then return false end
    ns.Say(ns.L["SETTINGS_WHERE"]:format(C_AddOns.GetAddOnMetadata(addonName, "Title")))
    return true
end

-- The notice for a player on the Classic chat style in the game's controller mode: why nothing opens, where the
-- game's setting is, and the box that hides IM style's typing line as Classic does. A flips the box, B shuts it.
function ns.StyleNotice()
    local L = ns.L
    local notice = options.notice
    if not notice then
        notice = CreateFrame("Frame", "FlickChatNotice", UIParent)
        notice:Hide()
        notice:SetFrameStrata("FULLSCREEN_DIALOG")
        notice:SetSize(520, 10)
        notice:SetPoint("CENTER", 0, 150)
        notice:EnableMouse(true)
        ns.Dress(notice)
        local EDGE = 24
        -- A button's icon at a size that reads in a sentence (the game's own inline size is small).
        local function Glyph(key)
            local text = GetBindingText(key, 1) or ""
            local atlas, file = text:match("|A:([^:|]+)"), text:match("|T([^:|]+)")
            if atlas then
                local big = atlas:gsub("_%d+$", "_64")
                return "|A:" .. (C_Texture.GetAtlasInfo(big) and big or atlas) .. ":21:21|a"
            elseif file then
                return "|T" .. file .. ":21:21|t"
            end
            return text
        end
        local function Text(font)
            local text = notice:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
            text:SetJustifyH("LEFT")
            return text
        end
        -- Under another line, the window's width.
        local function Line(above, gap, font)
            local line = Text(font)
            line:SetPoint("TOP", above, "BOTTOM", 0, -gap)
            line:SetPoint("LEFT", notice, "LEFT", EDGE, 0)
            line:SetPoint("RIGHT", notice, "RIGHT", -EDGE, 0)
            return line
        end
        local title = notice:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -22)
        title:SetText(C_AddOns.GetAddOnMetadata(addonName, "Title"))
        -- top right: B closes (a button, for the mouse too)
        local close = CreateFrame("Button", "FlickChatNoticeClose", notice)
        close.text = close:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        close.text:SetPoint("RIGHT")
        close:SetPoint("TOPRIGHT", -EDGE + 4, -14)
        close:SetScript("OnClick", function() notice:Hide() end)
        local text = Line(title, 12)
        text:SetText(L["NOTICE_WELCOME"])
        -- The keyboard's size, the keyboard itself under the window as the preview: LB - + RB at the right.
        local size = Text("GameFontNormal")
        size:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -18)
        -- right after the sentence, on its middle line: LB, minus, plus, RB
        local smaller = Text()
        smaller:SetPoint("LEFT", size, "RIGHT", 14, 0)
        local function Step(name, label, by, after)
            local button = CreateFrame("Button", name, notice, "UIPanelButtonTemplate")
            button:SetSize(26, 22)
            button:SetText(label)
            button:SetPoint("LEFT", after, "RIGHT", 6, 0)
            button:SetScript("OnClick", function()
                ns.db.size = math.max(70, math.min(200, (ns.db.size or 100) + by))
                size:SetText(L["NOTICE_SIZE"]:format(ns.db.size))
                if ns.Restyle then ns.Restyle() end
            end)
            return button
        end
        local minus = Step("FlickChatNoticeSmaller", "-", -10, smaller)
        local plus = Step("FlickChatNoticeLarger", "+", 10, minus)
        local larger = Text()
        larger:SetPoint("LEFT", plus, "RIGHT", 6, 0)
        local note = Line(size, 14, "GameFontDisableSmall")
        note:SetText(L["NOTICE_SIZE_NOTE"])
        -- The hide-line box, X at the end of its line.
        local check = CreateFrame("CheckButton", "FlickChatNoticeCheck", notice, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", note, "BOTTOMLEFT", -4, -10)
        check:SetScript("OnClick", function(self)
            ROWS.hideLine[2](self:GetChecked() == true)
            self:SetChecked(ROWS.hideLine[1]())
        end)
        local label = Text()
        label:SetPoint("TOPLEFT", check, "TOPRIGHT", 4, -4)
        label:SetPoint("RIGHT", notice, "RIGHT", -EDGE, 0)
        -- The Classic chat style, in a section of its own at the bottom: what it means in red, then the switch.
        local rule = notice:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(0.6, 0.45, 0.2, 0.7)
        rule:SetHeight(1)
        rule:SetPoint("LEFT", notice, "LEFT", EDGE, 0)
        rule:SetPoint("RIGHT", notice, "RIGHT", -EDGE, 0)
        rule:SetPoint("TOP", note, "BOTTOM", 0, -16)
        local warn = Line(rule, 14, "GameFontNormal")
        warn:SetJustifyH("CENTER")
        -- The switch itself: the game's own console command, run by a secure button on the player's press, so
        -- the change is the player's (a setting written by addon code is refused its chat changes). On
        -- UIParent: under the notice it would make the notice a protected frame.
        local swap = CreateFrame("Button", "FlickChatNoticeSwap", UIParent, "SecureActionButtonTemplate, UIPanelButtonTemplate")
        swap:Hide()
        swap:SetFrameStrata("FULLSCREEN_DIALOG")
        swap:SetFrameLevel(notice:GetFrameLevel() + 5)
        swap:SetSize(310, 36)
        swap:RegisterForClicks("AnyUp", "AnyDown")
        swap:SetAttribute("type", "macro")
        swap:SetAttribute("macrotext", "/console chatStyle im")
        -- What the window says for the chat style as it is now; whether the switch is offered.
        local function Tell()
            local classic = GetCVar("chatStyle") ~= "im"
            local section = classic or notice.switched
            close.text:SetText(L["NOTICE_KEY_CLOSE"]:format(Glyph("PAD2")))
            close:SetSize(close.text:GetStringWidth() + 4, 28)
            size:SetText(L["NOTICE_SIZE"]:format(ns.db.size or 100))
            smaller:SetText(Glyph("PADLSHOULDER"))
            larger:SetText(Glyph("PADRSHOULDER"))
            -- X right after the box's sentence
            label:SetText(L["OPT_HIDE_LINE"] .. "  " .. Glyph("PAD3"))
            swap:SetText(L["NOTICE_SWAP"] .. "   " .. Glyph("PAD1"))
            rule:SetShown(section)
            warn:SetShown(section)
            -- The hide-line box is IM style's: there from the start on IM style, under the section once switched.
            check:SetShown(not classic)
            label:SetShown(not classic)
            check:ClearAllPoints()
            check:SetPoint("TOPLEFT", section and warn or note, "BOTTOMLEFT", -4, -10)
            if classic then
                warn:SetText(L["NOTICE_STYLE"])
                warn:SetTextColor(1, 0.25, 0.2)
            else
                warn:SetText(L["NOTICE_SWAPPED"])
                warn:SetTextColor(0.4, 0.9, 0.4)
            end
            local height = 22 + title:GetStringHeight() + 12 + text:GetStringHeight() + 18 + size:GetStringHeight() + 14
                + note:GetStringHeight()
            if section then height = height + 16 + 1 + 14 + warn:GetStringHeight() + (classic and 14 + 36 or 0) end
            if not classic then height = height + 10 + 32 + math.max(0, label:GetStringHeight() - 18) end
            notice:SetHeight(height + 22)
            return classic
        end
        swap:SetScript("PostClick", function()
            C_Timer.After(0.3, function()
                if not notice:IsShown() then return end
                notice.switched = GetCVar("chatStyle") == "im"
                notice.Pad(true)
            end)
        end)
        -- On Classic style the pad buttons are key bindings to the window's own buttons, and the window takes
        -- no pad presses itself: the switch needs a press the game counts as the player's, and a press the
        -- window took never reaches it (measured). The game's controller mode sets its own pad bindings over
        -- ours as it goes, so ours go back whenever it does. On IM style the window reads the pad itself.
        local BOUND = { PAD1 = "FlickChatNoticeSwap", PAD2 = "FlickChatNoticeClose", PADLSHOULDER = "FlickChatNoticeSmaller",
            PADRSHOULDER = "FlickChatNoticeLarger" }
        local function Bind()
            notice.binding = true
            for key, button in pairs(BOUND) do SetOverrideBindingClick(notice, true, key, button) end
            notice.binding = false
        end
        hooksecurefunc("SetOverrideBindingClick", function(owner, _, key)
            if notice.bound and not notice.binding and owner ~= notice and BOUND[key] and not InCombatLockdown() then Bind() end
        end)
        -- Bindings and the secure button are a fight's to refuse: both wait one out.
        function notice.Pad(on)
            local classic = Tell()
            if InCombatLockdown() then
                notice:RegisterEvent("PLAYER_REGEN_ENABLED")
                swap:SetAlpha(on and classic and 1 or 0)
                return
            end
            notice:UnregisterEvent("PLAYER_REGEN_ENABLED")
            swap:SetAlpha(1)
            swap:SetShown(on and classic)
            notice.bound = on and classic
            ClearOverrideBindings(notice)
            notice:EnableGamePadButton(on and not classic)
            if on and classic then
                swap:ClearAllPoints()
                -- to the window itself: a secure button cannot hang on a piece of text
                swap:SetPoint("BOTTOM", notice, "BOTTOM", 0, 22)
                Bind()
            end
        end
        -- On IM style: the size, the box and closing are the window's own pad presses.
        notice:SetScript("OnGamePadButtonDown", function(self, button)
            if button == "PADLSHOULDER" then
                minus:GetScript("OnClick")(minus)
            elseif button == "PADRSHOULDER" then
                plus:GetScript("OnClick")(plus)
            elseif button == "PAD3" then
                check:SetChecked(not check:GetChecked())
                check:GetScript("OnClick")(check)
            elseif button == "PAD2" then
                self:Hide()
            end
        end)
        notice:SetScript("OnEvent", function(self) self.Pad(self:IsShown()) end)
        notice:SetScript("OnShow", function(self)
            self.switched = false
            check:SetChecked(ROWS.hideLine[1]())
            self.Pad(true)
            if ns.PreviewKeyboard then ns.PreviewKeyboard(self) end
        end)
        notice:SetScript("OnHide", function(self)
            ns.db.welcomed = true
            self.Pad(false)
            if ns.PreviewKeyboard then ns.PreviewKeyboard() end
        end)
        options.notice = notice
    end
    notice:Show()
end

-- Where the chat box can send, by flick (1-4 the left stick's up, right, down, left; 5-8 the right's): Say, Party,
-- Guild and the group on the left, the newest whisper partners (the target player second) on the right.
local function Named(key) return _G["CHAT_MSG_" .. key] or key end

-- How likely each kind of person is the one meant, for the name search and the whispers page.
local RECENT, CLOSE_BY, FRIEND, GUILDIE = 0.5, 0.4, 0.3, 0.1

-- The channel wheel's pages, eight slices each from the top going clockwise: where to talk, who to whisper (the
-- target, the newest whisper partners, friends online, then a name search), the numbered channels. A slice the player
-- cannot use now stays in its place, marked off.
function ns.WheelPages()
    local L = ns.L
    local instance, guild = IsInGroup(LE_PARTY_CATEGORY_INSTANCE), IsInGuild()
    local group = instance and "INSTANCE_CHAT" or "RAID"
    local talk = {
        { label = Named("SAY"), chatType = "SAY" },
        { label = Named("PARTY"), chatType = "PARTY", off = not IsInGroup() },
        { label = Named(group), chatType = group, off = not (IsInRaid() or instance) },
        { label = Named("GUILD"), chatType = "GUILD", off = not guild },
        { label = Named("OFFICER"), chatType = "OFFICER", off = not guild },
        { label = Named("YELL"), chatType = "YELL" },
        { label = Named("EMOTE"), chatType = "EMOTE" },
        -- The last slice is no channel: the sticks then carry and size the keyboard.
        { label = L["MOVE_SLICE"], move = true },
    }
    local people, seen = {}, {}
    if UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
        local target = GetUnitName("target", true)
        if target and not (issecretvalue and issecretvalue(target)) then
            seen[target] = true
            people[1] = { label = target:match("^[^%-]+"), chatType = "WHISPER", tellTarget = target }
        end
    end
    local name, kind = ChatFrameUtil.GetLastTellTarget()
    while name and name ~= "" and #people < 7 and not seen[name] do
        seen[name] = true
        people[#people + 1] = { label = name:match("^[^%-]+") or name, chatType = kind or "WHISPER", tellTarget = name }
        name, kind = ChatFrameUtil.GetNextTellTarget(name, kind)
    end
    for _, friend in ipairs(ns.WhisperNames()) do
        if #people >= 7 then break end
        if friend.chance >= FRIEND and not seen[friend.tellTarget] then
            seen[friend.tellTarget] = true
            people[#people + 1] = { label = friend.label, chatType = friend.chatType, tellTarget = friend.tellTarget }
        end
    end
    people[#people + 1] = { label = L["WHISPER_SOMEONE"], naming = true }
    local channels, list = {}, { GetChannelList() }
    for i = 1, #list, 3 do
        if not list[i + 2] and #channels < 8 then
            channels[#channels + 1] = { label = list[i] .. ". " .. list[i + 1], chatType = "CHANNEL",
                channelTarget = list[i] }
        end
    end
    return { { title = L["WHEEL_TALK"], picks = talk }, { title = L["WHEEL_WHISPERS"], picks = people },
        { title = L["WHEEL_CHANNELS"], picks = channels } }
end

-- Everyone a whisper can reach now, for the name search: battle.net friends by BattleTag and by the character they
-- play, WoW friends, the guild, the group, the target; the newest whisper partners count most.
function ns.WhisperNames()
    local list, seen, recent = {}, {}, {}
    local name, kind = ChatFrameUtil.GetLastTellTarget()
    local rank = 0
    while name and name ~= "" and rank < 10 and not recent[name] do
        rank = rank + 1
        recent[name] = RECENT / rank
        name, kind = ChatFrameUtil.GetNextTellTarget(name, kind)
    end
    local function Add(label, chatType, target, chance)
        if type(label) ~= "string" or type(target) ~= "string" or label == "" then return end
        if issecretvalue and (issecretvalue(label) or issecretvalue(target)) then return end
        local key = label:lower() .. "\0" .. target
        if seen[key] then return end
        seen[key] = true
        list[#list + 1] = { label = label, chatType = chatType, tellTarget = target,
            chance = math.max(chance, recent[target] or 0) }
    end
    for i = 1, BNGetNumFriends and BNGetNumFriends() or 0 do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        local game = info and info.gameAccountInfo
        if game and game.isOnline then
            Add(info.battleTag and info.battleTag:match("^[^#]+"), "BN_WHISPER", info.accountName, FRIEND)
            Add(game.characterName, "BN_WHISPER", info.accountName, FRIEND)
        end
    end
    for i = 1, C_FriendList.GetNumFriends() do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected then Add(info.name:match("^[^%-]+"), "WHISPER", info.name, FRIEND) end
    end
    if IsInGuild() then
        for i = 1, GetNumGuildMembers() do
            local full, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
            if full and online then Add(full:match("^[^%-]+"), "WHISPER", full, GUILDIE) end
        end
    end
    local unit = IsInRaid() and "raid" or "party"
    for i = 1, GetNumGroupMembers() do
        local full = GetUnitName(unit .. i, true)
        if full and not UnitIsUnit(unit .. i, "player") then Add(full:match("^[^%-]+"), "WHISPER", full, CLOSE_BY) end
    end
    if UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
        local full = GetUnitName("target", true)
        if full then Add(full:match("^[^%-]+"), "WHISPER", full, CLOSE_BY) end
    end
    for target, chance in pairs(recent) do
        if not target:find("|K", 1, true) then Add(target:match("^[^%-]+"), "WHISPER", target, chance) end
    end
    return list
end

-- The chat box sends there from now on; its header shows where.
function ns.SwitchChannel(box, pick)
    if not pick or not box.SetChatType then return end
    box:SetChatType(pick.chatType)
    if pick.tellTarget then box:SetTellTarget(pick.tellTarget) end
    if pick.channelTarget then box:SetChannelTarget(pick.channelTarget) end
    box:UpdateHeader()
end

function ns.IsChannel(box, pick)
    if not pick or not box.GetChatType or box:GetChatType() ~= pick.chatType then return false end
    if pick.tellTarget then return box:GetTellTarget() == pick.tellTarget end
    if pick.channelTarget then return tonumber(box:GetChannelTarget()) == pick.channelTarget end
    return true
end

SLASH_FLICKCHAT1 = "/flick"
SLASH_FLICKCHAT2 = "/flickchat"
SLASH_FLICKCHAT3 = "/fc"
SlashCmdList.FLICKCHAT = function(msg)
    local db = ns.db
    if not db then return end
    local cmd, value = (msg or ""):lower():match("^%s*(%S*)%s*(%S*)")
    if cmd == "size" and tonumber(value) then
        db.size = math.max(70, math.min(200, math.floor(tonumber(value))))
        ns.Say(ns.L["SIZE"]:format(db.size))
        if ns.Restyle then ns.Restyle() end
    elseif cmd == "layout" and ns.LAYOUTS[value] then
        db.layout = value
        ns.Say(ns.L["LAYOUT_" .. value:upper()])
        if ns.Relayout then ns.Relayout() end
    elseif cmd == "lesson" then
        ns.RunLessonAgain()
    elseif cmd == "move" then
        ns.MoveNext()
    elseif cmd == "practice" then
        ns.PracticeNext()
    elseif cmd == "new" then
        -- What a new player on the Classic chat style meets at login, whatever the style is now.
        ns.StyleNotice()
    elseif cmd == "chatprobe" then
        ns.StartChatProbe(30)
        ns.Say(ns.L["PROBE_CHAT"])
    elseif cmd == "sticks" then
        ns.StartStickProbe(40)
        ns.Say(ns.L["PROBE_STICKS"])
    elseif cmd == "phrases" and value == "reset" then
        ns.ResetPhrases()
        ns.Say(ns.L["PHRASES_RESET"])
    elseif cmd == "phrases" then
        if not ns.OpenOptions() then ns.Say(ns.L["USAGE"]) end
    elseif cmd == "lowercase" then
        db.lowercase = not db.lowercase or nil
        ns.Say(db.lowercase and ns.L["LOWER_ON"] or ns.L["LOWER_OFF"])
    elseif cmd == "" then
        db.enabled = not db.enabled
        ns.Say(db.enabled and ns.L["ON"] or ns.L["OFF"])
        if not db.enabled and ns.Shut then ns.Shut() end
    else
        ns.Say(ns.L["USAGE"])
    end
end

-- The dev addon (never shipped) is handed the addon's table.
function FlickChat_AttachDevTools(attach) attach(ns) end
