-- Gamepad Shoulder Slots.
--
-- While the hostile-target shoulder modifier is held, the Forever Gamepad UI
-- swaps the top action bar for GamepadHostileTargetingActionBar. Its four
-- D-pad buttons are placeholders that Blizzard disables and never assigns.
-- They are secure action buttons, and Blizzard's own D-pad bindings click
-- them (GamepadMainActionBarFrame:PressActionButton), so giving them
-- type/spell/item/macro attributes out of combat makes them usable in combat.
-- Blizzard's Shoot button on the same bar is set up the same way.
--
-- Rules this file keeps, so Blizzard's gamepad code stays untainted:
--   * buttons are changed only out of combat, through widget methods and
--     attributes; no field of a Blizzard table or frame is written;
--   * Blizzard's re-setup (SetUpActionButtons, run when a swap CVar changes)
--     is followed with hooksecurefunc and reapplied afterwards.
-- The friendly bar's D-pad is not used: Blizzard reassigns it for party
-- targeting on every show, in combat too.
local ADDON = ...

local DIRECTIONS = { "left", "up", "right", "down" }
-- Blizzard's references follow the placeholder action, not the physical
-- input, so they stay correct when GamepadSwapHostileTargetActions is on.
local BUTTON_KEYS = {
    left = "dpadLeftButton",
    up = "dpadTopButton",
    right = "dpadRightButton",
    down = "dpadBottomButton",
}
local KINDS = { spell = true, item = true, macro = true }
local INACTIVE_ALPHA = 0.3

local db, charDB
local hookedBar
local applied = {}       -- direction -> button this add-on configured
local pending = false
local focusOwner = CreateFrame("Frame")

local function Print(fmt, ...)
    print("|cff66ccffGamepad Shoulder Slots:|r " .. string.format(fmt, ...))
end

local function GetBar()
    local main = _G.GamepadMainActionBarFrame
    local pageUnit = main and main.PageUnit
    return pageUnit and pageUnit.HostileTargetingActionBar or nil
end

local function SpellInfo(value)
    if not C_Spell or not C_Spell.GetSpellInfo then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, value)
    return ok and type(info) == "table" and info or nil
end

local function ItemID(value)
    if type(value) == "number" then return value end
    local id = tonumber(value) or tonumber(tostring(value):match("item:(%d+)"))
    if id then return id end
    if C_Item and C_Item.GetItemInfoInstant then
        local ok, itemID = pcall(C_Item.GetItemInfoInstant, value)
        if ok and itemID then return itemID end
    end
    return nil
end

local function EntryIcon(entry)
    if entry.kind == "spell" then
        local info = SpellInfo(entry.value)
        return info and info.iconID
    elseif entry.kind == "item" then
        local id = ItemID(entry.value)
        return id and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    elseif entry.kind == "macro" then
        local _, icon = GetMacroInfo(entry.value)
        return icon
    end
end

-- start, duration, enabled, modRate for the slot's action, or nil.
local function EntryCooldown(entry)
    local spellID, itemID
    if entry.kind == "spell" then
        local info = SpellInfo(entry.value)
        spellID = info and info.spellID
    elseif entry.kind == "item" then
        itemID = ItemID(entry.value)
    elseif entry.kind == "macro" then
        local index = GetMacroIndexByName(entry.value)
        if index and index > 0 then
            spellID = GetMacroSpell and GetMacroSpell(index)
            if not spellID and GetMacroItem then
                local _, link = GetMacroItem(index)
                itemID = link and ItemID(link)
            end
        end
    end
    if spellID and C_Spell.GetSpellCooldown then
        local cd = C_Spell.GetSpellCooldown(spellID)
        if cd then return cd.startTime, cd.duration, cd.isEnabled, cd.modRate end
    elseif itemID and C_Item.GetItemCooldown then
        local start, duration, enabled = C_Item.GetItemCooldown(itemID)
        return start, duration, enabled
    end
end

