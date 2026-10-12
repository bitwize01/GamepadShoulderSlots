-- Shared WoW API mocks for the Gamepad Shoulder Slots tests.
-- Usage: local M = dofile("tests/mock.lua"); M.load() after adjusting M.* state.
local M = {}

M.combat = false
M.cursor = nil
M.overrides = {}
M.cooldownSets = 0
M.printed = {}
M.frames = {}
M.gamepadUI = true

local function region()
    local r = { shown = true }
    function r:SetTexture(t) self.texture = t; self.atlas = nil end
    function r:SetAtlas(a) self.atlas = a end
    function r:SetDesaturated(v) self.desaturated = v end
    function r:SetAllPoints() end
    function r:SetPoint() end
    function r:SetSize() end
    function r:SetWidth() end
    function r:SetJustifyH() end
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    return r
end
M.region = region

local function frame(kind, name)
    local f = { kind = kind, name = name, scripts = {}, events = {}, shown = true,
        attributes = { type = "action", action = 0 }, enabled = false, alpha = 1 }
    function f:SetScript(script, cb) self.scripts[script] = cb end
    function f:HookScript() end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetSize() end
    function f:SetPoint(...) self.point = { ... } end
    function f:ClearAllPoints() self.point = nil end
    function f:GetPoint() if self.point then return unpack(self.point) end end
    function f:GetCenter() return 100, 200 end
    function f:SetFrameStrata() end
    function f:SetClampedToScreen() end
    function f:SetMovable() end
    function f:EnableMouse() end
    function f:StartMoving() end
    function f:StopMovingOrSizing() end
    function f:RegisterForClicks() end
    function f:RegisterForDrag() end
    function f:SetHighlightTexture() end
    function f:SetPushedTexture() end
    function f:CreateTexture() return region() end
    function f:CreateFontString() return region() end
    function f:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:SetAttribute(k, v) self.attributes[k] = v end
    function f:GetAttribute(k) return self.attributes[k] end
    function f:SetEnabled(v) self.enabled = v end
    function f:SetAlpha(v) self.alpha = v end
    function f:Fire(event, ...) self.scripts.OnEvent(self, event, ...) end
    return f
end
M.frame = frame

