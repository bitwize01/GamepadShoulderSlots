-- Gamepad Shoulder Slots: minimap launcher (LibDataBroker + LibDBIcon).
local ADDON, ns = ...
local Slots, Panel = ns.Slots, ns.Panel

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local ICON = "Interface\\Icons\\INV_Gauntlets_04"

local launcher

local function OnTooltipShow(tooltip)
    tooltip:AddLine("Gamepad Shoulder Slots")
    for _, direction in ipairs(Slots.DIRECTIONS) do
        tooltip:AddDoubleLine(direction, Slots:Label(Slots:Get(direction)), 0.6, 0.8, 1, 1, 1, 1)
    end
    tooltip:AddLine(" ")
    tooltip:AddLine("Click to open the slot editor.", 0.6, 0.8, 1)
    tooltip:AddLine("Drag to move this button.", 0.6, 0.8, 1)
end

function MinimapButton:Init()
    local LibStub = _G.LibStub
    local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
    local icon = LibStub and LibStub("LibDBIcon-1.0", true)
    if not ldb or not icon then return end
    launcher = ldb:NewDataObject(ADDON, {
        type = "launcher",
        text = "Shoulder Slots",
        icon = ICON,
        OnClick = function() Panel:Toggle() end,
        OnTooltipShow = OnTooltipShow,
    })
    ns.db.minimap = type(ns.db.minimap) == "table" and ns.db.minimap or {}
    icon:Register(ADDON, launcher, ns.db.minimap)
end

function MinimapButton:SetShown(shown)
    local icon = _G.LibStub and _G.LibStub("LibDBIcon-1.0", true)
    if not icon or not ns.db.minimap then return end
    ns.db.minimap.hide = not shown or nil
    if shown then icon:Show(ADDON) else icon:Hide(ADDON) end
end

function MinimapButton:IsShown()
    return not (ns.db.minimap and ns.db.minimap.hide)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    MinimapButton:Init()
end)
