--[[
  Shared constants, colors, font, and helpers for configurator UI.
  No dependency on main loop state.
]]

local common                       = {}

-- Pad bits
common.PAD_UP                      = 0x0010
common.PAD_DOWN                    = 0x0040
common.PAD_LEFT                    = 0x0080
common.PAD_RIGHT                   = 0x0020
common.PAD_CROSS                   = 0x4000
common.PAD_CIRCLE                  = 0x2000
common.PAD_SELECT                  = 0x0001
common.PAD_START                   = 0x0008
common.PAD_TRIANGLE                = 0x1000
common.PAD_SQUARE                  = 0x8000
common.PAD_L1, common.PAD_R1       = 0x0400, 0x0800
common.PAD_L2, common.PAD_R2       = 0x0100, 0x0200
common.SWAP_CROSS_CIRCLE           = false

-- Colors
local FULL_ALPHA                   = 0x80
common.WHITE                       = Color.new(255, 255, 255, FULL_ALPHA)
common.GRAY                        = Color.new(160, 160, 160, FULL_ALPHA)
common.DIM                         = Color.new(96, 96, 96, FULL_ALPHA)
common.ERROR                       = Color.new(255, 64, 64, FULL_ALPHA)
common.BGCOLOR                     = Color.new(20, 20, 20, FULL_ALPHA)
common.HIGHLIGHT                   = Color.new(255, 220, 100, FULL_ALPHA)
common.SELECTED_ENTRY              = Color.new(0x00, 0x72, 0xA0, FULL_ALPHA)
common.SELECTED_ENTRY_DIM          = Color.new(0, 50, 80, FULL_ALPHA)
common.TEXT_CURSOR_COLOR           = Color.new(0x00, 0x72, 0xA0, FULL_ALPHA)
common.OPTION_HINT_COLOR           = Color.new(246, 231, 173, FULL_ALPHA) -- Manila yellow for option descriptions/hints.
common.PREFIX_W                    = 16
common.PAD_LABEL_CROSS             = Color.new(96, 96, 96, FULL_ALPHA) -- pre-button-color-test default
common.PAD_LABEL_SQUARE            = Color.new(96, 96, 96, FULL_ALPHA) -- pre-button-color-test default
common.PAD_LABEL_TRIANGLE          = Color.new(96, 96, 96, FULL_ALPHA) -- pre-button-color-test default
common.PAD_LABEL_CIRCLE            = Color.new(96, 96, 96, FULL_ALPHA) -- pre-button-color-test default

-- Layout
common.FONT_SCALE                  = 0.9
common.LINE_H                      = 22
common.ROW_H                       = 24
common.MARGIN_X, common.MARGIN_Y   = 40, 28
common.DEFAULT_W, common.DEFAULT_H = 640, 448
common.MAX_VISIBLE                 = 10
common.MAX_VISIBLE_LIST            = 12                    -- menu entries, path picker, entry paths, entry args, eGSM editor
common.DIM_ENTRY                   = Color.new(56, 56, 56, FULL_ALPHA) -- darker than DIM for disabled list rows
common.VALUE_X                     = 360
common.VALUE_MAX_LEN               = 38
common.VALUE_MAX_LEN_LONG          = 22
common.HINT_Y                      = 424

