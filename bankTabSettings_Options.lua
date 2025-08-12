--[[
Addon: bankTabSettings - Options Panel (Character-only)
Author: Zehel_Fenris
Interface: 110200
]]

local ADDON_NAME = ...

-- =====================================
-- SavedVariables helpers (account-wide)
-- =====================================
local DEFAULT_ICON = 134400 -- question mark

local function DefaultBlock()
  return {
    tabName = "",
    iconFileID = DEFAULT_ICON,
    expansion = "ANY", -- ANY | CURRENT | LEGACY
    filters = {
      Equipment=false, Consumables=false, ProfessionGoods=false,
      Reagents=false, Junk=false, IgnoreCleanup=false
    }
  }
end

local function EnsureDB()
  if type(bankTabSettingsDB) ~= "table" then bankTabSettingsDB = {} end
  if bankTabSettingsDB.debug == nil then bankTabSettingsDB.debug = false end -- default: OFF
  bankTabSettingsDB.characterBlocks = bankTabSettingsDB.characterBlocks or {}
  for i = 1, 6 do
    bankTabSettingsDB.characterBlocks[i] = bankTabSettingsDB.characterBlocks[i] or DefaultBlock()
  end
end

local function DB() EnsureDB(); return bankTabSettingsDB end

-- =====================================
-- Static popup (moved from core)
-- =====================================
StaticPopupDialogs["BANKTABSETTINGS_RELOAD_UI"] = {
  text = "bankTabSettings:\n\nReload the UI to apply your changes?\n\nAfter reload, open your bank once.",
  button1 = "Reload UI",
  button2 = CANCEL,
  OnAccept = function() ReloadUI() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

-- =====================================
-- Tiny UI helpers
-- =====================================
local function CreateLabel(parent, text, template)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
  fs:SetJustifyH("LEFT")
  fs:SetText(text)
  return fs
end

local function CreateCheckbox(parent, label, tooltip, get, set)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb.Text:SetText(label)
  cb.Text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  if tooltip then
    cb.tooltipText = label
    cb.tooltipRequirement = tooltip
  end
  cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  cb._refresh = function() cb:SetChecked(get()) end
  return cb
end

local function CreateEditBox(parent, width, get, set)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetAutoFocus(false)
  eb:SetWidth(width or 260)
  eb:SetHeight(24)
  eb:SetFontObject(ChatFontNormal)
  eb:SetScript("OnTextChanged", function(self) set(self:GetText() or "") end)
  eb._refresh = function() eb:SetText(get() or "") end
  return eb
end

local function CreateDropdown(parent, width, get, set)
  local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
  dd:SetWidth(width or 180)
  UIDropDownMenu_SetWidth(dd, width or 180)
  local function Refresh()
    UIDropDownMenu_Initialize(dd, function(_, level)
      local function add(text, value)
        local info = UIDropDownMenu_CreateInfo()
        info.text, info.value = text, value
        info.func = function() set(value); UIDropDownMenu_SetSelectedValue(dd, value) end
        info.checked = (get() == value)
        UIDropDownMenu_AddButton(info, level)
      end
      add("Any", "ANY")
      add("Current Only", "CURRENT")
      add("Legacy Only", "LEGACY")
    end)
    UIDropDownMenu_SetSelectedValue(dd, get())
  end
  dd._refresh = Refresh
  Refresh()
  return dd
end

-- =====================================
-- Accordion (single-open)
-- =====================================
local function CreateAccordion(parent, titleText, onToggle)
  local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  container:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })

  local header = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
  header:SetText(titleText)
  header:SetHeight(22)
  header:SetPoint("TOPLEFT", 6, -6)
  header:SetPoint("RIGHT", container, "RIGHT", -6, 0)

  local content = CreateFrame("Frame", nil, container)
  content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
  content:SetPoint("RIGHT", container, "RIGHT", -6, 0)
  content:Hide()

  local expanded = false
  local function SetExpanded(state)
    local want = state and true or false
    if expanded == want then return end
    expanded = want
    if expanded then content:Show() else content:Hide() end
    if onToggle then onToggle(container, expanded) end
  end
  container.SetExpanded = SetExpanded
  container.IsExpanded  = function() return expanded end
  container.GetContent  = function() return content end

  container._calcHeight = function()
    local paddingTopBottom = 12
    local h = header:GetHeight() + paddingTopBottom
    if expanded then
      local ch = content._height or content:GetHeight() or 0
      h = h + ch + 6
    end
    container:SetHeight(h)
    return h
  end

  header:SetScript("OnClick", function() SetExpanded(not expanded) end)
  return container
