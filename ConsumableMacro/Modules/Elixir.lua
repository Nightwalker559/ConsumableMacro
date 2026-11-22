-- ConsumableMacro Elixirs (WoW Forever only)
-- Several elixirs run at the same time, each press uses one (3 s shared cooldown). The macro
-- uses the first elixir of the list that is in the bags and whose buff is missing, so
-- repeated presses walk down the list. Auras are only readable out of combat; the macro
-- can't be edited in combat anyway, so it is rebuilt when the buffs change out of combat
-- and once more when the fight ends.
local CM = ConsumableMacroAddon
if not CM.IS_FOREVER then return end

-- True/false: the buff of this item is on the player. nil: unknown (aura data hidden
-- in combat, or the item's spell is not cached yet).
local function HasItemBuff(itemID)
    local C_Secrets = _G.C_Secrets
    if _G.InCombatLockdown() or (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()) then
        return nil
    end
    -- the spell an item casts is the buff it leaves (same spell ID)
    local spellName, spellID = C_Item.GetItemSpell(itemID)
    if not spellID then return nil end
    local auras = _G.C_UnitAuras
    if auras.GetPlayerAuraBySpellID(spellID) then return true end
    return spellName ~= nil and auras.GetAuraDataBySpellName("player", spellName, "HELPFUL") ~= nil
end

-- The elixir the macro uses now: the first in the bags without its buff. With unknown
-- buffs that is simply the first in the bags. Second value: true when every elixir in
-- the bags is active already (nothing left to use).
function CM.GetNextElixir(items)
    local anyInBags
    for _, item in ipairs(items) do
        if CM.IsInBags(item.id) then
            anyInBags = true
            if not HasItemBuff(item.id) then return item.id, false end
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
