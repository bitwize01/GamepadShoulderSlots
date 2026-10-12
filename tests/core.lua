-- Gamepad Shoulder Slots: slot engine on the hostile targeting bar.
-- Run from the add-on directory: lua5.1 tests/core.lua
local M = dofile("tests/mock.lua")
local check = M.check
M.install()
local bar = M.makeBar()
local left, right = bar.left, bar.right
M.load()
local slash = M.slash

-- Setting a spell by name configures the physical dpad button.
slash("set up spell Frost Nova")
check(left[2].attributes.type == "spell" and left[2].attributes.spell == "Frost Nova", "spell attributes on dpad up")
check(left[2].enabled and left[2].alpha == 1, "dpad up enabled and opaque")
check(left[2].SpecialActionIcon.texture == 135848 and left[2].SpecialActionIcon.shown, "spell icon shown")
check(M.cooldownSets > 0, "cooldown drawn")
check(GamepadShoulderSlotsCharDB.slots.up.value == "Frost Nova", "saved per character")
check(not left[1].enabled, "unassigned dpad left stays disabled")

-- Unknown names are refused without touching the button.
slash("set left spell Nonexistent")
check(left[1].attributes.type == "action" and not left[1].enabled, "unknown spell refused")

-- Macros and the cursor.
slash("set right macro Mount")
check(left[3].attributes.type == "macro" and left[3].attributes.macro == "Mount", "macro attributes")
M.cursor = { "item", 6948 }
slash("set down")
check(left[4].attributes.type == "item" and left[4].attributes.item == "item:6948", "item from cursor")
check(M.cursor == nil, "cursor cleared after use")

-- In combat, changes wait for PLAYER_REGEN_ENABLED.
M.combat = true
slash("set left spell 122")
check(left[1].attributes.type == "action", "no attribute change in combat")
check(M.ns.Slots:IsPending(), "change reported as pending")
M.combat = false
M.events:Fire("PLAYER_REGEN_ENABLED")
check(left[1].attributes.type == "spell" and left[1].enabled, "queued change applied after combat")
check(not M.ns.Slots:IsPending(), "pending cleared after combat")

-- Blizzard's re-setup (swap CVar) is followed: the new dpad buttons are
-- configured and the old ones are handed back to Blizzard's face setup.
bar.swapped = true
bar:SetUpActionButtons()
check(right[2].attributes.type == "spell" and right[2].enabled, "slots follow the swap")
check(left[2].attributes.type == "action" and left[2].attributes.spell == nil, "old dpad up cleared")
check(left[1].attributes.type == "spell" and left[1].attributes.spell == 5019, "Blizzard face setup kept after swap")
bar.swapped = false
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
check(M.overrides.NUMPAD0 == "TOGGLEUIFOCUS", "focus key bound")
M.events:Fire("PLAYER_ENTERING_WORLD")
check(M.overrides.NUMPAD0 == "TOGGLEUIFOCUS", "focus key reapplied at login")
slash("focuskey off")
check(M.overrides.NUMPAD0 == nil and GamepadShoulderSlotsDB.focusKey == nil, "focus key removed")

-- Listeners hear about every change.
local heard = 0
M.ns.Slots:RegisterCallback(function() heard = heard + 1 end)
M.ns.Slots:Set("up", { kind = "spell", value = "Blink" })
check(heard >= 1, "callback fired on set")

M.finish("core.lua")