end

-- =====================================
-- Build per-tab content
-- =====================================
local DROPDOWN_HEIGHT = 26
local NAMEBOX_HEIGHT  = 24
local ICONROW_HEIGHT  = 28

local function GetBlock(index)
  local db = DB()
  return db.characterBlocks[index]
end

local function BuildTabContent(content, index)
  local block = GetBlock(index)
  local y = 0
  local padX = 10

  -- Name
  local nameLabel = CreateLabel(content, "Tab name:")
  nameLabel:SetPoint("TOPLEFT", content, "TOPLEFT", padX, -y)
  local nameBox = CreateEditBox(content, 260, function() return block.tabName end, function(v) block.tabName = v end)
  nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
  y = y + (nameLabel:GetStringHeight() or 12) + 4 + NAMEBOX_HEIGHT + 8

  -- Icon ID + preview + help
  local iconLabel = CreateLabel(content, "Icon file ID:")
  iconLabel:SetPoint("TOPLEFT", content, "TOPLEFT", padX, -y)

  local iconRow = CreateFrame("Frame", nil, content)
  iconRow:SetPoint("TOPLEFT", iconLabel, "BOTTOMLEFT", 0, -4)
  iconRow:SetPoint("RIGHT", content, "RIGHT", -padX, 0)
  iconRow:SetHeight(24)

  local iconPreview = iconRow:CreateTexture(nil, "OVERLAY")
  iconPreview:SetSize(24, 24)
  iconPreview:SetPoint("LEFT", iconRow, "LEFT", 0, 0)
  iconPreview:SetTexture(block.iconFileID or DEFAULT_ICON)

  local iconIdBox = CreateEditBox(iconRow, 120, function()
      return tostring(block.iconFileID or DEFAULT_ICON)
    end,
    function(v)
      v = tostring(v or ""):gsub("%D", "")
      local num = tonumber(v)
      if num and num > 0 then
        block.iconFileID = num
        iconPreview:SetTexture(num)
      end
    end
  )
  iconIdBox:SetPoint("LEFT", iconPreview, "RIGHT", 8, 0)

  local help = CreateLabel(content, [[Tip: Use an icon's File ID.
- On Wowhead, open an icon page and use the 'File ID'.
- In-game: /dump select(5, GetItemInfoInstant(itemID))
- 134400 is the default question mark.]], "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", iconRow, "BOTTOMLEFT", 0, -4)
  help:SetWidth(400)
  help:SetJustifyH("LEFT")
  help:SetJustifyV("TOP")

  y = y + (iconLabel:GetStringHeight() or 12) + 4 + ICONROW_HEIGHT + (help:GetStringHeight() or 24) + 8

  -- Expansion
  local expLabel = CreateLabel(content, "Expansion filter:")
  expLabel:SetPoint("TOPLEFT", content, "TOPLEFT", padX, -y)
  local dd = CreateDropdown(content, 180,
    function() return block.expansion or "ANY" end,
    function(v) block.expansion = v end)
  dd:SetPoint("TOPLEFT", expLabel, "BOTTOMLEFT", -14, -2)
  y = y + (expLabel:GetStringHeight() or 12) + 2 + DROPDOWN_HEIGHT + 8

  -- Filters
  local filtersLabel = CreateLabel(content, "Categories:")
  filtersLabel:SetPoint("TOPLEFT", content, "TOPLEFT", padX, -y)
  y = y + (filtersLabel:GetStringHeight() or 12) + 4

  local filterArea = CreateFrame("Frame", nil, content)
  filterArea:SetPoint("TOPLEFT", content, "TOPLEFT", padX, -y)
  filterArea:SetPoint("RIGHT", content, "RIGHT", -padX, 0)

  local function g(k) return function() return block.filters[k] end end
  local function s(k) return function(v) block.filters[k] = v end end

  local col1x, col2x = 0, 190
  local rowGap = 6

  local cbEquip  = CreateCheckbox(filterArea, "Equipment", nil, g("Equipment"), s("Equipment"))
  cbEquip:SetPoint("TOPLEFT", col1x, 0)

  local cbCons   = CreateCheckbox(filterArea, "Consumables", nil, g("Consumables"), s("Consumables"))
  cbCons:SetPoint("TOPLEFT", cbEquip, "BOTTOMLEFT", 0, -rowGap)

  local cbTrade  = CreateCheckbox(filterArea, "Profession Goods", nil, g("ProfessionGoods"), s("ProfessionGoods"))
  cbTrade:SetPoint("TOPLEFT", cbCons, "BOTTOMLEFT", 0, -rowGap)

  local cbReag   = CreateCheckbox(filterArea, "Reagents", nil, g("Reagents"), s("Reagents"))
  cbReag:SetPoint("TOPLEFT", col2x, 0)

  local cbJunk   = CreateCheckbox(filterArea, "Junk", nil, g("Junk"), s("Junk"))
  cbJunk:SetPoint("TOPLEFT", cbReag, "BOTTOMLEFT", 0, -rowGap)

  local cbIgnore = CreateCheckbox(filterArea, "Ignore this tab for cleanup", nil, g("IgnoreCleanup"), s("IgnoreCleanup"))
  cbIgnore:SetPoint("TOPLEFT", cbJunk, "BOTTOMLEFT", 0, -rowGap)

  local cbH = cbEquip:GetHeight() or 22
  local rows = 3
  local filterHeight = (cbH * rows) + (rowGap * (rows - 1))
  filterArea:SetHeight(filterHeight)

  content._refresh = function()
    nameBox:_refresh()
    dd:_refresh()
    iconPreview:SetTexture(block.iconFileID or DEFAULT_ICON)
    iconIdBox:_refresh()
    cbEquip:_refresh(); cbCons:_refresh(); cbTrade:_refresh()
    cbReag:_refresh();  cbJunk:_refresh(); cbIgnore:_refresh()
  end

  local total = y + filterHeight + 10
  content._height = total
  content:SetHeight(total)
