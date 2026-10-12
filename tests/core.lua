-- Gamepad Shoulder Slots: slot setup on the hostile targeting bar.
-- Run from the add-on directory: lua5.1 tests/core.lua

local function region()
    local r = { shown = false }
    function r:SetTexture(t) self.texture = t end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    return r
end

local function button(name)
    local b = { name = name, attributes = { type = "action", action = 0 }, enabled = false, alpha = 0.3 }
    b.SpecialActionIcon = region()
    b.IconOverlay = region()
    b.cooldown = {}
    function b:SetAttribute(k, v) self.attributes[k] = v end
    function b:GetAttribute(k) return self.attributes[k] end
    function b:SetEnabled(v) self.enabled = v end
    function b:SetAlpha(v) self.alpha = v end
    return b
end

local combat = false
InCombatLockdown = function() return combat end

-- Minimal model of the hostile bar: SetUpActionButtons resets every button
-- and points the dpad references at the left or right group.
local left = { button("L1"), button("L2"), button("L3"), button("L4") }
local right = { button("R1"), button("R2"), button("R3"), button("R4") }
local bar = {}
local swapped = false
function bar:SetUpDpadBottom() self.dpadBottomButton:SetEnabled(false) end
function bar:SetUpActionButtons()
    for _, b in ipairs(left) do b:SetEnabled(true); b:SetAlpha(1) end
    for _, b in ipairs(right) do b:SetEnabled(true); b:SetAlpha(1) end
    local dpad = swapped and right or left
    self.dpadLeftButton, self.dpadTopButton, self.dpadRightButton, self.dpadBottomButton =
        dpad[1], dpad[2], dpad[3], dpad[4]
    for i = 1, 3 do dpad[i]:SetEnabled(false); dpad[i]:SetAlpha(0.3) end
    self:SetUpDpadBottom()
    -- Blizzard's face setup runs after the dpad setups.
    local face = swapped and left or right
    face[1]:SetAttribute("type", "spell"); face[1]:SetAttribute("spell", 5019)
end
GamepadMainActionBarFrame = { PageUnit = { HostileTargetingActionBar = bar } }
bar:SetUpActionButtons()

hooksecurefunc = function(t, key, post)
    local original = t[key]
    t[key] = function(...) local r = original(...); post(...); return r end
end

