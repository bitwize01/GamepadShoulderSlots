-- Gamepad Shoulder Slots: the drag-and-drop editor panel.
-- Run from the add-on directory: lua5.1 tests/panel.lua
local M = dofile("tests/mock.lua")
local check = M.check
M.install()
local bar = M.makeBar()
local left = bar.left
M.load()
local Panel, Slots = M.ns.Panel, M.ns.Slots

-- The bare slash command opens the panel, with Show (never ShowUIPanel).
ShowUIPanel = function() error("panel must not use ShowUIPanel") end
UISpecialFrames = {}
M.slash("")
check(Panel:IsShown(), "slash toggles the panel open")
check(#UISpecialFrames == 0, "panel not registered in UISpecialFrames")

local panelFrame
for _, f in ipairs(M.frames) do
    if f.name == "GamepadShoulderSlotsPanel" then panelFrame = f end
end
check(panelFrame ~= nil, "panel frame created")

local function slot(direction)
    for _, f in ipairs(M.frames) do
        if f.direction == direction then return f end
    end
end
local up, down = slot("up"), slot("down")
check(up and down and slot("left") and slot("right"), "four slot buttons")

-- Dropping a spell from the spellbook assigns it and clears the cursor.
M.cursor = { "spell", 12, "spell", 122 }
up.scripts.OnReceiveDrag(up)
check(Slots:Get("up") and Slots:Get("up").value == "Frost Nova", "drop assigns spell")
check(M.cursor == nil, "drop clears the cursor")
check(left[2].attributes.spell == "Frost Nova" and left[2].enabled, "drop reaches the shoulder bar")
check(up.Icon.texture == 135848, "slot shows the spell icon")

-- A left-click while holding a macro works like a drop.
M.cursor = { "macro", 3 }
down.scripts.OnClick(down, "LeftButton")
check(Slots:Get("down") and Slots:Get("down").kind == "macro", "click with cursor assigns macro")

-- A plain left-click with an empty cursor does nothing.
down.scripts.OnClick(down, "LeftButton")
check(Slots:Get("down") and Slots:Get("down").value == "Mount", "empty click keeps the slot")

-- Dropping onto a filled slot swaps: the old entry goes back to the cursor.
M.cursor = { "spell", 13, "spell", 1953 }
up.scripts.OnReceiveDrag(up)
check(Slots:Get("up").value == "Blink", "drop onto filled slot replaces it")
check(M.cursor and M.cursor[1] == "spell" and M.cursor[4] == 122, "old entry returned to the cursor")
M.cursor = nil

-- Unsupported cursor contents are refused.
M.cursor = { "money", 100 }
slot("left").scripts.OnReceiveDrag(slot("left"))
check(Slots:Get("left") == nil, "money refused")
check(M.cursor ~= nil, "refused drop leaves the cursor alone")
M.cursor = nil

-- Dragging a filled slot lifts it onto the cursor and empties the slot.
down.scripts.OnDragStart(down)
check(Slots:Get("down") == nil, "lift empties the slot")
check(M.cursor and M.cursor[1] == "macro", "lift puts the macro on the cursor")
check(left[4].attributes.type == "action" and not left[4].enabled, "lift restores the bar button")
check(down.Icon.texture ~= 132261, "lifted slot shows empty")
M.cursor = nil

-- Right-click clears.
up.scripts.OnClick(up, "RightButton")
check(Slots:Get("up") == nil, "right-click clears")
check(not left[2].enabled, "right-click restores the bar button")

-- Tooltips.
M.ns.Slots:Set("up", { kind = "spell", value = "Frost Nova" })
up.scripts.OnEnter(up)
check(GameTooltip.last and GameTooltip.last[1] == "Show", "tooltip shown")

-- Status line reflects what keeps the slots from working.
check(Panel:StatusText():find("Active"), "status active")
M.combat = true
M.ns.Slots:Set("left", { kind = "spell", value = "Blink" })
check(Panel:StatusText():find("after combat"), "status pending in combat")
M.combat = false
M.events:Fire("PLAYER_REGEN_ENABLED")
M.gamepadUI = false
check(Panel:StatusText():find("Gamepad UI is off"), "status Gamepad UI off")
M.gamepadUI = true
GamepadMainActionBarFrame = nil
check(Panel:StatusText():find("aren't loaded"), "status bars not loaded")

-- The bare slash command closes it again.
M.slash("")
check(not Panel:IsShown(), "slash toggles the panel closed")

M.finish("panel.lua")
