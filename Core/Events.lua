-- ConsumableMacro Events
-- Event handling, reminder triggers and slash commands (loaded last).
local CM = ConsumableMacroAddon

-- ── Event Handler State ────────────────────────────────────────────────────────
local wasInInstance        = false  -- true while inside a dungeon/raid/delve
local isLoginPending       = false  -- set by PLAYER_LOGIN, consumed by PLAYER_ENTERING_WORLD

-- IsInInstance() is also true for player housing ("neighborhood"/"interior"), which
-- must not arm or disarm the post-instance reminder.
local REAL_INSTANCE_TYPES = { party = true, raid = true, scenario = true, pvp = true, arena = true }
local function IsRealInstance()
    local inInstance, instanceType = IsInInstance()
    return inInstance and REAL_INSTANCE_TYPES[instanceType] or false
end

-- Rebuilds the macros (optional) and redraws everything that shows bag contents.
local function RefreshBagState(updateMacros)
    if updateMacros then CM.UpdateAllMacros() end
    CM.UpdateReminderFrame()
    CM.RefreshList()
end

-- Back in the open world after an instance: remind about low consumables. The
-- re-check after the delay covers zoning straight into another instance.
local function OnLeftInstance()
    wasInInstance = false
    _G.C_Timer.After(2.0, function()
        if IsRealInstance() then return end
        CM.CheckMissingConsumablesPostInstance()
    end)
end

-- ── Event Handler ──────────────────────────────────────────────────────────────
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("ITEM_DATA_LOAD_RESULT")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == CM.ADDON_NAME then
        CM.InitProfiles()
        CM.BuildUI()
        ev:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        isLoginPending = true
        CM.ApplyElvUISkin()
        -- Bags may not be cached yet: only create missing macros. Existing ones are
        -- rebuilt by the first bag update if Auto-Update is on.
        CM.UpdateAllMacros(true)
        ev:UnregisterEvent("PLAYER_LOGIN")

    elseif event == "PLAYER_ENTERING_WORLD" then
        local inInstance = IsRealInstance()
        -- Consume the flag on every call, so it can't leak into a later event.
        local wasLoginPending = isLoginPending
        isLoginPending = false

        if inInstance then
            wasInInstance = true
        elseif wasInInstance then
            OnLeftInstance()
        elseif wasLoginPending and not arg2 then
            -- Fresh login (not /reload). The bag data may not be cached yet, so wait
            -- briefly to avoid a false "missing" flash.
            _G.C_Timer.After(1.0, function()
                if IsRealInstance() then return end
                CM.CheckMissingConsumables()
            end)
        end

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        -- Catches instance entry/exit without a loading screen (e.g. delves).
        if IsRealInstance() then
            if not wasInInstance then
                wasInInstance  = true
                isLoginPending = false
            end
        elseif wasInInstance then
            OnLeftInstance()
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        CM.HideSubFrames()
        if CM.mainFrame and CM.mainFrame:IsShown() then CM.mainFrame:Hide() end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if CM.needsUpdateAfterCombat then
            CM.needsUpdateAfterCombat = false
            RefreshBagState(true)
        end

    elseif event == "BAG_UPDATE_DELAYED" and CM.db then
        if InCombatLockdown() then
            if CM.db.autoUpdate then CM.needsUpdateAfterCombat = true end
        else
            -- only the macro rebuild depends on Auto-Update
            CM.Defer("bagUpdate", function()
                RefreshBagState(CM.db and CM.db.autoUpdate)
            end, 1.0)
        end

    elseif event == "ITEM_DATA_LOAD_RESULT" then
        -- fires once per loaded item: coalesce into one list rebuild
        CM.Defer("refreshList", CM.RefreshList)
    end
end)

-- ── Slash Commands ─────────────────────────────────────────────────────────────
_G.SLASH_CONSUMABLEMACRO1 = "/cm"
_G.SLASH_CONSUMABLEMACRO2 = "/consumablemacro"
_G.SlashCmdList["CONSUMABLEMACRO"] = function(msg)
    if InCombatLockdown() then
        CM.ShowError(CM.L["ERR_COMBAT"])
        return
    end
    local raw = msg:trim()
    msg = raw:lower()
    if msg == "reset" then
        CM.ShowResetFrame()
    elseif msg == "update" then
        CM.UpdateAllMacros()
        CM.Print(CM.L["BTN_UPDATE"])
    elseif msg == "profile" or msg:find("^profile%s") then
        local arg = raw:match("^%S+%s+(.+)$")
        if not arg then
            CM.Print(CM.L["PROFILE_SWITCHED"]:format(CM.GetProfileName() or "?"))
            return
        end
        local name = CM.FindProfile(arg)
        if not name then
            CM.ShowError(CM.L["PROFILE_ERR_UNKNOWN"]:format(arg))
        elseif CM.SetProfile(name) then
            CM.Print(CM.L["PROFILE_SWITCHED"]:format(name))
        end
    elseif msg == "help" then
        _G.print(CM.L["HELP_TEXT"])
    elseif msg == "" then
        if not CM.mainFrame then return end
        if CM.mainFrame:IsShown() then
            CM.mainFrame:Hide()
        else
            CM.mainFrame:Show()
        end
    else
        _G.print(CM.L["HELP_TEXT"])
    end
end