-- Pad button hint icons (System/textures/*.png).
-- Layout metrics.
common.PAD_ICON_W                  = 26
common.PAD_ICON_H                  = 26
common.PAD_HINT_GAP                = 5
common.PAD_HINT_ROW_H              = 28
common.PAD_HINT_SIDE_MARGIN        = 16
common.PAD_HINT_TEXT_SCALE         = 0.75
common.PAD_HINT_BASE_SCALE         = 0.7
common.PAD_HINT_TOTAL_H            = common.PAD_HINT_ROW_H -- single-row hint bar
common.DESC_TO_HINT_MARGIN         = 20
common.DESC_Y_BOTTOM               = common.HINT_Y - common.PAD_HINT_TOTAL_H - common.DESC_TO_HINT_MARGIN
common.LIST_BOTTOM_CLEAR_ROWS      = 1 -- keep at least one full blank selectable row above bottom hints/description area

-- Scene transitions
common.SCENE_TRANSITION_DEFAULT_TYPE = "cut"
common.SCENE_TRANSITION_DEFAULT_FRAMES = 10
common.SCENE_TRANSITION_MIN_FRAMES = 1
common.SCENE_TRANSITION_MAX_FRAMES = 60

-- Hint-row geometry tuning (single-row 5-slot layout).
common.PAD_HINT_DEFAULT_WIDTH      = 560
common.PAD_HINT_GRID_EXTRA_W       = 60
common.PAD_HINT_GRID_X_SHIFT       = -55

-- Unused placeholder behavior (code-only).
common.PAD_HINT_DRAW_UNUSED_BUTTONS = true
common.PAD_HINT_UNUSED_ALPHA       = 13 -- ~5% opaque = ~95% transparent
local padIconCache                 = {}
local hintFtFontCache              = {}
local function canOpenPath(path)
  if not (System and System.openFile and System.closeFile) then
    return true
  end
  local h = System.openFile(path, 0)
  if h and h >= 0 then
    System.closeFile(h)
    return true
  end
  return false
end
local padIconNames                 = {
  up = "up",
  down = "down",
  left = "left",
  right = "right",
  cross = "cross",
  circle =
  "circle",
  square = "square",
  triangle = "triangle",
  start = "start",
  select = "select",
  l1 = "L1",
  l2 = "L2",
  l3 = "L3",
  r1 = "R1",
  r2 = "R2",
  r3 = "R3"
}

local function isValidImageHandle(img)
  return type(img) == "number" and img ~= 0
end

function common.getPadIcon(name)
  if type(name) ~= "string" or name == "" then return nil end
  local key = name:lower()
  local file = padIconNames[key] or key
  if padIconCache[file] == nil then
    local ok, img = pcall(Graphics.loadImage, "scripts/textures/" .. file .. ".png")
    if ok and isValidImageHandle(img) and Graphics.setImageFilters and LINEAR then
      pcall(Graphics.setImageFilters, img, LINEAR)
    end
    padIconCache[file] = (ok and isValidImageHandle(img)) and img or false
  end
  return (padIconCache[file] ~= false) and padIconCache[file] or nil
end

function common.flushPadIconCache()
  if Graphics and Graphics.freeImage then
    for key, img in pairs(padIconCache) do
      if type(img) == "number" and img ~= 0 then
        pcall(Graphics.freeImage, img)
      end
      padIconCache[key] = nil
    end
  else
    for key in pairs(padIconCache) do
      padIconCache[key] = nil
    end
  end
end

function common.setSwapCrossCircle(enabled)
  common.SWAP_CROSS_CIRCLE = (enabled == true)
end

function common.isSwapCrossCircle()
  return common.SWAP_CROSS_CIRCLE == true
end

function common.remapCrossCirclePadName(name)
  local key = tostring(name or ""):lower()
  if not common.isSwapCrossCircle() then return key end
  if key == "cross" then return "circle" end
  if key == "circle" then return "cross" end
  return key
end

function common.remapCrossCircleMask(mask)
  if not common.isSwapCrossCircle() then
    return mask
  end
  local hasCross = (mask & common.PAD_CROSS) ~= 0
  local hasCircle = (mask & common.PAD_CIRCLE) ~= 0
  local out = mask & ~(common.PAD_CROSS | common.PAD_CIRCLE)
  if hasCross then out = out | common.PAD_CIRCLE end
  if hasCircle then out = out | common.PAD_CROSS end
  return out
end

function common.makeDebugLogger(flagName, prefix)
  local flagKey = tostring(flagName or "")
  local msgPrefix = tostring(prefix or "")
  return function(...)
    if flagKey ~= "" and _G and _G[flagKey] == false then return end
    local parts = {}
    for i = 1, select("#", ...) do
      parts[#parts + 1] = tostring(select(i, ...))
    end
    print(msgPrefix .. table.concat(parts, " "))
  end
end

function common.findHintLabel(items, pad, fallback)
  local target = tostring(pad or ""):lower()
  for i = 1, #(items or {}) do
    local item = items[i]
    local itemPad = tostring(item and item.pad or ""):lower()
    local label = tostring(item and item.label or "")
    if itemPad == target and label ~= "" then
      return label
    end
  end
  return fallback
end

function common.withStartHintVisibility(items, showStart)
  if showStart then return items end
  local out = {}
  for i = 1, #(items or {}) do
    local item = items[i]
    if item and item.pad ~= "start" then
      out[#out + 1] = item
    else
      out[#out + 1] = { pad = "", label = "", row = item and item.row or 1 }
    end
  end
  return out
end

function common.bootKeyToPadName(key)
  if key == "boot_start" then return "start" end
  if key == "boot_triangle" then return "triangle" end
  if key == "boot_circle" then return "circle" end
  if key == "boot_cross" then return "cross" end
  if key == "boot_square" then return "square" end
  return nil
end

function common.isBblContext(context)
  return context == "ps2bbl" or context == "psxbbl"
end

function common.isOsdConfigFileType(fileType)
  return fileType == "osdmenu_cnf" or fileType == "osdgsm_cnf"
end

function common.getNextStateAfterMcSelection(context)
  if common.isBblContext(context) then return "select_config" end
  if context == "osdmenu" or context == "hosdmenu" then return "select_config" end
  return "open"
end

function common.getOpenParentState(context, fileType)
  if common.isBblContext(context) then
    return "select_config"
  end
  if (context == "freemcboot" or context == "freehddboot") and fileType == "freemcboot_cnf" then
    return "select_config"
  end
  if (context == "osdmenu" or context == "hosdmenu") and common.isOsdConfigFileType(fileType) then
    return "select_config"
  end
  return "main"
end

function common.getEditorBackState(context, fileType, getPresentMcSlots)
  if common.isBblContext(context) then
    return "select_config"
  end
  if (context == "freemcboot" or context == "freehddboot") and fileType == "freemcboot_cnf" then
    return "select_config"
  end
  if context == "hosdmenu" and common.isOsdConfigFileType(fileType) then
    return "select_config"
  end
  if context == "osdmenu" and common.isOsdConfigFileType(fileType) then
    local slots = (type(getPresentMcSlots) == "function" and getPresentMcSlots()) or {}
    if type(slots) == "table" and #slots > 1 then
      return "choose_mc"
    end
    return "main"
  end
  return "main"
end

function common.configureBelTextInput(ctx, opts)
  if not ctx then return end
  opts = opts or {}
  local allowBel = (opts.allow == true)
  local profile = opts.profile
  if profile == nil then
    local context = tostring(opts.context or ctx.context or ""):lower()
    profile = ((context == "freehddboot") or (context == "hosdmenu")) and "hddosd" or "ps2rom"
  end

  ctx.textInputEnableBelKey = allowBel and true or nil
  ctx.textInputBelProfile = allowBel and tostring(profile or "ps2rom") or nil
  ctx.textInputAllowBelAdd = allowBel and true or nil

  if opts.hidePipeBackslash ~= nil then
    ctx.textInputHidePipeBackslash = (opts.hidePipeBackslash == true) and true or nil
  else
    ctx.textInputHidePipeBackslash = nil
  end
end

function common.formatBelForDisplay(text)
  local s = tostring(text or "")
  if s == "" then return s end
  return s:gsub(string.char(7), "\226\150\161")
end

function common.drawPadTitle(_, padName, titleText, opts)
  if type(_) ~= "table" then return end
  opts = opts or {}
  local x = tonumber(opts.x) or _.MARGIN_X or 0
  local y = tonumber(opts.y) or _.MARGIN_Y or 0
  local lineH = tonumber(opts.lineH) or _.LINE_H or 26
  local gap = tonumber(opts.gap) or 8
  local scale = tonumber(opts.scale) or 1
  local color = opts.color or _.WHITE
  local label = tostring(titleText or "")

  local icon = padName and common.getPadIcon and common.getPadIcon(padName) or nil
  local baseIconW = common.PAD_ICON_W or 26
  local baseIconH = common.PAD_ICON_H or 26
  local textH = common.FT_PIXEL_H or 18
  local iconH = math.min(baseIconH, textH)
  local iconW = math.max(1, math.floor((baseIconW * iconH) / baseIconH + 0.5))
  local iconY = y + math.floor((lineH - iconH) / 2)

  if icon then
    if _.Graphics and _.Graphics.drawScaleImage then
      _.Graphics.drawScaleImage(icon, x, iconY, iconW, iconH)
    elseif _.Graphics and _.Graphics.drawImage then
      _.Graphics.drawImage(icon, x, iconY)
    end
  end

  local textX = x + iconW + gap
  if _.drawText then
    _.drawText(_.font, _.drawMode, textX, y, scale, label, color)
  end
end

function common.drawBootTitle(_, bootKey, titleLabel)
  local padName = common.bootKeyToPadName(bootKey)
  common.drawPadTitle(_, padName, "- " .. tostring(titleLabel or ""))
end

function common.drawHotkeyTitle(_, keyId, suffix)
  local tail = tostring(suffix or "")
  if keyId == "AUTO" then
    if _ and _.drawText then
      _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, "AUTOBOOT" .. tail, _.WHITE)
    end
    return
  end
  common.drawPadTitle(_, keyId, tail)
end

function common.formatDisplayPathWithCommands(_, pathVal)
  local raw = tostring(pathVal or "")
  local up = raw:gsub("^%s+", ""):gsub("%s+$", ""):upper()
  local p = (_ and _.path_str) or {}
  if up == "$CDVD" then return p.bbl_cmd_cdvd_label or "Launch disc" end
  if up == "$CDVD_NO_PS2LOGO" then return p.bbl_cmd_cdvd_no_logo_label or "Launch disc skip PS2 logo" end
  if up == "$OSDSYS" then return p.bbl_cmd_osdsys_label or "OSDSYS" end
  if up == "$CREDITS" then return p.bbl_cmd_credits_label or "Credits" end
  if up == "$HDDCHECKER" then return p.bbl_cmd_hddchecker_label or "Check HDD" end
  if common.normalizePathForDisplay then
    return common.normalizePathForDisplay(raw)
  end
  return raw
end

function common.trimPathValue(pathVal)
  return tostring(pathVal or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function common.pathTokenUpper(pathVal)
  return common.trimPathValue(pathVal):upper()
end

function common.isBblSpecialExclusivePath(pathVal)
  local up = common.pathTokenUpper(pathVal)
  return up == "$CDVD" or up == "$CDVD_NO_PS2LOGO" or up == "$CREDITS" or up == "$HDDCHECKER"
end

-- Canonicalize HDD APA/PFS display paths:
-- - hdd0:PART:pfs:foo   -> hdd0:PART:pfs:/foo
-- - hdd0:/PART/dir/file -> hdd0:PART:pfs:/dir/file
-- - hdd0:PART/dir/file  -> hdd0:PART:pfs:/dir/file
function common.normalizePathForDisplay(path)
  local raw = tostring(path or "")
  if raw == "" then return raw end
  raw = raw:gsub("\\", "/")

  local dev, part, rest = raw:match("^(hdd%d):/?([^:/]+):pfs:(.*)$")
  if dev and part then
    local suffix = tostring(rest or "")
    if suffix == "" then
      suffix = "/"
    else
      suffix = "/" .. suffix:gsub("^/+", "")
    end
    return dev .. ":" .. part .. ":pfs:" .. suffix
  end

  dev, part, rest = raw:match("^(hdd%d):/?([^:/]+)/(.*)$")
  if dev and part then
    local suffix = tostring(rest or ""):gsub("^/+", "")
    if suffix == "" then
      suffix = "/"
    else
      suffix = "/" .. suffix
    end
    return dev .. ":" .. part .. ":pfs:" .. suffix
  end

  return raw
end

local function isDeviceAbsolutePath(path)
  local p = tostring(path or "")
  if p == "" then return false end
  if p:match("^[%w_]+:") then return true end
  if p:sub(1, 1) == "/" then return true end
  return false
end

function common.resolvePathForAccess(path)
  local raw = tostring(path or "")
  if raw == "" then return raw end
  local p = raw:gsub("\\", "/")
  if isDeviceAbsolutePath(p) then
    return p
  end
  if p:sub(1, 2) == "./" then
    p = p:sub(3)
  end

  local base = (_G and _G.CONFIG_UI and _G.CONFIG_UI.startupCwd) or nil
  if type(base) ~= "string" or base == "" then
    if System and System.currentDirectory then
      local okCwd, cwd = pcall(System.currentDirectory)
      if okCwd and type(cwd) == "string" and cwd ~= "" then
        base = cwd
      end
    end
  end
  base = tostring(base or ""):gsub("\\", "/")
  if base ~= "" and isDeviceAbsolutePath(base) then
    if base:sub(-1) ~= "/" then
      base = base .. "/"
    end
    return base .. p
  end
  return p
end

function common.mapPartitionPathToMountedPfs(path)
  if not path then return nil, nil end
  local raw = tostring(path):gsub("\\", "/")
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

function common.beginPathAccess(path, opts)
  opts = opts or {}
  local resolvedPath = common.resolvePathForAccess(path)
  local loadModule = (opts.loadModule ~= false)
  local mountPartition = (opts.mountPartition ~= false)

  if loadModule then
    local moduleType = common.getPathModuleType and common.getPathModuleType(resolvedPath)
    if moduleType and System and System.loadModules then
      pcall(System.loadModules, moduleType)
    end
  end

  if not mountPartition then
    return nil, resolvedPath, nil
  end

  local part, mapped = common.mapPartitionPathToMountedPfs(resolvedPath)
  if part and mapped then
    local mounted = nil
    if System and System.fileXioMount then
      pcall(System.fileXioMount, "pfs0:", part)
      mounted = "pfs0:"
    end
    return mounted, mapped, part
  end

  local mounted = nil
  if resolvedPath and resolvedPath:match("^pfs0:/") and System and System.fileXioMount then
    pcall(System.fileXioMount, "pfs0:", "hdd0:__sysconf")
    mounted = "pfs0:"
  end
  return mounted, resolvedPath, nil
end

function common.endPathAccess(mounted)
  if mounted and System and System.fileXioUmount then
    pcall(System.fileXioUmount, mounted)
  end
end

local function getRuntimeFtPixelBase()
  local runtimePx = (_G.CONFIG_UI and tonumber(_G.CONFIG_UI.currentFtPixelH)) or 0
  if runtimePx > 0 then
    return runtimePx
  end
  return tonumber(common.FT_PIXEL_H) or 18
end

local function loadFtFontWithFallback()
  if not (Font and Font.ftLoad) then return nil end
  local cwdCandidates = { "font.ttf" }
  for i = 1, #cwdCandidates do
    local path = cwdCandidates[i]
    if canOpenPath(path) then
      local f = Font.ftLoad(path)
      if f and f >= 0 then
        return f
      end
    end
  end
  -- Always try bundled font directly; VFS paths may resolve even when System.openFile probe does not.
  local bundled = Font.ftLoad("scripts/font/font.ttf")
  if bundled and bundled >= 0 then
    return bundled
  end
  return nil
end

local function getHintFtFont(scaleFactor)
  local sf = tonumber(scaleFactor) or 1
  if sf <= 0 then sf = 1 end
  local basePx = getRuntimeFtPixelBase()
  local key = string.format("%d@%.3f", math.floor(basePx + 0.5), sf)
  if hintFtFontCache[key] then return hintFtFontCache[key] end
  local f = loadFtFontWithFallback()
  if f and f >= 0 then
    if Font.ftSetPixelSize then
      local px = math.max(8, math.floor((basePx * sf) + 0.5))
      pcall(Font.ftSetPixelSize, f, 0, px)
    end
    hintFtFontCache[key] = f
    return hintFtFontCache[key]
  end
  return nil
end

function common.getHintFont(fallbackFont, drawMode, textScale)
  local hintFont = fallbackFont
  if drawMode == "ftPrint" then
    local f = getHintFtFont(textScale or 1)
    if f then hintFont = f end
  end
  return hintFont
end

function common.getHintLabelDrawScale(baseScale)
  local bs = tonumber(baseScale) or common.PAD_HINT_BASE_SCALE or 0.7
  local ts = tonumber(common.PAD_HINT_TEXT_SCALE) or 0.75
  return bs * ts
end

function common.getHintLabelTextHeight()
  local ts = tonumber(common.PAD_HINT_TEXT_SCALE) or 0.75
  local basePx = getRuntimeFtPixelBase()
  return math.max(10, math.floor(basePx * ts + 0.5))
end

-- Draw a hint line: list of { pad = "cross", label = "Select" }.
-- Single-row 5-slot layout (top row removed in new UX).
-- totalWidth: optional. y = bottom of hint area.
function common.drawHintLine(font, drawMode, x, y, scale, hintItems, textFallback, color, totalWidth)
  if not color then color = common.DIM end
  local function getPadLabelColor(padName, fallbackColor)
    local key = tostring(padName or ""):lower()
    if key == "cross" then return common.PAD_LABEL_CROSS end
    if key == "square" then return common.PAD_LABEL_SQUARE end
    if key == "triangle" then return common.PAD_LABEL_TRIANGLE end
    if key == "circle" then return common.PAD_LABEL_CIRCLE end
    if key == "start" or key == "l1" or key == "r1" then return common.WHITE end
    return fallbackColor
  end
  if hintItems and #hintItems > 0 then
    local iconScale = 0.6
    local textScale = tonumber(common.PAD_HINT_TEXT_SCALE) or 0.75
    local drawScale = common.getHintLabelDrawScale(scale)
    local iconW = math.max(10, math.floor((common.PAD_ICON_W or 26) * iconScale + 0.5))
    local iconH = math.max(10, math.floor((common.PAD_ICON_H or 26) * iconScale + 0.5))
    local gap = math.max(2, math.floor((common.PAD_HINT_GAP or 5) * textScale + 0.5))
    local textH = common.getHintLabelTextHeight()
    local rowH = math.max(14, math.floor((common.PAD_HINT_ROW_H or 28) * textScale + 0.5), textH + 4)
    local approxCharW = math.floor(8 * drawScale)
    local width = (type(totalWidth) == "number" and totalWidth > 0) and totalWidth or common.PAD_HINT_DEFAULT_WIDTH
    width = width + (tonumber(common.PAD_HINT_GRID_EXTRA_W) or 0)
    local sideMargin = common.PAD_HINT_SIDE_MARGIN or 0
    local xEff = x + sideMargin + (tonumber(common.PAD_HINT_GRID_X_SHIFT) or 0)
    local widthEff = width - 2 * sideMargin
    local rowPads
    if common.isSwapCrossCircle() then
      rowPads = { "circle", "square", "start", "triangle", "cross" }
    else
      rowPads = { "cross", "square", "start", "triangle", "circle" }
    end
    local slotCount = #rowPads
    local slotW = widthEff / slotCount
    local hintFont = common.getHintFont(font, drawMode, textScale)

    local function getTextWidth(label)
      if not label or label == "" then return 0 end
      if common.calcTextWidth then
        local w = common.calcTextWidth(hintFont, label, drawScale)
        if type(w) == "number" and w > 0 then
          return w
        end
      end
      if drawMode == "ftPrint" and hintFont and Font and Font.ftCalcDimensions then
        local w = Font.ftCalcDimensions(hintFont, label)
        return (type(w) == "number" and w > 0) and w or math.floor(approxCharW * #label)
      end
      return math.floor(approxCharW * #label)
    end

    local rowSlots = {}
    local rowMap = {}
    local drawUnusedButtons = common.PAD_HINT_DRAW_UNUSED_BUTTONS == true
    for i = 1, slotCount do
      rowMap[rowPads[i]] = true
    end

    local activeByPad = {}
    for i = 1, #hintItems do
      local item = hintItems[i]
      local rawPad = tostring((item and item.pad) or "")
      local key = rawPad:gsub("^%s+", ""):gsub("%s+$", ""):lower()
      key = common.remapCrossCirclePadName(key)
      if key ~= "" and not activeByPad[key] and rowMap[key] then
        activeByPad[key] = { label = tostring(item.label or "") }
      end
    end

    for i = 1, slotCount do
      local key = rowPads[i]
      local active = activeByPad[key]
      if drawUnusedButtons or active then
        rowSlots[i] = { pad = key, label = active and active.label or "", used = not not active }
      end
    end

    local totalRowH = rowH
    local rowTop = math.floor(y) - totalRowH

    local function drawRow(slots, rowIndex)
      local rTop = rowTop + rowIndex * rowH
      local rowCenter = rTop + rowH / 2
      local iconY = math.floor(rowCenter - iconH / 2)
      local textY = math.floor(rowCenter - textH / 2) - 4
      local activeIconColor = Color.new(255, 255, 255, FULL_ALPHA)
      local inactiveIconColor = Color.new(255, 255, 255, common.PAD_HINT_UNUSED_ALPHA or 38)
      local function drawActiveIcon(icon, px)
        if Graphics.drawScaleImage then
          local drawScaled = Graphics.drawScaleImage
          local ok = pcall(drawScaled, icon, px, iconY, iconW, iconH)
          if not ok then
            drawScaled(icon, px, iconY, iconW, iconH, activeIconColor)
          end
        else
          Graphics.drawImage(icon, px, iconY)
        end
      end
      for col = 1, slotCount do
        local item = slots[col]
        local padName = item and item.pad
        local label = (item and item.label) or ""
        local isUsed = item and item.used
        local active = (padName and activeByPad[padName]) or nil
        if active then
          isUsed = true
          if label == "" then
            label = active.label or ""
          end
        end
        if padName and padName ~= "" then
          local icon = common.getPadIcon(padName)
          local slotLeft = xEff + (col - 1) * slotW
          local slotCenter = slotLeft + slotW / 2
          local px = math.floor(slotCenter - iconW / 2)
          if icon then
            if isUsed then
              drawActiveIcon(icon, px)
            else
              if Graphics.drawScaleImage then
                Graphics.drawScaleImage(icon, px, iconY, iconW, iconH, inactiveIconColor)
              else
                Graphics.drawImage(icon, px, iconY, inactiveIconColor)
              end
            end
          end
          if isUsed and label ~= "" then
            local textW = getTextWidth(label)
            local textX
            if icon then
              textX = px + iconW + gap
            else
              textX = math.floor(slotCenter - textW / 2)
            end
            local labelColor = getPadLabelColor(padName, color)
            common.drawText(hintFont, drawMode, textX, textY, drawScale, label, labelColor, textH)
          end
        end
      end
    end

    drawRow(rowSlots, 0)
    return
  end
  if textFallback and textFallback ~= "" then
    local rowTop = math.floor(y) - common.PAD_HINT_ROW_H
    common.drawText(font, drawMode, x, rowTop + math.floor((common.PAD_HINT_ROW_H - 16) / 2), scale, textFallback, color)
  end
end

-- Build editor hint items: show ±1/±10/±50 only for string; enum/bool use left/right with enumHintLabels.
-- Show Reset only when option has default.
function common.buildEditorHintItems(selOpt, hintEditItems, getDefaultFn, enumHintLabels)
  if not hintEditItems or #hintEditItems == 0 then return hintEditItems end
  local numericPads = { left = true, right = true, L1 = true, R1 = true, L2 = true, R2 = true }
  local showNumeric = selOpt and
      (selOpt.optType == "string" or selOpt.optType == "enum" or selOpt.optType == "bool")
  local showReset = selOpt and selOpt.key and selOpt.key:sub(1, 1) ~= "_" and selOpt.optType ~= "header" and getDefaultFn and
      getDefaultFn(selOpt.key) ~= nil
  local out = {}
  for _, item in ipairs(hintEditItems) do
    local pad = (item.pad or ""):lower()
    if pad == "l1" or pad == "r1" or pad == "l2" or pad == "r2" then pad = pad:upper() end
    if numericPads[pad] then
      if showNumeric and ((selOpt.optType ~= "enum" and selOpt.optType ~= "bool") or pad == "left" or pad == "right") then
        local toInsert = item
        if (selOpt.optType == "enum" or selOpt.optType == "bool") and (pad == "left" or pad == "right") and enumHintLabels and
            enumHintLabels[pad] then
          toInsert = { pad = item.pad, label = enumHintLabels[pad], row = item.row }
        elseif selOpt.optType ~= "enum" and selOpt.intPadLabels and selOpt.intPadLabels[pad] then
          toInsert = { pad = item.pad, label = tostring(selOpt.intPadLabels[pad]), row = item.row }
        end
        table.insert(out, toInsert)
      end
    elseif pad == "triangle" then
      if showReset then table.insert(out, item) end
    else
      table.insert(out, item)
    end
  end
  return out
end

-- Open an actions overlay with consistent state key initialization.
function common.openActionsMenu(ctx, openKey, selKey, scrollKey, opts)
  if not ctx then return end
  local openStateKey = tostring(openKey or "actionsMenuOpen")
  local selStateKey = tostring(selKey or "actionsMenuSel")
  local scrollStateKey = tostring(scrollKey or "actionsMenuScroll")
  opts = opts or {}

  ctx[openStateKey] = true
  if ctx[selStateKey] == nil then
    ctx[selStateKey] = tonumber(opts.defaultSel) or 1
  end
  if ctx[scrollStateKey] == nil then
    ctx[scrollStateKey] = tonumber(opts.defaultScroll) or 0
  end
end

function common.drawCenteredPromptModal(_, promptText, opts)
  if type(_) ~= "table" then return end
  opts = opts or {}
  local prompt = tostring(promptText or "")
  local padX = tonumber(opts.padX) or 24
  local padY = tonumber(opts.padY) or 14
  local lineH = _.LINE_H or common.LINE_H
  local maxTextW = math.max(80, (_.w or common.DEFAULT_W) - (((_.MARGIN_X or common.MARGIN_X) * 2) + (padX * 2)))
  if common.truncateTextToWidth then
    prompt = common.truncateTextToWidth(_.font, prompt, maxTextW, 1)
  end
  local textW = (common.calcTextWidth and common.calcTextWidth(_.font, prompt, 1)) or (#prompt * 14)
  local boxW = textW + (padX * 2)
  local boxH = lineH + (padY * 2)
  local boxX = math.floor(((_.w or common.DEFAULT_W) - boxW) / 2)
  local boxY = math.floor(((_.h or common.DEFAULT_H) - boxH) / 2)
  local bg = opts.bgColor or (Color and Color.new and Color.new(40, 40, 48, 110)) or common.DIM
  if _.Graphics and _.Graphics.drawRect then
    _.Graphics.drawRect(boxX, boxY, boxW, boxH, bg)
  end
  local textX = boxX + math.floor((boxW - textW) / 2)
  local textY = boxY + math.floor((boxH - lineH) / 2)
  if common.drawText then
    common.drawText(_.font, _.drawMode, textX, textY, 1, prompt, _.WHITE or common.WHITE)
  end
end

-- Shared leave-save prompt flow for editor-like scenes.
-- opts: { onSave, onDiscard, onCancel, drawPrompt(ctx, _, prompt), prompt }
function common.handleLeaveSavePrompt(ctx, opts)
  if not (ctx and ctx.editorLeavePrompt) then
    return false
  end
  local _ = ctx._
  if type(_) ~= "table" then
    return false
  end
  opts = opts or {}
  local prompt = tostring(opts.prompt or (_.editor_str and _.editor_str.leave_save_prompt) or
    "Save changes before leaving?")
  if type(opts.drawPrompt) == "function" then
    opts.drawPrompt(ctx, _, prompt)
  else
    common.drawCenteredPromptModal(_, prompt)
  end
  common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.editor_str.leave_save_hint_items, nil, _.DIM,
    _.w - 2 * _.MARGIN_X)
  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    ctx.editorLeavePrompt = nil
    if type(opts.onSave) == "function" then
      opts.onSave()
    end
  elseif (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
    ctx.editorLeavePrompt = nil
    if type(opts.onDiscard) == "function" then
      opts.onDiscard()
    end
  elseif (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.editorLeavePrompt = nil
    if type(opts.onCancel) == "function" then
      opts.onCancel()
    end
  end
  return true
end

-- Keyboard: full QWERTY rows 1-=, q-\ , a-', z-/
common.KEYBOARD_ROWS = { "1234567890-=", "qwertyuiop[]\\", "asdfghjkl;'", "zxcvbnm,./" }
common.KEYBOARD_ROWS_SHIFTED = { "!@#$%^&*()_+", "QWERTYUIOP{}|", "ASDFGHJKL:\"", "ZXCVBNM<>?" }
-- Title ID only: digits + uppercase letters, no shift (e.g. eGSM AAAA_000.00). No symbols.
common.KEYBOARD_ROWS_TITLE_ID = { "1234567890", "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" }
common.KEYBOARD_ROW_OFFSETS = { 0.0, 0.5, 0.85, 1.2 }
common.KEYBOARD_ROW_OFFSETS_TITLE_ID = { 0.0, 0.5, 0.85, 1.2 }
common.KEYBOARD_CENTER_X, common.KEYBOARD_CENTER_Y = 320, 220
common.KEY_WIDTH, common.KEY_HEIGHT = 34, 26
common.KEY_GAP = 2
common.KEY_BG = Color.new(56, 56, 56, FULL_ALPHA)
common.KEY_BG_SEL = Color.new(80, 80, 80, FULL_ALPHA)
common.KEY_BORDER = Color.new(100, 100, 100, FULL_ALPHA)
common.KEY_BORDER_SEL = Color.new(180, 160, 100, FULL_ALPHA)
common.KEY_CHAR_W = 10
common.KEY_LINE_H = 14

common.FT_PIXEL_H = 18
common.FT_DRAW_W, common.FT_DRAW_H = 620, 24

function common.tryOpen(path)
  local h = System.openFile(path, 0)
  if h and h >= 0 then
    System.closeFile(h); return true
  end
  return false
end

function common.isHddPresent()
  if not System or not System.listDirectory then return false end
  local ok, list = pcall(function() return System.listDirectory("hdd0:") end)
  return ok and type(list) == "table"
end

function common.getPresentMcSlots()
  local out = {}
  if common.tryOpen("mc0:/") then table.insert(out, 0) end
  if common.tryOpen("mc1:/") then table.insert(out, 1) end
  table.sort(out)
  return out
end

local function getConfigParser(ctx)
  if ctx and ctx._ and ctx._.config_parse then
    return ctx._.config_parse
  end
  if _G and _G.CONFIG_UI and _G.CONFIG_UI.config_parse then
    return _G.CONFIG_UI.config_parse
  end
  return nil
end

local function deepCloneValue(value, seen)
  if type(value) ~= "table" then
    return value
  end
  seen = seen or {}
  if seen[value] then
    return seen[value]
  end
  local out = {}
  seen[value] = out
  for k, v in pairs(value) do
    out[deepCloneValue(k, seen)] = deepCloneValue(v, seen)
  end
  local mt = getmetatable(value)
  if mt ~= nil then
    setmetatable(out, mt)
  end
  return out
end

function common.cloneConfigLines(lines)
  return deepCloneValue(lines or {})
end

local function fallbackSemanticDigest(lines)
  local out = {}
  for i = 1, #(lines or {}) do
    local entry = lines[i]
    if entry and entry.key then
      local key = tostring(entry.key)
      local value = tostring(entry.value or "")
      local commentState = 0
      if entry.comment == 2 then
        commentState = 2
      elseif entry.comment then
        commentState = 1
      end
      out[#out + 1] =
          tostring(#key) .. ":" .. key .. "|" .. tostring(#value) .. ":" .. value .. "|" .. tostring(commentState)
    end
  end
  return table.concat(out, "\n")
end

local function computeSemanticDigest(ctx, lines)
  local parser = getConfigParser(ctx)
  local digestLines = lines or {}

  if parser and parser.semanticDigest then
    return parser.semanticDigest(digestLines)
  end
  return fallbackSemanticDigest(digestLines)
end

function common.refreshConfigModified(ctx)
  if not ctx then return false end
  if not ctx.lines then
    ctx.configModified = false
    ctx._configModifiedCache = nil
    return false
  end

  local cache = ctx._configModifiedCache
  local sceneEpoch = tonumber(ctx._sceneEpoch) or 0
  local inputEpoch = tonumber(ctx._inputEpoch) or 0
  -- Global performance rule:
  -- avoid per-frame full semantic digest recomputation while navigating.
  -- Input-only movement should hit cache; recompute when config state changes.
  local isCurrentlyModified = ctx.configModified and true or false
  local lineCount = #(ctx.lines or {})
  local cleanDigest = ctx.configCleanSemanticDigest
  local needsInitialSave = (ctx.configNeedsInitialSave == true)
  local cacheHit = cache and
      cache.linesRef == ctx.lines and
      cache.sceneEpoch == sceneEpoch and
      cache.cleanDigest == cleanDigest and
      cache.needsInitialSave == needsInitialSave and
      cache.lineCount == lineCount and
      cache.result == isCurrentlyModified
  -- When already dirty, keep inputEpoch as a conservative invalidator so reverting
  -- back to the clean semantic state is detected on edit input.
  if cacheHit and ((not isCurrentlyModified) or cache.inputEpoch == inputEpoch) then
    ctx.configModified = cache.result and true or false
    return ctx.configModified
  end

  if ctx.configCleanSemanticDigest == nil then
    ctx.configCleanSemanticDigest = computeSemanticDigest(ctx, ctx.lines)
    cleanDigest = ctx.configCleanSemanticDigest
  end

  local currentDigest = computeSemanticDigest(ctx, ctx.lines)
  local semanticChanged = currentDigest ~= (ctx.configCleanSemanticDigest or "")
  ctx.configModified = semanticChanged or needsInitialSave
  ctx._configModifiedCache = {
    linesRef = ctx.lines,
    sceneEpoch = sceneEpoch,
    inputEpoch = inputEpoch,
    cleanDigest = ctx.configCleanSemanticDigest,
    needsInitialSave = needsInitialSave,
    lineCount = lineCount,
    result = ctx.configModified and true or false,
    digest = currentDigest
  }
  return ctx.configModified
end

function common.getPathModuleType(path)
  local p = tostring(path or ""):lower()
  if p == "" then return nil end
  if p:match("^massx:") then return "mx4sio" end
  if p:match("^mmce%d:") then return "mmce" end
  if p:match("^hdd%d:") or p:match("^pfs%d:") then return "hdd" end
  if p:match("^mass:") or p:match("^mass%d:") then return "usb" end
  return nil
end

local function resolveSaveTargetModule(path)
  local fromPath = common.getPathModuleType(path)
  if fromPath then
    return fromPath, path, "path"
  end
  if type(path) == "string" and path ~= "" and not path:find(":", 1, true) then
    local startupCwd = (_G and _G.CONFIG_UI and _G.CONFIG_UI.startupCwd) or nil
    if type(startupCwd) == "string" and startupCwd ~= "" then
      local fromStartupCwd = common.getPathModuleType(startupCwd)
      if fromStartupCwd then
        return fromStartupCwd, startupCwd, "startupCwd"
      end
    end
    if System and System.currentDirectory then
      local okCwd, cwd = pcall(System.currentDirectory)
      local cwdPath = okCwd and tostring(cwd or "") or ""
      if cwdPath ~= "" then
        local fromCwd = common.getPathModuleType(cwdPath)
        if fromCwd then
          return fromCwd, cwdPath, "cwd"
        end
      end
    end
  end
  return nil, nil, nil
end

local function ensureSaveTargetDeviceReady(path, saveDbg)
  if not (System and System.loadModules) then
    return true, nil
  end

  local moduleType, sourcePath, sourceKind = resolveSaveTargetModule(path)
  if not moduleType then
    saveDbg("prepare skipped", "reason=no_device_module_match", "path=" .. tostring(path))
    return true, nil
  end

  saveDbg("prepare target", "module=" .. tostring(moduleType), "source=" .. tostring(sourceKind),
    "value=" .. tostring(sourcePath))
  local ok, res = pcall(System.loadModules, moduleType)
  if not ok then
    saveDbg("prepare failed", "module=" .. tostring(moduleType), "error=" .. tostring(res))
    return false, "failed to prepare device modules (" .. tostring(moduleType) .. ")"
  end
  if type(res) == "number" and res < 0 then
    saveDbg("prepare failed", "module=" .. tostring(moduleType), "result=" .. tostring(res))
    return false, "failed to prepare device modules (" .. tostring(moduleType) .. ")"
  end
  saveDbg("prepare done", "module=" .. tostring(moduleType), "result=" .. tostring(res))
  return true, nil
end

function common.setCleanConfigSnapshot(ctx, opts)
  if not ctx then return false end
  opts = opts or {}
  local snapshotLines = (opts.lines ~= nil) and opts.lines or ctx.lines or {}
  ctx.configCleanSemanticDigest = computeSemanticDigest(ctx, snapshotLines)
  ctx.configNeedsInitialSave = opts.needsInitialSave == true
  ctx._configModifiedCache = nil
  return common.refreshConfigModified(ctx)
end

function common.markNewUnsavedConfig(ctx, opts)
  opts = opts or {}
  opts.needsInitialSave = true
  return common.setCleanConfigSnapshot(ctx, opts)
end

function common.markConfigSaved(ctx, lines)
  return common.setCleanConfigSnapshot(ctx, { lines = lines, needsInitialSave = false })
end

-- Save config; for pfs0 (__sysconf) paths we mount, save, then unmount so ELF browsing does not break saving.
function common.saveConfig(ctx, path, lines, createDir)
  local saveDbg = common.makeDebugLogger("CONFIG_UI_SAVE_DEBUG", "[save] ")
  local resolvedPath = common.resolvePathForAccess(path)
  local resolvedDir = common.resolvePathForAccess(createDir)

  saveDbg("route begin", "context=" .. tostring(ctx and ctx.context), "fileType=" .. tostring(ctx and ctx.fileType),
    "path=" .. tostring(path), "resolvedPath=" .. tostring(resolvedPath),
    "createDir=" .. tostring(createDir), "resolvedDir=" .. tostring(resolvedDir))
  local prepOk, prepErr = ensureSaveTargetDeviceReady(resolvedPath, saveDbg)
  if not prepOk then
    return nil, prepErr
  end
  local mounted, savePath, mountedPartition = common.beginPathAccess(resolvedPath, {
    loadModule = false,
    mountPartition = true,
  })
  local saveDir = resolvedDir

  if saveDir and saveDir ~= "" and mountedPartition then
    local dirPart, mappedDir = common.mapPartitionPathToMountedPfs(saveDir)
    if dirPart and dirPart == mountedPartition and mappedDir then
      saveDir = mappedDir
    end
  end

  if mounted then
    if mountedPartition then
      saveDbg("mount", tostring(mounted), "<-", tostring(mountedPartition))
    elseif savePath and savePath:match("^pfs0:/") then
      saveDbg("mount", tostring(mounted), "<-", "hdd0:__sysconf")
    else
      saveDbg("mount", tostring(mounted))
    end
  end
  saveDbg("dispatch", "savePath=" .. tostring(savePath), "saveDir=" .. tostring(saveDir))
  local ok, err = ctx._.config_parse.save(savePath, lines, saveDir)
  if ok then
    common.markConfigSaved(ctx, lines)
  end
  saveDbg("dispatch result", "ok=" .. tostring(ok), "err=" .. tostring(err))
  if mounted then
    saveDbg("umount", tostring(mounted))
    common.endPathAccess(mounted)
  end
  return ok, err
end

function common.regenerateLinesForSave(ctx)
  if not ctx then return end
  local _ = ctx._
  if not (_ and _.config_parse and _.config_parse.regenerateForSave) then return end
  ctx.lines = _.config_parse.regenerateForSave(ctx.lines, ctx.fileType, _.config_options)
end

-- Shared save flow used by multiple editor scenes.
-- opts:
--  allowChoose: boolean (default false)
--  chooseSaveState: default "choose_save"
--  locationFileType/locationContext/chosenMcSlot/locations/getLocations
--  regenerateBeforeSave: default true
--  beforeChooseSave(locations), beforeSave(path), afterSave(path)
--  noSaveLocationMessage, errorDetail(err), savedFrames, failedFrames
function common.saveCurrentConfig(ctx, opts)
  if not ctx then return nil, "no_context" end
  opts = opts or {}
  local _ = ctx._
  if not _ then return nil, "no_frame_context" end

  ctx.saveSplash = nil

  local locations = opts.locations
  if type(locations) ~= "table" then
    local resolver = opts.getLocations or _.getLocations
    if type(resolver) == "function" then
      local locContext = opts.locationContext or ctx.context
      local locFileType = opts.locationFileType or ctx.fileType
      local locSlot = (opts.chosenMcSlot ~= nil) and opts.chosenMcSlot or ctx.chosenMcSlot
      locations = resolver(locContext, locFileType, locSlot) or {}
    else
      locations = {}
    end
  end

  if opts.allowChoose and #locations >= 2 then
    if type(opts.beforeChooseSave) == "function" then
      opts.beforeChooseSave(locations)
    end
    ctx.saveChoices = locations
    ctx.saveSel = ctx.saveSel or 1
    ctx.state = opts.chooseSaveState or "choose_save"
    return true, "choose_save"
  end

  local path = opts.path
  if type(path) ~= "string" or path == "" then
    path = ctx.currentPath or (locations and locations[1])
  end
  if type(path) ~= "string" or path == "" then
    local noSaveLocation = opts.noSaveLocationMessage or (_.editor_str and _.editor_str.no_save_location) or
        "No save location"
    ctx.saveSplash = { kind = "failed", detail = noSaveLocation, framesLeft = opts.failedFrames or 120 }
    return nil, "no_save_location"
  end

  local regenBeforeSave = (opts.regenerateBeforeSave ~= false)
  if regenBeforeSave then
    common.regenerateLinesForSave(ctx)
  end
  if type(opts.beforeSave) == "function" then
    opts.beforeSave(path)
  end

  local parentDir = opts.createDir
  if parentDir == nil then
    parentDir = path:match("^(.+)/[^/]+$")
  end
  local ok, err = common.saveConfig(ctx, path, opts.lines or ctx.lines, parentDir)
  if ok then
    if opts.setCurrentPath ~= false then
      ctx.currentPath = path
    end
    if opts.markUnmodified ~= false then
      ctx.configModified = false
    end
    if type(opts.afterSave) == "function" then
      opts.afterSave(path)
    end
    ctx.saveSplash = { kind = "saved", detail = path or "", framesLeft = opts.savedFrames or 60 }
    return true
  end

  local detail = nil
  if type(opts.errorDetail) == "function" then
    detail = opts.errorDetail(err)
  end
  if detail == nil or detail == "" then
    detail = (common.localizeParseError and _.editor_str and common.localizeParseError(err, _.editor_str)) or
        (_.editor_str and _.editor_str.save_failed) or tostring(err or "Save failed")
  end
  ctx.saveSplash = { kind = "failed", detail = detail, framesLeft = opts.failedFrames or 120 }
  return nil, err
end

function common.listDirectoryFiltered(path, file_selector, opts)
  local raw = file_selector.listDirectory(path) or {}
  local out = {}
  local includeDirs = not (opts and opts.includeDirs == false)
  local extSet = nil
  if opts and type(opts.extensions) == "table" and #opts.extensions > 0 then
    extSet = {}
    for i = 1, #opts.extensions do
      local ext = tostring(opts.extensions[i] or ""):lower()
      if ext ~= "" then
        if ext:sub(1, 1) ~= "." then ext = "." .. ext end
        extSet[ext] = true
      end
    end
    if next(extSet) == nil then extSet = nil end
  end

  for _, e in ipairs(raw) do
    if e.directory then
      if includeDirs then table.insert(out, e) end
    elseif not extSet then
      table.insert(out, e)
    else
      local name = tostring(e.name or ""):lower()
      local dot = name:match("%.[^%.]+$")
      if dot and extSet[dot] then table.insert(out, e) end
    end
  end
  return out
end

function common.listDirectoryElfOnly(path, file_selector)
  return common.listDirectoryFiltered(path, file_selector, { extensions = { ".elf" } })
end

common.REPEATABLE_MASK = common.PAD_UP | common.PAD_DOWN
common.REPEAT_START_HZ = 5
common.REPEAT_END_HZ = 12
common.REPEAT_ACCEL_SECONDS = 3
common.REPEAT_FPS_SAMPLE_WINDOW = 8

function common.getRepeatFps(ctx, nominalFps, opts)
  local fallback = math.max(1, tonumber(nominalFps) or 60)
  if not ctx then
    return fallback
  end

  local cached = tonumber(ctx.holdRepeatFps) or 0
  if opts and opts.forceRefresh == true then
    cached = 0
  end
  if cached <= 0 and Screen and Screen.getFPS then
    local sampleWindow = math.max(1, math.floor(tonumber(common.REPEAT_FPS_SAMPLE_WINDOW) or 8))
    local measured = tonumber(Screen.getFPS(sampleWindow))
    if measured and measured > 0 then
      cached = measured
    end
  end

  if cached <= 0 then
    cached = fallback
  end

  ctx.holdRepeatFps = cached
  return math.max(1, cached)
end

function common.getRepeatIntervalFrames(fps, heldFrames)
  local safeFps = math.max(1, tonumber(fps) or 60)
  local startHz = tonumber(common.REPEAT_START_HZ) or 3
  local endHz = tonumber(common.REPEAT_END_HZ) or 12
  if startHz < 0.1 then startHz = 0.1 end
  if endHz < 0.1 then endHz = 0.1 end
  local accelFrames = math.max(1, math.floor((tonumber(common.REPEAT_ACCEL_SECONDS) or 4) * safeFps + 0.5))
  local t = (tonumber(heldFrames) or 0) / accelFrames
  if t < 0 then t = 0 end
  if t > 1 then t = 1 end
  local hz = startHz + ((endHz - startHz) * t)
  if hz < 0.1 then hz = 0.1 end
  return math.max(1, math.floor((safeFps / hz) + 0.5))
end

-- Generic hold-to-repeat helper for one action key.
-- Returns true when action should trigger this frame.
function common.consumeHeldRepeat(ctx, repeatKey, isHeld, opts)
  if not ctx or not repeatKey then
    return isHeld and true or false
  end
  local held = isHeld and true or false
  local store = ctx._holdRepeatStates
  if type(store) ~= "table" then
    store = {}
    ctx._holdRepeatStates = store
  end
  local key = tostring(repeatKey)
  local st = store[key]
  if type(st) ~= "table" then
    st = { wasHeld = false, heldFrames = 0, countdown = 0 }
    store[key] = st
  end
  if not held then
    st.wasHeld = false
    st.heldFrames = 0
    st.countdown = 0
    return false
  end

  local nominalFps = (Screen.getMode() and Screen.getMode().height == 512) and 50 or 60
  local fps = common.getRepeatFps(ctx, nominalFps)
  local speed = tonumber(opts and opts.speed) or 1
  if speed <= 0 then speed = 1 end

  local function intervalForFrame(frame)
    local base = common.getRepeatIntervalFrames(fps, frame)
    if speed == 1 then return base end
    return math.max(1, math.floor((base / speed) + 0.5))
  end

  if not st.wasHeld then
    st.wasHeld = true
    st.heldFrames = 0
    st.countdown = intervalForFrame(0)
    return true
  end

  st.heldFrames = st.heldFrames + 1
  local targetInterval = intervalForFrame(st.heldFrames)
  if st.countdown > targetInterval then
    st.countdown = targetInterval
  end
  st.countdown = st.countdown - 1
  if st.countdown <= 0 then
    st.countdown = targetInterval
    return true
  end
  return false
end

-- Update ctx with layout values from current screen mode (for scene runner).
function common.computeVisibleRows(ctx, startY, rowH, fallback, opts)
  local safeStartY = math.floor(tonumber(startY) or 0)
  local safeRowH = math.max(1, math.floor(tonumber(rowH) or 1))
  local hintY = math.floor(tonumber(ctx and ctx.HINT_Y) or common.HINT_Y or common.DEFAULT_H)
  local hintTop = hintY - (common.PAD_HINT_TOTAL_H or 0)
  local reserveRows = math.max(1, math.floor(tonumber((opts and opts.reserveRows) or common.LIST_BOTTOM_CLEAR_ROWS) or 1))
  local boundaryTop = hintTop
  if opts and opts.reserveDescription then
    local descTop = math.floor(tonumber(ctx and ctx.DESC_Y_BOTTOM) or 0)
    if descTop > 0 then
      boundaryTop = math.min(boundaryTop, descTop)
    end
  end
  if opts and opts.bottomY then
    local forcedTop = math.floor(tonumber(opts.bottomY) or 0)
    if forcedTop > 0 then
      boundaryTop = math.min(boundaryTop, forcedTop)
    end
  end
  -- Reserve N full rows between the last selectable row and bottom boundary.
  local maxRowTop = boundaryTop - ((reserveRows + 1) * safeRowH)
  local rows = math.floor((maxRowTop - safeStartY) / safeRowH) + 1
  if rows >= 1 then
    return rows
  end
  return math.max(1, math.floor(tonumber(fallback) or 1))
end

local transitions = dofile("scripts/transitions.lua")
if transitions and transitions.install then
  transitions.install(common)
end

function common.runLayout(ctx)
  local vmode = Screen.getMode()
  local w = (vmode and vmode.width) or common.DEFAULT_W
  local h = (vmode and vmode.height) or common.DEFAULT_H
  local sx = w / common.DEFAULT_W
  local sy = h / common.DEFAULT_H
  local uiScale = math.min(sx, sy)
  if uiScale <= 0 then
    uiScale = 1
  end
  local uiW = math.max(1, math.floor(common.DEFAULT_W * uiScale + 0.5))
  local uiH = math.max(1, math.floor(common.DEFAULT_H * uiScale + 0.5))
  local originX = math.floor((w - uiW) / 2)
  local originY = math.floor((h - uiH) / 2)
  if ctx then
    ctx.w = w
    ctx.h = h
    ctx.sx = sx
    ctx.sy = sy
    ctx.uiScale = uiScale
    ctx.uiOriginX = originX
    ctx.uiOriginY = originY
    ctx.uiW = uiW
    ctx.uiH = uiH
    ctx.scaleX = function(x) return math.floor(((x or 0) * uiScale) + 0.5) end
    ctx.scaleY = function(y) return math.floor(((y or 0) * uiScale) + 0.5) end
    ctx.MARGIN_X = originX + ctx.scaleX(common.MARGIN_X)
    ctx.MARGIN_Y = originY + ctx.scaleY(common.MARGIN_Y)
    ctx.LINE_H = math.max(1, ctx.scaleY(common.LINE_H))
    ctx.ROW_H = math.max(1, ctx.scaleY(common.ROW_H))
    ctx.VALUE_X = originX + ctx.scaleX(common.VALUE_X)
    ctx.KEYBOARD_CENTER_X = originX + ctx.scaleX(common.KEYBOARD_CENTER_X)
    ctx.KEYBOARD_CENTER_Y = originY + ctx.scaleY(common.KEYBOARD_CENTER_Y)
    ctx.KEY_WIDTH = math.max(1, ctx.scaleX(common.KEY_WIDTH))
    ctx.KEY_HEIGHT = math.max(1, ctx.scaleY(common.KEY_HEIGHT))
    ctx.KEY_GAP = math.max(1, ctx.scaleX(common.KEY_GAP))
    ctx.KEY_CHAR_W = math.max(1, ctx.scaleX(common.KEY_CHAR_W))
    ctx.KEY_LINE_H = math.max(1, ctx.scaleY(common.KEY_LINE_H))
    ctx.HINT_Y = originY + uiH - ctx.scaleY(24)
    ctx.DESC_Y_BOTTOM = ctx.HINT_Y - common.PAD_HINT_TOTAL_H - ctx.scaleY(common.DESC_TO_HINT_MARGIN)
    local startYList = ctx.MARGIN_Y + ctx.scaleY(50)
    local startYRows = ctx.MARGIN_Y + ctx.scaleY(58)
    local reserveRows = common.LIST_BOTTOM_CLEAR_ROWS
    ctx.MAX_VISIBLE_LIST = common.computeVisibleRows(ctx, startYList, ctx.LINE_H, common.MAX_VISIBLE_LIST, {
      reserveRows = reserveRows
    })
    ctx.MAX_VISIBLE = common.computeVisibleRows(ctx, startYRows, ctx.ROW_H, common.MAX_VISIBLE, {
      reserveRows = reserveRows
    })
  end
end

-- Shared scene loop: clear, layout, getPadEffective, runHandler(ctx, pad), exit when ctx.state ~= sceneName.
function common.runSceneLoop(ctx, sceneName, runHandler)
  while true do
    if not common.shouldSkipSceneClearForTransition(ctx) then
      Screen.clear(common.BGCOLOR)
    end
    common.runLayout(ctx)
    common.applySceneDrawOffsetForCurrentFrame(ctx)
    local uiScale = (ctx and tonumber(ctx.uiScale)) or 1
    local scaleX = (ctx and ctx.scaleX) or function(x) return math.floor(((x or 0) * uiScale) + 0.5) end
    local scaleY = (ctx and ctx.scaleY) or function(y) return math.floor(((y or 0) * uiScale) + 0.5) end
    if _G.CONFIG_UI then
      _G.CONFIG_UI.currentUiScale = uiScale
      _G.CONFIG_UI.currentDrawWidth = math.max(1, scaleX(common.FT_DRAW_W))
      _G.CONFIG_UI.currentDrawHeight = math.max(1, scaleY(common.FT_DRAW_H))
    end
    if ctx and ctx.drawMode == "ftPrint" and ctx.font and Font and Font.ftSetPixelSize then
      local runtimeDrawScale = tonumber(_G.CONFIG_UI and _G.CONFIG_UI.sceneDrawScale) or 1
      if runtimeDrawScale <= 0 then runtimeDrawScale = 1 end
      if runtimeDrawScale < 0.25 then runtimeDrawScale = 0.25 end
      if runtimeDrawScale > 4 then runtimeDrawScale = 4 end
      local wantPx = math.max(10, math.floor((common.FT_PIXEL_H or 18) * uiScale * runtimeDrawScale + 0.5))
      if ctx._ftPixelSizeApplied ~= wantPx then
        pcall(Font.ftSetPixelSize, ctx.font, 0, wantPx)
        ctx._ftPixelSizeApplied = wantPx
      end
      if _G.CONFIG_UI then
        _G.CONFIG_UI.currentFtPixelH = wantPx
      end
    elseif _G.CONFIG_UI then
      _G.CONFIG_UI.currentFtPixelH = nil
    end
    if ctx and ctx.drawBackgroundLayer and
        (not common.shouldDrawBackgroundLayerForTransition or common.shouldDrawBackgroundLayerForTransition(ctx) ~= false) then
      if common.drawWithoutSceneTransform then
        common.drawWithoutSceneTransform(function()
          ctx.drawBackgroundLayer(ctx)
        end)
      else
        ctx.drawBackgroundLayer(ctx)
      end
    end
    local rawPadEffective = common.getPadEffective(ctx)
    local padEffective = common.shouldBlockInputForSceneTransition(ctx) and 0 or rawPadEffective
    ctx._lastPadEffective = padEffective
    runHandler(ctx, padEffective)
    common.refreshConfigModified(ctx)
    common.drawAndAdvanceSceneTransitionIn(ctx)
    if ctx.state ~= sceneName then
      return ctx.state, ctx
    end
    -- Present on vblank to avoid tearing/shimmer on animated transitions.
    Screen.waitVblankStart()
    Screen.flip()
  end
end

-- Get pad with repeat logic; updates ctx.prevPad/ctx.holdFrameCount/ctx.holdRepeatCountdown.
-- Repeat ramps from REPEAT_START_HZ to REPEAT_END_HZ over REPEAT_ACCEL_SECONDS while held.
function common.getPadEffective(ctx)
  local pad = Pads.get(0)
  local prevPad = ctx.prevPad or 0
  local padJust = pad & ~prevPad
  local nominalFps = (Screen.getMode() and Screen.getMode().height == 512) and 50 or 60
  ctx.holdFrameCount = tonumber(ctx.holdFrameCount) or 0
  ctx.holdRepeatCountdown = tonumber(ctx.holdRepeatCountdown) or 0
  local padRepeat = 0
  local heldMask = pad & common.REPEATABLE_MASK
  local prevHeldMask = prevPad & common.REPEATABLE_MASK
  if heldMask ~= 0 then
    if prevHeldMask == 0 then
      local fps = common.getRepeatFps(ctx, nominalFps)
      -- New hold starts now: first repeat at start-rate interval.
      ctx.holdFrameCount = 0
      ctx.holdRepeatCountdown = common.getRepeatIntervalFrames(fps, 0)
    else
      local fps = common.getRepeatFps(ctx, nominalFps)
      ctx.holdFrameCount = ctx.holdFrameCount + 1
      local targetInterval = common.getRepeatIntervalFrames(fps, ctx.holdFrameCount)
      if ctx.holdRepeatCountdown > targetInterval then
        ctx.holdRepeatCountdown = targetInterval
      end
      ctx.holdRepeatCountdown = ctx.holdRepeatCountdown - 1
      if ctx.holdRepeatCountdown <= 0 then
        padRepeat = heldMask
        ctx.holdRepeatCountdown = targetInterval
      end
    end
  else
    ctx.holdFrameCount = 0
    ctx.holdRepeatCountdown = 0
  end
  ctx.prevPad = pad
  return common.remapCrossCircleMask(padJust | padRepeat)
end

function common.loadCustomFont()
  Font.ftInit()
  local f = loadFtFontWithFallback()
  if f and f >= 0 then
    Font.ftSetPixelSize(f, 0, common.FT_PIXEL_H)
    return f, "ftPrint"
  end
  error("Failed to load font")
end

-- Open text input scene with consistent defaults.
-- opts: { prompt, value, maxLen, callback, returnState, titleIdMode, gridSel, cursor, scroll, clearArgEditIdx, argEditIdx }
function common.beginTextInput(ctx, opts)
  if not ctx or type(opts) ~= "table" then return end
  -- Reset per-key held-repeat state so each text-input session starts clean.
  ctx._holdRepeatStates = nil
  if opts.clearArgEditIdx then
    ctx.argEditIdx = nil
  end
  if opts.argEditIdx ~= nil then
    ctx.argEditIdx = opts.argEditIdx
  end
  ctx.textInputTitleIdMode = opts.titleIdMode
  ctx.textInputPrompt = opts.prompt or ""
  ctx.textInputValue = tostring(opts.value or "")
  ctx.textInputMaxLen = math.max(1, math.floor(tonumber(opts.maxLen) or 79))
  ctx.textInputCallback = opts.callback
  ctx.textInputReturnState = opts.returnState or ctx.state or "main"
  ctx.textInputGridSel = math.max(1, math.floor(tonumber(opts.gridSel) or 1))
  ctx.textInputCursor = math.max(1, math.floor(tonumber(opts.cursor) or (#ctx.textInputValue + 1)))
  ctx.textInputScroll = math.max(1, math.floor(tonumber(opts.scroll) or 1))
  ctx.state = opts.state or "text_input"
end

-- Approximate width of text for centering. Uses Font.ftCalcDimensions when available (ftPrint).
function common.calcTextWidth(font, text, scale)
  if not text or text == "" then return 0 end
  local s = scale or 0.72
  local approxCharW = math.floor(8 * s)
  local cache = common._textWidthCache
  if not cache then
    cache = {}
    common._textWidthCache = cache
    common._textWidthCacheSize = 0
  end
  local cacheKey = tostring(font) .. "\31" .. tostring(s) .. "\31" .. tostring(text)
  local cachedWidth = cache[cacheKey]
  if cachedWidth ~= nil then
    return cachedWidth
  end
  local measured
  if font and Font and Font.ftCalcDimensions then
    local w = Font.ftCalcDimensions(font, text)
    measured = (type(w) == "number" and w > 0) and w or math.floor(approxCharW * #text)
  else
    measured = math.floor(approxCharW * #text)
  end
  cache[cacheKey] = measured
  common._textWidthCacheSize = (common._textWidthCacheSize or 0) + 1
  if (common._textWidthCacheSize or 0) > 8192 then
    common._textWidthCache = {}
    common._textWidthCacheSize = 0
  end
  return measured
end

-- Truncate text to fit within maxPixels at scale, appending "..." when shortened.
function common.truncateTextToWidth(font, text, maxPixels, scale)
  if not text or maxPixels <= 0 then return text or "" end
  local s = scale or 1
  local ellipsis = "..."
  if (common.calcTextWidth(font, text, s) or 0) <= maxPixels then return text end
  local ellipsisW = common.calcTextWidth(font, ellipsis, s) or (3 * math.floor(8 * s))
  local maxForName = maxPixels - ellipsisW
  if maxForName <= 0 then return ellipsis end
  local n = #text
  while n > 0 do
    local part = text:sub(1, n) .. ellipsis
    if (common.calcTextWidth(font, part, s) or 0) <= maxPixels then return part end
    n = n - 1
  end
  return ellipsis
end

-- Clamp list selection to [1..total]. Empty lists always return 1.
function common.clampListSelection(sel, total)
  local n = math.floor(tonumber(sel) or 1)
  local count = math.max(0, math.floor(tonumber(total) or 0))
  if count <= 0 then return 1 end
  if n < 1 then n = 1 end
  if n > count then n = count end
  return n
end

-- Wrap selection by step for cyclic lists. Empty lists always return 1.
function common.wrapListSelection(sel, total, step)
  local count = math.max(0, math.floor(tonumber(total) or 0))
  if count <= 0 then return 1 end
  local idx = common.clampListSelection(sel, count)
  local delta = math.floor(tonumber(step) or 0)
  if delta == 0 then return idx end
  idx = idx + delta
  while idx < 1 do idx = idx + count end
  while idx > count do idx = idx - count end
  return idx
end

-- Centered list scroll start for rendering [scroll+1 .. scroll+maxVisible].
function common.centeredListScroll(sel, total, maxVisible)
  local count = math.max(0, math.floor(tonumber(total) or 0))
  local maxVis = math.max(1, math.floor(tonumber(maxVisible) or 1))
  if count <= maxVis then return 0 end
  local idx = common.clampListSelection(sel, count)
  local scroll = idx - math.floor(maxVis / 2)
  if scroll < 0 then scroll = 0 end
  local maxScroll = count - maxVis
  if scroll > maxScroll then scroll = maxScroll end
  return scroll
end

-- Draw a right-side list scrollbar for overflowing row lists.
-- opts: { totalRows, visibleRows, scrollRows, rowTopY, rowHeight, color, barWidth, x, minBarHeight }.
function common.drawListScrollbar(_, opts)
  if not (_ and _.Graphics and _.Graphics.drawRect) then return end
  local totalRows = math.max(0, math.floor(tonumber(opts and opts.totalRows) or 0))
  local visibleRows = math.max(0, math.floor(tonumber(opts and opts.visibleRows) or 0))
  if visibleRows <= 0 or totalRows <= visibleRows then return end

  local rowTopY = math.floor(tonumber(opts and opts.rowTopY) or 0)
  local rowHeight = math.max(1, math.floor(tonumber(opts and opts.rowHeight) or (_.LINE_H or common.LINE_H)))
  local trackHeight = math.max(1, visibleRows * rowHeight)

  local defaultBarW = (_.scaleX and _.scaleX(8)) or 8
  local barWidth = math.max(1, math.floor(tonumber(opts and opts.barWidth) or defaultBarW))
  local x = tonumber(opts and opts.x)
  if not x then
    x = ((_.w or common.DEFAULT_W) - (_.MARGIN_X or common.MARGIN_X) - barWidth)
  end

  local maxScroll = math.max(0, totalRows - visibleRows)
  local scrollRows = math.floor(tonumber(opts and opts.scrollRows) or 0)
  if scrollRows < 0 then scrollRows = 0 end
  if scrollRows > maxScroll then scrollRows = maxScroll end

  local color = (opts and opts.color) or _.DIM or common.DIM
  local trackX = math.floor(x + 0.5)
  local trackY = math.floor(rowTopY + 0.5)
  local trackW = math.max(1, barWidth)
  local trackH = math.max(1, trackHeight)

  if trackW >= 2 and trackH >= 2 then
    -- 1px perimeter around the full track (top of first row to bottom of last row).
    _.Graphics.drawRect(trackX, trackY, trackW, 1, color)
    _.Graphics.drawRect(trackX, trackY + trackH - 1, trackW, 1, color)
    if trackH > 2 then
      _.Graphics.drawRect(trackX, trackY + 1, 1, trackH - 2, color)
      _.Graphics.drawRect(trackX + trackW - 1, trackY + 1, 1, trackH - 2, color)
    end

    local innerX = trackX + 1
    local innerY = trackY + 1
    local innerW = math.max(1, trackW - 2)
    local innerH = math.max(1, trackH - 2)
    local barHeight = math.floor((innerH * (visibleRows / totalRows)) + 0.5)
    local minBarH = (_.scaleY and _.scaleY(6)) or 6
    minBarH = math.max(2, math.floor(tonumber(opts and opts.minBarHeight) or minBarH))
    if barHeight < minBarH then barHeight = minBarH end
    if barHeight > innerH then barHeight = innerH end
    local travel = math.max(0, innerH - barHeight)
    local y = innerY
    if travel > 0 and maxScroll > 0 then
      y = innerY + math.floor(((scrollRows / maxScroll) * travel) + 0.5)
    end
    _.Graphics.drawRect(innerX, y, innerW, barHeight, color)
    return
  end

  -- Fallback for very tiny widths/heights.
  local barHeight = math.floor((trackH * (visibleRows / totalRows)) + 0.5)
  if barHeight < 1 then barHeight = 1 end
  if barHeight > trackH then barHeight = trackH end
  local travel = math.max(0, trackH - barHeight)
  local y = trackY
  if travel > 0 and maxScroll > 0 then
    y = trackY + math.floor(((scrollRows / maxScroll) * travel) + 0.5)
  end
  _.Graphics.drawRect(trackX, y, trackW, barHeight, color)
end

-- Return row text fitted to maxPixels. Selected rows use delayed horizontal marquee
-- (hold at start, scroll right, hold at end, then repeat). Unselected rows are truncated.
function common.fitListRowText(ctx, stateKey, font, text, maxPixels, scale, selected, opts)
  local raw = tostring(text or "")
  if maxPixels <= 0 or raw == "" then return raw end
  local s = scale or 1
  local st = nil
  if ctx and stateKey then
    local store = ctx._rowMarqueeStates
    if not store then
      store = {}
      ctx._rowMarqueeStates = store
    end
    st = store[stateKey]
  end
  if not selected then
    if st and st.text == raw and st.maxPixels == maxPixels and st.scale == s and st.truncated ~= nil then
      st.selected = false
      st.ticks = 0
      return st.truncated
    end
    local truncated = common.truncateTextToWidth(font, raw, maxPixels, s)
    if ctx and stateKey then
      local store = ctx._rowMarqueeStates or {}
      store[stateKey] = {
        text = raw,
        maxPixels = maxPixels,
        scale = s,
        selected = false,
        ticks = 0,
        visibleChars = nil,
        truncated = truncated
      }
      ctx._rowMarqueeStates = store
    end
    return truncated
  end
  local textW = common.calcTextWidth(font, raw, s) or 0
  if textW <= maxPixels then
    if st then
      st.text = raw
      st.maxPixels = maxPixels
      st.scale = s
      st.selected = true
      st.ticks = 0
      st.visibleChars = nil
      st.truncated = raw
    end
    return raw
  end

  -- Fail-safe fallback if scene did not pass context or key.
  if not ctx or not stateKey then
    return common.truncateTextToWidth(font, raw, maxPixels, s)
  end

  local store = ctx._rowMarqueeStates
  if not store then
    store = {}
    ctx._rowMarqueeStates = store
  end
  st = store[stateKey]
  if not st or st.text ~= raw or st.maxPixels ~= maxPixels or st.scale ~= s then
    st = {
      text = raw,
      maxPixels = maxPixels,
      scale = s,
      ticks = 0,
      visibleChars = nil,
      selected = true,
      truncated = nil,
    }
    store[stateKey] = st
  elseif st.selected ~= true then
    st.ticks = 0
    st.visibleChars = nil
    st.selected = true
  end

  if not st.visibleChars then
    local vis = #raw
    for n = 1, #raw do
      if (common.calcTextWidth(font, raw:sub(1, n), s) or 0) > maxPixels then
        vis = n - 1
        break
      end
    end
    st.visibleChars = math.max(1, vis)
  end

  local totalSteps = math.max(0, #raw - st.visibleChars)
  if totalSteps <= 0 then return raw end

  local holdStart = (opts and tonumber(opts.holdStart)) or 45
  local stepFrames = (opts and tonumber(opts.stepFrames)) or 8
  local holdEnd = (opts and tonumber(opts.holdEnd)) or 45
  if holdStart < 0 then holdStart = 0 end
  if holdEnd < 0 then holdEnd = 0 end
  if stepFrames < 1 then stepFrames = 1 end

  st.ticks = (st.ticks or 0) + 1
  local cycleLen = holdStart + totalSteps * stepFrames + holdEnd
  local ticks = st.ticks
  if ticks >= cycleLen then
    st.ticks = 0
    ticks = 0
  end

  local startIdx
  if ticks < holdStart then
    startIdx = 1
  elseif ticks < holdStart + totalSteps * stepFrames then
    startIdx = 1 + math.floor((ticks - holdStart) / stepFrames)
  else
    startIdx = totalSteps + 1
  end

  return raw:sub(startIdx, startIdx + st.visibleChars - 1)
end

-- Value-column marquee/truncation helper with slower defaults than list rows.
function common.fitValueText(ctx, stateKey, font, text, maxPixels, scale, selected, opts)
  local cfg = {
    holdStart = (opts and tonumber(opts.holdStart)) or 50,
    stepFrames = (opts and tonumber(opts.stepFrames)) or 18,
    holdEnd = (opts and tonumber(opts.holdEnd)) or 70,
  }
  return common.fitListRowText(ctx, stateKey, font, text, maxPixels, scale, selected, cfg)
end

function common.drawText(font, mode, x, y, scale, text, color, drawHeight)
  local c = color or common.WHITE
  local runtime = _G and _G.CONFIG_UI
  local offsetX = math.floor(tonumber(runtime and runtime.sceneDrawOffsetX) or 0)
  local drawScale = tonumber(runtime and runtime.sceneDrawScale) or 1
  if drawScale <= 0 then drawScale = 1 end
  if drawScale < 0.1 then drawScale = 0.1 end
  if drawScale > 4 then drawScale = 4 end
  local drawScaleX = tonumber(runtime and runtime.sceneDrawScaleX)
  if drawScaleX == nil then drawScaleX = drawScale end
  if drawScaleX < -4 then drawScaleX = -4 end
  if drawScaleX > 4 then drawScaleX = 4 end
  local drawScaleY = tonumber(runtime and runtime.sceneDrawScaleY)
  if drawScaleY == nil then drawScaleY = drawScale end
  if drawScaleY < -4 then drawScaleY = -4 end
  if drawScaleY > 4 then drawScaleY = 4 end
  local centerX = tonumber(runtime and runtime.sceneDrawCenterX) or
      ((tonumber(runtime and runtime.currentSceneWidth) or common.DEFAULT_W) / 2)
  local centerY = tonumber(runtime and runtime.sceneDrawCenterY) or
      ((tonumber(runtime and runtime.currentSceneHeight) or common.DEFAULT_H) / 2)
  local drawAlpha = tonumber(runtime and runtime.sceneDrawAlpha) or 1
  if c and drawAlpha < 0.999 then
    local base = math.floor(tonumber(c) or 0)
    local a = (base >> 24) & 0xFF
    local scaledA = math.floor(a * math.max(0, math.min(1, drawAlpha)) + 0.5)
    if scaledA < 0 then scaledA = 0 end
    if scaledA > 0x80 then scaledA = 0x80 end
    c = (base & 0x00FFFFFF) | ((scaledA & 0xFF) << 24)
  end
  local px = tonumber(x) or 0
  local py = tonumber(y) or 0
  if math.abs(drawScaleX - 1) > 0.0001 or math.abs(drawScaleY - 1) > 0.0001 then
    px = centerX + ((px - centerX) * drawScaleX)
    py = centerY + ((py - centerY) * drawScaleY)
  end
  local ix = math.floor(px + offsetX)
  local iy = math.floor(py)
  local s = text or ""
  local scaleN = tonumber(scale) or 1
  if mode == "fmPrint" then
    Font.fmPrint(ix, iy, scaleN * drawScale, s, c)
  elseif mode == "ftPrint" then
    local w = (_G.CONFIG_UI and _G.CONFIG_UI.currentDrawWidth) or common.FT_DRAW_W
    local h = (drawHeight and drawHeight > 0) and drawHeight or (_G.CONFIG_UI and _G.CONFIG_UI.currentDrawHeight) or
        common.FT_DRAW_H
    Font.ftPrint(font, ix, iy, 0, w, h, s, c)
  else
    Font.print(font, ix, iy, scaleN * drawScale, s, c)
  end
end

function common.parseColor(value)
  local r, g, b, a = 0, 0, 0, 128
  if value and value ~= "" then
    local h1, h2, h3, h4 = value:match("0x([%x]+)%s*,%s*0x([%x]+)%s*,%s*0x([%x]+)%s*,%s*0x([%x]+)")
    if h1 then r = math.max(0, math.min(255, tonumber(h1, 16) or 0)) end
    if h2 then g = math.max(0, math.min(255, tonumber(h2, 16) or 0)) end
    if h3 then b = math.max(0, math.min(255, tonumber(h3, 16) or 0)) end
    if h4 then a = math.max(0, math.min(255, tonumber(h4, 16) or 128)) end
  end
  return r, g, b, a
end

function common.formatColor(r, g, b, a)
  local function hex(n) return string.format("0x%02X", math.max(0, math.min(255, n))) end
  return hex(r or 0) .. "," .. hex(g or 0) .. "," .. hex(b or 0) .. "," .. hex(a or 128)
end

-- Map parse.save/load error string to localized editor string when available.
function common.localizeParseError(err, editor_str)
  if not err or not editor_str then return err end
  if err == "write failed" then return editor_str.error_write_failed end
  if err == "read failed" then return editor_str.error_read_failed end
  if err == "cannot get size" then return editor_str.error_cannot_get_size end
  local p1, p2 = err:match("^(cannot open for write )(.*)$")
  if p1 then return (editor_str.error_cannot_open_for_write or p1) .. p2 end
  p1, p2 = err:match("^(cannot open )(.*)$")
  if p1 then return (editor_str.error_cannot_open or p1) .. p2 end
  return err
end

-- Horizontal center for text (c = context with .w and .MARGIN_X).
function common.centerX(c, textWidth)
  local w = (c and c.w) or common.DEFAULT_W
  local mx = (c and c.MARGIN_X) or common.MARGIN_X
  return math.max(mx, math.floor((w - textWidth) / 2))
end

-- Unified save splash: "Saved" or "Save Failed!", drawn on top. ctx.saveSplash = { kind = "saved"|"failed", detail = string, framesLeft = N }.
-- Decrements framesLeft; when 0, clears saveSplash and (if kind=="saved" and returnToSelectConfigAfterSaveFlash) performs transition.
function common.drawSaveSplash(ctx)
  local sp = ctx.saveSplash
  if not sp or not sp.framesLeft or sp.framesLeft <= 0 then return end
  local _ = ctx._
  local lineH = _.LINE_H or common.LINE_H
  local isFailed = (sp.kind == "failed")
  local title = sp.title or (isFailed and "Save Failed!" or (_.editor_str.saved or "Saved"))
  local textColor = sp.textColor or (isFailed and common.ERROR or _.HIGHLIGHT)
  local tw = common.calcTextWidth(_.font, title, 1) or (#title * 14)
  local detailStr = (sp.detail and sp.detail ~= "") and tostring(sp.detail) or ""
  if #detailStr > 52 then detailStr = detailStr:sub(1, 49) .. "..." end
  local detailW = (detailStr ~= "" and (common.calcTextWidth(_.font, detailStr, 0.8) or (#detailStr * 10))) or 0
  local boxW = math.max(tw, detailW) + 48
  local boxH = (detailStr ~= "" and (lineH * 2 + 24) or (lineH + 24))
  local boxX = math.floor(((_.w or common.DEFAULT_W) - boxW) / 2)
  local boxY = math.floor(((_.h or common.DEFAULT_H) - boxH) / 2)
  local splashBg = Color.new(40, 40, 48, 110)
  if _.Graphics and _.Graphics.drawRect then
    _.Graphics.drawRect(boxX, boxY, boxW, boxH, splashBg)
  end
  local centerY = boxY + math.floor((boxH - (detailStr ~= "" and lineH * 2 or lineH)) / 2)
  common.drawText(_.font, _.drawMode, common.centerX(_, tw), centerY, 1, title, textColor)
  if detailStr ~= "" then
    common.drawText(_.font, _.drawMode, common.centerX(_, detailW), centerY + lineH, 1, detailStr, textColor)
  end
  sp.framesLeft = sp.framesLeft - 1
  if sp.framesLeft <= 0 then
    ctx.saveSplash = nil
    if sp.kind == "saved" and (ctx.returnToSelectConfigAfterSaveFlash or ctx.returnStateAfterSaveFlash) then
      local targetState = ctx.returnStateAfterSaveFlash or "select_config"
      ctx.returnStateAfterSaveFlash = nil
      ctx.returnToSelectConfigAfterSaveFlash = nil
      ctx.state = targetState
      ctx.currentPath = nil
      ctx.lines = nil
      ctx.optList = nil
      ctx.editorCategoryIdx = 0
    end
  end
end

return common
