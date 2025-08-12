--[[
Addon: bankTabSettings
Author: Zehel_Fenris
Interface: 110200
]]

local ADDON_NAME = ...
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
f:RegisterEvent("BANKFRAME_OPENED")

-- ===== Constants =====
local DEFAULT_ICON  = 134400 -- question mark
local BANK_TYPE     = (Enum and Enum.BankType and Enum.BankType.Character) or 0
local TAB_IDS       = { 6, 7, 8, 9, 10, 11 } -- hardcoded Character bank tabIDs

-- ===== SavedVariables =====
local function EnsureDB()
  if type(bankTabSettingsDB) ~= "table" then bankTabSettingsDB = {} end
  if bankTabSettingsDB.debug == nil then bankTabSettingsDB.debug = false end
  bankTabSettingsDB.characterBlocks = bankTabSettingsDB.characterBlocks or {}
  for i = 1, 6 do
    bankTabSettingsDB.characterBlocks[i] = bankTabSettingsDB.characterBlocks[i] or {
      tabName    = "",
      iconFileID = DEFAULT_ICON,
      expansion  = "ANY", -- ANY | CURRENT | LEGACY
      filters = {
        Equipment=false, Consumables=false, ProfessionGoods=false,
        Reagents=false, Junk=false, IgnoreCleanup=false,
      },
    }
  end
end

-- ===== Debug =====
local function isDebug() return bankTabSettingsDB and bankTabSettingsDB.debug end
local function dbg(fmt, ...)
  if not isDebug() then return end
  local ok, msg = pcall(string.format, fmt, ...)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99bankTabSettings|r: "..(ok and msg or tostring(fmt)))
end

-- ===== Flags =====
local FLAGS = {
  Nothing              = 0,
  DisableAutoSort      = 1,
  ClassEquipment       = 2,
  ClassConsumables     = 4,
  ClassProfessionGoods = 8,
  ClassJunk            = 16,
  ClassQuestItems      = 32,  -- unused by our UI
  ExcludeJunkSell      = 64,  -- unused by our UI
  ClassReagents        = 128,
  ExpansionCurrent     = 256,
  ExpansionLegacy      = 512,
}
local function BuildDepositFlags(b)
  local f = FLAGS.Nothing
  local fl = b.filters or {}
  if fl.Equipment       then f = f + FLAGS.ClassEquipment end
  if fl.Consumables     then f = f + FLAGS.ClassConsumables end
  if fl.ProfessionGoods then f = f + FLAGS.ClassProfessionGoods end
  if fl.Junk            then f = f + FLAGS.ClassJunk end
  if fl.Reagents        then f = f + FLAGS.ClassReagents end
  if fl.IgnoreCleanup   then f = f + FLAGS.DisableAutoSort end
  if b.expansion == "CURRENT" then
    f = f + FLAGS.ExpansionCurrent
  elseif b.expansion == "LEGACY" then
    f = f + FLAGS.ExpansionLegacy
  end
  return f
end

-- ===== Update wrapper (quiet: only log errors) =====
local function CallUpdate(tabID, name, iconFileID, flags)
  if not (C_Bank and C_Bank.UpdateBankTabSettings) then
    dbg("ERROR: C_Bank.UpdateBankTabSettings API missing")
    return false, "API missing"
  end
  local ok, err = pcall(C_Bank.UpdateBankTabSettings, BANK_TYPE, tabID, name, iconFileID, flags)
  if not ok then
    dbg("ERROR updating tabID %s -> %s", tostring(tabID), tostring(err))
  end
  return ok, err
end

-- ===== Apply (always push to 6..11, sequential with delay + final retry for tab 11) =====
local function DefaultTabName(i) return ("Character Tab %d"):format(i) end

local function ApplyHardcoded()
  EnsureDB()
  local i = 1
  local function step()
    if i > 6 then return end
    local block = bankTabSettingsDB.characterBlocks[i]
    local tabID = TAB_IDS[i]
    local name  = (block.tabName ~= "" and block.tabName) or DefaultTabName(i)
    local icon  = block.iconFileID or DEFAULT_ICON
    local flags = BuildDepositFlags(block)

    CallUpdate(tabID, name, icon, flags)

    i = i + 1
    if i <= 6 then
      C_Timer.After(1.35, step) -- slight delay before next tab
    end
  end

  -- Start sequence after a short delay so bank data is fully ready
  C_Timer.After(0.15, step)

  -- One extra safety retry for the last tab (tabID 11) after the sequence finishes
  C_Timer.After(0.15 + (0.35 * 6) + 0.30, function()
    local block = bankTabSettingsDB.characterBlocks[6]
    if block then
      local tabID = TAB_IDS[6]
      local name  = (block.tabName ~= "" and block.tabName) or DefaultTabName(6)
      local icon  = block.iconFileID or DEFAULT_ICON
      local flags = BuildDepositFlags(block)
      CallUpdate(tabID, name, icon, flags)
    end
  end)

  -- Compact summary after all attempts (printed only if debug is on)
  C_Timer.After(0.15 + (0.35 * 6) + 0.30 + 0.10, function()
    dbg("Applied settings to tabs 6–11.")
  end)
end

-- ===== Events =====
local function OnAddonLoaded(name)
  if name ~= ADDON_NAME then return end
  EnsureDB()
  dbg("ADDON_LOADED: %s", tostring(name))
end

f:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    OnAddonLoaded(...)
  elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
    local it = ...
    local banker = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.Banker
    if it == banker then
      C_Timer.After(0.3, ApplyHardcoded)
    end
  elseif event == "BANKFRAME_OPENED" then
    C_Timer.After(0.3, ApplyHardcoded)
  end
end)

-- Exposed for options button
function bankTabSettings_ApplyNow()
  -- Popup is now owned by the Options file. If not present, fall back to ReloadUI.
  if StaticPopup_Show and StaticPopupDialogs and StaticPopupDialogs["BANKTABSETTINGS_RELOAD_UI"] then
    StaticPopup_Show("BANKTABSETTINGS_RELOAD_UI")
  else
    ReloadUI()
  end
end
