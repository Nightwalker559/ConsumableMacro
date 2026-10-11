-- ConsumableMacro ElvUI skin
-- Everything that touches ElvUI lives here (the reminder frame aside, which has a
-- non-ElvUI fallback). Without ElvUI nothing in this file does anything.
local CM = ConsumableMacroAddon

-- ElvUI Skins module, or nil if ElvUI isn't loaded.
function CM.GetElvSkins()
    local E = _G.ElvUI and _G.ElvUI[1]
    return E and E:GetModule("Skins", true) or nil
end

function CM.SkinCheckbox(S, cb)
    if S and cb and S.HandleCheckBox then S:HandleCheckBox(cb) end
end

-- Widgets of one Restock setup row: checkbox, boxes, remove "X", fold icon.
function CM.SkinRestockRow(row)
    local S = CM.GetElvSkins()
    if not S then return end
    CM.SkinCheckbox(S, row.chk)
    -- remove button -> ElvUI close "X", fold icon -> ElvUI +/- (best-effort)
    if S.HandleCloseButton then pcall(S.HandleCloseButton, S, row.delBtn) end
    if S.HandleCollapseTexture then pcall(S.HandleCollapseTexture, S, row.toggle) end
    for _, box in ipairs({ row.box, row.minBox }) do
        if box and S.HandleEditBox then S:HandleEditBox(box) end
    end
end

-- ── ElvUI Skin ─────────────────────────────────────────────────────────────────
-- Skins every addon frame that exists so far; missing frames/handlers are skipped,
-- so it is safe to call at any time.
function CM.ApplyElvUISkin()
    local mf = CM.mainFrame
    if not mf then return end
    local S = CM.GetElvSkins()
    if not S then return end

    local function frame(f)  if f and S.HandleFrame       then S:HandleFrame(f)       end end
    local function button(b) if b and S.HandleButton      then S:HandleButton(b)      end end
    local function edit(e)   if e and S.HandleEditBox     then S:HandleEditBox(e)     end end
    local function check(c)  CM.SkinCheckbox(S, c) end
    local function scrollbar(scroll)  -- the minimal scrollbar of CM.CreateScrollFrame
        local sb = scroll and scroll.ScrollBar
        if sb and S.HandleTrimScrollBar then S:HandleTrimScrollBar(sb) end
    end
    -- shared by the IE and Reset frames
    local function dialog(f)
        if not f then return end
        frame(f)
        button(f.okBtn); button(f.cancelBtn)
        for _, chk in pairs(f.checkboxes or {}) do check(chk) end
    end

    -- Main window (S:HandleFrame also skins the window's close button)
    frame(mf); frame(mf.scrollBg)
    edit(mf.editBox); edit(mf.dropSkin)
    button(mf.addBtn); button(mf.updateBtn); button(mf.optionsBtn)
    frame(mf.sideBar)
    -- flat selection tint in ElvUI's accent colour instead of Blizzard's list atlases
    local E = _G.ElvUI[1]
    CM.flatTabColor = E.media and E.media.rgbvaluecolor or { 1, 0.82, 0 }
    for _, b in pairs(mf.tabBtns) do CM.SetSideTabSelected(b, b.selected) end
    scrollbar(mf.scroll)
    -- the reminder frame skins itself when it is created

    -- Options
    local o = CM.optionsFrame
    if o then
        frame(o)
        check(o.autoUpdateChk); check(o.reminderChk)
        for _, box in pairs(o.minBoxes or {}) do edit(box) end
        button(o.exportBtn); button(o.importBtn); edit(o.ieBox)
        button(o.resetBtn)
        check(o.apEnableChk); check(o.apStopCastChk); edit(o.apResetBox)
        button(o.apSyncBtn); button(o.apConfigureBtn)
        button(o.rsConfigBtn)
        -- best-effort, once only: ElvUI adds a new arrow texture on every call
        if o.profileDD and S.HandleDropDownBox and not o.profileDD.cmSkinned then
            o.profileDD.cmSkinned = true
            pcall(S.HandleDropDownBox, S, o.profileDD, 288)
        end
    end

    -- Profile name / delete dialog
    local pf = CM.profileFrame
    if pf then
        frame(pf); edit(pf.editBox)
        button(pf.okBtn); button(pf.altBtn); button(pf.cancelBtn)
    end

    -- AutoPotion priority frame
    local ap = CM.autoPotionFrame
    if ap then
        frame(ap); button(ap.closeBtn)
    end

    -- Restock: AH panel + config frame
    frame(CM.restockFrame)
    local rc = CM.restockConfigFrame
    if rc then
        frame(rc); frame(rc.scrollBg)
        check(rc.enableChk); check(rc.bankChk)
        edit(rc.addBox); button(rc.addBtn)
        scrollbar(rc.scroll)
    end

    -- IE selection + Reset frames
    dialog(CM.ieFrame)
    dialog(CM.resetFrame)
end
