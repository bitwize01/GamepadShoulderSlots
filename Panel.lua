-- Gamepad Shoulder Slots: the D-pad editor panel.
--
-- Four ordinary (insecure) buttons laid out like a D-pad. They never cast
-- anything; they only edit the saved slots through ns.Slots, which applies
-- them to Blizzard's secure buttons out of combat.
--
-- The panel is shown with Show(), not ShowUIPanel, so the Gamepad UI's
-- FrameControlsManager doesn't take gamepad focus, and it is not added to
-- UISpecialFrames, whose edits spread taint into gamepad state.
local _, ns = ...
local Slots = ns.Slots

local Panel = {}
ns.Panel = Panel

local SLOT_SIZE = 40
local SLOT_OFFSET = 50
local EMPTY_TEXTURE = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
local FALLBACK_CENTER_ICON = "Interface\\Icons\\Ability_DualWield"
local OFFSETS = {
    up = { 0, SLOT_OFFSET },
    left = { -SLOT_OFFSET, 0 },
    right = { SLOT_OFFSET, 0 },
    down = { 0, -SLOT_OFFSET },
}
local DIRECTION_LABELS = { up = "D-pad Up", left = "D-pad Left", right = "D-pad Right", down = "D-pad Down" }

local frame
local slotButtons = {}

-- Assigns what the cursor holds to a slot. A slot that already held
-- something hands its old entry back to the cursor, like an action bar.
function Panel:Drop(direction)
    local entry, reason = Slots:EntryFromCursor()
    if not entry then
        ns.Print("%s.", reason)
        return false
    end
    local previous = Slots:Get(direction)
    ClearCursor()
    Slots:Set(direction, entry)
    if previous and (previous.kind ~= entry.kind or previous.value ~= entry.value) then
        Slots:Pickup(previous)
    end
    return true
end

-- Lifts a slot's entry onto the cursor and empties the slot.
function Panel:Lift(direction)
    local entry = Slots:Get(direction)
    if not entry or GetCursorInfo() then return false end
    Slots:Clear(direction)
    Slots:Pickup(entry)
    return true
end

local function ShowTooltip(button)
    local direction = button.direction
    local entry = Slots:Get(direction)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    local spellID, itemID = Slots:SpellID(entry), Slots:ItemID(entry)
    if spellID then
        GameTooltip:SetSpellByID(spellID)
    elseif itemID then
        GameTooltip:SetItemByID(itemID)
    elseif entry then
        GameTooltip:SetText(entry.value, 1, 1, 1)
        GameTooltip:AddLine("Macro", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    else
        GameTooltip:SetText(DIRECTION_LABELS[direction], 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Drag a spell, macro or item here.", 0.6, 0.8, 1)
    if entry then
        GameTooltip:AddLine("Drag out to move it. Right-click to clear.", 0.6, 0.8, 1)
    end
    GameTooltip:Show()
end

local function CreateSlot(parent, direction)
    local button = CreateFrame("Button", nil, parent)
    button.direction = direction
    button:SetSize(SLOT_SIZE, SLOT_SIZE)
    button:SetPoint("CENTER", parent.Center, "CENTER", OFFSETS[direction][1], OFFSETS[direction][2])

    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetAllPoints()
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

    button.Label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.Label:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnReceiveDrag", function(self) Panel:Drop(self.direction) end)
    button:SetScript("OnDragStart", function(self) Panel:Lift(self.direction) end)
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            Slots:Clear(self.direction)
        elseif GetCursorInfo() then
            Panel:Drop(self.direction)
        end
    end)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

-- Status line text: what (if anything) is keeping the slots from working.
function Panel:StatusText()
    if not Slots:IsGamepadUIEnabled() then
        return "|cffffd200Gamepad UI is off.|r Slots are saved and apply when it's on."
    elseif not Slots:IsBarAvailable() then
        return "|cffffd200Gamepad action bars aren't loaded yet.|r Slots apply when they load."
    elseif Slots:IsPending() then
        return "|cffffd200Changes apply after combat.|r"
    end
    return "|cff40ff40Active.|r Hold the hostile-target shoulder and press the D-pad."
end

function Panel:Refresh()
    if not frame then return end
    for direction, button in pairs(slotButtons) do
        local entry = Slots:Get(direction)
        if entry then
            button.Icon:SetTexture(Slots:Icon(entry))
            button.Icon:SetDesaturated(false)
            button.Label:SetText("")
        else
            button.Icon:SetTexture(EMPTY_TEXTURE)
            button.Label:SetText(direction == "up" and "Up" or direction == "down" and "Down"
                or direction == "left" and "Left" or "Right")
        end
    end
    frame.Status:SetText(self:StatusText())
    local key = Slots:GetFocusKey()
    frame.FocusKey:SetText("Return-focus key: " .. (key and ("|cffffffff" .. key .. "|r")
        or "|cff808080none|r  (/gpslots focuskey KEY)"))
end

local function SavePosition()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    ns.db.panel = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function PlaceFrame()
    frame:ClearAllPoints()
    local saved = ns.db.panel
    if type(saved) == "table" and saved.point then
        frame:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
        return
    end
    -- First open: centre on Offhand's game display when it spans UIParent
    -- across two monitors, so the panel doesn't land on the seam.
    local mainhand = _G.OffhandMainhandFrame
    if mainhand and mainhand.GetCenter and mainhand:GetCenter() then
        local x, y = mainhand:GetCenter()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    else
        frame:SetPoint("CENTER")
    end
end

local function CreatePanel()
    local ok, created = pcall(CreateFrame, "Frame", "GamepadShoulderSlotsPanel", UIParent, "BasicFrameTemplateWithInset")
    frame = ok and created or CreateFrame("Frame", "GamepadShoulderSlotsPanel", UIParent)
    frame:SetSize(230, 270)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)

    local title = frame.TitleText or frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if not frame.TitleText then title:SetPoint("TOP", 0, -6) end
    title:SetText("Shoulder Slots")

    frame.Center = CreateFrame("Frame", nil, frame)
    frame.Center:SetSize(1, 1)
    frame.Center:SetPoint("CENTER", frame, "TOP", 0, -112)

    local shoulder = frame:CreateTexture(nil, "ARTWORK")
    shoulder:SetSize(34, 34)
    shoulder:SetPoint("CENTER", frame.Center)
    if not (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("gamepad-targeting-hostile")) then
        shoulder:SetTexture(FALLBACK_CENTER_ICON)
    else
        shoulder:SetAtlas("gamepad-targeting-hostile")
    end

    for _, direction in ipairs(Slots.DIRECTIONS) do
        slotButtons[direction] = CreateSlot(frame, direction)
    end

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOP", frame.Center, "CENTER", 0, -SLOT_OFFSET - 32)
    hint:SetText("Hold the hostile-target shoulder")

    frame.Status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Status:SetPoint("TOPLEFT", hint, "BOTTOM", -100, -8)
    frame.Status:SetWidth(200)
    frame.Status:SetJustifyH("CENTER")

    frame.FocusKey = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.FocusKey:SetPoint("BOTTOM", frame, "BOTTOM", 0, 12)

    frame:SetScript("OnShow", function() Panel:Refresh() end)
    frame:SetScript("OnEvent", function() Panel:Refresh() end)
    frame:RegisterEvent("UPDATE_MACROS")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")

    PlaceFrame()
    frame:Hide()
end

function Panel:Toggle()
    if not ns.db then return end
    if not frame then CreatePanel() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

function Panel:IsShown()
    return frame ~= nil and frame:IsShown()
end

Slots:RegisterCallback(function()
    if frame and frame:IsShown() then Panel:Refresh() end
end)
