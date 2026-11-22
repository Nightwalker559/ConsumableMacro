-- ConsumableMacro Aura debug
-- /cm auradebug prints what the client lets an addon read about the player's buffs and
-- whether those values are secret (restricted in combat, dungeons, raids), for the
-- active tab's items. /cm auradebug watch toggles a line per UNIT_AURA event of the
-- player. Works in combat, unlike the other commands. Read-only: it changes nothing.
local CM = ConsumableMacroAddon

local function Secret(v)
    return _G.issecretvalue ~= nil and _G.issecretvalue(v)
end

local function Show(v)
    if Secret(v) then return "<secret>" end
    return tostring(v)
end

-- Result of an API call as short text: an error, nothing, <secret>, "found" (a table) or the value.
local function Probe(fn, ...)
    if type(fn) ~= "function" then return "n/a" end
    local ok, a = pcall(fn, ...)
    if not ok then return "ERR " .. tostring(a):sub(1, 50) end
    if Secret(a) then return "<secret>" end
    if a == nil then return "none" end
    return type(a) == "table" and "found" or tostring(a)
end

local function Say(fmt, ...)
    CM.Print(("auradebug: " .. fmt):format(...))
end

local function PrintEnvironment()
    local _, instanceType = _G.IsInInstance()
    Say("combat=%s instance=%s build=%s", tostring(_G.InCombatLockdown()), tostring(instanceType),
        tostring(select(4, _G.GetBuildInfo())))
    -- the answers of C_Secrets that need no argument (which of them exist depends on the client)
    local parts = {}
    for name, fn in pairs(_G.C_Secrets or {}) do
        if type(fn) == "function" then
            local answer = Probe(fn)
            if not answer:find("^ERR") then tinsert(parts, name .. "=" .. answer) end
        end
    end
    table.sort(parts)
    Say("C_Secrets: %s", #parts > 0 and table.concat(parts, ", ") or "n/a")
end

-- The player's first buffs by index: shows whether name and spell ID can be read.
local function PrintAuras()
    local api = _G.C_UnitAuras
    local get = api and api.GetAuraDataByIndex
    if not get then Say("C_UnitAuras.GetAuraDataByIndex n/a"); return end
    local count, parts = 0, {}
    for i = 1, 40 do
        local ok, a = pcall(get, "player", i, "HELPFUL")
        if not ok or a == nil then break end
        count = i
        if i <= 4 then
            local okp, text = pcall(function() return Show(a.name) .. " (" .. Show(a.spellId) .. ")" end)
            tinsert(parts, okp and text or "ERR")
        end
    end
    Say("buffs by index: %d, first: %s", count, #parts > 0 and table.concat(parts, "; ") or "-")
end

-- One line per item of the open tab: its use spell and what each lookup says about it.
local function PrintItems()
    local list = CM.db and CM.db[CM.activeTab] and CM.db[CM.activeTab].items or {}
    if #list == 0 then Say("tab %s is empty", tostring(CM.activeTab)); return end
    local api = _G.C_UnitAuras or {}
    local getSpell = (_G.C_Item and _G.C_Item.GetItemSpell) or _G.GetItemSpell
    for _, item in ipairs(list) do
        local okS, spellName, spellID = pcall(getSpell, item.id)
        if not okS then spellName, spellID = nil, nil end
        local bySpell = Probe(api.GetPlayerAuraBySpellID, spellID)
        local byName  = Probe(api.GetAuraDataBySpellName, "player", spellName, "HELPFUL")
        local find    = Probe(_G.AuraUtil and _G.AuraUtil.FindAuraByName, spellName, "player", "HELPFUL")
        -- whether the client treats this spell's aura as secret
        local secrecy = Probe(_G.C_Secrets and _G.C_Secrets.GetSpellAuraSecrecy, spellID)
        local secret  = Probe(_G.C_Secrets and _G.C_Secrets.ShouldSpellAuraBeSecret, spellID)
        Say("%s (%d): spell %s/%s | bySpellID=%s byName=%s findName=%s | secrecy=%s shouldBeSecret=%s",
            tostring(C_Item.GetItemNameByID(item.id)), item.id, tostring(spellName), tostring(spellID),
            bySpell, byName, find, secrecy, secret)
    end
end

-- ── UNIT_AURA watch ────────────────────────────────────────────────────────────
local watcher

local function OnAura(_, _, unit, info)
    local text = "-"
    if type(info) == "table" then
        local ok, t = pcall(function()
            return ("full=%s added=%s removed=%s updated=%s"):format(Show(info.isFullUpdate),
                Show(info.addedAuras and #info.addedAuras), Show(info.removedAuraInstanceIDs and #info.removedAuraInstanceIDs),
                Show(info.updatedAuraInstanceIDs and #info.updatedAuraInstanceIDs))
        end)
        text = ok and t or "ERR"
    end
    Say("UNIT_AURA %s %s", Show(unit), text)
end

local function ToggleWatch()
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:SetScript("OnEvent", OnAura)
    end
    if watcher:IsEventRegistered("UNIT_AURA") then
        watcher:UnregisterEvent("UNIT_AURA")
        Say("watch off")
    else
        watcher:RegisterUnitEvent("UNIT_AURA", "player")
        Say("watch on - drink an elixir, enter combat, zone into a dungeon")
    end
end

function CM.RunAuraDebug(watch)
    if watch then ToggleWatch(); return end
    PrintEnvironment()
    PrintAuras()
    PrintItems()
end
