-- ConsumableMacro Profiles
-- Profile storage and management. Item lists and all settings live in a profile;
-- each character only remembers which profile it uses.
--   ConsumableMacroDB     = { dbVersion, profiles = { [name] = profile }, aliases = { [oldName] = newName } }
--   ConsumableMacroCharDB = { profile = name, reminderPos = {...} }
-- CM.db always points at the active profile table, so the rest of the addon
-- keeps reading CM.db.<tab>, CM.db.autoUpdate etc. unchanged.
local CM = ConsumableMacroAddon

local DEFAULT_PROFILE = "Default"  -- target of the one-time migration
local DB_VERSION      = 2
local DEFAULT_ORDER   = { "classspell", "healpotion", "healthstone" }

-- ── Helpers ────────────────────────────────────────────────────────────────────
local function DeepCopy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = DeepCopy(x) end
    return t
end

local function Trim(s)
    return (tostring(s or ""):match("^%s*(.-)%s*$"))
end

-- "Name-Realm" - name of the profile a brand-new character starts with.
function CM.GetCharKey()
    return (_G.UnitName("player") or "Unknown") .. "-" .. (_G.GetRealmName() or "Realm")
end

-- Fills every missing field of a profile with its default.
function CM.FillProfileDefaults(p)
    for _, t in ipairs(CM.TABS) do
        local tab = p[t.key]
        if type(tab) ~= "table" then tab = {}; p[t.key] = tab end
        tab.items = tab.items or {}
        if not CM.MINCOUNT_SKIP[t.key] then tab.minCount = tab.minCount or 0 end
    end
    if p.autoUpdate   == nil then p.autoUpdate   = true end
    if p.showReminder == nil then p.showReminder = true end
    p.autoPotion = p.autoPotion or { enabled = false, stopCasting = true }
    p.restock    = p.restock    or { enabled = false, countBank = false }
    p.restock.extra     = p.restock.extra     or {}  -- items without a tab: { id, restock, target, minCount }
    p.restock.collapsed = p.restock.collapsed or {}  -- [sectionKey] = true while folded in the setup
    p.autoPotionResetSeconds = p.autoPotionResetSeconds or 0
    p.autoPotionOrder        = p.autoPotionOrder or DeepCopy(DEFAULT_ORDER)
end

-- Follows renames (aliases) until an existing profile is found; nil if none.
local function ResolveName(root, name)
    for _ = 1, 10 do
        if not name then return nil end
        if root.profiles[name] then return name end
        name = root.aliases[name]
    end
    return nil
end

-- ── Init (ADDON_LOADED) ────────────────────────────────────────────────────────
function CM.InitProfiles()
    ConsumableMacroDB = ConsumableMacroDB or {}
    local root = ConsumableMacroDB

    if not root.profiles then
        -- One-time migration: the old account-wide data becomes profile "Default".
        local legacy = {}
        for k, v in pairs(root) do legacy[k] = v end
        _G.wipe(root)
        root.profiles = {}
        if next(legacy) then root.profiles[DEFAULT_PROFILE] = legacy end
    end
    root.dbVersion = DB_VERSION
    root.aliases   = root.aliases or {}

    local isNewChar = ConsumableMacroCharDB == nil
    ConsumableMacroCharDB = ConsumableMacroCharDB or {}
    local cdb = ConsumableMacroCharDB
    CM.charDb = cdb

    -- Existing characters (pre-profiles) join "Default"; new characters get their own.
    local name = cdb.profile
    if not name then
        name = (not isNewChar and root.profiles[DEFAULT_PROFILE]) and DEFAULT_PROFILE or CM.GetCharKey()
    end
    -- Profile deleted or renamed on another character -> follow the rename, else own profile.
    name = ResolveName(root, name) or CM.GetCharKey()
    root.profiles[name] = root.profiles[name] or {}
    local p = root.profiles[name]

    -- Seed fields that used to be per-character / nested (only where the profile has none).
    local ap = p.autoPotion
    if p.showReminder == nil then p.showReminder = cdb.showReminder end
    if p.autoPotionResetSeconds == nil then
        p.autoPotionResetSeconds = cdb.autoPotionResetSeconds or (ap and ap.resetSeconds)
    end
    if p.autoPotionOrder == nil then
        p.autoPotionOrder = cdb.autoPotionOrder or (ap and ap.order)
    end
    cdb.showReminder, cdb.autoPotionResetSeconds, cdb.autoPotionOrder = nil, nil, nil
    if ap then ap.resetSeconds = nil; ap.order = nil end

    cdb.profile = name
    CM.db = p
    CM.FillProfileDefaults(p)
