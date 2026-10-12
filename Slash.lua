-- Gamepad Shoulder Slots: /gpslots.
local _, ns = ...
local Slots, Panel = ns.Slots, ns.Panel
local Print = ns.Print

local function ShowStatus()
    Print("Hostile-target shoulder D-pad:")
    for _, direction in ipairs(Slots.DIRECTIONS) do
        Print("  %-5s %s", direction, Slots:Label(Slots:Get(direction)))
    end
    Print("Focus key: %s", Slots:GetFocusKey() and ("|cffffffff" .. Slots:GetFocusKey() .. "|r") or "|cff808080off|r")
    Print("%s", Panel:StatusText())
    Print("/gpslots — open the editor   /gpslots status   /gpslots minimap")
    Print("/gpslots set <up|left|right|down> [spell|item|macro <name>]   /gpslots clear <direction|all>")
    Print("/gpslots focuskey <KEY|off>")
end

SLASH_GAMEPADSHOULDERSLOTS1 = "/gpslots"
SlashCmdList.GAMEPADSHOULDERSLOTS = function(msg)
    if not ns.db then return end
    local command, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" then
        Panel:Toggle()
    elseif command == "set" then
        local direction, kind, text = rest:match("^(%S*)%s*(%S*)%s*(.-)$")
        direction, kind = direction:lower(), kind:lower()
        if not Slots:IsDirection(direction) then return Print("Pick a direction: up, left, right or down.") end
        local entry, err
        if kind == "" then
            entry, err = Slots:EntryFromCursor()
            if entry then ClearCursor() end
        else
            entry, err = Slots:EntryFromText(kind, text)
        end
        if not entry then return Print("|cffff4040Not set:|r %s.", err) end
        Slots:Set(direction, entry)
        Print("%s: %s%s", direction, Slots:Label(entry), Slots:IsPending() and " (after combat)" or "")
    elseif command == "clear" then
        local direction = rest:lower()
        if not Slots:Clear(direction) then return Print("Pick a direction: up, left, right, down or all.") end
        Print("Cleared %s.", direction)
    elseif command == "focuskey" then
        local key = rest:upper()
        if key == "" then return Print("Name a key, for example NUMPAD0, or 'off'.") end
        Slots:SetFocusKey(key ~= "OFF" and key or nil)
        Print("Focus key %s.", Slots:GetFocusKey() and ("set to " .. Slots:GetFocusKey()) or "off")
    elseif command == "minimap" then
        local button = ns.MinimapButton
        button:SetShown(not button:IsShown())
        Print("Minimap button %s.", button:IsShown() and "shown" or "hidden")
    else
        ShowStatus()
    end
end
