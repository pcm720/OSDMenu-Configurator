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

-- Colors
common.WHITE                       = Color.new(255, 255, 255)
common.GRAY                        = Color.new(160, 160, 160)
common.DIM                         = Color.new(96, 96, 96)
common.BGCOLOR                     = Color.new(20, 20, 20)
common.HIGHLIGHT                   = Color.new(255, 220, 100)
common.SELECTED_ENTRY              = Color.new(0x00, 0x72, 0xA0)
common.SELECTED_ENTRY_DIM          = Color.new(0, 50, 80)
common.TEXT_CURSOR_COLOR           = Color.new(0x00, 0x72, 0xA0)
common.PREFIX_W                    = 16

-- Layout
common.FONT_SCALE                  = 0.9
common.LINE_H                      = 22
common.ROW_H                       = 24
common.MARGIN_X, common.MARGIN_Y   = 40, 28
common.DEFAULT_W, common.DEFAULT_H = 640, 448
common.MAX_VISIBLE                 = 10
common.MAX_VISIBLE_LIST            = 12                    -- menu entries, path picker, entry paths, entry args, eGSM editor
common.DIM_ENTRY                   = Color.new(56, 56, 56) -- darker than DIM for disabled list rows
common.VALUE_X                     = 360
common.VALUE_MAX_LEN               = 38
common.VALUE_MAX_LEN_LONG          = 22
common.HINT_Y                      = 424