end

-- ── Queries ────────────────────────────────────────────────────────────────────
function CM.GetProfileName()
    return CM.charDb and CM.charDb.profile
end

-- Sorted (case-insensitive) list of all profile names.
function CM.GetProfileNames()
    local names = {}
    for name in pairs(ConsumableMacroDB and ConsumableMacroDB.profiles or {}) do
        tinsert(names, name)
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

-- Exact match first, then case-insensitive. Returns the real name or nil.
function CM.FindProfile(name)
    local profiles = ConsumableMacroDB and ConsumableMacroDB.profiles
    if not profiles or not name then return nil end
    if profiles[name] then return name end
    local lower = name:lower()
    for existing in pairs(profiles) do
        if existing:lower() == lower then return existing end
    end
    return nil
end

-- ── Actions ────────────────────────────────────────────────────────────────────
-- Validates a new profile name; shows the error and returns nil if unusable.
local function CheckNewName(name)
    name = Trim(name)
    if name == "" then
        CM.ShowError(CM.L["PROFILE_ERR_EMPTY"])
        return nil
    end
    if ConsumableMacroDB.profiles[name] then
        CM.ShowError(CM.L["PROFILE_ERR_EXISTS"])
        return nil
    end
    return name
end

-- Refreshes the Options dropdown label/menu (deferred: safe inside menu callbacks).
function CM.RefreshProfileDropdown()
    local dd = CM.optionsFrame and CM.optionsFrame.profileDD
    if dd and dd.GenerateMenu then
        _G.RunNextFrame(function() dd:GenerateMenu() end)
    end
end

-- Everything that shows profile data is redrawn / rebuilt after a switch.
local function OnProfileChanged()
    CM.UpdateAllMacros()
    CM.UpdateReminderFrame()
    CM.RefreshRestockFrame()
    CM.RefreshList()
    if CM.optionsFrame and CM.optionsFrame:IsShown() then CM.RefreshOptionsFrame() end
    if CM.autoPotionFrame and CM.autoPotionFrame:IsShown() then CM.RefreshAutoPotionFrame() end
    CM.RefreshProfileDropdown()
end

-- Switches this character to an existing profile. Returns true on success.
function CM.SetProfile(name)
    local p = ConsumableMacroDB and ConsumableMacroDB.profiles[name]
    if not p or not CM.charDb then return false end
    if p == CM.db then return true end
    if InCombatLockdown() then
        CM.ShowError(CM.L["ERR_COMBAT"])
        return false
    end

    -- Store pending edits in the old profile, close windows bound to it.
    CM.CommitOptionsBoxes()
    CM.HideFrames({ "restockConfigFrame", "ieFrame", "resetFrame", "profileFrame" })

    CM.charDb.profile = name
    CM.db = p
    CM.FillProfileDefaults(p)
    OnProfileChanged()
    return true
end

-- Creates a profile (empty, or a copy of `copyFrom`). Returns its name or nil.
function CM.CreateProfile(name, copyFrom)
    name = CheckNewName(name)
    if not name then return nil end
    local src = copyFrom and ConsumableMacroDB.profiles[copyFrom]
    if src == CM.db then CM.CommitOptionsBoxes() end
    local p = src and DeepCopy(src) or {}
    CM.FillProfileDefaults(p)
    ConsumableMacroDB.profiles[name] = p
    CM.RefreshProfileDropdown()
    return name
end

function CM.RenameProfile(old, new)
    local root = ConsumableMacroDB
    if not root.profiles[old] then return false end
    if Trim(new) == old then return true end
    new = CheckNewName(new)
    if not new then return false end

    root.profiles[new] = root.profiles[old]
    root.profiles[old] = nil
    -- Other characters still point at the old name: keep them working via alias.
    for k, v in pairs(root.aliases) do
        if v == old then root.aliases[k] = new end
    end
    root.aliases[old] = new
    if CM.charDb and CM.charDb.profile == old then CM.charDb.profile = new end
    CM.RefreshProfileDropdown()
    return true
end

-- The active profile cannot be deleted.
function CM.DeleteProfile(name)
    local root = ConsumableMacroDB
    if not root.profiles[name] or name == CM.GetProfileName() then return false end
    root.profiles[name] = nil
    for k, v in pairs(root.aliases) do
        if k == name or v == name then root.aliases[k] = nil end
    end
    CM.RefreshProfileDropdown()
    return true
end
