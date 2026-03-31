--[[
  Main flow: main, choose_mc, select_config, initHdd, open, choose_load.
  run*(s, pad) where s has .common, .font, .drawMode, .drawListRow and state vars.
  Strings: try strings.lua (cwd override) then scripts/lang/strings_XX.lua. If CWD override, L1/R1 lang cycle is disabled.
  (Use loadfile for the optional CWD file: with VFS, pcall(dofile, path) can fail for paths not in VFS; loadfile returns nil if missing.)
]]

local function tryLoadStrings(path)
  local chunk = loadfile(path)
  if not chunk then return nil end
  local ok, t = pcall(chunk)
  return (ok and type(t) == "table") and t or nil
end

local startupDefaultLanguage = (_G.CONFIG_UI and _G.CONFIG_UI.startupDefaultLanguage) or nil

local strings = tryLoadStrings("strings.lua")
local cwdOverride = (strings ~= nil)
if not cwdOverride then
  if type(startupDefaultLanguage) == "string" and startupDefaultLanguage ~= "" then
    strings = tryLoadStrings("scripts/lang/strings_" .. startupDefaultLanguage .. ".lua")
  end
  if not strings then
    strings = dofile("scripts/lang/strings_en.lua")
  end
end
strings = strings or {}
_G.CONFIG_UI.strings = strings
_G.CONFIG_UI.langCycleDisabled = cwdOverride

local function defaultLanguageDisplayName(code)
  local names = {
    de = "Deutsch",
    en = "English",
    es = "Espanol",
    fr = "Francais",
  }
  return names[code] or ((type(code) == "string" and code ~= "") and code:upper() or "Language")
end

local function getLanguageCodeFromFile(file)
  return type(file) == "string" and file:match("^strings_(%w+)%.lua$") or nil
end

local function buildLanguageDisplayNames(files)
  local names = {}
  for i, file in ipairs(files or {}) do
    local code = getLanguageCodeFromFile(file)
    local displayName = defaultLanguageDisplayName(code)
    local langStrings = tryLoadStrings("scripts/lang/" .. file)
    if langStrings and type(langStrings.language_name) == "string" and langStrings.language_name ~= "" then
      displayName = langStrings.language_name
    elseif langStrings and type(langStrings.main) == "table" and type(langStrings.main.language_name) == "string" and
        langStrings.main.language_name ~= "" then
      displayName = langStrings.main.language_name
    end
    names[i] = displayName
  end
  return names
end

-- Build list of lang files (scripts/lang/strings_*.lua) for L1/R1 cycle; only when not CWD override.
if not cwdOverride and System and System.listDirectory then
  local list = {}
  local okList, listRaw = pcall(System.listDirectory, "/scripts/lang")
  if okList and type(listRaw) == "table" then
    for i = 1, #listRaw do
      local e = listRaw[i]
      local name = (e and e.name) or ""
      if name:match("^strings_(%w+)%.lua$") and not (e and e.directory) then
        table.insert(list, name)
      end
    end
    table.sort(list)
  end
  _G.CONFIG_UI.langFiles = list
  _G.CONFIG_UI.langDisplayNames = buildLanguageDisplayNames(list)
  local idx = 1
  local foundTarget = false
  local targetFile = nil
  if type(startupDefaultLanguage) == "string" and startupDefaultLanguage ~= "" then
    targetFile = "strings_" .. startupDefaultLanguage .. ".lua"
  end
  if targetFile then
    for i, f in ipairs(list) do
      if f == targetFile then
        idx = i
        foundTarget = true
        break
      end
    end
  end
  if not foundTarget then
    for i, f in ipairs(list) do
      if f == "strings_en.lua" then
        idx = i; break
      end
    end
  end
  _G.CONFIG_UI.langIndex = idx
else
  _G.CONFIG_UI.langFiles = nil
  _G.CONFIG_UI.langIndex = nil
  _G.CONFIG_UI.langDisplayNames = nil
end

local C = _G.CONFIG_UI
local common = C.common
local config_parse = C.config_parse

local PAD_UP, PAD_DOWN, PAD_CROSS, PAD_CIRCLE, PAD_START, PAD_SQUARE, PAD_TRIANGLE = common.PAD_UP, common.PAD_DOWN,
    common.PAD_CROSS, common.PAD_CIRCLE, common.PAD_START, common.PAD_SQUARE, common.PAD_TRIANGLE