-- Pad button hint icons (System/textures/*.png). Layout for icon+label.
common.PAD_ICON_W                  = 26
common.PAD_ICON_H                  = 26
common.PAD_HINT_GAP                = 5
common.PAD_HINT_GROUP_GAP          = 20
common.PAD_HINT_ROW_H              = 28
common.PAD_HINT_ROW_GAP            = 6
common.PAD_HINT_SIDE_MARGIN        = 16
common.PAD_HINT_ITEM_GAP           = 20
common.PAD_HINT_TOTAL_H            = common.PAD_HINT_ROW_H * 2 + common.PAD_HINT_ROW_GAP -- height when 2 rows
common.DESC_TO_HINT_MARGIN         = 20
common.DESC_Y_BOTTOM               = common.HINT_Y - common.PAD_HINT_TOTAL_H - common.DESC_TO_HINT_MARGIN
common.PAD_HINT_DEFAULT_WIDTH      = 560
common.PAD_HINT_MAX_PER_ROW        = 4
common.PAD_HINT_DRAW_UNUSED_BUTTONS = true
common.PAD_HINT_UNUSED_ALPHA       = 38 -- 15% opaque = 85% transparent
local padIconCache                 = {}
local hintFtFontCache              = {}
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

local function getHintFtFont(scaleFactor)
  local sf = tonumber(scaleFactor) or 1
  if sf <= 0 then sf = 1 end
  local key = string.format("%.3f", sf)
  if hintFtFontCache[key] then return hintFtFontCache[key] end
  if not (Font and Font.ftLoad) then return nil end
  local f = Font.ftLoad("font.ttf")
  if not (f and f >= 0) then
    f = Font.ftLoad("scripts/font/font.ttf")
  end
  if f and f >= 0 then
    if Font.ftSetPixelSize then
      local px = math.max(8, math.floor(((common.FT_PIXEL_H or 18) * sf) + 0.5))
      pcall(Font.ftSetPixelSize, f, 0, px)
    end
    hintFtFontCache[key] = f
    return hintFtFontCache[key]
  end
  return nil
end

-- Draw a hint line: list of { pad = "cross", label = "Select" [, row = 1|2 ] }. Uses pad textures when available; else falls back to text.
-- row: 1 = bottom row, 2 = top row. If any item has row=2, rows are from lang; else first PAD_HINT_MAX_PER_ROW on bottom, rest on top.
-- totalWidth: optional. y = bottom of hint area. Full width (minus side margin) divided into equal slots. Odd: icon+label centered in slot. Even: left half left-aligned, right half right-aligned. Uses Font.ftCalcDimensions when available for accurate text width.
function common.drawHintLine(font, drawMode, x, y, scale, hintItems, textFallback, color, totalWidth)
  if not color then color = common.DIM end
  if hintItems and #hintItems > 0 then
    local iconScale = 0.6
    local textScale = 0.75
    local drawScale = (scale or 0.7) * textScale
    local iconW = math.max(10, math.floor((common.PAD_ICON_W or 26) * iconScale + 0.5))
    local iconH = math.max(10, math.floor((common.PAD_ICON_H or 26) * iconScale + 0.5))
    local gap = math.max(2, math.floor((common.PAD_HINT_GAP or 5) * textScale + 0.5))
    local rowH = math.max(14, math.floor((common.PAD_HINT_ROW_H or 28) * textScale + 0.5))
    local rowGap = math.max(2, math.floor((common.PAD_HINT_ROW_GAP or 6) * textScale + 0.5))
    local approxCharW = math.floor(8 * drawScale)
    local textH = math.max(10, math.floor((common.FT_PIXEL_H or 18) * textScale + 0.5))
    local width = (type(totalWidth) == "number" and totalWidth > 0) and totalWidth or common.PAD_HINT_DEFAULT_WIDTH
    local sideMargin = common.PAD_HINT_SIDE_MARGIN or 0
    local xEff = x + sideMargin
    local widthEff = width - 2 * sideMargin
    local slotCount = 6
    local slotW = widthEff / slotCount
    local hintFont = font
    if drawMode == "ftPrint" then
      local f = getHintFtFont(textScale)
      if f then hintFont = f end
    end

    local function getTextWidth(label)
      if not label or label == "" then return 0 end
      if drawMode == "ftPrint" and hintFont and Font and Font.ftCalcDimensions then
        local w = Font.ftCalcDimensions(hintFont, label)
        return (type(w) == "number" and w > 0) and w or math.floor(approxCharW * #label)
      end
      return math.floor(approxCharW * #label)
    end

    local topPads = { "left", "l1", "l2", "r2", "r1", "right" }
    local bottomPads = { "cross", "square", "select", "start", "triangle", "circle" }
    local topSlots, bottomSlots = {}, {}
    local topMap, bottomMap = {}, {}
    local drawUnusedButtons = common.PAD_HINT_DRAW_UNUSED_BUTTONS == true
    for i = 1, slotCount do
      topMap[topPads[i]] = i
      bottomMap[bottomPads[i]] = i
      if drawUnusedButtons then
        topSlots[i] = { pad = topPads[i], label = "", used = false }
        bottomSlots[i] = { pad = bottomPads[i], label = "", used = false }
      end
    end

    local overflow = {}
    for i = 1, #hintItems do
      local item = hintItems[i]
      local padName = tostring((item and item.pad) or "")
      local key = padName:lower()
      if key ~= "" then
        local topIdx = topMap[key]
        local bottomIdx = bottomMap[key]
        if topIdx and (drawUnusedButtons or not topSlots[topIdx]) then
          topSlots[topIdx] = { pad = key, label = tostring(item.label or ""), used = true }
        elseif bottomIdx and (drawUnusedButtons or not bottomSlots[bottomIdx]) then
          bottomSlots[bottomIdx] = { pad = key, label = tostring(item.label or ""), used = true }
        else
          overflow[#overflow + 1] = item
        end
      end
    end

    local function placeOverflow(slots)
      for i = 1, slotCount do
        if (not slots[i] or not slots[i].used) and #overflow > 0 then
          local item = table.remove(overflow, 1)
          slots[i] = { pad = tostring(item.pad or ""), label = tostring(item.label or ""), used = true }
        end
      end
    end
    placeOverflow(bottomSlots)
    placeOverflow(topSlots)

    local totalRowH = rowH * 2 + rowGap
    local rowTop = math.floor(y) - totalRowH

    local function drawRow(slots, rowIndex)
      local rTop = rowTop + rowIndex * (rowH + rowGap)
      local rowCenter = rTop + rowH / 2
      local iconY = math.floor(rowCenter - iconH / 2)
      local textY = math.floor(rowCenter - textH / 2) - 4
      local activeIconColor = Color.new(255, 255, 255, 255)
      local inactiveIconColor = Color.new(255, 255, 255, common.PAD_HINT_UNUSED_ALPHA or 38)
      for col = 1, slotCount do
        local item = slots[col]
        local padName = item and item.pad
        local label = (item and item.label) or ""
        local isUsed = item and item.used
        if padName and padName ~= "" then
          local icon = common.getPadIcon(padName)
          local slotLeft = xEff + (col - 1) * slotW
          local slotCenter = slotLeft + slotW / 2
          local px = math.floor(slotCenter - iconW / 2)
          if icon then
            local iconColor = isUsed and activeIconColor or inactiveIconColor
            if Graphics.drawScaleImage then
              Graphics.drawScaleImage(icon, px, iconY, iconW, iconH, iconColor)
            else
              Graphics.drawImage(icon, px, iconY, iconColor)
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
            common.drawText(hintFont, drawMode, textX, textY, drawScale, label, color, textH)
          end
        end
      end
    end

    drawRow(topSlots, 0)
    drawRow(bottomSlots, 1)
    return
  end
  if textFallback and textFallback ~= "" then
    local rowTop = math.floor(y) - common.PAD_HINT_ROW_H
    common.drawText(font, drawMode, x, rowTop + math.floor((common.PAD_HINT_ROW_H - 16) / 2), scale, textFallback, color)
  end
end

-- Build editor hint items: show ±1/±10/±50 only for int/string; enum/bool use left/right with enumHintLabels.
-- Show Reset only when option has default.
function common.buildEditorHintItems(selOpt, hintEditItems, getDefaultFn, enumHintLabels)
  if not hintEditItems or #hintEditItems == 0 then return hintEditItems end
  local numericPads = { left = true, right = true, L1 = true, R1 = true, L2 = true, R2 = true }
  local showNumeric = selOpt and
      (selOpt.optType == "int" or selOpt.optType == "string" or selOpt.optType == "enum" or selOpt.optType == "bool")
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
common.KEY_BG = Color.new(56, 56, 56)
common.KEY_BG_SEL = Color.new(80, 80, 80)
common.KEY_BORDER = Color.new(100, 100, 100)
common.KEY_BORDER_SEL = Color.new(180, 160, 100)
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

-- Save config; for pfs0 (__sysconf) paths we mount, save, then unmount so ELF browsing does not break saving.
function common.saveConfig(ctx, path, lines, createDir)
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
    if saveDir and saveDir ~= "" then
      local dPart, dRest = splitHddPartitionPath(saveDir)
      if dPart and dPart == part and dRest then
        saveDir = "pfs0:" .. dRest
      end
    end
    if System and System.fileXioMount then
      System.fileXioMount("pfs0:", part)
      mounted = "pfs0:"
    end
  elseif savePath and savePath:match("^pfs0:/") then
    if System and System.fileXioMount then
      System.fileXioMount("pfs0:", "hdd0:__sysconf")
      mounted = "pfs0:"
    end
  end
  local ok, err = ctx._.config_parse.save(savePath, lines, saveDir)
  if mounted and System and System.fileXioUmount then
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

local PAD_UP, PAD_DOWN, PAD_LEFT, PAD_RIGHT = 0x0010, 0x0040, 0x0080, 0x0020
local PAD_L1, PAD_R1, PAD_L2, PAD_R2 = 0x0400, 0x0800, 0x0100, 0x0200
common.REPEATABLE_MASK = PAD_UP | PAD_DOWN | PAD_LEFT | PAD_RIGHT | PAD_L1 | PAD_R1 | PAD_L2 | PAD_R2

-- Update ctx with layout values from current screen mode (for scene runner).
function common.runLayout(ctx)
  local vmode = Screen.getMode()
  local w = (vmode and vmode.width) or common.DEFAULT_W
  local h = (vmode and vmode.height) or common.DEFAULT_H
  local sy = h / common.DEFAULT_H
  if ctx then
    ctx.w = w
    ctx.h = h
    ctx.sy = sy
    ctx.MARGIN_Y = math.floor(common.MARGIN_Y * sy)
    ctx.LINE_H = common.LINE_H
    ctx.ROW_H = common.ROW_H
    ctx.HINT_Y = h - math.floor(24 * sy)
    ctx.DESC_Y_BOTTOM = ctx.HINT_Y - common.PAD_HINT_TOTAL_H - common.DESC_TO_HINT_MARGIN
    ctx.scaleY = function(y) return math.floor((y or 0) * sy) end
  end
end

-- Shared scene loop: clear, layout, getPadEffective, runHandler(ctx, pad), exit when ctx.state ~= sceneName.
function common.runSceneLoop(ctx, sceneName, runHandler)
  while true do
    Screen.clear(common.BGCOLOR)
    common.runLayout(ctx)
    if ctx and ctx.drawBackgroundLayer then
      ctx.drawBackgroundLayer(ctx)
    end
    local padEffective = common.getPadEffective(ctx)
    runHandler(ctx, padEffective)
    if ctx.state ~= sceneName then
      return ctx.state, ctx
    end
    Screen.flip()
    Screen.waitVblankStart()
  end
end

-- Get pad with repeat logic; updates ctx.prevPad and ctx.holdFrameCount. Returns padEffective.
function common.getPadEffective(ctx)
  local pad = Pads.get(0)
  local padJust = pad & ~(ctx.prevPad or 0)
  local fps = (Screen.getMode() and Screen.getMode().height == 512) and 50 or 60
  local REPEAT_DELAY_FRAMES = math.ceil(fps / 3)
  ctx.holdFrameCount = ctx.holdFrameCount or 0
  local padRepeat = 0
  if (pad & common.REPEATABLE_MASK) ~= 0 then
    ctx.holdFrameCount = ctx.holdFrameCount + 1
    if ctx.holdFrameCount >= REPEAT_DELAY_FRAMES then
      padRepeat = pad & common.REPEATABLE_MASK
      ctx.holdFrameCount = 0
    end
  else
    ctx.holdFrameCount = 0
  end
  ctx.prevPad = pad
  return padJust | padRepeat
end

function common.loadCustomFont()
  Font.ftInit()
  -- CWD first (user override)
  local f = Font.ftLoad("font.ttf")
  if f and f >= 0 then
    Font.ftSetPixelSize(f, 0, common.FT_PIXEL_H)
    return f, "ftPrint"
  end
  -- Try known font path inside the scripts directory (including VFS)
  f = Font.ftLoad("scripts/font/font.ttf")
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
  if font and Font and Font.ftCalcDimensions then
    local w = Font.ftCalcDimensions(font, text)
    return (type(w) == "number" and w > 0) and w or math.floor(approxCharW * #text)
  end
  return math.floor(approxCharW * #text)
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

-- Return row text fitted to maxPixels. Selected rows use delayed horizontal marquee
-- (hold at start, scroll right, hold at end, then repeat). Unselected rows are truncated.
function common.fitListRowText(ctx, stateKey, font, text, maxPixels, scale, selected, opts)
  local raw = tostring(text or "")
  if maxPixels <= 0 or raw == "" then return raw end
  local s = scale or 1
  if not selected then
    if ctx and ctx._rowMarqueeStates and stateKey then
      ctx._rowMarqueeStates[stateKey] = nil
    end
    return common.truncateTextToWidth(font, raw, maxPixels, s)
  end
  local textW = common.calcTextWidth(font, raw, s) or 0
  if textW <= maxPixels then
    if ctx and ctx._rowMarqueeStates and stateKey then
      ctx._rowMarqueeStates[stateKey] = nil
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
  local st = store[stateKey]
  if not st or st.text ~= raw or st.maxPixels ~= maxPixels or st.scale ~= s then
    st = {
      text = raw,
      maxPixels = maxPixels,
      scale = s,
      ticks = 0,
      visibleChars = nil,
    }
    store[stateKey] = st
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

-- Unified save splash: "Saved" or "Save failed", drawn on top. ctx.saveSplash = { kind = "saved"|"failed", detail = string, framesLeft = N }.
-- Decrements framesLeft; when 0, clears saveSplash and (if kind=="saved" and returnToSelectConfigAfterSaveFlash) performs transition.
function common.drawSaveSplash(ctx)
  local sp = ctx.saveSplash
  if not sp or not sp.framesLeft or sp.framesLeft <= 0 then return end
  local _ = ctx._
  local lineH = _.LINE_H or common.LINE_H
  local title = (sp.kind == "failed") and (_.editor_str.save_failed or "Save failed") or (_.editor_str.saved or "Saved")
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
  common.drawText(_.font, _.drawMode, common.centerX(_, tw), centerY, 1, title, _.HIGHLIGHT)
  if detailStr ~= "" then
    common.drawText(_.font, _.drawMode, common.centerX(_, detailW), centerY + lineH, 1, detailStr, _.HIGHLIGHT)
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
