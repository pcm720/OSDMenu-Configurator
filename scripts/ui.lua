--[[
  OSDMenu GUI Configurator — main and editor UI.
  Renders every frame; pad debounced. Main flow in ui_main.lua.
]]

local common = dofile("scripts/ui_common.lua")
local config_parse = dofile("scripts/parse.lua")
local scene_module = dofile("scripts/ui_state.lua")

local function trimString(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function getStartupCwd()
  if System and System.currentDirectory then
    local okCwd, cwdValue = pcall(System.currentDirectory)
    if okCwd and type(cwdValue) == "string" and cwdValue ~= "" then
      return cwdValue
    end
  end
  return nil
end

local function splitHddPartitionPath(path)
  local s = tostring(path or ""):gsub("\\", "/")
  local part, rest = s:match("^(hdd%d:[^:]+):pfs:(.*)$")
  if not part then
    -- Accept FMCB-style partition path (hdd0:__sysconf/dir/file) in addition to :pfs: form.
    part, rest = s:match("^(hdd%d:[^/:]+)(/.*)$")
  end
  if not part then return nil, nil end
  if not rest or rest == "" then rest = "/" end
  if rest:sub(1, 1) ~= "/" then rest = "/" .. rest end
  return part, rest
end

local function beginStartupPathAccess(path)
  local resolved = (common.resolvePathForAccess and common.resolvePathForAccess(path)) or tostring(path or "")
  local moduleType = common.getPathModuleType and common.getPathModuleType(resolved)
  if moduleType and System and System.loadModules then
    pcall(System.loadModules, moduleType)
  end

  local part, rest = splitHddPartitionPath(resolved)
  if part and rest then
    if System and System.fileXioMount then
      pcall(System.fileXioMount, "pfs0:", part)
      return "pfs0:", "pfs0:" .. rest, resolved
    end
    return nil, resolved, resolved
  end
  if resolved:match("^pfs0:/") and System and System.fileXioMount then
    pcall(System.fileXioMount, "pfs0:", "hdd0:__sysconf")
    return "pfs0:", resolved, resolved
  end
  return nil, resolved, resolved
end

local function endStartupPathAccess(mounted)
  if mounted and System and System.fileXioUmount then
    pcall(System.fileXioUmount, mounted)
  end
end

local function startupFileExists(path)
  local mounted, accessPath = beginStartupPathAccess(path)
  local ok, exists = pcall(doesFileExist, accessPath or path)
  endStartupPathAccess(mounted)
  return ok and exists == true
end

local function resolveStartupPath(path)
  if type(path) ~= "string" or path == "" then return nil end
  if startupFileExists(path) then return path end
  if startupFileExists("./" .. path) then return "./" .. path end
  local cwd = getStartupCwd()
  if cwd and cwd ~= "" then
    local base = cwd
    if base:sub(-1) ~= "/" then base = base .. "/" end
    if startupFileExists(base .. path) then
      return base .. path
    end
  end
  return nil
end

local function parseStartupBool(v)
  local s = trimString(v):lower()
  if s == "1" or s == "true" or s == "yes" or s == "on" then return true end
  if s == "0" or s == "false" or s == "no" or s == "off" then return false end
  return nil
end

local function loadStartupConfig()
  local cfg = {
    path = nil,
    video_mode = nil,
    swap_buttons = nil,
    default_language = nil,
    main_filter = nil,
    colors = {},
  }

  local cfgPath = resolveStartupPath("r3configurator.cnf")
  if not cfgPath then
    return cfg
  end

  local mounted, accessPath, resolvedPath = beginStartupPathAccess(cfgPath)
  local lines, err = config_parse.load(accessPath or cfgPath)
  endStartupPathAccess(mounted)
  if not lines then
    print("ui: failed loading startup config r3configurator.cnf: " .. tostring(err))
    return cfg
  end

  cfg.path = resolvedPath or cfgPath
  local kv = {}
  for i = 1, #(lines or {}) do
    local e = lines[i]
    if e and e.key and not e.comment then
      kv[trimString(e.key):lower()] = trimString(e.value or "")
    end
  end

  local vm = trimString(kv.video_mode):lower()
  if vm == "480p" or vm == "pal" or vm == "ntsc" or vm == "auto" then
    cfg.video_mode = vm
  end

  local swap = parseStartupBool(kv.swap_buttons)
  if swap ~= nil then
    cfg.swap_buttons = swap
  end

  local lang = trimString(kv.default_language):lower()
  if lang ~= "" and lang:match("^[%a][%w_]*$") then
    cfg.default_language = lang
  end

  local showKeyToId = {
    show_freemcboot = "freemcboot",
    show_freehddboot = "freehddboot",
    show_osdmenu = "osdmenu",
    show_osdmenu_mbr = "mbr",
    show_hosdmenu = "hosdmenu",
    show_ps2bbl = "ps2bbl",
    show_psxbbl = "psxbbl",
  }
  local filter = {}
  local hasFilter = false
  for key, id in pairs(showKeyToId) do
    local b = parseStartupBool(kv[key])
    if b ~= nil then
      hasFilter = true
      filter[id] = b
    end
  end
  if hasFilter then
    cfg.main_filter = filter
  end

  local colorKeys = {
    "cross", "square", "triangle", "circle",
    "selected", "selected_dim", "unselected", "dim", "background"
  }
  for i = 1, #colorKeys do
    local key = colorKeys[i]
    local value = trimString(kv[key])
    if value ~= "" then
      cfg.colors[key] = value
    end
  end

  return cfg
end

local function normalizeVideoModeSpec(spec)
  if type(spec) ~= "table" then return nil end

  local mode = tonumber(spec.mode or spec.vmode)
  local width = tonumber(spec.width) or 640
  local height = tonumber(spec.height) or 448
  local interlace = tonumber(spec.interlace)
  local field = tonumber(spec.field)

  if type(mode) ~= "number" then
    if interlace == NONINTERLACED and type(_480p) == "number" then
      mode = _480p
    elseif height >= 500 and type(PAL) == "number" then
      mode = PAL
    elseif type(NTSC) == "number" then
      mode = NTSC
    end
  end
  if type(mode) ~= "number" then return nil end

  if type(interlace) ~= "number" then
    if mode == _480p then
      interlace = NONINTERLACED
    else
      interlace = INTERLACED
    end
  end
  if type(field) ~= "number" then
    field = (interlace == NONINTERLACED) and FRAME or FIELD
  end

  local outW = math.max(1, math.floor(width + 0.5))
  local outH = math.max(1, math.floor(height + 0.5))
  return {
    mode = mode,
    width = outW,
    height = outH,
    interlace = interlace,
    field = field,
  }
end

local function captureCurrentVideoModeSpec()
  if not (Screen and Screen.getMode) then return nil end
  local ok, spec = pcall(Screen.getMode)
  if not ok or type(spec) ~= "table" then
    return nil
  end
  return normalizeVideoModeSpec(spec)
end

local flushOverlayLogoCache = nil

local function applyVideoModeSpec(spec)
  local normalized = normalizeVideoModeSpec(spec)
  if not normalized then
    return false, "invalid mode specification"
  end
  if not (Screen and Screen.setMode) then
    return false, "Screen.setMode unavailable"
  end
  if common.flushPadIconCache then
    pcall(common.flushPadIconCache)
  end
  if flushOverlayLogoCache then
    pcall(flushOverlayLogoCache)
  end
  local ok, err = pcall(Screen.setMode, normalized.mode, normalized.width, normalized.height, CT24, normalized.interlace,
    normalized.field)
  if not ok then
    return false, err
  end
  return true
end

local function getVideoModeSpecForKey(modeKey)
  local key = trimString(modeKey):lower()
  local specs = {
    ["480p"] = { mode = _480p, width = 640, height = 480, interlace = NONINTERLACED, field = FRAME },
    ["pal"] = { mode = PAL, width = 640, height = 512, interlace = INTERLACED, field = FIELD },
    ["ntsc"] = { mode = NTSC, width = 640, height = 448, interlace = INTERLACED, field = FIELD },
  }
  local spec = specs[key]
  if not spec then return nil end
  return {
    mode = spec.mode,
    width = spec.width,
    height = spec.height,
    interlace = spec.interlace,
    field = spec.field,
  }
end

local STARTUP_CFG = loadStartupConfig()
local NATIVE_VIDEO_MODE_SPEC = captureCurrentVideoModeSpec()
local STARTUP_CWD = getStartupCwd()

_G.CONFIG_UI = {
  common = common,
  config_parse = config_parse,
  startupConfig = STARTUP_CFG,
  startupCwd = STARTUP_CWD,
  startupMainFilter = STARTUP_CFG.main_filter,
  startupDefaultLanguage = STARTUP_CFG.default_language,
  nativeVideoMode = NATIVE_VIDEO_MODE_SPEC,
  applyVideoModeSpec = applyVideoModeSpec,
  getVideoModeSpecForKey = getVideoModeSpecForKey,
}
local main = dofile("scripts/ui_main.lua")
local file_selector = dofile("scripts/file_selector.lua")
local config_options = dofile("scripts/options.lua")
_G.CONFIG_UI.file_selector = file_selector
_G.CONFIG_UI.config_options = config_options
_G.CONFIG_UI.main = main
-- State modules (editor, choose_save, etc.): each has .run(ctx) and reads/writes ctx.
local scene_editor = dofile("scripts/scenes/editor.lua")
local scene_choose_save = dofile("scripts/scenes/choose_save.lua")
local scene_menu_entries = dofile("scripts/scenes/menu_entries.lua")
local scene_menu_entry_edit = dofile("scripts/scenes/menu_entry_edit.lua")
local scene_entry_cdrom_options = dofile("scripts/scenes/entry_cdrom_options.lua")
local scene_entry_paths = dofile("scripts/scenes/entry_paths.lua")
local scene_entry_args = dofile("scripts/scenes/entry_args.lua")
local scene_bbl_hotkeys = dofile("scripts/scenes/bbl_hotkeys.lua")
local scene_bbl_irx_entries = dofile("scripts/scenes/bbl_irx_entries.lua")
local scene_bbl_hotkey_entries = dofile("scripts/scenes/bbl_hotkey_entries.lua")
local scene_bbl_hotkey_entry = dofile("scripts/scenes/bbl_hotkey_entry.lua")
local scene_bbl_hotkey_args = dofile("scripts/scenes/bbl_hotkey_args.lua")
local scene_text_input = dofile("scripts/scenes/text_input.lua")
local scene_path_picker = dofile("scripts/scenes/path_picker.lua")
local scene_egsm_editor = dofile("scripts/scenes/egsm_editor.lua")
local scene_egsm_value_edit = dofile("scripts/scenes/egsm_value_edit.lua")

local strings = _G.CONFIG_UI.strings
local editor_str = strings.editor
local menu_str = strings.menu_entries
local path_str = strings.path_picker
local common_str = strings.common
local text_str = strings.text_input
local dev_str = strings.devices

-- Local aliases so the rest of the file can stay unchanged
local PAD_UP, PAD_DOWN, PAD_LEFT, PAD_RIGHT = common.PAD_UP, common.PAD_DOWN, common.PAD_LEFT, common.PAD_RIGHT
local PAD_CROSS, PAD_CIRCLE, PAD_START, PAD_TRIANGLE, PAD_SQUARE = common.PAD_CROSS, common.PAD_CIRCLE, common.PAD_START,
    common.PAD_TRIANGLE, common.PAD_SQUARE
local PAD_L1, PAD_R1, PAD_L2, PAD_R2 = common.PAD_L1, common.PAD_R1, common.PAD_L2, common.PAD_R2
local WHITE, GRAY, DIM, DIM_ENTRY, BLACK = common.WHITE, common.GRAY, common.DIM, common.DIM_ENTRY, common.BGCOLOR
local HIGHLIGHT, SELECTED_ENTRY, PREFIX_W = common.HIGHLIGHT, common.SELECTED_ENTRY, common.PREFIX_W
local SELECTED_ENTRY_DIM = common.SELECTED_ENTRY_DIM
local TEXT_CURSOR_COLOR = common.TEXT_CURSOR_COLOR
local FONT_SCALE = common.FONT_SCALE
local VALUE_MAX_LEN, VALUE_MAX_LEN_LONG = common.VALUE_MAX_LEN, common.VALUE_MAX_LEN_LONG
local KEYBOARD_ROWS, KEYBOARD_ROWS_SHIFTED, KEYBOARD_ROWS_TITLE_ID = common.KEYBOARD_ROWS, common.KEYBOARD_ROWS_SHIFTED,
    common.KEYBOARD_ROWS_TITLE_ID
local KEY_BG, KEY_BG_SEL, KEY_BORDER, KEY_BORDER_SEL = common.KEY_BG, common.KEY_BG_SEL, common.KEY_BORDER,
    common.KEY_BORDER_SEL

local function refreshRuntimeColorAliases()
  WHITE, GRAY, DIM, DIM_ENTRY, BLACK = common.WHITE, common.GRAY, common.DIM, common.DIM_ENTRY, common.BGCOLOR
  HIGHLIGHT, SELECTED_ENTRY, PREFIX_W = common.HIGHLIGHT, common.SELECTED_ENTRY, common.PREFIX_W
  SELECTED_ENTRY_DIM = common.SELECTED_ENTRY_DIM
  TEXT_CURSOR_COLOR = common.TEXT_CURSOR_COLOR
end

local function applyStartupVideoModeCnf()
  local modeKey = STARTUP_CFG and STARTUP_CFG.video_mode or nil
  if not modeKey or modeKey == "" or modeKey == "auto" then return end

  local selected = getVideoModeSpecForKey(modeKey)
  if not selected or type(selected.mode) ~= "number" then return end

  local ok, err = applyVideoModeSpec(selected)
  if ok then
    print("ui: startup video mode override from r3configurator.cnf (video_mode=" .. tostring(modeKey) .. ")")
  else
    print("ui: failed startup video mode override from r3configurator.cnf: " .. tostring(err))
  end
end

local function applyStartupSwapButtonsCnf()
  local enabled = (STARTUP_CFG and STARTUP_CFG.swap_buttons == true) and true or false
  if common.setSwapCrossCircle then
    common.setSwapCrossCircle(enabled)
  else
    common.SWAP_CROSS_CIRCLE = (enabled == true)
  end
  _G.CONFIG_UI.swapCrossCircle = enabled == true
  if enabled then
    print("ui: startup button swap override from r3configurator.cnf (swap_buttons=1)")
  end
end

local function parseStartupColorValue(raw)
  local value = tostring(raw or "")
  local trimmed = value:gsub("^%s+", ""):gsub("%s+$", "")
  if trimmed == "" then return nil end

  if trimmed:match("^[%x][%x][%x][%x][%x][%x]$") then
    return tonumber(trimmed:sub(1, 2), 16), tonumber(trimmed:sub(3, 4), 16), tonumber(trimmed:sub(5, 6), 16), 0x80
  end

  return nil
end

local function applyStartupColorsCnf()
  if not (STARTUP_CFG and STARTUP_CFG.path) then return end
  local kv = STARTUP_CFG.colors or {}

  local applied = 0
  local function applyColor(field, key)
    local raw = kv[key]
    local usedKey = key
    if not raw then return end

    local r, g, b, a = parseStartupColorValue(raw)
    if not r then
      print("ui: r3configurator.cnf invalid value for " .. tostring(usedKey) .. ": " .. tostring(raw))
      return
    end

    common[field] = Color.new(r, g, b, a)
    applied = applied + 1
  end

  applyColor("PAD_LABEL_CROSS", "cross")
  applyColor("PAD_LABEL_SQUARE", "square")
  applyColor("PAD_LABEL_TRIANGLE", "triangle")
  applyColor("PAD_LABEL_CIRCLE", "circle")
  applyColor("SELECTED_ENTRY", "selected")
  applyColor("SELECTED_ENTRY_DIM", "selected_dim")
  applyColor("GRAY", "unselected")
  applyColor("DIM", "dim")
  applyColor("BGCOLOR", "background")

  refreshRuntimeColorAliases()

  _G.CONFIG_UI.colorsCnfActive = true
  if applied > 0 then
    print("ui: startup colors override from r3configurator.cnf (" .. tostring(applied) .. " key(s) applied)")
  else
    print("ui: startup colors override from r3configurator.cnf (no valid keys found)")
  end
end

local function getLocations(ctx, ft, slot) return config_options.getLocations(ctx, ft, slot) end
local function loadCustomFont() return common.loadCustomFont() end
local function drawText(font, mode, x, y, scale, text, color) return common.drawText(font, mode, x, y, scale, text, color) end
local function parseColor(v) return common.parseColor(v) end
local function formatColor(r, g, b, a) return common.formatColor(r, g, b, a) end

local function listDirectoryElfOnly(path)
  return common.listDirectoryElfOnly(path, file_selector)
end

local function resolveNextOsdItemKey(lines)
  local prefix = "path1_OSDSYS_ITEM_"
  local entries = config_parse.getByPrefix(lines, prefix)
  local maxN = 0
  for _, entry in ipairs(entries) do
    local num = entry.key and tonumber(entry.key:sub(#prefix + 1))
    if num and num > maxN then maxN = num end
  end
  return prefix .. tostring(maxN + 1)
end

local overlayLogoCache = {}
local OVERLAY_LOGO_OPACITY = 0.25 -- 75% transparent
local OVERLAY_LOGO_OPACITY_R3 = 1.0 -- keep splash/title logo fully visible if selected
local OVERLAY_LOGO_R3_TITLE_KEY = "__r3_title__"
local OVERLAY_LOGO_R3_TITLE_SCALE = 0.50

local function isValidImageHandle(img)
  return type(img) == "number" and img ~= 0
end

flushOverlayLogoCache = function()
  if Graphics and Graphics.freeImage then
    for key, tex in pairs(overlayLogoCache) do
      if isValidImageHandle(tex) then
        pcall(Graphics.freeImage, tex)
      end
      overlayLogoCache[key] = nil
    end
  else
    for key in pairs(overlayLogoCache) do
      overlayLogoCache[key] = nil
    end
  end
end

local function getOverlayLogoColor(key)
  local opacity = (key == "r3configurat3r") and OVERLAY_LOGO_OPACITY_R3 or OVERLAY_LOGO_OPACITY
  return Color.new(0x80, 0x80, 0x80, math.floor(0x80 * opacity + 0.5))
end

local function getSelectionOverlayLogoTexture(key)
  if not key or key == "" then return nil end
  local cached = overlayLogoCache[key]
  if cached ~= nil then
    return (cached ~= false) and cached or nil
  end

  local candidatePaths
  if key == OVERLAY_LOGO_R3_TITLE_KEY then
    candidatePaths = { "res/title.png", "res/logo_r3configurat3r.png" }
  else
    candidatePaths = { "res/logo_" .. tostring(key) .. ".png" }
  end

  for i = 1, #candidatePaths do
    local rawPath = candidatePaths[i]
    local resolvedPath = resolveStartupPath(rawPath)
    local tried = {}
    local loadPaths = {}
    if resolvedPath and resolvedPath ~= "" then
      loadPaths[#loadPaths + 1] = resolvedPath
      tried[resolvedPath] = true
    end
    if rawPath and rawPath ~= "" and not tried[rawPath] then
      loadPaths[#loadPaths + 1] = rawPath
    end
    for j = 1, #loadPaths do
      local ok, img = pcall(Graphics.loadImage, loadPaths[j])
      if ok and isValidImageHandle(img) then
        if Graphics.setImageFilters and LINEAR then
          pcall(Graphics.setImageFilters, img, LINEAR)
        end
        overlayLogoCache[key] = img
        return img
      end
    end
  end

  overlayLogoCache[key] = false
  return nil
end

local function drawSelectionOverlayLogo(ctx)
  if not ctx then return end
  local isR3SettingsScene = (ctx.state ~= "main") and (ctx.context == "r3configurator")
  local key = isR3SettingsScene and OVERLAY_LOGO_R3_TITLE_KEY or ctx.mainOverlayLogoKey
  if not key or key == "" then return end
  local tex = getSelectionOverlayLogoTexture(key)
  if not tex then return end

  local sw = ctx.w or common.DEFAULT_W
  local sh = ctx.h or common.DEFAULT_H
  local iw = (Graphics.getImageWidth and Graphics.getImageWidth(tex)) or 0
  local ih = (Graphics.getImageHeight and Graphics.getImageHeight(tex)) or 0
  if iw <= 0 or ih <= 0 then return end

  local maxW = math.floor(sw * 0.90)
  local maxH = math.floor(sh * 0.72)
  local scale = math.min(1.0, maxW / iw, maxH / ih)
  if isR3SettingsScene then
    scale = math.min(scale, OVERLAY_LOGO_R3_TITLE_SCALE)
  end
  local dw = math.max(1, math.floor(iw * scale + 0.5))
  local dh = math.max(1, math.floor(ih * scale + 0.5))
  local x = math.floor((sw - dw) / 2)
  local y = math.floor((sh - dh) / 2)

  if Graphics.drawScaleImage then
    Graphics.drawScaleImage(tex, x, y, dw, dh, getOverlayLogoColor(key))
  else
    Graphics.drawImage(tex, x, y, getOverlayLogoColor(key))
  end
end

local function mainLoop()
  local font, drawMode = loadCustomFont()
  local function drawListRow(x, y, selected, label, col)
    drawText(font, drawMode, x, y, FONT_SCALE, label, col)
  end

  local ctx = scene_module.initContext()
  ctx.font, ctx.drawMode, ctx.drawListRow = font, drawMode, drawListRow
  ctx.drawBackgroundLayer = drawSelectionOverlayLogo
  ctx.main = {
    (strings.main.main_freemcboot or "FreeMCBoot"),
    (strings.main.main_freehddboot or "FreeHDBoot"),
    (strings.main.main_osdmenu or "OSDMenu"),
    (strings.main.main_osdmenu_mbr or "OSDMenu MBR"),
    (strings.main.main_hosdmenu or "HOSDMenu"),
    (strings.main.main_ps2bbl_mc or "PS2BBL"),
    (strings.main.main_psxbbl_mc or "PSXBBL"),
  }
  if config_options.isEgsmUiEnabled and config_options.isEgsmUiEnabled() then
    table.insert(ctx.main, 6, (strings.main.main_egsm or "eGSM"))
  end

  local mainSel = 1
  local context, fileType, currentPath, lines = "ps2bbl", nil, nil, nil
  local chosenMcSlot = nil
  local state = "main"
  local mcSel = 1
  local hddReady = false
  local prevPad = 0
  local optList, optSel, optScroll, saveSplash = nil, 1, 0, nil
  local editKey = nil
  local pathPickerSub = nil
  local pathPickerSel, pathPickerScroll = 1, 0
  local pathBrowsePath, pathList = nil, nil
  local pathPickerTarget, pathPickerFileExts = nil, nil
  local isAddPath, addPathKey = false, nil
  local pathPickerContext = "osdmenu"
  local pfs1Mounted = nil
  local entryList, entrySel, entryScroll = {}, 1, 0
  local entryIdx, entryEditSub = nil, 1
  local pathPickerForEntryIdx = nil
  local pathPickerBblHotkeyKey, pathPickerBblHotkeySlot, pathPickerBblHotkeyDisabled = nil, nil, nil
  local pathPickerBblIrxIdx, pathPickerBblIrxDisabled = nil, nil
  local textInputPrompt, textInputValue, textInputMaxLen, textInputCallback = nil, "", 79, nil
  local textInputGridSel, textInputShift = 1, false
  local editorCategoryIdx = 0
  local loadChoices, loadSel = nil, 1
  local saveChoices, saveSel = nil, 1
  local entryPathSel, entryPathScroll = 1, 0
  local entryArgSel, entryArgScroll = 1, 0
  local bblIrxSel, bblIrxScroll = 1, 0
  local cdromOptSel = 1
  local pathPickerEditIdx, argEditIdx = nil, nil
  local textInputReturnState, textInputCursor, textInputScroll = "menu_entry_edit", 1, 1
  local holdFrameCount = 0
  local holdRepeatCountdown = 0
  local holdRepeatFps = 0
  local bootKey, pathPickerBootKey, pathPickerReturnState = nil, nil, nil
  local configModified, editorLeavePrompt, returnToSelectConfigAfterSave, returnToSelectConfigAfterSaveFlash = false, nil,
      nil, nil
  local openExplicitPath = nil

  local function syncToS(c)
    c.state, c.lines, c.currentPath, c.fileType, c.context = state, lines, currentPath, fileType, context
    c.chosenMcSlot, c.mainSel, c.mcSel, c.hddReady = chosenMcSlot, mainSel, mcSel, hddReady
    c.optList, c.optSel, c.optScroll, c.saveSplash = optList, optSel, optScroll, saveSplash
    c.editKey, c.pathPickerSub, c.pathPickerSel, c.pathPickerScroll = editKey, pathPickerSub, pathPickerSel,
        pathPickerScroll
    c.pathBrowsePath, c.pathList, c.pathPickerTarget, c.pathPickerFileExts = pathBrowsePath, pathList, pathPickerTarget,
        pathPickerFileExts
    c.isAddPath, c.addPathKey = isAddPath, addPathKey
    c.pathPickerContext, c.pfs1Mounted = pathPickerContext, pfs1Mounted
    c.entryList, c.entrySel, c.entryScroll = entryList, entrySel, entryScroll
    c.entryIdx, c.entryEditSub = entryIdx, entryEditSub
    c.pathPickerForEntryIdx = pathPickerForEntryIdx
    c.pathPickerBblHotkeyKey, c.pathPickerBblHotkeySlot, c.pathPickerBblHotkeyDisabled = pathPickerBblHotkeyKey,
        pathPickerBblHotkeySlot, pathPickerBblHotkeyDisabled
    c.pathPickerBblIrxIdx, c.pathPickerBblIrxDisabled = pathPickerBblIrxIdx, pathPickerBblIrxDisabled
    c.textInputPrompt, c.textInputValue, c.textInputMaxLen = textInputPrompt, textInputValue, textInputMaxLen
    c.textInputGridSel, c.textInputShift = textInputGridSel, textInputShift
    c.editorCategoryIdx = editorCategoryIdx
    c.loadChoices, c.loadSel = loadChoices, loadSel
    c.saveChoices, c.saveSel = saveChoices, saveSel
    c.entryPathSel, c.entryPathScroll = entryPathSel, entryPathScroll
    c.entryArgSel, c.entryArgScroll = entryArgSel, entryArgScroll
    c.bblIrxSel, c.bblIrxScroll = bblIrxSel, bblIrxScroll
    c.cdromOptSel = cdromOptSel
    c.pathPickerEditIdx, c.argEditIdx = pathPickerEditIdx, argEditIdx
    c.textInputReturnState, c.textInputCursor, c.textInputScroll = textInputReturnState, textInputCursor, textInputScroll
    c.bootKey, c.pathPickerBootKey, c.pathPickerReturnState = bootKey, pathPickerBootKey, pathPickerReturnState
    c.prevPad, c.holdFrameCount, c.holdRepeatCountdown, c.holdRepeatFps = prevPad, holdFrameCount,
        holdRepeatCountdown, holdRepeatFps
    c.configModified, c.editorLeavePrompt, c.returnToSelectConfigAfterSave, c.returnToSelectConfigAfterSaveFlash =
        configModified, editorLeavePrompt, returnToSelectConfigAfterSave, returnToSelectConfigAfterSaveFlash
    c.openExplicitPath = openExplicitPath
  end
  local function syncFromS(c)
    state, lines, currentPath, fileType, context = c.state, c.lines, c.currentPath, c.fileType, c.context
    chosenMcSlot, mainSel, mcSel, hddReady = c.chosenMcSlot, c.mainSel, c.mcSel, c.hddReady
    optList, optSel, optScroll, saveSplash = c.optList, c.optSel, c.optScroll, c.saveSplash
    editKey, pathPickerSub, pathPickerSel, pathPickerScroll = c.editKey, c.pathPickerSub, c.pathPickerSel,
        c.pathPickerScroll
    pathBrowsePath, pathList = c.pathBrowsePath, c.pathList
    pathPickerTarget, pathPickerFileExts = c.pathPickerTarget, c.pathPickerFileExts
    isAddPath, addPathKey = c.isAddPath, c.addPathKey
    pathPickerContext, pfs1Mounted = c.pathPickerContext, c.pfs1Mounted
    entryList, entrySel, entryScroll = c.entryList, c.entrySel, c.entryScroll
    entryIdx, entryEditSub = c.entryIdx, c.entryEditSub
    pathPickerForEntryIdx = c.pathPickerForEntryIdx
    pathPickerBblHotkeyKey, pathPickerBblHotkeySlot, pathPickerBblHotkeyDisabled = c.pathPickerBblHotkeyKey,
        c.pathPickerBblHotkeySlot, c.pathPickerBblHotkeyDisabled
    pathPickerBblIrxIdx, pathPickerBblIrxDisabled = c.pathPickerBblIrxIdx, c.pathPickerBblIrxDisabled
    textInputPrompt, textInputValue, textInputMaxLen = c.textInputPrompt, c.textInputValue, c.textInputMaxLen
    textInputGridSel, textInputShift = c.textInputGridSel, c.textInputShift
    editorCategoryIdx = c.editorCategoryIdx
    loadChoices, loadSel = c.loadChoices, c.loadSel
    saveChoices, saveSel = c.saveChoices, c.saveSel
    entryPathSel, entryPathScroll = c.entryPathSel, c.entryPathScroll
    entryArgSel, entryArgScroll = c.entryArgSel, c.entryArgScroll
    bblIrxSel, bblIrxScroll = c.bblIrxSel, c.bblIrxScroll
    cdromOptSel = c.cdromOptSel
    pathPickerEditIdx, argEditIdx = c.pathPickerEditIdx, c.argEditIdx
    textInputReturnState, textInputCursor, textInputScroll = c.textInputReturnState, c.textInputCursor, c
        .textInputScroll
    bootKey, pathPickerBootKey, pathPickerReturnState = c.bootKey, c.pathPickerBootKey, c.pathPickerReturnState
    prevPad, holdFrameCount, holdRepeatCountdown, holdRepeatFps = c.prevPad or prevPad, c.holdFrameCount or 0,
        c.holdRepeatCountdown or 0, c.holdRepeatFps or 0
    configModified, editorLeavePrompt, returnToSelectConfigAfterSave, returnToSelectConfigAfterSaveFlash =
        c.configModified, c.editorLeavePrompt, c.returnToSelectConfigAfterSave, c.returnToSelectConfigAfterSaveFlash
    openExplicitPath = c.openExplicitPath
  end

  -- One-frame dispatch for all states. Main-flow states use runSceneLoop; others use this.
  local function runOneFrame(c)
    syncFromS(c)
    refreshRuntimeColorAliases()
    Screen.clear(BLACK)
    common.runLayout(c)
    local w = c.w or common.DEFAULT_W
    local h = c.h or common.DEFAULT_H
    local uiScale = c.uiScale or 1
    local scaleX = c.scaleX or function(x) return math.floor(((x or 0) * uiScale) + 0.5) end
    local scaleY = c.scaleY or function(y) return math.floor(((y or 0) * uiScale) + 0.5) end
    if _G.CONFIG_UI then
      _G.CONFIG_UI.currentUiScale = uiScale
      _G.CONFIG_UI.currentDrawWidth = math.max(1, scaleX(common.FT_DRAW_W))
      _G.CONFIG_UI.currentDrawHeight = math.max(1, scaleY(common.FT_DRAW_H))
    end
    if c.drawBackgroundLayer then
      c.drawBackgroundLayer(c)
    end
    local HINT_Y = c.HINT_Y
    local DESC_Y_BOTTOM = c.DESC_Y_BOTTOM
    local MARGIN_X = c.MARGIN_X or common.MARGIN_X
    local MARGIN_Y, LINE_H, ROW_H = c.MARGIN_Y, c.LINE_H, c.ROW_H
    local VALUE_X = c.VALUE_X or common.VALUE_X
    local KEYBOARD_CENTER_X = c.KEYBOARD_CENTER_X or ((c.uiOriginX or 0) + scaleX(common.KEYBOARD_CENTER_X))
    local KEYBOARD_CENTER_Y = c.KEYBOARD_CENTER_Y or ((c.uiOriginY or 0) + scaleY(common.KEYBOARD_CENTER_Y))
    local maxVisible = c.MAX_VISIBLE or common.MAX_VISIBLE
    local maxVisibleList = c.MAX_VISIBLE_LIST or common.MAX_VISIBLE_LIST
    local KEY_W = c.KEY_WIDTH or math.max(1, scaleX(common.KEY_WIDTH))
    local KEY_H = c.KEY_HEIGHT or math.max(1, scaleY(common.KEY_HEIGHT))
    local KEY_G = c.KEY_GAP or math.max(1, scaleX(common.KEY_GAP))
    local KEY_CW = c.KEY_CHAR_W or math.max(1, scaleX(common.KEY_CHAR_W))
    local KEY_LH = c.KEY_LINE_H or math.max(1, scaleY(common.KEY_LINE_H))
    if drawMode == "ftPrint" and font then
      local wantPx = math.max(10, math.floor((common.FT_PIXEL_H or 18) * uiScale + 0.5))
      if c._ftPixelSizeApplied ~= wantPx then
        Font.ftSetPixelSize(font, 0, wantPx)
        c._ftPixelSizeApplied = wantPx
      end
      if _G.CONFIG_UI then
        _G.CONFIG_UI.currentFtPixelH = wantPx
      end
    elseif _G.CONFIG_UI then
      _G.CONFIG_UI.currentFtPixelH = nil
    end
    c.prevPad = prevPad
    c.holdFrameCount = holdFrameCount
    c.holdRepeatCountdown = holdRepeatCountdown
    c.holdRepeatFps = holdRepeatFps
    local padEffective = common.getPadEffective(c)
    prevPad = c.prevPad or prevPad
    holdFrameCount = c.holdFrameCount or 0
    holdRepeatCountdown = c.holdRepeatCountdown or 0
    holdRepeatFps = c.holdRepeatFps or holdRepeatFps
    -- Epochs are used by scene-level caches:
    -- scene epoch bumps on state transitions; input epoch bumps after button activity.
    c._sceneEpoch = c._sceneEpoch or 0
    c._inputEpoch = c._inputEpoch or 0
    if c._lastSceneForEpoch ~= state then
      c._sceneEpoch = c._sceneEpoch + 1
      c._lastSceneForEpoch = state
    end
    -- Refresh strings from CONFIG_UI so L1/R1 lang cycle in main menu takes effect in all states.
    local strings = (_G.CONFIG_UI and _G.CONFIG_UI.strings) or strings
    local editor_str = (strings and strings.editor) or editor_str
    local menu_str = (strings and strings.menu_entries) or menu_str
    local path_str = (strings and strings.path_picker) or path_str
    local common_str = (strings and strings.common) or common_str
    local text_str = (strings and strings.text_input) or text_str
    local dev_str = (strings and strings.devices) or dev_str
    -- Frame context for state modules: read/write c.*, use c._ for helpers and constants.
    c._ = {
      font = font,
      drawMode = drawMode,
      w = w,
      h = h,
      padEffective = padEffective,
      drawListRow = drawListRow,
      scaleX = scaleX,
      scaleY = scaleY,
      MARGIN_X = MARGIN_X,
      MARGIN_Y = MARGIN_Y,
      LINE_H = LINE_H,
      ROW_H = ROW_H,
      MAX_VISIBLE = maxVisible,
      MAX_VISIBLE_LIST = maxVisibleList,
      VALUE_X = VALUE_X,
      FONT_SCALE = FONT_SCALE,
      VALUE_MAX_LEN = VALUE_MAX_LEN,
      VALUE_MAX_LEN_LONG = VALUE_MAX_LEN_LONG,
      DESC_Y_BOTTOM = DESC_Y_BOTTOM,
      HINT_Y = HINT_Y,
      SELECTED_ENTRY = SELECTED_ENTRY,
      SELECTED_ENTRY_DIM = SELECTED_ENTRY_DIM,
      WHITE = WHITE,
      GRAY = GRAY,
      DIM = DIM,
      DIM_ENTRY = DIM_ENTRY,
      HIGHLIGHT = HIGHLIGHT,
      TEXT_CURSOR_COLOR = TEXT_CURSOR_COLOR,
      drawText = drawText,
      common = common,
      config_parse = config_parse,
      config_options = config_options,
      strings = strings,
      editor_str = editor_str,
      menu_str = menu_str,
      path_str = path_str,
      common_str = common_str,
      text_str = text_str,
      dev_str = dev_str,
      getLocations = getLocations,
      parseColor = parseColor,
      formatColor = formatColor,
      listDirectoryElfOnly = listDirectoryElfOnly,
      resolveNextOsdItemKey = resolveNextOsdItemKey,
      file_selector = file_selector,
      Graphics = Graphics,
      Color = Color,
      KEYBOARD_CENTER_X = KEYBOARD_CENTER_X,
      KEYBOARD_CENTER_Y = KEYBOARD_CENTER_Y,
      KEY_WIDTH = KEY_W,
      KEY_HEIGHT = KEY_H,
      KEY_GAP = KEY_G,
      KEY_H = KEY_H,
      KEY_LH = KEY_LH,
      KEY_CHAR_W = KEY_CW,
      KEY_BG = KEY_BG,
      KEY_BG_SEL = KEY_BG_SEL,
      KEY_BORDER = KEY_BORDER,
      KEY_BORDER_SEL = KEY_BORDER_SEL,
      KEYBOARD_ROWS = KEYBOARD_ROWS,
      KEYBOARD_ROWS_SHIFTED = KEYBOARD_ROWS_SHIFTED,
      KEYBOARD_ROWS_TITLE_ID = KEYBOARD_ROWS_TITLE_ID,
      PAD_UP = PAD_UP,
      PAD_DOWN = PAD_DOWN,
      PAD_LEFT = PAD_LEFT,
      PAD_RIGHT = PAD_RIGHT,
      PAD_CROSS = PAD_CROSS,
      PAD_CIRCLE = PAD_CIRCLE,
      PAD_START = PAD_START,
      PAD_TRIANGLE = PAD_TRIANGLE,
      PAD_SQUARE = PAD_SQUARE,
      PAD_L1 = PAD_L1,
      PAD_R1 = PAD_R1,
      PAD_L2 = PAD_L2,
      PAD_R2 = PAD_R2,
    }

    if state == "main" then
      main.runMain(ctx, padEffective)
      syncFromS(ctx)
    elseif state == "choose_mc" then
      main.runChooseMc(ctx, padEffective)
      syncFromS(ctx)
    elseif state == "select_config" then
      main.runSelectConfig(ctx, padEffective)
      syncFromS(ctx)
    elseif state == "initHdd" then
      main.runInitHdd(ctx, padEffective)
      syncFromS(ctx)
    elseif state == "open" then
      main.runOpen(ctx, padEffective)
      syncFromS(ctx)
    elseif state == "choose_load" then
      main.runChooseLoad(ctx, padEffective)
      syncFromS(ctx)
    elseif state == "editor" then
      syncToS(c)
      scene_editor.run(c)
      syncFromS(c)
    elseif state == "choose_save" then
      syncToS(c)
      scene_choose_save.run(c)
      syncFromS(c)
    elseif state == "menu_entries" then
      syncToS(c)
      scene_menu_entries.run(c)
      syncFromS(c)
    elseif state == "menu_entry_edit" then
      syncToS(c)
      scene_menu_entry_edit.run(c)
      syncFromS(c)
    elseif state == "entry_cdrom_options" then
      syncToS(c)
      scene_entry_cdrom_options.run(c)
      syncFromS(c)
    elseif state == "entry_paths" then
      syncToS(c)
      scene_entry_paths.run(c)
      syncFromS(c)
    elseif state == "entry_args" then
      syncToS(c)
      scene_entry_args.run(c)
      syncFromS(c)
    elseif state == "bbl_hotkeys" then
      syncToS(c)
      scene_bbl_hotkeys.run(c)
      syncFromS(c)
    elseif state == "bbl_irx_entries" then
      syncToS(c)
      scene_bbl_irx_entries.run(c)
      syncFromS(c)
    elseif state == "bbl_hotkey_entries" then
      syncToS(c)
      scene_bbl_hotkey_entries.run(c)
      syncFromS(c)
    elseif state == "bbl_hotkey_entry" then
      syncToS(c)
      scene_bbl_hotkey_entry.run(c)
      syncFromS(c)
    elseif state == "bbl_hotkey_args" then
      syncToS(c)
      scene_bbl_hotkey_args.run(c)
      syncFromS(c)
    elseif state == "egsm_editor" then
      syncToS(c)
      scene_egsm_editor.run(c)
      syncFromS(c)
    elseif state == "egsm_value_edit" then
      syncToS(c)
      scene_egsm_value_edit.run(c)
      syncFromS(c)
    elseif state == "text_input" then
      syncToS(c)
      scene_text_input.run(c)
      syncFromS(c)
    elseif state == "path_picker" then
      syncToS(c)
      scene_path_picker.run(c)
      syncFromS(c)
    end

    common.refreshConfigModified(c)
    common.drawSaveSplash(c)
    syncFromS(c)
    if padEffective ~= 0 then
      c._inputEpoch = (c._inputEpoch or 0) + 1
    end

    prevPad = c.prevPad or prevPad
    syncToS(c)
    -- Present on vblank to reduce full-screen shimmer/tearing.
    Screen.waitVblankStart()
    Screen.flip()
    return c.state, c
  end
  local sceneNames = { "main", "choose_mc", "select_config", "initHdd", "open", "choose_load", "editor", "choose_save",
    "menu_entries", "menu_entry_edit", "entry_cdrom_options", "entry_paths", "entry_args", "bbl_hotkeys",
    "bbl_irx_entries",
    "bbl_hotkey_entries", "bbl_hotkey_entry", "bbl_hotkey_args", "egsm_editor", "egsm_value_edit", "text_input",
    "path_picker" }
  local scenes = {}
  for _, name in ipairs(sceneNames) do scenes[name] = { run = runOneFrame } end
  -- Main-flow scenes use runSceneLoop (clear, layout, handler, flip until state change).
  local mainFlowHandlers = {
    main = main.runMain,
    choose_mc = main.runChooseMc,
    select_config = main.runSelectConfig,
    initHdd = main.runInitHdd,
    open = main.runOpen,
    choose_load = main.runChooseLoad,
  }
  for name, handler in pairs(mainFlowHandlers) do
    scenes[name] = {
      run = function(ctx)
        return common.runSceneLoop(ctx, name, handler)
      end,
    }
  end
  local currentScene = ctx.state
  while currentScene do
    local scene = scenes[currentScene]
    if not scene or not scene.run then break end
    local nextScene, newCtx = scene.run(ctx)
    ctx = newCtx
    currentScene = nextScene
  end
end

applyStartupVideoModeCnf()
applyStartupSwapButtonsCnf()
applyStartupColorsCnf()
return mainLoop()