local frames = {}
CreateFrame = function()
    local f = {}
    function f:RegisterEvent() end
    function f:SetScript(_, cb) self.OnEvent = cb end
    frames[#frames + 1] = f
    return f
end
C_Timer = { After = function(_, cb) cb() end }
local spells = { ["Frost Nova"] = { name = "Frost Nova", spellID = 122, iconID = 135848 } }
spells[122] = spells["Frost Nova"]
C_Spell = {
    GetSpellInfo = function(v) return spells[v] end,
    GetSpellCooldown = function() return { startTime = 10, duration = 25, isEnabled = true, modRate = 1 } end,
}
C_Item = {
    GetItemInfoInstant = function() return nil end,
    GetItemIconByID = function() return 134414 end,
    GetItemNameByID = function() return "Hearthstone" end,
    GetItemCooldown = function() return 0, 0, true end,
}
local macros = { Mount = { index = 3, icon = 132261 } }
GetMacroIndexByName = function(n) return macros[n] and macros[n].index or 0 end
GetMacroInfo = function(n)
    if type(n) == "number" then for k, m in pairs(macros) do if m.index == n then return k, m.icon end end end
    return macros[n] and n, macros[n] and macros[n].icon
end
GetMacroSpell = function() return nil end
GetMacroItem = function() return nil end
local cursor
GetCursorInfo = function() if cursor then return unpack(cursor) end end
ClearCursor = function() cursor = nil end
local cooldownSets = 0
CooldownFrame_Set = function(_, start) if start and start > 0 then cooldownSets = cooldownSets + 1 end end
local overrides = {}
SetOverrideBinding = function(_, _, key, action) overrides[key] = action end
ClearOverrideBindings = function() overrides = {} end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
local printed = {}
print = function(text) printed[#printed + 1] = text end
SlashCmdList = {}

local failures = 0
local function check(cond, message)
    if not cond then failures = failures + 1; io.stderr:write("FAIL: " .. message .. "\n") end
end

local chunk = assert(loadfile("Core.lua"))
chunk("GamepadShoulderSlots")
local events = frames[#frames]
local function fire(event, arg) events.OnEvent(events, event, arg) end
local slash = SlashCmdList.GAMEPADSHOULDERSLOTS

fire("ADDON_LOADED", "GamepadShoulderSlots")
fire("PLAYER_ENTERING_WORLD")

-- Setting a spell by name configures the physical dpad button.
slash("set up spell Frost Nova")
check(left[2].attributes.type == "spell" and left[2].attributes.spell == "Frost Nova", "spell attributes on dpad up")
check(left[2].enabled and left[2].alpha == 1, "dpad up enabled and opaque")
check(left[2].SpecialActionIcon.texture == 135848 and left[2].SpecialActionIcon.shown, "spell icon shown")
check(cooldownSets > 0, "cooldown drawn")
check(GamepadShoulderSlotsCharDB.slots.up.value == "Frost Nova", "saved per character")
check(not left[1].enabled, "unassigned dpad left stays disabled")

-- Unknown names are refused without touching the button.
slash("set left spell Nonexistent")
check(left[1].attributes.type == "action" and not left[1].enabled, "unknown spell refused")

-- Macros and the cursor.
slash("set right macro Mount")
check(left[3].attributes.type == "macro" and left[3].attributes.macro == "Mount", "macro attributes")
cursor = { "item", 6948 }
slash("set down")
check(left[4].attributes.type == "item" and left[4].attributes.item == "item:6948", "item from cursor")
check(cursor == nil, "cursor cleared after use")

-- In combat, changes wait for PLAYER_REGEN_ENABLED.
combat = true
slash("set left spell 122")
check(left[1].attributes.type == "action", "no attribute change in combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
check(left[1].attributes.type == "spell" and left[1].enabled, "queued change applied after combat")

-- Blizzard's re-setup (swap CVar) is followed: the new dpad buttons are
-- configured and the old ones are handed back to Blizzard's face setup.
swapped = true
bar:SetUpActionButtons()
check(right[2].attributes.type == "spell" and right[2].enabled, "slots follow the swap")
check(left[2].attributes.type == "action" and left[2].attributes.spell == nil, "old dpad up cleared")
check(left[1].attributes.type == "spell" and left[1].attributes.spell == 5019, "Blizzard face setup kept after swap")
swapped = false
bar:SetUpActionButtons()
check(left[2].attributes.spell == "Frost Nova" and left[2].enabled, "slots follow the swap back")

-- Clearing restores Blizzard's placeholder state.
slash("clear up")
check(left[2].attributes.type == "action" and not left[2].enabled and left[2].alpha == 0.3, "cleared slot restored")
check(not left[2].SpecialActionIcon.shown, "cleared slot icon hidden")
slash("clear all")
check(next(GamepadShoulderSlotsCharDB.slots) == nil, "clear all empties saved slots")
check(not left[4].enabled, "clear all restores buttons")

-- Focus key override.
slash("focuskey numpad0")
check(overrides.NUMPAD0 == "TOGGLEUIFOCUS", "focus key bound")
fire("PLAYER_ENTERING_WORLD")
check(overrides.NUMPAD0 == "TOGGLEUIFOCUS", "focus key reapplied at login")
slash("focuskey off")
check(overrides.NUMPAD0 == nil and GamepadShoulderSlotsDB.focusKey == nil, "focus key removed")

if failures > 0 then
    print = _G.print
    io.stderr:write(failures .. " failure(s)\n")
    os.exit(1)
end
io.stdout:write("core.lua: all checks passed\n")