local function openDbg(...)
  if _G and _G.CONFIG_UI_OPEN_DEBUG == false then return end
  local parts = {}
  for i = 1, select("#", ...) do
    parts[#parts + 1] = tostring(select(i, ...))
  end
  print("[open] " .. table.concat(parts, " "))
end

local function countTrue(list)
  local n = 0
  for i = 1, #(list or {}) do
    if list[i] then n = n + 1 end
  end
  return n
end

local function findHintLabel(items, pad, fallback)
  for _, item in ipairs(items or {}) do
    if item.pad == pad and item.label and item.label ~= "" then
      return item.label
    end
  end
  return fallback
end

local function getLanguageDisplayName(idx)
  local names = C.langDisplayNames
  if names and names[idx] and names[idx] ~= "" then
    return names[idx]
  end
  local code = getLanguageCodeFromFile(C.langFiles and C.langFiles[idx] or nil)
  return defaultLanguageDisplayName(code)
end

local function hasLanguageChoices()
  return not C.langCycleDisabled and C.langFiles and #C.langFiles > 1
end

local function getLanguageHintLabel(main_str)
  local baseHint = main_str.main_hint_items_with_lang or main_str.main_hint_items or {}
  local raw = findHintLabel(baseHint, "L1", findHintLabel(baseHint, "R1", "Language"))
  local cleaned = tostring(raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
  cleaned = cleaned:gsub("%s*[%+%-]$", "")
  if cleaned == "" then cleaned = "Language" end
  return cleaned
end

local function getSettingsHintLabel(main_str)
  local raw = main_str.main_settings or "Settings"
  local cleaned = tostring(raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if cleaned == "" then cleaned = "Settings" end
  return cleaned
end

local function getCreditsHintLabel(main_str)
  local baseHint = main_str.main_hint_items or {}
  local raw = main_str.main_credits or findHintLabel(baseHint, "triangle", "Credits")
  local cleaned = tostring(raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if cleaned == "" then cleaned = "Credits" end
  return cleaned
end

local function buildMainCreditsLines(main_str)
  return {
    main_str.main_credits_built_using or "Built Using:",
    "-Enceladus",
    main_str.main_credits_thanks_to or "Thanks to:",
    "-pcm720",
    "-R3Z3N",
    "-Berion",
    main_str.main_credits_translators or "Translators:",
    "-VizoR: Spanish",
    "-nuno: Portugese",
  }
end

local CREDITS_HEADING_BLUE = Color.new(0x36, 0x51, 0x72, 0x80)

local function buildMainBaseHintItems(main_str)
  local baseHint = main_str.main_hint_items or {}
  local enterLabel = findHintLabel(baseHint, "cross", "Enter")
  local exitLabel = findHintLabel(baseHint, "circle", findHintLabel(baseHint, "start", "Exit"))
  local settingsLabel = getSettingsHintLabel(main_str)
  local creditsLabel = getCreditsHintLabel(main_str)
  local out = {
    { pad = "cross", label = enterLabel, row = 1 },
    { pad = "square", label = settingsLabel, row = 1 },
    { pad = "circle", label = exitLabel, row = 1 },
  }
  table.insert(out, #out, { pad = "triangle", label = creditsLabel, row = 1 })
  return out
end

local function buildMainLanguageOverlayHintItems(main_str)
  local base = main_str.cross_select_circle_back_items or {}
  local selectLabel = findHintLabel(base, "cross", "Enter")
  local cancelLabel = (strings and strings.menu_entries and strings.menu_entries.cancel_label) or
      findHintLabel(base, "circle", "Cancel")
  local languageLabel = getLanguageHintLabel(main_str)
  return {
    { pad = "cross", label = selectLabel, row = 1 },
    { pad = "square", label = languageLabel, row = 1 },
    { pad = "circle", label = cancelLabel, row = 1 },
  }
end

local function buildMainCreditsOverlayHintItems(main_str)
  local base = main_str.cross_select_circle_back_items or {}
  local cancelLabel = (strings and strings.menu_entries and strings.menu_entries.cancel_label) or
      findHintLabel(base, "circle", "Back")
  local creditsLabel = getCreditsHintLabel(main_str)
  return {
    { pad = "triangle", label = creditsLabel, row = 1 },
    { pad = "circle", label = cancelLabel, row = 1 },
  }
end

local function clearPathPickerState(s)
  s.bootKey = nil
  s.pathPickerBootKey = nil
  s.pathPickerReturnState = nil
  s.pathPickerTarget = nil
  s.pathPickerFileExts = nil
  s.pathPickerLockedDevice = nil
  s.pathPickerLockedDeviceStarted = nil
end

local function clearLoadChoiceState(s)
  s.loadChoices = nil
  s.loadAllowCreate = nil
  s.loadPathExists = nil
  s.loadReturnState = nil
end

local function detectMainCnfFilter()
  local configured = (_G.CONFIG_UI and _G.CONFIG_UI.startupMainFilter) or nil
  if type(configured) == "table" then
    local out = {}
    local hasAny = false
    for id, enabled in pairs(configured) do
      if enabled == true or enabled == false then
        out[id] = enabled
        hasAny = true
      end
    end
    if hasAny then
      return out
    end
    return nil
  end
  return nil
end

local MAIN_CNF_FILTER = detectMainCnfFilter()

local MAIN_SHOW_KEY_TO_ID = {
  show_freemcboot = "freemcboot",
  show_freehddboot = "freehddboot",
  show_osdmenu = "osdmenu",
  show_osdmenu_mbr = "mbr",
  show_hosdmenu = "hosdmenu",
  show_ps2bbl = "ps2bbl",
  show_psxbbl = "psxbbl",
}

local MAIN_FILTER_KEY_ORDER = {
  "freemcboot",
  "freehddboot",
  "osdmenu",
  "mbr",
  "hosdmenu",
  "ps2bbl",
  "psxbbl",
}

local function parseMainFilterEnabled(value)
  if value == true then return true end
  if value == false then return false end
  local s = tostring(value or ""):lower()
  if s == "1" or s == "true" or s == "yes" or s == "on" then return true end
  if s == "0" or s == "false" or s == "no" or s == "off" then return false end
  return nil
end

local function getMainFilterBuildKey()
  if type(MAIN_CNF_FILTER) ~= "table" then
    return "all"
  end
  local parts = {}
  for i = 1, #MAIN_FILTER_KEY_ORDER do
    local id = MAIN_FILTER_KEY_ORDER[i]
    local enabled = MAIN_CNF_FILTER[id]
    if enabled == true then
      parts[#parts + 1] = id .. "=1"
    elseif enabled == false then
      parts[#parts + 1] = id .. "=0"
    end
  end
  if #parts == 0 then
    return "all"
  end
  return table.concat(parts, ";")
end

local function setMainFilterFromShowKey(rawKey, value)
  local showKey = tostring(rawKey or ""):lower()
  local id = MAIN_SHOW_KEY_TO_ID[showKey]
  if not id then return false end
  local enabled = parseMainFilterEnabled(value)
  if enabled == nil then return false end
  if type(MAIN_CNF_FILTER) ~= "table" then
    MAIN_CNF_FILTER = {}
  end
  MAIN_CNF_FILTER[id] = enabled
  return true
end

C.setMainFilterFromShowKey = setMainFilterFromShowKey

local function includeMainEntry(id)
  if MAIN_CNF_FILTER == nil then return true end
  local enabled = MAIN_CNF_FILTER[id]
  if enabled == nil then
    return true
  end
  return enabled == true
end

local function buildMainEntries(main_str)
  local out = {}
  local function addEntry(entry)
    if includeMainEntry(entry.id) then
      out[#out + 1] = entry
    end
  end

  addEntry({
    id = "freemcboot",
    label = main_str.main_freemcboot or "FreeMCBoot",
    logoKey = "freemcboot",
    context = "freemcboot",
    fileType = "freemcboot_cnf",
    state = "select_config",
  })
  addEntry({
    id = "freehddboot",
    label = main_str.main_freehddboot or "FreeHDBoot",
    logoKey = "freehdboot",
    context = "freehddboot",
    fileType = "freemcboot_cnf",
    state = "select_config",
  })
  addEntry({
    id = "osdmenu",
    label = main_str.main_osdmenu or "OSDMenu",
    logoKey = "osdmenu",
    context = "osdmenu",
    fileType = "osdmenu_cnf",
    state = "choose_mc",
  })
  addEntry({
    id = "mbr",
    label = main_str.main_osdmenu_mbr or "OSDMenu MBR",
    logoKey = "osdmenu_mbr",
    context = "mbr",
    fileType = "osdmbr_cnf",
    state = "open",
  })
  addEntry({
    id = "hosdmenu",
    label = main_str.main_hosdmenu or "HOSDMenu",
    logoKey = "hosdmenu",
    context = "hosdmenu",
    fileType = "osdmenu_cnf",
    state = "open",
  })
  if C.config_options and C.config_options.isEgsmUiEnabled and C.config_options.isEgsmUiEnabled() then
    addEntry({
      id = "egsm",
      label = main_str.main_egsm or "eGSM",
      logoKey = "osdmenu",
      context = "osdmenu",
      fileType = "osdgsm_cnf",
      state = "choose_mc",
    })
  end
  addEntry({
    id = "ps2bbl",
    label = main_str.main_ps2bbl_mc or "PS2BBL",
    logoKey = "ps2bbl",
    context = "ps2bbl",
    fileType = "ps2bbl_ini",
    state = "select_config",
  })
  addEntry({
    id = "psxbbl",
    label = main_str.main_psxbbl_mc or "PSXBBL",
    logoKey = "psxbbl",
    context = "psxbbl",
    fileType = "psxbbl_ini",
    state = "select_config",
  })

  return out
end

local function buildMainChoices(main_str)
  local entries = buildMainEntries(main_str)
  local out = {}
  for i = 1, #entries do
    out[i] = entries[i].label
  end
  return out, entries
end

local function applyLanguageFileIndex(s, idx)
  local files = C.langFiles
  if not files or #files < 1 then return false end
  local target = common.clampListSelection(idx or (C.langIndex or 1), #files)
  local okLoad, newStrings = pcall(dofile, "scripts/lang/" .. files[target])
  if okLoad and newStrings and type(newStrings) == "table" then
    C.strings = newStrings
    C.langIndex = target
    if _G.CONFIG_UI then
      _G.CONFIG_UI.strings = newStrings
      local code = getLanguageCodeFromFile(files[target])
      if type(code) == "string" and code ~= "" then
        _G.CONFIG_UI.startupDefaultLanguage = code
      end
    end
    if s then
      local labels, entries = buildMainChoices(newStrings.main or {})
      s.main = labels
      s.mainEntries = entries
      s.mainBuildKey = nil
    end
    return true
  end
  return false
end

local function applyLanguageIndex(s, idx)
  if not hasLanguageChoices() then return false end
  return applyLanguageFileIndex(s, idx)
end

local function applyLanguageCode(s, code)
  local targetCode = tostring(code or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if targetCode == "" then return false end
  local files = C.langFiles
  if not files or #files < 1 then return false end
  for i = 1, #files do
    local fileCode = getLanguageCodeFromFile(files[i])
    if type(fileCode) == "string" and fileCode:lower() == targetCode then
      return applyLanguageFileIndex(s, i)
    end
  end
  return false
end

C.applyLanguageCode = applyLanguageCode

local function isBblContext(context)
  return context == "ps2bbl" or context == "psxbbl"
end

local function nextStateAfterMcSelection(s)
  if isBblContext(s.context) then return "select_config" end
  if s.context == "osdmenu" then return "select_config" end
  return "open"
end

local function getOpenParentState(s)
  if isBblContext(s.context) then
    return "select_config"
  end
  if s.context == "freemcboot" or s.context == "freehddboot" then
    if s.fileType == "freemcboot_cnf" then
      return "select_config"
    end
  end
  if s.context == "osdmenu" then
    if s.fileType == "osdmenu_cnf" or s.fileType == "osdgsm_cnf" then
      return "select_config"
    end
  end
  return "main"
end

local function getSelectConfigSelTable(s)
  if type(s.selectConfigSelByContext) ~= "table" then
    s.selectConfigSelByContext = {}
  end
  return s.selectConfigSelByContext
end

local function getSelectConfigSel(s)
  local t = getSelectConfigSelTable(s)
  local key = s.context or "__none__"
  local sel = t[key]
  if type(sel) ~= "number" then return 1 end
  return math.floor(sel)
end

local function setSelectConfigSel(s, sel)
  local t = getSelectConfigSelTable(s)
  local key = s.context or "__none__"
  t[key] = sel
end

local function resolveContextFileType(s)
  if s.context == "ps2bbl" then return "ps2bbl_ini" end
  if s.context == "psxbbl" then return "psxbbl_ini" end
  return nil
end

local function resolveIniFileType(s)
  local ft = resolveContextFileType(s)
  if ft then return ft end
  if s.fileType == "ps2bbl_ini" or s.fileType == "psxbbl_ini" then
    return s.fileType
  end
  return nil
end

local function initEmptyLinesForFileType(s, reason)
  s.lines = config_parse.parse("")
  if s.fileType == "freemcboot_cnf" and C.config_options.getFreemcbootDefaults then
    for k, v in pairs(C.config_options.getFreemcbootDefaults()) do config_parse.set(s.lines, k, v) end
  elseif s.fileType == "osdmenu_cnf" and C.config_options.getOsdmenuDefaults then
    for k, v in pairs(C.config_options.getOsdmenuDefaults()) do config_parse.set(s.lines, k, v) end
  elseif s.fileType == "r3configurator_cnf" and C.config_options.r3configurator_cnf then
    for i = 1, #C.config_options.r3configurator_cnf do
      local o = C.config_options.r3configurator_cnf[i]
      if o and o.key and o.key:sub(1, 1) ~= "_" and o.default ~= nil then
        config_parse.set(s.lines, o.key, tostring(o.default))
      end
    end
  end
  openDbg("init empty lines", "fileType=" .. tostring(s.fileType), "reason=" .. tostring(reason),
    "lineCount=" .. tostring(#(s.lines or {})))
end

local function getPathModuleType(path)
  if not path or path == "" then return nil end
  local p = tostring(path)
  if p:match("^massX:") then return "mx4sio" end
  if p:match("^mass%d*:") then return "usb" end
  if p:match("^mmce%d:") then return "mmce" end
  if p:match("^hdd%d:") or p:match("^pfs%d:/") then return "hdd" end
  return nil
end

local function mapPartitionPathToMountedPfs(path)
  if not path then return nil, nil end
  local raw = tostring(path)
  local part, rest = raw:match("^(hdd%d:[^:]+):pfs:(.*)$")
  if not part then
    -- Accept FMCB-style partition path (hdd0:__sysconf/dir/file) in addition to :pfs: form.
    part, rest = raw:match("^(hdd%d:[^/:]+)(/.*)$")
  end
  if not part then return nil, nil end
  if not rest or rest == "" then rest = "/" end
  if rest:sub(1, 1) ~= "/" then rest = "/" .. rest end
  return part, "pfs0:" .. rest
end

local function beginPathAccess(path)
  local moduleType = getPathModuleType(path)
  if moduleType and System and System.loadModules then
    pcall(System.loadModules, moduleType)
  end
  local part, mapped = mapPartitionPathToMountedPfs(path)
  if part and mapped then
    local mounted = nil
    if System and System.fileXioMount then
      pcall(System.fileXioMount, "pfs0:", part)
      mounted = "pfs0:"
    end
    return mounted, mapped
  end
  local mounted = nil
  if path and path:match("^pfs0:/") and System and System.fileXioMount then
    pcall(System.fileXioMount, "pfs0:", "hdd0:__sysconf")
    mounted = "pfs0:"
  end
  return mounted, path
end

local function endPathAccess(mounted)
  if mounted and System and System.fileXioUmount then
    pcall(System.fileXioUmount, mounted)
  end
end

local function pathExists(path)
  local mounted, accessPath = beginPathAccess(path)
  local ok = common.tryOpen(accessPath or path)
  endPathAccess(mounted)
  openDbg("exists", "path=" .. tostring(path), "accessPath=" .. tostring(accessPath or path), "result=" .. tostring(ok))
  return ok
end

local function findExistingPathsWithDeviceAccess(locations)
  local out = {}
  for _, p in ipairs(locations or {}) do
    if p and p ~= "" and pathExists(p) then
      out[#out + 1] = p
    end
  end
  return out
end

local function loadLinesWithDeviceAccess(path)
  local mounted, accessPath = beginPathAccess(path)
  openDbg("load begin", "path=" .. tostring(path), "accessPath=" .. tostring(accessPath or path),
    "mounted=" .. tostring(mounted))
  local ok, lines, err = pcall(config_parse.load, accessPath or path)
  endPathAccess(mounted)
  if ok and lines then
    openDbg("load success", "path=" .. tostring(path), "entries=" .. tostring(#(lines or {})))
    return lines
  end
  if ok then
    openDbg("load failed", "path=" .. tostring(path), "error=" .. tostring(err))
    return nil, err
  end
  openDbg("load exception", "path=" .. tostring(path), "error=" .. tostring(lines))
  return nil, lines
end

local function setStateAfterLoad(s)
  if common.setCleanConfigSnapshot then
    common.setCleanConfigSnapshot(s, { needsInitialSave = false })
  else
    s.configModified = false
    s.configNeedsInitialSave = false
  end
  local isCategorized = (s.fileType == "osdmenu_cnf" or s.fileType == "freemcboot_cnf" or s.fileType == "ps2bbl_ini" or
      s.fileType == "psxbbl_ini")
  if s.fileType == "osdgsm_cnf" then
    s.state = "egsm_editor"
    s.egsmSel, s.egsmScroll = 1, 0
  else
    s.state = "editor"
    s.editorCategoryIdx = isCategorized and 0 or nil
    s.optList = isCategorized and nil or C.config_options[s.fileType]
    s.optSel, s.optScroll = 1, 0
    if not s.optList then s.optList = {} end
  end
  if s.fileType ~= "osdmbr_cnf" then clearPathPickerState(s) end
end

local function markNewInMemoryConfigState(s)
  if s and s.fileType == "r3configurator_cnf" then
    if common.setCleanConfigSnapshot then
      common.setCleanConfigSnapshot(s, { needsInitialSave = false })
    else
      s.configModified = false
      s.configNeedsInitialSave = false
    end
  else
    if common.markNewUnsavedConfig then
      common.markNewUnsavedConfig(s)
    else
      s.configModified = true
    end
  end
end

local function runMain(s, pad)
  local main_str = (C.strings and C.strings.main) or {}
  local dt, dlr = common.drawText, s.drawListRow
  local M = s.MARGIN_X or common.MARGIN_X
  local H = s.HINT_Y or common.HINT_Y
  local L = s.LINE_H or common.LINE_H
  local MY = s.MARGIN_Y or common.MARGIN_Y
  local sc = s.scaleY or function(y) return y end
  local SE = common.SELECTED_ENTRY

  local egsmEnabled = (C.config_options and C.config_options.isEgsmUiEnabled and C.config_options.isEgsmUiEnabled()) or
      false
  local filterKey = getMainFilterBuildKey()
  local expectedBuildKey = tostring(egsmEnabled) .. "|" .. filterKey
  if type(s.main) ~= "table" or type(s.mainEntries) ~= "table" or s.mainBuildKey ~= expectedBuildKey then
    local labels, entries = buildMainChoices(main_str)
    s.main = labels
    s.mainEntries = entries
    s.mainBuildKey = expectedBuildKey
  end

  if #s.main < 1 then
    s.main = { main_str.main_freemcboot or "FreeMCBoot" }
    s.mainEntries = {
      {
        id = "freemcboot",
        label = main_str.main_freemcboot or "FreeMCBoot",
        logoKey = "freemcboot",
        context = "freemcboot",
        fileType = "freemcboot_cnf",
        state = "select_config",
      }
    }
  end

  local function getMainOverlayLogoKey(sel)
    local entry = s.mainEntries and s.mainEntries[sel]
    return entry and entry.logoKey or nil
  end

  local function getMainEntryById(id)
    local entryId = tostring(id or "")
    if entryId == "" then return nil end
    for i = 1, #(s.mainEntries or {}) do
      local entry = s.mainEntries[i]
      if entry and entry.id == entryId then
        return entry
      end
    end
    return nil
  end

  local function openMainEntry(entry)
    if not entry then return false end
    s.mainOverlayLogoKey = entry.logoKey
    s.context = entry.context
    s.fileType = entry.fileType
    s.chosenMcSlot = nil
    clearLoadChoiceState(s)
    clearPathPickerState(s)
    s.state = entry.state
    return true
  end

  if s.mainSel < 1 then s.mainSel = 1 end
  if s.mainSel > #s.main then s.mainSel = #s.main end

  local function drawMainBaseUi()
    dt(s.font, s.drawMode, M, MY, 1.1, main_str.main_title or "", common.WHITE)
    local versionStr = (type(APP_VERSION) == "string" and APP_VERSION ~= "") and APP_VERSION or
        (main_str.version_unknown or "unknown")
    local vw = common.calcTextWidth(s.font, versionStr, 0.75) or (#versionStr * 9)
    local viewW = s.w or 640
    dt(s.font, s.drawMode, viewW - M - vw, MY, 0.75, versionStr, common.DIM)
    dt(s.font, s.drawMode, M, MY + sc(22), 0.75, main_str.main_sub or "", common.DIM)
    local hintItems = buildMainBaseHintItems(main_str)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, hintItems or {}, nil, common.DIM)
    for i, label in ipairs(s.main) do
      local y = MY + sc(50) + (i - 1) * L
      local col = (i == s.mainSel) and SE or common.GRAY
      dlr(M + 20, y, i == s.mainSel, label, col)
    end
  end

  if s.mainLangPrompt and not hasLanguageChoices() then
    s.mainLangPrompt = nil
    s.mainLangSel = nil
    s.mainLangPromptAnim = nil
    s.mainLangPromptClosing = nil
  end
  if s.mainLangPrompt then
    local total = #C.langFiles
    s.mainLangSel = common.clampListSelection(s.mainLangSel or (C.langIndex or 1), total)
    local closing = s.mainLangPromptClosing == true
    local anim = tonumber(s.mainLangPromptAnim)
    if type(anim) ~= "number" then
      anim = closing and 1 or 0
    end
    if closing then
      anim = math.max(0, anim - (1 / 6))
    else
      anim = math.min(1, anim + (1 / 6))
    end
    s.mainLangPromptAnim = anim
    drawMainBaseUi()
    local maxVis = math.max(1, math.min(8, total))
    local scroll = common.centeredListScroll(s.mainLangSel, total, maxVis)
    local textScale = tonumber((common and common.PAD_HINT_TEXT_SCALE) or 0.75)
    local titleScale = (common.getHintLabelDrawScale and common.getHintLabelDrawScale(0.7)) or (0.7 * textScale)
    local rowScale = titleScale
    local hintFont = (common.getHintFont and common.getHintFont(s.font, s.drawMode, textScale)) or s.font
    local textH = (common.getHintLabelTextHeight and common.getHintLabelTextHeight()) or
        math.max(10, math.floor(((common.FT_PIXEL_H or 18) * textScale) + 0.5))
    local function textWidth(text, scale)
      local useScale = scale or rowScale
      if common.calcTextWidth then
        return common.calcTextWidth(hintFont, tostring(text or ""), useScale)
      end
      local str = tostring(text or "")
      return math.floor((8 * useScale) * #str)
    end

    local spaceW = textWidth(" ", rowScale)
    if spaceW < 1 then
      local probeW = textWidth("M", rowScale)
      if probeW < 1 then probeW = math.floor((8 * rowScale) + 0.5) end
      spaceW = math.max(2, math.floor((probeW * 0.32) + 0.5))
    end
    local markerW = textWidth(">", rowScale)
    if markerW < 1 then markerW = math.max(2, math.floor((spaceW * 1.2) + 0.5)) end
    local maxLabelWIntrinsic = 0
    for i = 1, total do
      local lw = textWidth(getLanguageDisplayName(i), rowScale)
      if lw > maxLabelWIntrinsic then maxLabelWIntrinsic = lw end
    end

    local padX = math.floor((sc(8) or 8) + 0.5)
    local padTop = math.floor((sc(6) or 6) + 0.5)
    local titleH = 0
    local titleGap = 0
    local padBottom = math.floor((sc(6) or 6) + 0.5)
    local rowStep = textH + math.max(2, math.floor((sc(3) or 3) + 0.5))

    local sideMargin = common.PAD_HINT_SIDE_MARGIN or 0
    local hintGridXShift = common.PAD_HINT_GRID_X_SHIFT or 0
    local hintGridExtraW = common.PAD_HINT_GRID_EXTRA_W or 0
    local hintTotalW = ((s.w or 640) - (2 * M)) + hintGridExtraW
    local hintXEff = M + sideMargin + hintGridXShift
    local hintWidthEff = hintTotalW - (2 * sideMargin)
    local slotW = hintWidthEff / 5
    local squareSlotLeft = hintXEff + slotW
    local squareSlotCenter = squareSlotLeft + (slotW / 2)
    local startSlotLeft = hintXEff + (2 * slotW)
    local startSlotCenter = startSlotLeft + (slotW / 2)
    local hintIconScale = 0.6
    local hintIconW = math.max(10, math.floor(((common.PAD_ICON_W or 26) * hintIconScale) + 0.5))
    local hintGap = math.max(2, math.floor(((common.PAD_HINT_GAP or 5) * textScale) + 0.5))
    local squareButtonLeft = math.floor(squareSlotCenter - (hintIconW / 2))
    local startButtonLeft = math.floor(startSlotCenter - (hintIconW / 2))
    local desiredBoxX = squareButtonLeft
    local desiredRowLabelX = squareButtonLeft + hintIconW + hintGap
    local rowLabelOffset = desiredRowLabelX - desiredBoxX
    if rowLabelOffset < (padX + markerW + spaceW) then
      rowLabelOffset = padX + markerW + spaceW
    end
    local rightGap = math.max(3, math.floor((sc(4) or 4) + 0.5))
    local targetRightX = startButtonLeft - rightGap
    local desiredToStartW = math.floor(targetRightX - desiredBoxX + 0.5)
    if desiredToStartW < 90 then desiredToStartW = 90 end
    local contentW = math.max(90, math.floor((rowLabelOffset + maxLabelWIntrinsic + padX) + 0.5))
    local boxW = math.max(desiredToStartW, contentW)
    local maxBoxW = (s.w or 640) - (2 * M)
    if boxW > maxBoxW then boxW = maxBoxW end
    local boxH = padTop + titleH + titleGap + (maxVis * rowStep) + padBottom

    local hintRowH = math.max(14, math.floor(((common.PAD_HINT_ROW_H or 28) * textScale) + 0.5))
    local hintRowTop = math.floor(H) - hintRowH
    local finalBoxY = hintRowTop - boxH - math.max(2, math.floor((sc(2) or 2) + 0.5))
    local slideDist = math.max(10, math.floor((sc(14) or 14) + 0.5))
    local boxY = finalBoxY + math.floor((1 - anim) * slideDist)
    local boxX = desiredBoxX
    local minX = M
    local maxX = (s.w or 640) - boxW - M
    if boxX < minX then boxX = minX end
    if boxX > maxX then boxX = maxX end

    if Graphics and Graphics.drawRect then
      local alpha = math.floor(120 * anim + 0.5)
      if alpha < 0 then alpha = 0 end
      if alpha > 120 then alpha = 120 end
      Graphics.drawRect(boxX, boxY, boxW, boxH, Color.new(40, 40, 48, alpha))
    end

    local rowStartY = boxY + padTop + titleH + titleGap
    local rowLabelX = desiredRowLabelX
    local rowMarkerX = rowLabelX - markerW - spaceW
    local maxLabelW = (boxX + boxW) - padX - rowLabelX
    if maxLabelW < 1 then maxLabelW = 1 end

    for i = scroll + 1, math.min(scroll + maxVis, total) do
      local y = rowStartY + (i - scroll - 1) * rowStep
      local label = getLanguageDisplayName(i)
      if common.fitListRowText then
        label = common.fitListRowText(s, "main_lang_row_" .. tostring(i), hintFont, label, maxLabelW, rowScale,
          i == s.mainLangSel)
      elseif common.truncateTextToWidth then
        label = common.truncateTextToWidth(hintFont, label, maxLabelW, rowScale)
      end
      local col = (i == s.mainLangSel) and SE or common.WHITE
      if i == s.mainLangSel then
        dt(hintFont, s.drawMode, rowMarkerX, y, rowScale, ">", col)
      end
      dt(hintFont, s.drawMode, rowLabelX, y, rowScale, label, col)
    end
    local hintItems = buildMainLanguageOverlayHintItems(main_str)
    if Graphics and Graphics.drawRect then
      local hintBg = (common and common.BGCOLOR) or Color.new(20, 20, 20, 0x80)
      local hintRowH = math.max(14, math.floor(((common.PAD_HINT_ROW_H or 28) * 0.75) + 0.5))
      local hintRowTop = math.floor(H) - hintRowH
      local hintW = (s.w or 640) - (2 * M)
      Graphics.drawRect(M, hintRowTop, hintW, hintRowH, hintBg)
    end
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, hintItems, nil, common.DIM)
    if not closing then
      if (pad & PAD_UP) ~= 0 then
        s.mainLangSel = common.wrapListSelection(s.mainLangSel, total, -1)
      end
      if (pad & PAD_DOWN) ~= 0 then
        s.mainLangSel = common.wrapListSelection(s.mainLangSel, total, 1)
      end
      if (pad & PAD_CROSS) ~= 0 then
        applyLanguageIndex(s, s.mainLangSel)
        s.mainLangPrompt = nil
        s.mainLangSel = nil
        s.mainLangPromptAnim = nil
        s.mainLangPromptClosing = nil
      elseif (pad & PAD_CIRCLE) ~= 0 or (pad & PAD_SQUARE) ~= 0 then
        s.mainLangPromptClosing = true
        if s.mainLangPromptAnim < 0.001 then
          s.mainLangPromptAnim = 1
        end
      end
    elseif anim <= 0.001 then
      s.mainLangPrompt = nil
      s.mainLangSel = nil
      s.mainLangPromptAnim = nil
      s.mainLangPromptClosing = nil
    end
    return
  end

  if s.mainCreditsPrompt then
    local closing = s.mainCreditsPromptClosing == true
    local anim = tonumber(s.mainCreditsPromptAnim)
    if type(anim) ~= "number" then
      anim = closing and 1 or 0
    end
    if closing then
      anim = math.max(0, anim - (1 / 6))
    else
      anim = math.min(1, anim + (1 / 6))
    end
    s.mainCreditsPromptAnim = anim
    drawMainBaseUi()

    local lines = buildMainCreditsLines(main_str)
    local total = #lines
    local textScale = tonumber((common and common.PAD_HINT_TEXT_SCALE) or 0.75)
    local titleScale = (common.getHintLabelDrawScale and common.getHintLabelDrawScale(0.7)) or (0.7 * textScale)
    local rowScale = titleScale
    local hintFont = (common.getHintFont and common.getHintFont(s.font, s.drawMode, textScale)) or s.font
    local textH = (common.getHintLabelTextHeight and common.getHintLabelTextHeight()) or
        math.max(10, math.floor(((common.FT_PIXEL_H or 18) * textScale) + 0.5))
    local function textWidth(text, scale)
      local useScale = scale or rowScale
      if common.calcTextWidth then
        return common.calcTextWidth(hintFont, tostring(text or ""), useScale)
      end
      local str = tostring(text or "")
      return math.floor((8 * useScale) * #str)
    end

    local maxLabelWIntrinsic = 0
    for i = 1, total do
      local lw = textWidth(lines[i], rowScale)
      if lw > maxLabelWIntrinsic then maxLabelWIntrinsic = lw end
    end

    local padX = math.floor((sc(8) or 8) + 0.5)
    local padTop = math.floor((sc(6) or 6) + 0.5)
    local padBottom = math.floor((sc(6) or 6) + 0.5)
    local rowStep = textH + math.max(2, math.floor((sc(3) or 3) + 0.5))

    local sideMargin = common.PAD_HINT_SIDE_MARGIN or 0
    local hintGridXShift = common.PAD_HINT_GRID_X_SHIFT or 0
    local hintGridExtraW = common.PAD_HINT_GRID_EXTRA_W or 0
    local hintTotalW = ((s.w or 640) - (2 * M)) + hintGridExtraW
    local hintXEff = M + sideMargin + hintGridXShift
    local hintWidthEff = hintTotalW - (2 * sideMargin)
    local slotW = hintWidthEff / 5
    local triangleSlotLeft = hintXEff + (3 * slotW)
    local triangleSlotCenter = triangleSlotLeft + (slotW / 2)
    local circleSlotLeft = hintXEff + (4 * slotW)
    local circleSlotCenter = circleSlotLeft + (slotW / 2)
    local hintIconScale = 0.6
    local hintIconW = math.max(10, math.floor(((common.PAD_ICON_W or 26) * hintIconScale) + 0.5))
    local hintGap = math.max(2, math.floor(((common.PAD_HINT_GAP or 5) * textScale) + 0.5))
    local triangleButtonLeft = math.floor(triangleSlotCenter - (hintIconW / 2))
    local circleButtonLeft = math.floor(circleSlotCenter - (hintIconW / 2))
    local desiredBoxX = triangleButtonLeft
    local desiredRowLabelX = triangleButtonLeft + hintIconW + hintGap
    local rowLabelOffset = desiredRowLabelX - desiredBoxX
    if rowLabelOffset < padX then rowLabelOffset = padX end
    local rightGap = math.max(3, math.floor((sc(4) or 4) + 0.5))
    local targetRightX = circleButtonLeft - rightGap
    local desiredToCircleW = math.floor(targetRightX - desiredBoxX + 0.5)
    if desiredToCircleW < 90 then desiredToCircleW = 90 end
    local contentW = math.max(90, math.floor((rowLabelOffset + maxLabelWIntrinsic + padX) + 0.5))
    local boxW = math.max(desiredToCircleW, contentW)
    local maxBoxW = (s.w or 640) - (2 * M)
    if boxW > maxBoxW then boxW = maxBoxW end
    local boxH = padTop + (total * rowStep) + padBottom

    local hintRowH = math.max(14, math.floor(((common.PAD_HINT_ROW_H or 28) * textScale) + 0.5))
    local hintRowTop = math.floor(H) - hintRowH
    local finalBoxY = hintRowTop - boxH - math.max(2, math.floor((sc(2) or 2) + 0.5))
    local slideDist = math.max(10, math.floor((sc(14) or 14) + 0.5))
    local boxY = finalBoxY + math.floor((1 - anim) * slideDist)
    local boxX = desiredBoxX
    local minX = M
    local maxX = (s.w or 640) - boxW - M
    if boxX < minX then boxX = minX end
    if boxX > maxX then boxX = maxX end

    if Graphics and Graphics.drawRect then
      local alpha = math.floor(120 * anim + 0.5)
      if alpha < 0 then alpha = 0 end
      if alpha > 120 then alpha = 120 end
      Graphics.drawRect(boxX, boxY, boxW, boxH, Color.new(40, 40, 48, alpha))
    end

    local rowStartY = boxY + padTop
    local rowLabelX = boxX + rowLabelOffset
    local maxLabelW = (boxX + boxW) - padX - rowLabelX
    if maxLabelW < 1 then maxLabelW = 1 end
    local creditsHeadingColor = CREDITS_HEADING_BLUE
    for i = 1, total do
      local y = rowStartY + (i - 1) * rowStep
      local label = lines[i]
      if common.fitListRowText then
        label = common.fitListRowText(s, "main_credits_row_" .. tostring(i), hintFont, label, maxLabelW, rowScale, false)
      elseif common.truncateTextToWidth then
        label = common.truncateTextToWidth(hintFont, label, maxLabelW, rowScale)
      end
      local isHeading = (i == 1 or i == 3 or i == 7)
      local rowColor = isHeading and creditsHeadingColor or common.WHITE
      dt(hintFont, s.drawMode, rowLabelX, y, rowScale, label, rowColor)
    end

    local hintItems = buildMainCreditsOverlayHintItems(main_str)
    if Graphics and Graphics.drawRect then
      local hintBg = (common and common.BGCOLOR) or Color.new(20, 20, 20, 0x80)
      local hintRowH = math.max(14, math.floor(((common.PAD_HINT_ROW_H or 28) * 0.75) + 0.5))
      local hintRowTop = math.floor(H) - hintRowH
      local hintW = (s.w or 640) - (2 * M)
      Graphics.drawRect(M, hintRowTop, hintW, hintRowH, hintBg)
    end
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, hintItems, nil, common.DIM)

    if not closing then
      if (pad & PAD_TRIANGLE) ~= 0 or (pad & PAD_CIRCLE) ~= 0 then
        s.mainCreditsPromptClosing = true
        if s.mainCreditsPromptAnim < 0.001 then
          s.mainCreditsPromptAnim = 1
        end
      end
    elseif anim <= 0.001 then
      s.mainCreditsPrompt = nil
      s.mainCreditsPromptAnim = nil
      s.mainCreditsPromptClosing = nil
    end
    return
  end

  if (pad & PAD_TRIANGLE) ~= 0 then
    s.mainCreditsPrompt = true
    s.mainCreditsPromptAnim = 0
    s.mainCreditsPromptClosing = nil
    drawMainBaseUi()
    return
  end

  if (pad & PAD_SQUARE) ~= 0 then
    local settingsEntry = getMainEntryById("r3configurator") or {
      id = "r3configurator",
      logoKey = nil,
      context = "r3configurator",
      fileType = "r3configurator_cnf",
      state = "open",
    }
    if openMainEntry(settingsEntry) then
      return
    end
  end

  if (pad & PAD_UP) ~= 0 and s.mainSel > 1 then
    s.mainSel = s.mainSel - 1
  end
  if (pad & PAD_DOWN) ~= 0 and s.mainSel < #s.main then
    s.mainSel = s.mainSel + 1
  end
  s.mainOverlayLogoKey = getMainOverlayLogoKey(s.mainSel)
  local openedExitPrompt = false
  if (pad & PAD_CIRCLE) ~= 0 and not s.mainExitPrompt then
    s.mainExitPrompt = true
    openedExitPrompt = true
  end
  if s.mainExitPrompt then
    local msg = main_str.main_exit_prompt or main_str.main_exit
    local tw = common.calcTextWidth(s.font, msg, 1.1)
    local w = s.w or 640
    local h = s.h or 448
    local lineH = s.LINE_H or common.LINE_H
    local boxW = tw + 48
    local boxH = lineH + 24
    local boxX = math.floor((w - boxW) / 2)
    local boxY = math.floor((h - boxH) / 2)
    if Graphics and Graphics.drawRect then
      Graphics.drawRect(boxX, boxY, boxW, boxH, Color.new(40, 40, 48, 110))
    end
    local cx = common.centerX and common.centerX(s, tw) or math.floor((w - tw) / 2)
    local cy = boxY + math.floor((boxH - lineH) / 2)
    dt(s.font, s.drawMode, math.max(M, cx), cy, 1.1, msg, common.WHITE)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.main_exit_hint_items or main_str.circle_back_items, nil,
      common.DIM)
    if (pad & PAD_CROSS) ~= 0 then System.exitToBrowser() end
    if (pad & PAD_CIRCLE) ~= 0 and not openedExitPrompt then s.mainExitPrompt = nil end
    return
  end
  drawMainBaseUi()
  if (pad & PAD_CROSS) ~= 0 then
    local entry = s.mainEntries and s.mainEntries[s.mainSel]
    openMainEntry(entry)
  end
end

local function runChooseMc(s, pad)
  local main_str = (C.strings and C.strings.main) or {}
  local dt, dlr = common.drawText, s.drawListRow
  local M = s.MARGIN_X or common.MARGIN_X
  local H = s.HINT_Y or common.HINT_Y
  local L = s.LINE_H or common.LINE_H
  local MY = s.MARGIN_Y or common.MARGIN_Y
  local sc = s.scaleY or function(y) return y end
  local SE = common.SELECTED_ENTRY
  local slots = common.getPresentMcSlots()
  if #slots == 0 then
    if s.context == "freemcboot" and s.fileType == "freemcboot_cnf" then
      -- FreeMCBoot can still be loaded/created on mass:/ even when no MC is inserted.
      s.chosenMcSlot = nil
      s.state = "open"
      return
    end
    dt(s.font, s.drawMode, M, MY, 1.1, main_str.no_memory_card, common.WHITE)
    dt(s.font, s.drawMode, M, MY + sc(30), 0.8, main_str.insert_mc, common.GRAY)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.circle_back_items, nil, common.DIM)
    if (pad & PAD_CIRCLE) ~= 0 then s.state = "main" end
  elseif #slots == 1 then
    s.chosenMcSlot = slots[1]
    s.state = nextStateAfterMcSelection(s)
  else
    dt(s.font, s.drawMode, M, MY, 1.1, main_str.select_memory_card, common.WHITE)
    dt(s.font, s.drawMode, M, MY + sc(24), 0.8, main_str.config_card_hint, common.DIM)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_select_circle_back_items, nil, common.DIM)
    if s.mcSel < 1 then s.mcSel = 1 end
    if s.mcSel > #slots then s.mcSel = #slots end
    for i = 1, #slots do
      local y = MY + sc(50) + (i - 1) * L
      local label = (slots[i] == 0 and main_str.memory_card_1_slot) or main_str.memory_card_2_slot
      local col = (i == s.mcSel) and SE or common.WHITE
      dlr(M + 20, y, i == s.mcSel, label, col)
    end
    if (pad & PAD_UP) ~= 0 then
      s.mcSel = s.mcSel - 1; if s.mcSel < 1 then s.mcSel = #slots end
    end
    if (pad & PAD_DOWN) ~= 0 then
      s.mcSel = s.mcSel + 1; if s.mcSel > #slots then s.mcSel = 1 end
    end
    if (pad & PAD_CROSS) ~= 0 then
      s.chosenMcSlot = slots[s.mcSel]
      s.state = nextStateAfterMcSelection(s)
    end
    if (pad & PAD_CIRCLE) ~= 0 then s.state = "main" end
  end
end

local function isVisible(visibility, key)
  if not visibility or not key then return true end
  local v = visibility[key]
  if v == nil then return true end
  return v == true
end

local function appendUniquePath(paths, path)
  if not path or path == "" then return end
  for i = 1, #paths do
    if paths[i] == path then return end
  end
  paths[#paths + 1] = path
end

local function normalizeMountpoint(mp)
  if type(mp) ~= "string" or mp == "" then return nil end
  return (mp:sub(-1) == ":") and mp or (mp .. ":")
end

local function normalizeLaunchFamily(value)
  local fam = tostring(value or ""):lower()
  if fam == "mass" then fam = "usb" end
  if fam == "usb" or fam == "mmce" or fam == "mx4sio" or fam == "ata" or fam == "hdd" or fam == "mc" or fam == "bdm" then
    return fam
  end
  return nil
end

local function inferLaunchFamilyFromPath(path)
  if type(path) ~= "string" or path == "" then return nil end
  local p = path:lower()
  if p:match("^mmce%d*:") then return "mmce" end
  if p:match("^mass%d*:") then return "usb" end
  if p:match("^hdd%d:") or p:match("^pfs%d:") then return "hdd" end
  if p:match("^mc%d:") then return "mc" end
  return nil
end

local function getLaunchSourceFamily(s)
  if type(s.launchSourceFamily) == "string" and s.launchSourceFamily ~= "" then
    return s.launchSourceFamily
  end
  local family = nil
  if System and System.getLaunchDeviceFamily then
    local ok, val = pcall(System.getLaunchDeviceFamily)
    if ok then family = normalizeLaunchFamily(val) end
  end
  if not family and System and System.currentDirectory then
    local ok, cwd = pcall(System.currentDirectory)
    if ok then family = inferLaunchFamilyFromPath(cwd) end
  end
  if not family then family = "unknown" end
  s.launchSourceFamily = family
  return family
end

local function getDeviceMountpoint(deviceId)
  if not deviceId or deviceId == "" then return nil end
  if C.file_selector and C.file_selector.getDeviceMountpoint then
    local ok, mp = pcall(C.file_selector.getDeviceMountpoint, deviceId)
    if ok then return normalizeMountpoint(mp) end
  end
  if System and System.getDeviceMountpoint then
    local ok, mp = pcall(System.getDeviceMountpoint, deviceId)
    if ok then return normalizeMountpoint(mp) end
  end
  return nil
end

local function isPrefixAvailable(prefix)
  if not prefix or prefix == "" then return false end
  local probe = tostring(prefix)
  if probe:sub(-1) == ":" then probe = probe .. "/" end
  return common.tryOpen(probe)
end

local function hasMountedUsbSlot(deviceId, fallbackPrefix)
  local mountpoint = getDeviceMountpoint(deviceId)
  if mountpoint and isPrefixAvailable(mountpoint) then
    return true
  end
  return isPrefixAvailable(fallbackPrefix)
end

local function getSelectConfigDevicePresence(s)
  local sceneEpoch = s._sceneEpoch or 0
  local inputEpoch = s._inputEpoch or 0
  local cache = s.selectConfigDevicePresenceCache
  if cache and cache.sceneEpoch == sceneEpoch and cache.inputEpoch == inputEpoch then
    return cache
  end
  local launchFamily = getLaunchSourceFamily(s)
  local restrictToExistingRemovables = (launchFamily == "mmce" or launchFamily == "usb")
  local mmce0Visible, mmce1Visible, usb0Visible, usb1Visible
  if restrictToExistingRemovables then
    mmce0Visible = isPrefixAvailable("mmce0:")
    mmce1Visible = isPrefixAvailable("mmce1:")
    usb0Visible = hasMountedUsbSlot("usb0", "mass:")
    usb1Visible = hasMountedUsbSlot("usb1", "mass1:")
  else
    -- For non-USB/MMCE launch sources, keep legacy behavior: show these rows in fixed order.
    mmce0Visible = true
    mmce1Visible = true
    usb0Visible = true
    usb1Visible = true
  end
  cache = {
    sceneEpoch = sceneEpoch,
    inputEpoch = inputEpoch,
    launchFamily = launchFamily,
    mmce0 = mmce0Visible,
    mmce1 = mmce1Visible,
    usb0 = usb0Visible,
    usb1 = usb1Visible,
  }
  s.selectConfigDevicePresenceCache = cache
  return cache
end

local function buildBblSourceOptions(s, iniFileType)
  local dev_str = (C.strings and C.strings.devices) or {}
  local visibility = (C.config_options and C.config_options.getBblPathDeviceVisibility and
      C.config_options.getBblPathDeviceVisibility()) or nil
  local iniName = (iniFileType == "psxbbl_ini") and "PSXBBL.INI" or "PS2BBL.INI"
  local presence = getSelectConfigDevicePresence(s)
  local presentMc = {}
  local slots = (common.getPresentMcSlots and common.getPresentMcSlots()) or {}
  for i = 1, #slots do
    if slots[i] == 0 or slots[i] == 1 then
      presentMc[slots[i]] = true
    end
  end
  local out = {}
  local function addDevice(visKey, label, paths, browseDeviceName, browseDeviceId, browseDeviceType)
    if not isVisible(visibility, visKey) then return end
    local rows = {}
    if type(paths) == "table" then
      for i = 1, #paths do
        appendUniquePath(rows, paths[i])
      end
    else
      appendUniquePath(rows, paths)
    end
    if #rows == 0 then return end
    out[#out + 1] = {
      label = label,
      action = "known_paths",
      paths = rows,
      browseDeviceName = browseDeviceName,
      browseDeviceId = browseDeviceId,
      browseDeviceType = browseDeviceType,
    }
  end
  if presentMc[0] then
    addDevice("mc", dev_str.memory_card_1 or "Memory Card 1", { "mc0:/SYS-CONF/" .. iniName }, "mc0:")
  end
  if presentMc[1] then
    addDevice("mc", dev_str.memory_card_2 or "Memory Card 2", { "mc1:/SYS-CONF/" .. iniName }, "mc1:")
  end
  if presence.mmce0 then
    addDevice("mmce", dev_str.mmce_0 or "MMCE in slot 1", { "mmce0:/PS2BBL/PS2BBL.INI" }, "mmce0:", nil, "mmce")
  end
  if presence.mmce1 then
    addDevice("mmce", dev_str.mmce_1 or "MMCE in slot 2", { "mmce1:/PS2BBL/PS2BBL.INI" }, "mmce1:", nil, "mmce")
  end
  if presence.usb0 then
    addDevice("usb", dev_str.usb_storage_0 or "USB Mass Storage 1", { "mass:/PS2BBL/CONFIG.INI" }, nil, "usb0", "usb")
  end
  if presence.usb1 then
    addDevice("usb", dev_str.usb_storage_1 or "USB Mass Storage 2", { "mass1:/PS2BBL/CONFIG.INI" }, nil, "usb1", "usb")
  end
  addDevice("mx4sio", dev_str.mx4sio_sd or "MX4SIO", { "massX:/PS2BBL/CONFIG.INI" }, nil, "mx4sio", "mx4sio")
  addDevice("hdd", dev_str.hdd or "APA-formatted HDD", { "hdd0:__sysconf:pfs:/PS2BBL/CONFIG.INI" }, "hdd0:", nil, "hdd")
  return out
end

local function buildFreemcbootSourceOptions(s, context)
  local dev_str = (C.strings and C.strings.devices) or {}
  local presence = getSelectConfigDevicePresence(s)
  local presentMc = {}
  local slots = (common.getPresentMcSlots and common.getPresentMcSlots()) or {}
  for i = 1, #slots do
    if slots[i] == 0 or slots[i] == 1 then
      presentMc[slots[i]] = true
    end
  end
  local out = {}
  local fileName = (context == "freehddboot") and "FREEHDB.CNF" or "FREEMCB.CNF"

  local function add(label, path, deviceType)
    out[#out + 1] = {
      label = label,
      action = "known_paths",
      paths = { path },
      browseDeviceType = deviceType,
    }
  end

  if context == "freehddboot" then
    add(dev_str.hdd or "APA-formatted HDD", "hdd0:__sysconf/FMCB/FREEHDB.CNF", "hdd")
  end
  if presentMc[0] then
    add(dev_str.memory_card_1 or "Memory Card 1", "mc0:/SYS-CONF/" .. fileName, "mc")
  end
  if presentMc[1] then
    add(dev_str.memory_card_2 or "Memory Card 2", "mc1:/SYS-CONF/" .. fileName, "mc")
  end
  if presence.usb0 then
    add(dev_str.usb_storage_0 or "USB Mass Storage 1", "mass:/" .. fileName, "usb")
  end
  if presence.usb1 then
    add(dev_str.usb_storage_1 or "USB Mass Storage 2", "mass1:/" .. fileName, "usb")
  end
  return out
end

local function pickUsesHdd(pick)
  if not pick then return false end
  if pick.browseDeviceType == "hdd" then return true end
  local paths = pick.paths or {}
  for i = 1, #paths do
    local p = tostring(paths[i] or "")
    if p:match("^hdd%d:") or p:match("^pfs%d:/") then
      return true
    end
  end
  return false
end

local function applyKnownPathPick(s, pick, main_str, opts)
  if not pick or pick.action ~= "known_paths" then return false end
  opts = opts or {}
  local includeBrowseIni = (opts.includeBrowseIni == true)
  s.loadChoices = {}
  s.loadPathExists = {}
  local paths = pick.paths or {}
  for i = 1, #paths do
    local p = paths[i]
    s.loadChoices[#s.loadChoices + 1] = p
    s.loadPathExists[#s.loadPathExists + 1] = pathExists(p)
  end
  if includeBrowseIni then
    s.loadChoices[#s.loadChoices + 1] = {
      kind = "browse_ini",
      label = main_str.select_config_browse_ini or "Browse CONFIG.INI (CWD)",
      browseDeviceName = pick.browseDeviceName,
      browseDeviceId = pick.browseDeviceId,
      browseDeviceType = pick.browseDeviceType,
    }
    s.loadPathExists[#s.loadPathExists + 1] = false
  end
  s.loadAllowCreate = true
  s.loadSel = 1
  s.loadReturnState = "select_config"
  s.state = "choose_load"
  return true
end

local function runSelectConfig(s, pad)
  local main_str = (C.strings and C.strings.main) or {}
  local path_str = (C.strings and C.strings.path_picker) or {}
  local dt, dlr = common.drawText, s.drawListRow
  local M = s.MARGIN_X or common.MARGIN_X
  local H = s.HINT_Y or common.HINT_Y
  local L = s.LINE_H or common.LINE_H
  local MY = s.MARGIN_Y or common.MARGIN_Y
  local sc = s.scaleY or function(y) return y end
  local SE = common.SELECTED_ENTRY

  if s.context == "osdmenu" then
    local options = {
      { label = main_str.select_config_osdmenu_cnf or "OSDMENU.CNF", fileType = "osdmenu_cnf" },
      { label = main_str.select_config_osdgsm_cnf or "OSDGSM.CNF", fileType = "osdgsm_cnf" },
    }
    local sel = getSelectConfigSel(s)
    if sel < 1 then sel = 1 end
    if sel > #options then sel = #options end
    setSelectConfigSel(s, sel)

    dt(s.font, s.drawMode, M, MY, 1.1, main_str.which_file, common.WHITE)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_select_circle_back_items, nil, common.DIM)
    for i, opt in ipairs(options) do
      local y = MY + sc(50) + (i - 1) * L
      local col = (i == sel) and SE or common.GRAY
      dlr(M + 20, y, i == sel, opt.label or "", col)
    end

    if (pad & PAD_UP) ~= 0 then
      sel = sel - 1
      if sel < 1 then sel = #options end
    end
    if (pad & PAD_DOWN) ~= 0 then
      sel = sel + 1
      if sel > #options then sel = 1 end
    end
    setSelectConfigSel(s, sel)

    if (pad & PAD_CROSS) ~= 0 then
      local pick = options[sel]
      if pick and pick.fileType then
        s.fileType = pick.fileType
        clearLoadChoiceState(s)
        clearPathPickerState(s)
        s.state = "open"
        return
      end
    end
    if (pad & PAD_CIRCLE) ~= 0 then
      local slots = (common.getPresentMcSlots and common.getPresentMcSlots()) or {}
      if type(slots) == "table" and #slots > 1 then
        s.state = "choose_mc"
      else
        s.state = "main"
      end
    end
    return
  end

  if s.context == "freemcboot" or s.context == "freehddboot" then
    local options = buildFreemcbootSourceOptions(s, s.context)
    if s.pendingKnownPathPick then
      local pendingPick = s.pendingKnownPathPick
      s.pendingKnownPathPick = nil
      if applyKnownPathPick(s, pendingPick, main_str) then
        return
      end
    end
    local sel = getSelectConfigSel(s)
    if sel < 1 then sel = 1 end
    if sel > #options then sel = #options end
    setSelectConfigSel(s, sel)

    dt(s.font, s.drawMode, M, MY, 1.1, main_str.which_file, common.WHITE)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_select_circle_back_items, nil, common.DIM)
    for i, opt in ipairs(options) do
      local y = MY + sc(50) + (i - 1) * L
      local col = (i == sel) and SE or common.GRAY
      dlr(M + 20, y, i == sel, opt.label or "", col)
    end
    if (pad & PAD_UP) ~= 0 and sel > 1 then sel = sel - 1 end
    if (pad & PAD_DOWN) ~= 0 and sel < #options then sel = sel + 1 end
    setSelectConfigSel(s, sel)

    if (pad & PAD_CROSS) ~= 0 then
      local pick = options[sel]
      s.fileType = "freemcboot_cnf"
      clearPathPickerState(s)
      if pick and pick.action == "known_paths" then
        if pickUsesHdd(pick) and not s.hddReady then
          s.pendingKnownPathPick = pick
          s.initHddSuccessState = "select_config"
          s.initHddCancelState = "select_config"
          s.state = "initHdd"
          s.initHddPhase = "load"
          return
        end
        applyKnownPathPick(s, pick, main_str)
      end
    end

    if (pad & PAD_CIRCLE) ~= 0 then
      s.state = "main"
    end
    return
  end

  local iniFileType = resolveIniFileType(s)
  if iniFileType ~= "ps2bbl_ini" and iniFileType ~= "psxbbl_ini" then
    s.state = "open"
    return
  end

  local options = buildBblSourceOptions(s, iniFileType)
  if s.pendingKnownPathPick then
    local pendingPick = s.pendingKnownPathPick
    s.pendingKnownPathPick = nil
    if applyKnownPathPick(s, pendingPick, main_str, { includeBrowseIni = true }) then
      return
    end
  end
  local sel = getSelectConfigSel(s)
  if sel < 1 then sel = 1 end
  if sel > #options then sel = #options end
  setSelectConfigSel(s, sel)

  dt(s.font, s.drawMode, M, MY, 1.1, main_str.which_file, common.WHITE)
  if path_str.bbl_build_device_hint then
    local bblName = (iniFileType == "psxbbl_ini") and "PSXBBL" or "PS2BBL"
    local hint = tostring(path_str.bbl_build_device_hint):gsub("PS%?BBL", bblName)
    if common.truncateTextToWidth then
      hint = common.truncateTextToWidth(s.font, hint, (s.w or 640) - (M * 2), 0.55)
    end
    dt(s.font, s.drawMode, M, MY + sc(20), 0.55, hint, common.DIM)
  end
  common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_select_circle_back_items, nil, common.DIM)
  for i, opt in ipairs(options) do
    local y = MY + sc(50) + (i - 1) * L
    local col = (i == sel) and SE or common.GRAY
    dlr(M + 20, y, i == sel, opt.label or "", col)
  end
  if (pad & PAD_UP) ~= 0 and sel > 1 then sel = sel - 1 end
  if (pad & PAD_DOWN) ~= 0 and sel < #options then sel = sel + 1 end
  setSelectConfigSel(s, sel)

  if (pad & PAD_CROSS) ~= 0 then
    local pick = options[sel]
    s.fileType = iniFileType
    clearPathPickerState(s)
    if pick and pick.action == "known_paths" then
      if pickUsesHdd(pick) and not s.hddReady then
        s.pendingKnownPathPick = pick
        s.initHddSuccessState = "select_config"
        s.initHddCancelState = "select_config"
        s.state = "initHdd"
        s.initHddPhase = "load"
        return
      end
      applyKnownPathPick(s, pick, main_str, { includeBrowseIni = true })
    end
  end

  if (pad & PAD_CIRCLE) ~= 0 then
    s.state = "main"
  end
end

local INIT_HDD_PROBE_FRAMES = 12    -- probe hdd0: every ~200ms at 60fps
local INIT_HDD_TIMEOUT_FRAMES = 180 -- 3s at 60fps

local function runInitHdd(s, pad)
  local main_str = (C.strings and C.strings.main) or {}
  local dt = common.drawText
  local M = s.MARGIN_X or common.MARGIN_X
  local MY = s.MARGIN_Y or common.MARGIN_Y
  local H = s.HINT_Y or common.HINT_Y
  local sc = s.scaleY or function(y) return y end
  local phase = s.initHddPhase or "load"

  if phase == "load" then
    local w = s.w or 640
    local h = s.h or 448
    local tw1 = common.calcTextWidth(s.font, main_str.init_hdd_title, 1.1)
    local tw2 = common.calcTextWidth(s.font, main_str.init_hdd_sub, 0.85)
    local cx1 = math.floor((w - tw1) / 2)
    local cx2 = math.floor((w - tw2) / 2)
    local lineH = sc(22)
    local gap = sc(10)
    local blockH = lineH + gap + lineH
    local titleY = math.floor((h - blockH) / 2)
    local descY = titleY + lineH + gap
    dt(s.font, s.drawMode, math.max(M, cx1), titleY, 1.1, main_str.init_hdd_title, common.WHITE)
    dt(s.font, s.drawMode, math.max(M, cx2), descY, 0.85, main_str.init_hdd_sub, common.DIM)
    -- Show this frame on vblank before module load to avoid a visible full-screen flash.
    Screen.waitVblankStart()
    Screen.flip()
    if System.loadModules then System.loadModules("hdd") end
    s.initHddPhase = "wait"
    s.initHddFrames = 0
    return
  end

  if phase == "wait" then
    s.initHddFrames = (s.initHddFrames or 0) + 1
    if s.initHddFrames > 0 and s.initHddFrames % INIT_HDD_PROBE_FRAMES == 0 then
      if common.isHddPresent() then
        s.hddReady = true
        s.hddNotFound = nil
        s.state = s.initHddSuccessState or "open"
        s.initHddPhase = nil
        s.initHddFrames = nil
        s.initHddSuccessState = nil
        s.initHddCancelState = nil
        return
      end
    end
    if s.initHddFrames >= INIT_HDD_TIMEOUT_FRAMES then
      s.initHddPhase = "timeout"
      s.initHddFrames = nil
      s.hddNotFound = true
    else
      -- Keep showing init message (same as load phase); "Waiting for device drivers" is only for path selectors
      local w = s.w or 640
      local h = s.h or 448
      local tw1 = common.calcTextWidth(s.font, main_str.init_hdd_title, 1.1)
      local tw2 = common.calcTextWidth(s.font, main_str.init_hdd_sub, 0.85)
      local cx1 = math.floor((w - tw1) / 2)
      local cx2 = math.floor((w - tw2) / 2)
      local lineH = sc(22)
      local gap = sc(10)
      local blockH = lineH + gap + lineH
      local titleY = math.floor((h - blockH) / 2)
      local descY = titleY + lineH + gap
      dt(s.font, s.drawMode, math.max(M, cx1), titleY, 1.1, main_str.init_hdd_title, common.WHITE)
      dt(s.font, s.drawMode, math.max(M, cx2), descY, 0.85, main_str.init_hdd_sub, common.DIM)
      common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.circle_back_items, nil, common.DIM)
      return
    end
  end

  if phase == "timeout" then
    local msg = main_str.hdd_not_found
    local tw = common.calcTextWidth(s.font, msg, 1.1)
    local w = s.w or 640
    local cx = math.floor((w - tw) / 2)
    local cy = math.floor((MY + H) / 2) - math.floor((s.LINE_H or common.LINE_H) / 2)
    dt(s.font, s.drawMode, math.max(M, cx), cy, 1.1, msg, common.WHITE)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.circle_back_items, nil, common.DIM)
    if (pad & PAD_CIRCLE) ~= 0 then
      s.state = s.initHddCancelState or "main"
      s.initHddPhase = nil
      s.initHddSuccessState = nil
      s.initHddCancelState = nil
      s.pendingKnownPathPick = nil
    end
  end
end

local function runOpen(s, pad)
  local main_str = (C.strings and C.strings.main) or {}
  if (s.context == "hosdmenu" or s.context == "mbr") and not s.hddReady then
    s.state = "initHdd"
    s.initHddPhase = "load"
    s.initHddSuccessState = "open"
    s.initHddCancelState = "main"
    s.pendingKnownPathPick = nil
    return
  end
  local dt = common.drawText
  local M = s.MARGIN_X or common.MARGIN_X
  local H = s.HINT_Y or common.HINT_Y
  local MY = s.MARGIN_Y or common.MARGIN_Y
  local sc = s.scaleY or function(y) return y end
  if s.openExplicitPath and s.currentPath and s.currentPath ~= "" then
    if not pathExists(s.currentPath) then
      openDbg("explicit path missing; creating new in memory", "path=" .. tostring(s.currentPath))
      initEmptyLinesForFileType(s, "explicit path missing")
      s.openExplicitPath = nil
      clearLoadChoiceState(s)
      setStateAfterLoad(s)
      markNewInMemoryConfigState(s)
      openDbg("mark modified", "reason=new file in memory (explicit path missing)")
      return
    end
    local loaded, loadErr = loadLinesWithDeviceAccess(s.currentPath)
    if loaded then
      s.lines = loaded
      s.openExplicitPath = nil
      clearLoadChoiceState(s)
      setStateAfterLoad(s)
      return
    end
    openDbg("explicit path load failed", "path=" .. tostring(s.currentPath), "error=" .. tostring(loadErr))
    dt(s.font, s.drawMode, M, MY + sc(60), common.FONT_SCALE, main_str.failed_to_load .. tostring(s.currentPath),
      common.GRAY)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_back_items, nil, common.DIM)
    if (pad & PAD_CROSS) ~= 0 then
      s.openExplicitPath = nil
      clearLoadChoiceState(s)
      s.state = getOpenParentState(s)
    end
    return
  end
  local locations = C.config_options.getLocations(s.context, s.fileType, s.chosenMcSlot)
  openDbg("resolve locations", "context=" .. tostring(s.context), "fileType=" .. tostring(s.fileType),
    "count=" .. tostring(#(locations or {})))
  if s.fileType == "freemcboot_cnf" and (s.context == "freemcboot" or s.context == "freehddboot") and
      type(locations) == "table" and #locations > 0 then
    local prevPath = nil
    if s.loadChoices and s.loadSel and s.loadChoices[s.loadSel] then
      prevPath = s.loadChoices[s.loadSel]
    end
    s.loadChoices = {}
    s.loadPathExists = {}
    for i = 1, #locations do
      local p = locations[i]
      s.loadChoices[#s.loadChoices + 1] = p
      s.loadPathExists[#s.loadPathExists + 1] = pathExists(p)
    end
    if prevPath then
      local foundIdx = nil
      for i = 1, #s.loadChoices do
        if s.loadChoices[i] == prevPath then
          foundIdx = i
          break
        end
      end
      s.loadSel = foundIdx or s.loadSel or 1
    else
      s.loadSel = s.loadSel or 1
    end
    s.loadAllowCreate = true
    s.loadReturnState = getOpenParentState(s)
    openDbg("choose load", "mode=allow_create", "choices=" .. tostring(#s.loadChoices),
      "existingChoices=" .. tostring(countTrue(s.loadPathExists)))
    s.state = "choose_load"
    return
  end
  local existing = findExistingPathsWithDeviceAccess(locations)
  if #existing == 0 then
    if C.config_options and C.config_options.getDefaultLocation then
      s.currentPath = C.config_options.getDefaultLocation(s.context, s.fileType, s.chosenMcSlot)
    else
      s.currentPath = locations[1]
    end
    if not s.currentPath then
      openDbg("open failed", "reason=no location found")
      dt(s.font, s.drawMode, M, MY + sc(60), common.FONT_SCALE, main_str.no_location, common.GRAY)
      common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_back_items, nil, common.DIM)
      if (pad & PAD_CROSS) ~= 0 then s.state = getOpenParentState(s) end
    else
      openDbg("no existing file; creating new in memory", "path=" .. tostring(s.currentPath))
      initEmptyLinesForFileType(s, "no existing path")
      setStateAfterLoad(s)
      markNewInMemoryConfigState(s)
      openDbg("mark modified", "reason=new file in memory (no existing path)")
    end
  elseif #existing == 1 then
    s.currentPath = existing[1]
    openDbg("single existing path", "path=" .. tostring(s.currentPath))
    local loaded, loadErr = loadLinesWithDeviceAccess(s.currentPath)
    if not loaded then
      openDbg("single path load failed", "path=" .. tostring(s.currentPath), "error=" .. tostring(loadErr))
      dt(s.font, s.drawMode, M, MY + sc(60), common.FONT_SCALE, main_str.failed_to_load .. tostring(s.currentPath),
        common.GRAY)
      common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_back_items, nil, common.DIM)
      if (pad & PAD_CROSS) ~= 0 then s.state = getOpenParentState(s) end
    else
      s.lines = loaded
      setStateAfterLoad(s)
    end
  else
    local prevPath = nil
    if s.loadChoices and s.loadSel and s.loadChoices[s.loadSel] then
      prevPath = s.loadChoices[s.loadSel]
    end
    s.loadChoices = existing
    if prevPath then
      local foundIdx = nil
      for i, p in ipairs(existing) do
        if p == prevPath then
          foundIdx = i
          break
        end
      end
      s.loadSel = foundIdx or s.loadSel or 1
    else
      s.loadSel = s.loadSel or 1
    end
    s.loadAllowCreate = nil
    s.loadPathExists = nil
    s.loadReturnState = getOpenParentState(s)
    openDbg("choose load", "mode=existing_only", "choices=" .. tostring(#existing))
    s.state = "choose_load"
  end
end

local function runChooseLoad(s, pad)
  local main_str = (C.strings and C.strings.main) or {}
  local dev_str = (C.strings and C.strings.devices) or {}
  local dt, dlr = common.drawText, s.drawListRow
  local M = s.MARGIN_X or common.MARGIN_X
  local H = s.HINT_Y or common.HINT_Y
  local L = s.LINE_H or common.LINE_H
  local MY = s.MARGIN_Y or common.MARGIN_Y
  local sc = s.scaleY or function(y) return y end
  local SE = common.SELECTED_ENTRY
  local choices = s.loadChoices or {}
  local allowCreate = (s.loadAllowCreate == true)
  if s.loadSel < 1 then s.loadSel = 1 end
  if s.loadSel > #choices then s.loadSel = #choices end
  local maxVis = s.MAX_VISIBLE_LIST or s.MAX_VISIBLE or common.MAX_VISIBLE
  local total = #choices
  local maxLabelW = (s.w or 640) - (M + 24) - M
  local scroll = 0
  if total > maxVis then
    scroll = s.loadSel - math.floor(maxVis / 2)
    scroll = math.max(0, math.min(scroll, total - maxVis))
  end
  for i = scroll + 1, math.min(scroll + maxVis, total) do
    local idx = i
    local choice = choices[idx]
    local isBrowseIni = (type(choice) == "table" and choice.kind == "browse_ini")
    local p = (type(choice) == "string") and choice or ""
    local label = nil
    if isBrowseIni then
      label = choice.label or (main_str.select_config_browse_ini or "Browse CONFIG.INI (CWD)")
    elseif allowCreate then
      label = p
    elseif s.fileType == "freemcboot_cnf" then
      label = p
    else
      label = (p:match("^mc0:") and dev_str.memory_card_1) or (p:match("^mc1:") and dev_str.memory_card_2) or
          (p:match("^massX:") and dev_str.mx4sio_sd) or
          ((p:match("^mass:") or p:match("^mass%d:")) and dev_str.usb_storage_0) or
          (p:match("^mmce0:") and dev_str.mmce_0) or
          (p:match("^mmce1:") and dev_str.mmce_1) or
          (p:match("^hdd0:") and dev_str.hdd) or
          (p:match("^pfs0:") and dev_str.hdd) or
          p:sub(1, 40)
    end
    if common.fitListRowText then
      label = common.fitListRowText(s, "choose_load_row_" .. tostring(i), s.font, label, maxLabelW, common.FONT_SCALE,
        idx == s.loadSel)
    elseif common.truncateTextToWidth then
      label = common.truncateTextToWidth(s.font, label or "", maxLabelW, common.FONT_SCALE)
    end
    local y = MY + sc(50) + (i - scroll - 1) * L
    local col = (idx == s.loadSel) and SE or common.WHITE
    dlr(M + 20, y, idx == s.loadSel, label, col)
  end
  common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_load_circle_back_items, nil, common.DIM)
  if (pad & PAD_UP) ~= 0 then
    s.loadSel = s.loadSel - 1; if s.loadSel < 1 then s.loadSel = #choices end
  end
  if (pad & PAD_DOWN) ~= 0 then
    s.loadSel = s.loadSel + 1; if s.loadSel > #choices then s.loadSel = 1 end
  end
  if (pad & PAD_CROSS) ~= 0 and #choices > 0 then
    local chosen = choices[s.loadSel]
    if type(chosen) == "table" and chosen.kind == "browse_ini" then
      openDbg("choose load selection", "kind=browse_ini", "deviceId=" .. tostring(chosen.browseDeviceId),
        "deviceType=" .. tostring(chosen.browseDeviceType))
      local allDevices = (C.file_selector and C.file_selector.getDevices and C.file_selector.getDevices("config_ini")) or {}
      local targetDevice = nil
      for i = 1, #allDevices do
        local d = allDevices[i]
        if chosen.browseDeviceId and d and d.deviceId == chosen.browseDeviceId then
          targetDevice = d
          break
        end
        if chosen.browseDeviceName and d and d.name == chosen.browseDeviceName then
          targetDevice = d
          break
        end
      end
      if not targetDevice and #allDevices == 1 then
        targetDevice = allDevices[1]
      end
      if not targetDevice and (chosen.browseDeviceName or chosen.browseDeviceId) then
        targetDevice = {
          name = chosen.browseDeviceName,
          deviceId = chosen.browseDeviceId,
          deviceType = chosen.browseDeviceType,
          desc = chosen.label,
        }
      end
      s.pathPickerContext = "config_ini"
      s.pathPickerTarget = "config_open"
      s.pathPickerFileExts = { ".ini" }
      s.pathPickerSub = "device"
      s.pathPickerLockedDevice = targetDevice
      s.pathPickerLockedDeviceStarted = nil
      s.pathList = targetDevice and { targetDevice } or {}
      s.pathPickerSel = 1
      s.pathPickerScroll = 0
      s.pathBrowsePath = nil
      s.pathPickerReturnState = "choose_load"
      s.state = "path_picker"
      return
    end

    s.currentPath = chosen
    local exists = allowCreate and ((type(s.loadPathExists) == "table" and s.loadPathExists[s.loadSel]) or pathExists(s.currentPath))
    openDbg("choose load selection", "path=" .. tostring(s.currentPath), "allowCreate=" .. tostring(allowCreate),
      "exists=" .. tostring(exists))
    if allowCreate and not exists then
      openDbg("selected missing path; creating new in memory", "path=" .. tostring(s.currentPath))
      initEmptyLinesForFileType(s, "choose_load create missing")
      setStateAfterLoad(s)
      markNewInMemoryConfigState(s)
      openDbg("mark modified", "reason=new file in memory (choose_load missing path)")
      clearLoadChoiceState(s)
    else
      local loaded, loadErr = loadLinesWithDeviceAccess(s.currentPath)
      if loaded then
        s.lines = loaded
        setStateAfterLoad(s)
        clearLoadChoiceState(s)
      else
        openDbg("choose load failed", "path=" .. tostring(s.currentPath), "error=" .. tostring(loadErr))
      end
    end
  end
  if (pad & PAD_CIRCLE) ~= 0 then
    s.state = s.loadReturnState or "select_config"
    clearLoadChoiceState(s)
  end
end

return {
  runMain = runMain,
  runChooseMc = runChooseMc,
  runSelectConfig = runSelectConfig,
  runInitHdd = runInitHdd,
  runOpen = runOpen,
  runChooseLoad = runChooseLoad,
}