local function ClearAttributes(button)
    button:SetAttribute("type", "action")
    button:SetAttribute("spell", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("macro", nil)
end

local function UpdateCooldown(button, entry)
    local cooldown = button.cooldown
    if not cooldown or not CooldownFrame_Set then return end
    -- Cosmetic only. Cooldown values can be restricted in combat; a failed
    -- update leaves the previous swipe instead of raising an error.
    pcall(function()
        local start, duration, enabled, modRate = EntryCooldown(entry)
        if start and duration then
            CooldownFrame_Set(cooldown, start, duration, enabled, false, modRate)
        else
            CooldownFrame_Set(cooldown, 0, 0, false)
        end
    end)
end

local function Restore(button)
    ClearAttributes(button)
    button:SetEnabled(false)
    button:SetAlpha(INACTIVE_ALPHA)
    if button.SpecialActionIcon then button.SpecialActionIcon:Hide() end
    if button.cooldown and CooldownFrame_Set then pcall(CooldownFrame_Set, button.cooldown, 0, 0, false) end
end

local function Configure(button, entry)
    ClearAttributes(button)
    button:SetAttribute("type", entry.kind)
    button:SetAttribute(entry.kind, entry.value)
    button:SetEnabled(true)
    button:SetAlpha(1)
    local icon = button.SpecialActionIcon
    if icon then
        icon:SetTexture(EntryIcon(entry) or 134400) -- question mark
        icon:Show()
    end
    if button.IconOverlay then button.IconOverlay:Hide() end
    UpdateCooldown(button, entry)
end

local function Apply()
    if not charDB then return end
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    local bar = GetBar()
    if not bar then return end
    for _, direction in ipairs(DIRECTIONS) do
        local button = bar[BUTTON_KEYS[direction]]
        local previous = applied[direction]
        -- After a left/right swap the old button now carries one of
        -- Blizzard's own face actions; hand it back clean.
        if previous and previous ~= button then ClearAttributes(previous) end
        applied[direction] = nil
        local entry = charDB.slots[direction]
        if button then
            if entry then
                Configure(button, entry)
                applied[direction] = button
            elseif previous == button then
                Restore(button)
            end
        end
    end
end

local function HookBar()
    local bar = GetBar()
    if not bar or hookedBar == bar then return end
    hookedBar = bar
    -- SetUpActionButtons calls SetUpDpadBottom last among the D-pad setups,
    -- after the button references are final and before the face setups.
    hooksecurefunc(bar, "SetUpDpadBottom", function() Apply() end)
end

local function RefreshCooldowns()
    for direction, button in pairs(applied) do
        local entry = charDB and charDB.slots[direction]
        if entry then UpdateCooldown(button, entry) end
    end
end

local function ApplyFocusKey()
    if InCombatLockdown() then
        pending = true
        return
    end
    ClearOverrideBindings(focusOwner)
    if db and db.focusKey then
        SetOverrideBinding(focusOwner, false, db.focusKey, "TOGGLEUIFOCUS")
    end
end

local function EntryLabel(entry)
    if not entry then return "|cff808080empty|r" end
    local name = entry.value
    if entry.kind == "spell" then
        local info = SpellInfo(entry.value)
        name = info and info.name or name
    elseif entry.kind == "item" then
        local id = ItemID(entry.value)
        name = (id and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or name
    end
    return string.format("%s |cffffffff%s|r", entry.kind, tostring(name))
end

-- Builds a slot entry from text, or from the cursor when text is empty.
local function ParseEntry(kind, text)
    if not kind or kind == "" then
        local cursorType, a, b, c = GetCursorInfo()
        if cursorType == "spell" then
            local info = SpellInfo(c or a)
            if info then return { kind = "spell", value = info.name } end
        elseif cursorType == "item" then
            return { kind = "item", value = "item:" .. a }
        elseif cursorType == "macro" then
            local name = GetMacroInfo(a)
            if name then return { kind = "macro", value = name } end
        end
        return nil, "pick up a spell, item or macro first, or name one"
    end
    if not KINDS[kind] then return nil, "the type must be spell, item or macro" end
    if text == "" then return nil, "name the " .. kind end
    if kind == "spell" then
        local info = SpellInfo(tonumber(text) or text)
        if not info then return nil, "unknown spell '" .. text .. "'" end
        return { kind = "spell", value = info.name }
    elseif kind == "item" then
        local id = ItemID(text)
        if not id then return nil, "unknown item '" .. text .. "'; pick it up or use its item ID" end
        return { kind = "item", value = "item:" .. id }
    else
        local index = GetMacroIndexByName(text)
        if not index or index == 0 then return nil, "no macro named '" .. text .. "'" end
        return { kind = "macro", value = text }
    end
end

local function ShowStatus()
    local bar = GetBar()
    Print("Hostile-target shoulder D-pad%s:", bar and "" or " |cffff8040(Gamepad UI bars not loaded)|r")
    for _, direction in ipairs(DIRECTIONS) do
        Print("  %-5s %s", direction, EntryLabel(charDB.slots[direction]))
    end
    Print("Focus key: %s", db.focusKey and ("|cffffffff" .. db.focusKey .. "|r") or "|cff808080off|r")
    if pending then Print("|cffffd200Changes apply when combat ends.|r") end
    Print("Usage: /gpslots set <left|up|right|down> [spell|item|macro <name>]  (no name: uses the cursor)")
    Print("       /gpslots clear <direction|all>   /gpslots focuskey <KEY|off>")
end

SLASH_GAMEPADSHOULDERSLOTS1 = "/gpslots"
SlashCmdList.GAMEPADSHOULDERSLOTS = function(msg)
    local command, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "set" then
        local direction, kind, text = rest:match("^(%S*)%s*(%S*)%s*(.-)$")
        direction, kind = direction:lower(), kind:lower()
        if not BUTTON_KEYS[direction] then return Print("Pick a direction: left, up, right or down.") end
        local entry, err = ParseEntry(kind, text)
        if not entry then return Print("|cffff4040Not set:|r %s.", err) end
        if kind == "" then ClearCursor() end
        charDB.slots[direction] = entry
        Apply()
        Print("%s: %s%s", direction, EntryLabel(entry), pending and " (after combat)" or "")
    elseif command == "clear" then
        local direction = rest:lower()
        if direction == "all" then
            wipe(charDB.slots)
        elseif BUTTON_KEYS[direction] then
            charDB.slots[direction] = nil
        else
            return Print("Pick a direction: left, up, right, down or all.")
        end
        Apply()
        Print("Cleared %s.", direction)
    elseif command == "focuskey" then
        local key = rest:upper()
        if key == "" then return Print("Name a key, for example NUMPAD0, or 'off'.") end
        db.focusKey = key ~= "OFF" and key or nil
        ApplyFocusKey()
        Print("Focus key %s.", db.focusKey and ("set to " .. db.focusKey) or "off")
    else
        ShowStatus()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterEvent("BAG_UPDATE_COOLDOWN")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            GamepadShoulderSlotsDB = type(GamepadShoulderSlotsDB) == "table" and GamepadShoulderSlotsDB or {}
            GamepadShoulderSlotsCharDB = type(GamepadShoulderSlotsCharDB) == "table" and GamepadShoulderSlotsCharDB or {}
            db, charDB = GamepadShoulderSlotsDB, GamepadShoulderSlotsCharDB
            charDB.slots = type(charDB.slots) == "table" and charDB.slots or {}
        elseif arg1 == "Blizzard_GamepadActionBars" then
            HookBar()
            Apply()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        HookBar()
        ApplyFocusKey()
        -- Let Blizzard's own post-variables bar setup run first.
        C_Timer.After(1, function() HookBar(); Apply() end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then
            Apply()
            ApplyFocusKey()
        end
    else
        RefreshCooldowns()
    end
end)
