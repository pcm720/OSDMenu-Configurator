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

-- Keyboard: full QWERTY rows 1-=, q-], a-', z-/
common.KEYBOARD_ROWS = { "1234567890-=", "qwertyuiop[]", "asdfghjkl;'", "zxcvbnm,./" }
common.KEYBOARD_ROWS_SHIFTED = { "!@#$%^&*()_+", "QWERTYUIOP{}", "ASDFGHJKL:\"", "ZXCVBNM<>?" }
-- Title ID only: digits + uppercase letters, no shift (e.g. eGSM AAAA_000.00). No symbols.
common.KEYBOARD_ROWS_TITLE_ID = { "1234567890", "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" }
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

function common.findExistingPaths(locations)
  local out = {}
  for _, p in ipairs(locations) do
    if common.tryOpen(p) then table.insert(out, p) end
  end
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

  saveDbg("route begin", "context=" .. tostring(ctx and ctx.context), "fileType=" .. tostring(ctx and ctx.fileType),
    "path=" .. tostring(path), "createDir=" .. tostring(createDir))
  local prepOk, prepErr = ensureSaveTargetDeviceReady(path, saveDbg)
  if not prepOk then
    return nil, prepErr
  end
  local savePath = path
  local saveDir = createDir
  local mounted = nil

  local function splitHddPartitionPath(p)
    local s = tostring(p or "")
    local part, rest = s:match("^(hdd%d:[^:]+):pfs:(.*)$")
    if not part then
      -- Accept FMCB-style partition path (hdd0:__sysconf/dir/file) in addition to :pfs: form.
      part, rest = s:match("^(hdd%d:[^/:]+)(/.*)$")
    end
    if not part then return nil, nil end
    if rest == "" then rest = "/" end
    if rest:sub(1, 1) ~= "/" then rest = "/" .. rest end
    return part, rest
  end

  local part, rest = splitHddPartitionPath(path)
  if part and rest then
    savePath = "pfs0:" .. rest
    saveDbg("route partition", "part=" .. tostring(part), "savePath=" .. tostring(savePath))
    if saveDir and saveDir ~= "" then
      local dPart, dRest = splitHddPartitionPath(saveDir)
      if dPart and dPart == part and dRest then
        saveDir = "pfs0:" .. dRest
      end
    end
    if System and System.fileXioMount then
      saveDbg("mount", "pfs0:", "<-", tostring(part))
      System.fileXioMount("pfs0:", part)
      mounted = "pfs0:"
    end
  elseif savePath and savePath:match("^pfs0:/") then
    if System and System.fileXioMount then
      saveDbg("mount", "pfs0:", "<-", "hdd0:__sysconf")
      System.fileXioMount("pfs0:", "hdd0:__sysconf")
      mounted = "pfs0:"
    end
  end
  saveDbg("dispatch", "savePath=" .. tostring(savePath), "saveDir=" .. tostring(saveDir))
  local ok, err = ctx._.config_parse.save(savePath, lines, saveDir)
  if ok then
    common.markConfigSaved(ctx, lines)
  end
  saveDbg("dispatch result", "ok=" .. tostring(ok), "err=" .. tostring(err))
  if mounted and System and System.fileXioUmount then
    saveDbg("umount", tostring(mounted))
    System.fileXioUmount(mounted)
  end
  return ok, err
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
common.REPEAT_START_HZ = 3
common.REPEAT_END_HZ = 12
common.REPEAT_ACCEL_SECONDS = 4
common.REPEAT_FPS_SAMPLE_WINDOW = 8

function common.getRepeatFps(ctx, nominalFps)
  local fallback = math.max(1, tonumber(nominalFps) or 60)
  if not ctx then
    return fallback
  end

  local cached = tonumber(ctx.holdRepeatFps) or 0
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
    Screen.clear(common.BGCOLOR)
    common.runLayout(ctx)
    local uiScale = (ctx and tonumber(ctx.uiScale)) or 1
    local scaleX = (ctx and ctx.scaleX) or function(x) return math.floor(((x or 0) * uiScale) + 0.5) end
    local scaleY = (ctx and ctx.scaleY) or function(y) return math.floor(((y or 0) * uiScale) + 0.5) end
    if _G.CONFIG_UI then
      _G.CONFIG_UI.currentUiScale = uiScale
      _G.CONFIG_UI.currentDrawWidth = math.max(1, scaleX(common.FT_DRAW_W))
      _G.CONFIG_UI.currentDrawHeight = math.max(1, scaleY(common.FT_DRAW_H))
    end
    if ctx and ctx.drawMode == "ftPrint" and ctx.font and Font and Font.ftSetPixelSize then
      local wantPx = math.max(10, math.floor((common.FT_PIXEL_H or 18) * uiScale + 0.5))
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
    if ctx and ctx.drawBackgroundLayer then
      ctx.drawBackgroundLayer(ctx)
    end
    local padEffective = common.getPadEffective(ctx)
    ctx._lastPadEffective = padEffective
    runHandler(ctx, padEffective)
    common.refreshConfigModified(ctx)
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
  local fps = common.getRepeatFps(ctx, nominalFps)
  ctx.holdFrameCount = tonumber(ctx.holdFrameCount) or 0
  ctx.holdRepeatCountdown = tonumber(ctx.holdRepeatCountdown) or 0
  local padRepeat = 0
  local heldMask = pad & common.REPEATABLE_MASK
  local prevHeldMask = prevPad & common.REPEATABLE_MASK
  if heldMask ~= 0 then
    if prevHeldMask == 0 then
      -- New hold starts now: first repeat at start-rate interval.
      ctx.holdFrameCount = 0
      ctx.holdRepeatCountdown = common.getRepeatIntervalFrames(fps, 0)
    else
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
  local ix, iy = math.floor(tonumber(x) or 0), math.floor(tonumber(y) or 0)
  local s = text or ""
  if mode == "fmPrint" then
    Font.fmPrint(ix, iy, scale, s, c)
  elseif mode == "ftPrint" then
    local w = (_G.CONFIG_UI and _G.CONFIG_UI.currentDrawWidth) or common.FT_DRAW_W
    local h = (drawHeight and drawHeight > 0) and drawHeight or (_G.CONFIG_UI and _G.CONFIG_UI.currentDrawHeight) or
        common.FT_DRAW_H
    Font.ftPrint(font, ix, iy, 0, w, h, s, c)
  else
    Font.print(font, ix, iy, scale, s, c)
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
