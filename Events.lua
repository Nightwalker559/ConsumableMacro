-- ConsumableMacro Events
-- Event handling, reminder triggers and slash commands (loaded last).
local CM = ConsumableMacroAddon

-- ── Event Handler State ────────────────────────────────────────────────────────
-- Declared before the event handler so all closures share the correct locals.
-- (Lua state is rebuilt on relog/reload, so no explicit reset is needed.)
local wasInInstance        = false  -- true while inside a dungeon/raid/delve
local isLoginPending       = false  -- set by PLAYER_LOGIN, consumed by PLAYER_ENTERING_WORLD

-- IsInInstance() also returns true for instanceType "neighborhood" and "interior"
-- (player housing, Patch 12.0+). Those are not "content" instances and must not
-- arm/disarm the post-instance reminder, so filter to the types that matter here.
local REAL_INSTANCE_TYPES = { party = true, raid = true, scenario = true, pvp = true, arena = true }
local function IsRealInstance()
    local inInstance, instanceType = IsInInstance()
    return inInstance and REAL_INSTANCE_TYPES[instanceType] or false
end

-- Rebuilds the macros (optional) and redraws everything that shows bag contents.
local function RefreshBagState(updateMacros)
    if updateMacros then CM.UpdateAllMacros() end
    CM.UpdateReminderFrame()
    if CM.mainFrame and CM.mainFrame:IsShown() then CM.RefreshList() end
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
-- ZONE_CHANGED_NEW_AREA also fires on zone transitions without a loading screen
-- (e.g. delve entry/exit), which PLAYER_ENTERING_WORLD does not catch.
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
        -- rebuilt by the first bag update (BAG_UPDATE_DELAYED) if Auto-Update is on.
        CM.UpdateAllMacros(true)
        ev:UnregisterEvent("PLAYER_LOGIN")

    elseif event == "PLAYER_ENTERING_WORLD" then
        local inInstance = IsRealInstance()
        -- Consume unconditionally on the first call no matter which branch below
        -- matches, so a stale flag can never leak into a later, unrelated event
        -- (e.g. a UI reload right after login that doesn't match any branch).
        local wasLoginPending = isLoginPending
        isLoginPending = false

        if inInstance then
            -- Entered a real instance — arm the post-instance trigger
            wasInInstance = true
        elseif wasInInstance then
            -- Left an instance, now in open world → post-instance reminder
            wasInInstance = false
            _G.C_Timer.After(2.0, function()
                if IsRealInstance() then return end
                CM.CheckMissingConsumablesPostInstance()
            end)
        elseif wasLoginPending and not arg2 then
            -- Fresh login (not /reload, not inside an instance). Bag data may not be
            -- fully cached at this exact instant, so wait briefly before checking —
            -- avoids a false "missing" flash that BAG_UPDATE_DELAYED then corrects.
            _G.C_Timer.After(1.0, function()
                if IsRealInstance() then return end
                CM.CheckMissingConsumables()
            end)
        end

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        -- Catches instance entry/exit that happens without a loading screen
        -- (e.g. delves). PLAYER_ENTERING_WORLD does not catch those, but also
        -- fires for housing neighborhood/interior transitions — IsRealInstance()
        -- filters those out so portaling out of your house/neighborhood never
        -- triggers the post-instance reminder.
        if IsRealInstance() then
            if not wasInInstance then
                wasInInstance  = true
                isLoginPending = false
            end
        elseif wasInInstance then
            wasInInstance = false
            _G.C_Timer.After(2.0, function()
                if IsRealInstance() then return end
                CM.CheckMissingConsumablesPostInstance()
            end)
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- closes the main window, and every dialog that was opened without it (e.g. /cm reset)
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
            -- only the macro rebuild depends on Auto-Update; reminder and list always follow the bags
            CM.Defer("bagUpdate", function()
                RefreshBagState(CM.db and CM.db.autoUpdate)
            end, 1.0)
        end

    elseif event == "ITEM_DATA_LOAD_RESULT" then
        -- fires once per loaded item: coalesce into a single list rebuild
        if CM.mainFrame and CM.mainFrame:IsShown() then CM.Defer("refreshList", CM.RefreshList) end
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
        CM.ShowResetFrame()  -- tab selection + OK doubles as the confirmation
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
            CM.mainFrame:Show()  -- OnShow refreshes the list and applies the skin
        end
    else
        _G.print(CM.L["HELP_TEXT"])
    end
end