function M.install()
    InCombatLockdown = function() return M.combat end
    CreateFrame = function(kind, name, parent, template)
        local f = frame(kind, name)
        f.template = template
        if template == "BasicFrameTemplateWithInset" then f.TitleText = region() end
        M.frames[#M.frames + 1] = f
        return f
    end
    UIParent = frame("Frame", "UIParent")
    hooksecurefunc = function(t, key, post)
        local original = t[key]
        t[key] = function(...) local r = original(...); post(...); return r end
    end
    C_Timer = { After = function(_, cb) cb() end }
    InputUtil = { IsGamepadUIEnabled = function() return M.gamepadUI end }
    M.spells = { ["Frost Nova"] = { name = "Frost Nova", spellID = 122, iconID = 135848 },
        ["Blink"] = { name = "Blink", spellID = 1953, iconID = 135736 } }
    M.spells[122], M.spells[1953] = M.spells["Frost Nova"], M.spells["Blink"]
    M.pickedUp = {}
    C_Spell = {
        GetSpellInfo = function(v) return M.spells[v] end,
        GetSpellCooldown = function() return { startTime = 10, duration = 25, isEnabled = true, modRate = 1 } end,
        PickupSpell = function(id) M.pickedUp[#M.pickedUp + 1] = "spell:" .. id; M.cursor = { "spell", 1, "spell", id } end,
    }
    C_Item = {
        GetItemInfoInstant = function() return nil end,
        GetItemIconByID = function() return 134414 end,
        GetItemNameByID = function() return "Hearthstone" end,
        GetItemCooldown = function() return 0, 0, true end,
        PickupItem = function(id) M.pickedUp[#M.pickedUp + 1] = "item:" .. id; M.cursor = { "item", id } end,
    }
    C_Texture = { GetAtlasInfo = function(a) return a == "gamepad-targeting-hostile" and {} or nil end }
    M.macros = { Mount = { index = 3, icon = 132261 } }
    GetMacroIndexByName = function(n) return M.macros[n] and M.macros[n].index or 0 end
    GetMacroInfo = function(n)
        if type(n) == "number" then
            for k, m in pairs(M.macros) do if m.index == n then return k, m.icon end end
            return nil
        end
        return M.macros[n] and n, M.macros[n] and M.macros[n].icon
    end
    GetMacroSpell = function() return nil end
    GetMacroItem = function() return nil end
    PickupMacro = function(name)
        M.pickedUp[#M.pickedUp + 1] = "macro:" .. name
        M.cursor = { "macro", M.macros[name].index }
    end
    GetCursorInfo = function() if M.cursor then return unpack(M.cursor) end end
    ClearCursor = function() M.cursor = nil end
    CooldownFrame_Set = function(_, start) if start and start > 0 then M.cooldownSets = M.cooldownSets + 1 end end
    SetOverrideBinding = function(_, _, key, action) M.overrides[key] = action end
    ClearOverrideBindings = function() M.overrides = {} end
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    geterrorhandler = function() return function(err) error(err, 0) end end
    print = function(text) M.printed[#M.printed + 1] = text end
    GameTooltip = {}
    for _, method in ipairs({ "SetOwner", "SetSpellByID", "SetItemByID", "SetText", "AddLine", "Show", "Hide" }) do
        GameTooltip[method] = function(self, a) self.last = { method, a } end
    end
    NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
    SlashCmdList = {}
end

-- Minimal model of Blizzard's hostile bar: SetUpActionButtons resets every
-- button and points the dpad references at the left or right group.
function M.makeBar()
    local bar = { left = {}, right = {}, swapped = false }
    for i = 1, 4 do
        for _, side in ipairs({ "left", "right" }) do
            local b = frame("CheckButton", side .. i)
            b.SpecialActionIcon = region()
            b.SpecialActionIcon.shown = false
            b.IconOverlay = region()
            b.cooldown = {}
            bar[side][i] = b
        end
    end
    function bar:SetUpDpadBottom() self.dpadBottomButton:SetEnabled(false) end
    function bar:SetUpActionButtons()
        for _, b in ipairs(self.left) do b:SetEnabled(true); b:SetAlpha(1) end
        for _, b in ipairs(self.right) do b:SetEnabled(true); b:SetAlpha(1) end
        local dpad = self.swapped and self.right or self.left
        self.dpadLeftButton, self.dpadTopButton, self.dpadRightButton, self.dpadBottomButton =
            dpad[1], dpad[2], dpad[3], dpad[4]
        for i = 1, 3 do dpad[i]:SetEnabled(false); dpad[i]:SetAlpha(0.3) end
        self:SetUpDpadBottom()
        -- Blizzard's face setup runs after the dpad setups.
        local face = self.swapped and self.left or self.right
        face[1]:SetAttribute("type", "spell"); face[1]:SetAttribute("spell", 5019)
    end
    bar:SetUpActionButtons()
    GamepadMainActionBarFrame = { PageUnit = { HostileTargetingActionBar = bar } }
    return bar
end

-- Loads the add-on files in TOC order (libraries excluded) with one namespace.
function M.load()
    M.ns = {}
    for _, file in ipairs({ "Slots.lua", "Panel.lua", "Minimap.lua", "Slash.lua" }) do
        local chunk = assert(loadfile(file))
        chunk("GamepadShoulderSlots", M.ns)
    end
    for _, f in ipairs(M.frames) do
        if f.events.CVAR_UPDATE then M.events = f end
    end
    M.slash = SlashCmdList.GAMEPADSHOULDERSLOTS
    M.events:Fire("ADDON_LOADED", "GamepadShoulderSlots")
    M.events:Fire("PLAYER_ENTERING_WORLD")
end

M.failures = 0
function M.check(cond, message)
    if not cond then
        M.failures = M.failures + 1
        io.stderr:write("FAIL: " .. message .. "\n")
    end
end

function M.finish(name)
    if M.failures > 0 then
        io.stderr:write(name .. ": " .. M.failures .. " failure(s)\n")
        os.exit(1)
    end
    io.stdout:write(name .. ": all checks passed\n")
end

return M
