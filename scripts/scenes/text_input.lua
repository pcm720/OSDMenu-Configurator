--[[ On-screen keyboard text input. ]]

local actions_menu = dofile("scripts/scenes/actions_menu.lua")

local function buildKeyboardShoulderHints(hintItems)
  local out = {}
  for i = 1, #(hintItems or {}) do
    local item = hintItems[i]
    local pad = tostring(item and item.pad or ""):lower()
    if pad == "l1" or pad == "r1" or pad == "l2" or pad == "r2" then
      out[pad] = tostring(item and item.label or "")
    end
  end
  return out
end

local function drawKeyboardShoulderHints(ctx, _, hintItems, scale, totalWidth, color)
  local labels = buildKeyboardShoulderHints(hintItems)
  if not (labels.l1 or labels.r1) then
    return
  end
  local drawColor = _.WHITE or color or _.DIM
  local iconScale = 0.6
  local textScale = 0.75
  local drawScale = (scale or 0.7) * textScale
  local hintFont = (_.common.getHintFont and _.common.getHintFont(_.font, _.drawMode, textScale)) or _.font
  local iconW = math.max(10, math.floor((_.common.PAD_ICON_W or 26) * iconScale + 0.5))
  local iconH = math.max(10, math.floor((_.common.PAD_ICON_H or 26) * iconScale + 0.5))
  local gap = math.max(2, math.floor((_.common.PAD_HINT_GAP or 5) * textScale + 0.5))
  local rowH = math.max(14, math.floor((_.common.PAD_HINT_ROW_H or 28) * textScale + 0.5))
  local textH = math.max(10, math.floor((_.common.FT_PIXEL_H or 18) * textScale + 0.5))
  local width = (type(totalWidth) == "number" and totalWidth > 0) and totalWidth or _.common.PAD_HINT_DEFAULT_WIDTH
  width = width + (tonumber(_.common.PAD_HINT_GRID_EXTRA_W) or 0)
  local sideMargin = _.common.PAD_HINT_SIDE_MARGIN or 0
  local xEff = (_.MARGIN_X or 0) + sideMargin + (tonumber(_.common.PAD_HINT_GRID_X_SHIFT) or 0)
  local widthEff = width - 2 * sideMargin
  local slotW = widthEff / 5
  local bottomRowTop = math.floor(_.HINT_Y) - rowH
  local topRowTop = bottomRowTop - rowH

  local columns = {
    { pad = "l1", col = 2 },
    { pad = "r1", col = 4 },
  }

  for i = 1, #columns do
    local c = columns[i]
    local label = labels[c.pad]
    if label and label ~= "" then
      local icon = _.common.getPadIcon(c.pad)
      local slotCenter = xEff + (c.col - 1) * slotW + (slotW / 2)
      local iconY = math.floor(topRowTop + (rowH - iconH) / 2)
      local textY = math.floor(topRowTop + (rowH - textH) / 2) - 4
      if icon then
        local px = math.floor(slotCenter - iconW / 2)
        if _.Graphics.drawScaleImage then
          _.Graphics.drawScaleImage(icon, px, iconY, iconW, iconH)
        else
          _.Graphics.drawImage(icon, px, iconY)
        end
        _.common.drawText(hintFont, _.drawMode, px + iconW + gap, textY, drawScale, label, drawColor, textH)
      else
        local textW = (_.common.calcTextWidth and _.common.calcTextWidth(hintFont, label, drawScale)) or
            math.floor(8 * drawScale * #label)
        local textX = math.floor(slotCenter - (textW / 2))
        _.common.drawText(hintFont, _.drawMode, textX, textY, drawScale, label, drawColor, textH)
      end
    end
  end
end

local BEL = string.char(7)
local BEL_WARNING_TEXT_FALLBACK = "Advanced glyphs, use with caution"
local GLYPH_KEY_LABEL_FALLBACK = "Glyphs"
-- Match current helper-text scale, but keep it decoupled for future tuning.
local GLYPH_KEY_LABEL_SCALE = 0.7
local GLYPH_KEY_GAP_SLOTS = 0.5

local BEL_COLOR_TOKENS = {
  { code = "c0", desc = "White" },
  { code = "c1", desc = "Yellow" },
  { code = "c2", desc = "Blue" },
  { code = "c3", desc = "Pink" },
  { code = "c4", desc = "Gray" },
  { code = "c5", desc = "Cyan" },
  { code = "c6", desc = "Red" },
  { code = "c7", desc = "Grey" },
  { code = "c8", desc = "Grey1" },
  { code = "c9", desc = "Green" },
}

local BEL_SYMBOLS_PS2_ROM = {
  { code = "o000", desc = "Down Shafted Arrow" },
  { code = "o001", desc = "Right Shafted Arrow" },
  { code = "o002", desc = "Left Arrow" },
  { code = "o003", desc = "Right Arrow" },
  { code = "o004", desc = "Registered Trademark" },
  { code = "o005", desc = "Registered Trademark (small)" },
  { code = "o006", desc = "Up Arrow" },
  { code = "o007", desc = "Down Arrow" },
  { code = "o008", desc = "Left Arrow" },
  { code = "o009", desc = "Right Arrow" },
  { code = "o010", desc = "Up Button" },
  { code = "o011", desc = "Down Button" },
  { code = "o012", desc = "Left Button" },
  { code = "o013", desc = "Right Button" },
  { code = "o014", desc = "Repeat" },
  { code = "o015", desc = "Up/Down Arrows" },
  { code = "o016", desc = "(PS2)" },
  { code = "o017", desc = "(PS2), cut off" },
  { code = "o018", desc = "Stop" },
  { code = "o019", desc = "Daylight Savings(?)" },
  { code = "o020", desc = "Up/Down Arrows (again?)" },
  { code = "o021", desc = "Up/Down Arrows (again)" },
}

local BEL_SYMBOLS_HDDOSD = {
  { code = "o000", desc = "Double-chevron opening quote" },
  { code = "o001", desc = "Double-chevron closing quote" },
  { code = "o002", desc = "Bar" },
  { code = "o003", desc = "Bar" },
  { code = "o004", desc = "Right Shafted Arrow" },
  { code = "o005", desc = "Left Arrow" },
  { code = "o006", desc = "Right Arrow" },
  { code = "o007", desc = "Registered Trademark" },
  { code = "o008", desc = "Registered Trademark (small)" },
  { code = "o009", desc = "Up Arrow" },
  { code = "o010", desc = "Left Arrow" },
  { code = "o011", desc = "Down Arrow" },
  { code = "o012", desc = "Right Arrow" },
  { code = "o013", desc = "Up Button" },
  { code = "o014", desc = "Down Button" },
  { code = "o015", desc = "Left Button" },
  { code = "o016", desc = "Right Button" },
  { code = "o017", desc = "Repeat Icon" },
  { code = "o018", desc = "Up/Down Arrows" },
  { code = "o019", desc = "Stop Icon" },
  { code = "o020", desc = "Daylight Savings(?)" },
  { code = "o021", desc = "Up/Down Arrows (again?)" },
  { code = "o022", desc = "Up/Down Arrows (small)" },
  { code = "o023", desc = "Warning Icon" },
}

local function countBelChars(s)
  local _, n = tostring(s or ""):gsub(BEL, "")
  return n or 0
end

local function clampBelCharsToBaseline(currentValue, baselineValue)
  local keepBel = countBelChars(baselineValue)
  local out = {}
  local kept = 0
  local s = tostring(currentValue or "")
  for i = 1, #s do
    local ch = s:sub(i, i)
    if ch == BEL then
      if kept < keepBel then
        kept = kept + 1
        out[#out + 1] = ch
      end
    else
      out[#out + 1] = ch
    end
  end
  return table.concat(out)
end

local function belProfileFromContext(ctx)
  local profile = tostring(ctx and ctx.textInputBelProfile or ""):lower()
  if profile == "hddosd" then return "hddosd" end
  if profile == "ps2rom" then return "ps2rom" end
  return "ps2rom"
end

local function buildBelTokenRows(profile)
  local out = {}
  local symHeader = (profile == "hddosd") and "Symbols (HDDOSD Browser 2.00)" or "Symbols (PS2 ROM OSD)"
  local symRows = (profile == "hddosd") and BEL_SYMBOLS_HDDOSD or BEL_SYMBOLS_PS2_ROM

  out[#out + 1] = { id = "header_colors", label = "Colors", enabled = false }
  for i = 1, #BEL_COLOR_TOKENS do
    local t = BEL_COLOR_TOKENS[i]
    local token = BEL .. tostring(t.code)
    out[#out + 1] = {
      id = "token_" .. tostring(t.code),
      label = token .. "  " .. tostring(t.desc or ""),
      token = token,
    }
  end

  out[#out + 1] = { id = "header_symbols", label = symHeader, enabled = false }
  for i = 1, #symRows do
    local t = symRows[i]
    local token = BEL .. tostring(t.code)
    out[#out + 1] = {
      id = "token_" .. tostring(t.code),
      label = token .. "  " .. tostring(t.desc or ""),
      token = token,
    }
  end
  return out
end

local function drawBelWarning(_, text, scale, totalWidth, color)
  local drawColor = _.WHITE or color or _.DIM
  local textScale = 0.75
  local drawScale = (scale or 0.7) * textScale
  local hintFont = (_.common.getHintFont and _.common.getHintFont(_.font, _.drawMode, textScale)) or _.font
  local rowH = math.max(14, math.floor((_.common.PAD_HINT_ROW_H or 28) * textScale + 0.5))
  local textH = math.max(10, math.floor((_.common.FT_PIXEL_H or 18) * textScale + 0.5))
  local width = (type(totalWidth) == "number" and totalWidth > 0) and totalWidth or _.common.PAD_HINT_DEFAULT_WIDTH
  width = width + (tonumber(_.common.PAD_HINT_GRID_EXTRA_W) or 0)
  local sideMargin = _.common.PAD_HINT_SIDE_MARGIN or 0
  local xEff = (_.MARGIN_X or 0) + sideMargin + (tonumber(_.common.PAD_HINT_GRID_X_SHIFT) or 0)
  local widthEff = width - 2 * sideMargin
  local topRowTop = math.floor(_.HINT_Y) - (2 * rowH)
  local warnRowTop = topRowTop - rowH
  local msg = tostring(text or "")
  local textW = (_.common.calcTextWidth and _.common.calcTextWidth(hintFont, msg, drawScale)) or
      math.floor(8 * drawScale * #msg)
  local textX = math.floor(xEff + (widthEff - textW) / 2)
  local textY = math.floor(warnRowTop + (rowH - textH) / 2) - 4
  _.common.drawText(hintFont, _.drawMode, textX, textY, drawScale, msg, drawColor, textH)
end

local function run(ctx)
  local _ = ctx._
  if not ctx.textInputCallback then
    ctx.textInputBelMenuOpen = nil
    ctx.textInputBelMenuSel = nil
    ctx.textInputBelMenuScroll = nil
    ctx._textInputBelBaselineCallback = nil
    ctx.textInputBelBaseline = nil
    ctx.textInputAllowBelAdd = nil
    ctx.textInputEnableBelKey = nil
    ctx.textInputBelProfile = nil
    ctx.textInputHidePipeBackslash = nil
    ctx.state = "editor"; return
  end
  if ctx._textInputBelBaselineCallback ~= ctx.textInputCallback then
    ctx._textInputBelBaselineCallback = ctx.textInputCallback
    ctx.textInputBelBaseline = tostring(ctx.textInputValue or "")
  end
  if not ctx.textInputCursor then ctx.textInputCursor = #ctx.textInputValue + 1 end
  if ctx.textInputCursor < 1 then ctx.textInputCursor = 1 end
  if ctx.textInputCursor > #ctx.textInputValue + 1 then ctx.textInputCursor = #ctx.textInputValue + 1 end
  local TEXT_DISP_CHARS = 42
  if ctx.textInputCursor < ctx.textInputScroll then ctx.textInputScroll = ctx.textInputCursor end
  if ctx.textInputCursor > ctx.textInputScroll + TEXT_DISP_CHARS - 1 then
    ctx.textInputScroll = ctx.textInputCursor -
        TEXT_DISP_CHARS + 1
  end
  if ctx.textInputScroll < 1 then ctx.textInputScroll = 1 end
  if ctx.textInputScroll > #ctx.textInputValue + 1 then
    ctx.textInputScroll = math.max(1,
      #ctx.textInputValue - TEXT_DISP_CHARS + 2)
  end
  local segStart = ctx.textInputScroll
  local segEnd = math.min(segStart + TEXT_DISP_CHARS - 2, #ctx.textInputValue)
  local beforeCurs = ctx.textInputValue:sub(segStart, ctx.textInputCursor - 1)
  local afterCurs = ctx.textInputValue:sub(ctx.textInputCursor, segEnd)
  local baseX = _.KEYBOARD_CENTER_X - 200
  local textY = _.scaleY(108)
  local scale = 0.9
  _.drawText(_.font, _.drawMode, _.KEYBOARD_CENTER_X - 200, _.scaleY(88), 0.9,
    ctx.textInputPrompt or _.common_str.enter_text, _.DIM)
  local x = baseX
  if beforeCurs ~= "" then
    _.drawText(_.font, _.drawMode, x, textY, scale, beforeCurs, _.WHITE)
    x = x + (_.common.calcTextWidth and _.common.calcTextWidth(_.font, beforeCurs, scale) or (#beforeCurs * 10))
  end
  _.drawText(_.font, _.drawMode, x, textY, scale, "|", _.TEXT_CURSOR_COLOR or _.WHITE)
  x = x + (_.common.calcTextWidth and _.common.calcTextWidth(_.font, "|", scale) or 10)
  if afterCurs ~= "" then
    _.drawText(_.font, _.drawMode, x, textY, scale, afterCurs, _.WHITE)
  end
  local rows = ctx.textInputTitleIdMode and (_.KEYBOARD_ROWS_TITLE_ID or _.KEYBOARD_ROWS_SHIFTED) or
      (ctx.textInputShift and _.KEYBOARD_ROWS_SHIFTED or _.KEYBOARD_ROWS)
  if ctx.textInputHidePipeBackslash then
    local filtered = {}
    for i = 1, #(rows or {}) do
      local row = tostring(rows[i] or "")
      row = row:gsub("\\", "")
      row = row:gsub("|", "")
      filtered[#filtered + 1] = row
    end
    rows = filtered
  end
  local belEnabled = (ctx.textInputEnableBelKey == true) and (not ctx.textInputTitleIdMode)
  local glyphKeyLabel = (_.text_str and _.text_str.glyphs_key_label) or GLYPH_KEY_LABEL_FALLBACK
  local keyList = {}
  local specialKeys = {}
  local rowLen = {}
  local rowStart = {}
  local rowCount = #rows
  local running = 1
  for r = 1, rowCount do
    local row = rows[r] or ""
    rowStart[r] = running
    rowLen[r] = #row
    for i = 1, #row do
      keyList[#keyList + 1] = row:sub(i, i)
    end
    running = running + rowLen[r]
  end
  local belIdx = nil
  local spaceIdx = nil
  if not ctx.textInputTitleIdMode then
    if belEnabled then
      belIdx = running
      keyList[#keyList + 1] = ""
      specialKeys[belIdx] = { kind = "bel", label = glyphKeyLabel }
      rowLen[rowCount] = (rowLen[rowCount] or 0) + 1
      running = running + 1
    end
    rowStart[rowCount + 1] = running
    spaceIdx = running
    keyList[#keyList + 1] = " "
    specialKeys[spaceIdx] = { kind = "space", label = "" }
    running = running + 1
    rowLen[rowCount + 1] = 1
  end
  local maxRow = rowCount + ((spaceIdx ~= nil) and 1 or 0)
  if ctx.textInputGridSel < 1 then ctx.textInputGridSel = 1 end
  if ctx.textInputGridSel > #keyList then ctx.textInputGridSel = #keyList end
  local keyY = _.KEYBOARD_CENTER_Y - _.scaleY(50)
  local kw, kh = _.KEY_WIDTH - _.KEY_GAP, _.KEY_H - _.KEY_GAP
  local keyScale = 0.7
  local glyphLabelW = (_.common.calcTextWidth and _.common.calcTextWidth(_.font, glyphKeyLabel, GLYPH_KEY_LABEL_SCALE))
      or math.floor(((_.KEY_CHAR_W or 8) * GLYPH_KEY_LABEL_SCALE) * #glyphKeyLabel)
  local glyphPadX = math.max(4, math.floor((_.KEY_WIDTH * 0.22) + 0.5))
  local glyphW = math.max(kw, glyphLabelW + (glyphPadX * 2))
  local rowOffsets = (ctx.textInputTitleIdMode and _.KEYBOARD_ROW_OFFSETS_TITLE_ID) or _.KEYBOARD_ROW_OFFSETS or
      { 0, 0.5, 0.85, 1.2 }
  local minOffset = 0
  local maxExtent = 0
  for r = 1, rowCount do
    local off = tonumber(rowOffsets[r]) or 0
    if r == 1 or off < minOffset then minOffset = off end
    -- Keep classic qwerty alignment centered from the base character rows only.
    local extent = off + #(rows[r] or "")
    if extent > maxExtent then maxExtent = extent end
  end
  local keyboardBlockW = math.max(_.KEY_WIDTH, (maxExtent - minOffset) * _.KEY_WIDTH)
  local keyboardLeft = _.KEYBOARD_CENTER_X - keyboardBlockW / 2 - (minOffset * _.KEY_WIDTH)

  local function drawKey(kx, ky, w, h, label, sel, labelScale)
    local drawLabelScale = tonumber(labelScale) or keyScale
    local bg = sel and _.KEY_BG_SEL or _.KEY_BG
    local border = sel and _.KEY_BORDER_SEL or _.KEY_BORDER
    _.Graphics.drawRect(kx, ky, w, h, bg)
    _.Graphics.drawRect(kx, ky, w, 1, border)
    _.Graphics.drawRect(kx, ky + h - 1, w, 1, border)
    _.Graphics.drawRect(kx, ky, 1, h, border)
    _.Graphics.drawRect(kx + w - 1, ky, 1, h, border)
    local textW = (_.common.calcTextWidth and _.common.calcTextWidth(_.font, label, drawLabelScale)) or
        (_.KEY_CHAR_W * #label)
    local textX = math.max(kx, math.floor(kx + (w - textW) / 2))
    local textY = math.floor(ky + (h - _.KEY_LH) / 2) - 2
    _.drawText(_.font, _.drawMode, textX, textY, drawLabelScale, label, sel and _.HIGHLIGHT or _.WHITE)
  end
  for r = 1, rowCount do
    local row = rows[r] or ""
    local n = #row
    local startX = keyboardLeft + (tonumber(rowOffsets[r]) or 0) * _.KEY_WIDTH
    for col = 1, n do
      local idx = rowStart[r] + col - 1
      local kx = math.floor(startX + (col - 1) * _.KEY_WIDTH + _.KEY_GAP / 2)
      local ky = math.floor(keyY + (r - 1) * _.KEY_H + _.KEY_GAP / 2)
      local ch = row:sub(col, col)
      drawKey(kx, ky, kw, kh, ch, idx == ctx.textInputGridSel)
    end
  end
  if belIdx then
    local belRow = rowCount
    local row = rows[belRow] or ""
    local startX = keyboardLeft + (tonumber(rowOffsets[belRow]) or 0) * _.KEY_WIDTH
    local belCol = #row + 1 + GLYPH_KEY_GAP_SLOTS
    local belKx = math.floor(startX + (belCol - 1) * _.KEY_WIDTH + _.KEY_GAP / 2)
    local belKy = math.floor(keyY + (belRow - 1) * _.KEY_H + _.KEY_GAP / 2)
    drawKey(belKx, belKy, glyphW, kh, glyphKeyLabel, belIdx == ctx.textInputGridSel, GLYPH_KEY_LABEL_SCALE)
  end
  if spaceIdx then
    local specY = keyY + rowCount * _.KEY_H
    local ky = math.floor(specY + _.KEY_GAP / 2)
    local specSlotW = _.KEY_WIDTH * 2.2
    local spaceW = math.floor(specSlotW * 2 - _.KEY_GAP)
    local specStartX = _.KEYBOARD_CENTER_X - spaceW / 2
    drawKey(specStartX, ky, spaceW, kh, "", spaceIdx == ctx.textInputGridSel)
  end

  if ctx.textInputBelMenuOpen then
    local belRows = buildBelTokenRows(belProfileFromContext(ctx))
    local handled = actions_menu.run(ctx, {
      openKey = "textInputBelMenuOpen",
      selKey = "textInputBelMenuSel",
      scrollKey = "textInputBelMenuScroll",
      rowStateKeyPrefix = "text_input_bel_row_",
      anchorPad = "square",
      anchorLabel = glyphKeyLabel,
      titleOverride = "Insert Advanced Control",
      rows = belRows,
      maxVisible = 8,
      closeOnSelect = true,
      onSelect = function(row)
        local token = row and row.token
        if token and #ctx.textInputValue + #token <= ctx.textInputMaxLen then
          ctx.textInputValue = ctx.textInputValue:sub(1, ctx.textInputCursor - 1) ..
              token .. ctx.textInputValue:sub(ctx.textInputCursor)
          ctx.textInputCursor = ctx.textInputCursor + #token
        end
      end,
      onCancel = function()
        ctx.textInputBelMenuOpen = nil
        ctx.textInputBelMenuSel = nil
        ctx.textInputBelMenuScroll = nil
      end,
      hints = {
        { pad = "cross", label = "Insert", row = 1 },
        { pad = "square", label = "Close", row = 1 },
        { pad = "circle", label = "Cancel", row = 1 },
      },
    })
    if handled then
      return
    end
  end
  local rowSize = rowLen
  local function rowOf(s)
    for r = 1, maxRow do
      local start = rowStart[r]
      local size = rowSize[r] or 0
      if start and size > 0 and s >= start and s < (start + size) then
        return r
      end
    end
    return 1
  end
  if (_.padEffective & _.PAD_LEFT) ~= 0 then
    ctx.textInputGridSel = ctx.textInputGridSel - 1; if ctx.textInputGridSel < 1 then ctx.textInputGridSel = #keyList end
  end
  if (_.padEffective & _.PAD_RIGHT) ~= 0 then
    ctx.textInputGridSel = ctx.textInputGridSel + 1; if ctx.textInputGridSel > #keyList then ctx.textInputGridSel = 1 end
  end
  if (_.padEffective & _.PAD_UP) ~= 0 then
    local r = rowOf(ctx.textInputGridSel)
    if r > 1 then
      local colInRow = ctx.textInputGridSel - rowStart[r] + 1
      local prevSize = rowSize[r - 1]
      ctx.textInputGridSel = rowStart[r - 1] + math.min(colInRow, prevSize) - 1
    elseif r == 1 and spaceIdx then
      ctx.textInputGridSel = spaceIdx
    end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    local r = rowOf(ctx.textInputGridSel)
    if r < maxRow then
      local colInRow = ctx.textInputGridSel - rowStart[r] + 1
      local nextSize = rowSize[r + 1]
      ctx.textInputGridSel = rowStart[r + 1] + math.min(colInRow, nextSize) - 1
    elseif r == maxRow and spaceIdx then
      local colInRow = ctx.textInputGridSel - rowStart[r] + 1
      ctx.textInputGridSel = rowStart[1] + math.min(colInRow, rowSize[1]) - 1
    end
  end
  if (_.padEffective & _.PAD_L1) ~= 0 then ctx.textInputCursor = math.max(1, ctx.textInputCursor - 1) end
  if (_.padEffective & _.PAD_R1) ~= 0 then
    ctx.textInputCursor = math.min(#ctx.textInputValue + 1,
      ctx.textInputCursor + 1)
  end
  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    local selIdx = ctx.textInputGridSel
    local sk = specialKeys[selIdx]
    if sk and sk.kind == "bel" then
      ctx.textInputBelMenuOpen = true
      ctx.textInputBelMenuSel = ctx.textInputBelMenuSel or 1
      ctx.textInputBelMenuScroll = ctx.textInputBelMenuScroll or 0
    elseif sk and sk.kind == "space" then
      if #ctx.textInputValue < ctx.textInputMaxLen then
        ctx.textInputValue = ctx.textInputValue:sub(1, ctx.textInputCursor - 1) ..
            " " .. ctx.textInputValue:sub(ctx.textInputCursor)
        ctx.textInputCursor = ctx.textInputCursor + 1
      end
    else
      local ch = keyList[selIdx]
      -- Safety guard: on-screen keyboard must never insert BEL control bytes.
      if ch and ch ~= BEL and #ctx.textInputValue < ctx.textInputMaxLen then
        ctx.textInputValue = ctx.textInputValue:sub(1, ctx.textInputCursor - 1) ..
            ch .. ctx.textInputValue:sub(ctx.textInputCursor)
        ctx.textInputCursor = ctx.textInputCursor + 1
      end
    end
  end
  if (_.padEffective & _.PAD_START) ~= 0 then
    local submitValue = tostring(ctx.textInputValue or "")
    if ctx.textInputAllowBelAdd ~= true then
      submitValue = clampBelCharsToBaseline(submitValue, ctx.textInputBelBaseline or "")
    end
    ctx.textInputCallback(submitValue)
    ctx.textInputCallback = nil
    ctx._textInputBelBaselineCallback = nil
    ctx.textInputBelBaseline = nil
    ctx.textInputAllowBelAdd = nil
    ctx.textInputEnableBelKey = nil
    ctx.textInputBelProfile = nil
    ctx.textInputHidePipeBackslash = nil
    ctx.textInputBelMenuOpen = nil
    ctx.textInputBelMenuSel = nil
    ctx.textInputBelMenuScroll = nil
    -- Callback sets ctx.state (e.g. applyManualPath -> entry_paths); do not overwrite
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.textInputCallback = nil
    ctx._textInputBelBaselineCallback = nil
    ctx.textInputBelBaseline = nil
    ctx.textInputAllowBelAdd = nil
    ctx.textInputEnableBelKey = nil
    ctx.textInputBelProfile = nil
    ctx.textInputHidePipeBackslash = nil
    ctx.textInputBelMenuOpen = nil
    ctx.textInputBelMenuSel = nil
    ctx.textInputBelMenuScroll = nil
    ctx.state = ctx.textInputReturnState or "menu_entry_edit"
  end
  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 and not ctx.textInputTitleIdMode then
    ctx.textInputShift = not ctx
        .textInputShift
  end
  if (_.padEffective & _.PAD_SQUARE) ~= 0 then
    if ctx.textInputCursor > 1 then
      ctx.textInputValue = ctx.textInputValue:sub(1, ctx.textInputCursor - 2) ..
          ctx.textInputValue:sub(ctx.textInputCursor)
      ctx.textInputCursor = ctx.textInputCursor - 1
    end
  end
  local hints = (ctx.textInputTitleIdMode and _.text_str.hint_items_title_id) or _.text_str.hint_items
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hints, nil, _.DIM,
    _.w - 2 * _.MARGIN_X)
  drawKeyboardShoulderHints(ctx, _, hints, 0.7, _.w - 2 * _.MARGIN_X, _.DIM)
  if belIdx and ctx.textInputGridSel == belIdx then
    local warningText = (_.text_str and _.text_str.advanced_glyphs_warning) or BEL_WARNING_TEXT_FALLBACK
    drawBelWarning(_, warningText, 0.7, _.w - 2 * _.MARGIN_X, _.DIM)
  end
end

return { run = run }