end

-- =====================================
-- Options panel
-- =====================================
local function BuildOptionsPanel()
  EnsureDB()

  local root = CreateFrame("Frame")
  root.name = "bankTabSettings"

  -- ScrollFrame
  local sf = CreateFrame("ScrollFrame", nil, root, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 0, -4)
  sf:SetPoint("BOTTOMRIGHT", -28, 4)

  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(650, 2000)
  sf:SetScrollChild(content)

  local header = CreateLabel(content, "bankTabSettings", "GameFontNormalHuge")
  header:SetPoint("TOPLEFT", 16, -16)

  -- Debug toggle
  local debugCB = CreateCheckbox(content, "Enable debug logging",
    "Print detailed events in chat. You can also type /tabsettings debug to toggle.",
    function() return bankTabSettingsDB and bankTabSettingsDB.debug end,
    function(v) bankTabSettingsDB.debug = not not v end)
  debugCB:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)

  -- Accordions
  local accordions = {}
  accordions._char = {}
  for i = 1, 6 do
    local acc = CreateAccordion(content, ("Character Tab %d"):format(i), function(selfAcc, expanded)
      if expanded then
        for _, other in ipairs(accordions._char) do
          if other ~= selfAcc and other.IsExpanded() then other.SetExpanded(false) end
        end
      end
      -- Relayout after open/close
      if content._relayout then content._relayout() end
    end)
    BuildTabContent(acc.GetContent(), i)
    table.insert(accordions._char, acc)
  end

  -- Apply button (opens reload popup)
  local applyBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
  applyBtn:SetText("Apply to Bank Now")
  applyBtn:SetSize(180, 24)
  applyBtn:SetScript("OnClick", function()
    if bankTabSettings_ApplyNow then
      bankTabSettings_ApplyNow() -- will show popup from core
    else
      StaticPopup_Show("BANKTABSETTINGS_RELOAD_UI")
    end
  end)

  -- Relayout
  content._relayout = function()
    local y = 16 + (header:GetStringHeight() or 20) + 8 + (debugCB:GetHeight() or 20) + 12

    if not content._charTitle then
      content._charTitle = CreateLabel(content, "Character Tabs", "GameFontNormalLarge")
      content._charTitle:SetTextColor(1, 0.85, 0)
    end
    content._charTitle:ClearAllPoints()
    content._charTitle:SetPoint("TOPLEFT", 12, -y)
    y = y + (content._charTitle:GetStringHeight() or 20) + 6

    for _, acc in ipairs(accordions._char) do
      acc:ClearAllPoints()
      acc:SetPoint("TOPLEFT", 12, -y)
      acc:SetPoint("RIGHT", content, "RIGHT", -12, 0)
      y = y + acc._calcHeight() + 8
    end

    applyBtn:ClearAllPoints()
    applyBtn:SetPoint("TOPLEFT", 12, -y)
    y = y + applyBtn:GetHeight() + 12

    content:SetHeight(y + 20)
  end

  -- Default: all accordions closed
  for _, acc in ipairs(accordions._char) do acc.SetExpanded(false) end
  content._relayout()

  root:SetScript("OnShow", function()
    EnsureDB()
    debugCB:SetChecked(bankTabSettingsDB and bankTabSettingsDB.debug)
    for _, acc in ipairs(accordions._char) do
      local inner = acc.GetContent()
      if inner._refresh then inner._refresh() end
      inner._height = math.max(inner._height or 0, inner:GetHeight() or 0)
    end
    content._relayout()
  end)

  if Settings and Settings.RegisterCanvasLayoutCategory then
    local cat = Settings.RegisterCanvasLayoutCategory(root, root.name)
    cat.ID = root.name
    Settings.RegisterAddOnCategory(cat)
  else
    root:Hide()
    InterfaceOptions_AddCategory(root)
  end
end

-- Build once on login or addon load
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and arg1 == ADDON_NAME) then
    if not _G.bankTabSettings_OptionsBuilt then
      _G.bankTabSettings_OptionsBuilt = true
      BuildOptionsPanel()
    end
  end
end)

-- =====================================
-- Slash: /tabsettings (no 'apply')
-- =====================================
SLASH_BANKTABSETTINGS1 = "/tabsettings"
SlashCmdList.BANKTABSETTINGS = function(msg)
  msg = (msg or ""):gsub("^%s+"," "):gsub("%s+$", ""):lower()
  if msg:match("^debug") then
    local arg = msg:match("^debug%s+(%S+)")
    if arg == "on" then
      bankTabSettingsDB.debug = true
    elseif arg == "off" then
      bankTabSettingsDB.debug = false
    else
      bankTabSettingsDB.debug = not bankTabSettingsDB.debug
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99bankTabSettings|r: Debug "..(bankTabSettingsDB.debug and "ENABLED" or "disabled"))
  else
    if Settings and Settings.OpenToCategory then
      Settings.OpenToCategory("bankTabSettings")
    elseif InterfaceOptionsFrame_OpenToCategory then
      InterfaceOptionsFrame_OpenToCategory("bankTabSettings")
    end
  end
end
