-- ConsumableMacro Elixirs (WoW Forever only)
-- Several elixirs run at the same time, each press uses one (3 s shared cooldown). The macro
-- uses the first elixir of the list that is in the bags and whose buff is missing, so
-- repeated presses walk down the list. Auras are only readable out of combat; the macro
-- can't be edited in combat anyway, so it is rebuilt when the buffs change out of combat
-- and once more when the fight ends.
local CM = ConsumableMacroAddon
if not CM.IS_FOREVER then return end

-- Auras can be read out of combat only (they are secret values in combat).
local function AurasReadable()
    local C_Secrets = _G.C_Secrets
    if _G.InCombatLockdown() then return false end
    return not (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret())
end

-- True if the buff of this item is on the player; false if not or if the item's spell
-- isn't cached yet (then the elixir counts as missing and gets used).
local function HasItemBuff(itemID)
    -- the spell an item casts is the buff it leaves (same spell ID)
    local spellName, spellID = C_Item.GetItemSpell(itemID)
    if not spellID then return false end
    local auras = _G.C_UnitAuras
    if auras.GetPlayerAuraBySpellID(spellID) then return true end
    return spellName ~= nil and auras.GetAuraDataBySpellName("player", spellName, "HELPFUL") ~= nil
end

-- The elixir the macro uses now: the first in the bags without its buff. In combat the
-- buffs are unknown, so it is simply the first in the bags. Second value: true when every
-- elixir in the bags is active already (nothing left to use).
function CM.GetNextElixir(items)
    local readable = AurasReadable()
    local anyInBags
    for _, item in ipairs(items) do
        if CM.IsInBags(item.id) then
            anyInBags = true
            if not (readable and HasItemBuff(item.id)) then return item.id, false end
        end
    end
    return nil, anyInBags == true
end

function CM.BuildElixirMacroBody()
    local items = CM.db.elixir.items
    local nextID = CM.GetNextElixir(items)
    local lines = { CM.GetShowtooltipLine(items, nextID), "/cqs", "/stopcasting" }
    if nextID then tinsert(lines, "/use item:" .. nextID) end
    return CM.TrimMacroLines(lines)
end

-- ── Rebuild when the buffs change ──────────────────────────────────────────────
local ev = CreateFrame("Frame")
ev:RegisterUnitEvent("UNIT_AURA", "player")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function()
    if not CM.db or not CM.db.autoUpdate or _G.InCombatLockdown() then return end
    -- UNIT_AURA comes in bursts: one rebuild per 0.5 s (the body is only written when it changed)
    CM.Defer("elixirAura", function()
        if not _G.InCombatLockdown() then CM.UpdateMacro("elixir") end
    end, 0.5)
end)
