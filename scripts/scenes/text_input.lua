--[[ On-screen keyboard text input. ]]

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

local function run(ctx)
  local _ = ctx._
  if not ctx.textInputCallback then
    ctx.state = "editor"; return
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
  local keyList = {}
  for _, row in ipairs(rows) do for i = 1, #row do table.insert(keyList, row:sub(i, i)) end end
  if not ctx.textInputTitleIdMode then table.insert(keyList, " ") end
  local rowLen = ctx.textInputTitleIdMode and { 10, 10, 9, 7 } or { 12, 12, 11, 10 }
  if ctx.textInputGridSel < 1 then ctx.textInputGridSel = 1 end
  if ctx.textInputGridSel > #keyList then ctx.textInputGridSel = #keyList end
  local keyY = _.KEYBOARD_CENTER_Y - _.scaleY(50)
  local kw, kh = _.KEY_WIDTH - _.KEY_GAP, _.KEY_H - _.KEY_GAP
  local keyScale = 0.7
  local function drawKey(kx, ky, w, h, label, sel)
    local bg = sel and _.KEY_BG_SEL or _.KEY_BG
    local border = sel and _.KEY_BORDER_SEL or _.KEY_BORDER
    _.Graphics.drawRect(kx, ky, w, h, bg)
    _.Graphics.drawRect(kx, ky, w, 1, border)
    _.Graphics.drawRect(kx, ky + h - 1, w, 1, border)
    _.Graphics.drawRect(kx, ky, 1, h, border)
    _.Graphics.drawRect(kx + w - 1, ky, 1, h, border)
    local textW = (_.common.calcTextWidth and _.common.calcTextWidth(_.font, label, keyScale)) or (_.KEY_CHAR_W * #label)
    local textX = math.max(kx, math.floor(kx + (w - textW) / 2))
    local textY = math.floor(ky + (h - _.KEY_LH) / 2) - 2
    _.drawText(_.font, _.drawMode, textX, textY, keyScale, label, sel and _.HIGHLIGHT or _.WHITE)
  end
  local rowStart = ctx.textInputTitleIdMode and { 1, 11, 21, 30 } or { 1, 13, 25, 36 }
  for r = 1, 4 do
    local n = rowLen[r]
    local startX = _.KEYBOARD_CENTER_X - (n * _.KEY_WIDTH) / 2
    for col = 1, n do
      local idx = rowStart[r] + col - 1
      local kx = math.floor(startX + (col - 1) * _.KEY_WIDTH + _.KEY_GAP / 2)
      local ky = math.floor(keyY + (r - 1) * _.KEY_H + _.KEY_GAP / 2)
      local ch = rows[r]:sub(col, col)
      drawKey(kx, ky, kw, kh, ch, idx == ctx.textInputGridSel)
    end
  end
  if not ctx.textInputTitleIdMode then
    local specY = keyY + 4 * _.KEY_H
    local specSlotW = _.KEY_WIDTH * 2.2
    local spaceW = math.floor(specSlotW * 2 - _.KEY_GAP)
    local specStartX = _.KEYBOARD_CENTER_X - spaceW / 2
    local ky = math.floor(specY + _.KEY_GAP / 2)
    drawKey(specStartX, ky, spaceW, kh, "", 46 == ctx.textInputGridSel)
  end
  rowStart = ctx.textInputTitleIdMode and { 1, 11, 21, 30 } or { 1, 13, 25, 36, 46 }
  local rowSize = ctx.textInputTitleIdMode and { 10, 10, 9, 7 } or { 12, 12, 11, 10, 1 }
  local maxRow = ctx.textInputTitleIdMode and 4 or 5
  local function rowOf(s)
    if ctx.textInputTitleIdMode then
      if s <= 10 then return 1 elseif s <= 20 then return 2 elseif s <= 29 then return 3 else return 4 end
    else
      if s <= 12 then return 1 elseif s <= 24 then return 2 elseif s <= 35 then return 3 elseif s <= 45 then return 4 else return 5 end
    end
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
    elseif r == 1 and not ctx.textInputTitleIdMode then
      ctx.textInputGridSel = 46
    end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    local r = rowOf(ctx.textInputGridSel)
    if r < maxRow then
      local colInRow = ctx.textInputGridSel - rowStart[r] + 1
      local nextSize = rowSize[r + 1]
      ctx.textInputGridSel = rowStart[r + 1] + math.min(colInRow, nextSize) - 1
    elseif r == maxRow and not ctx.textInputTitleIdMode then
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
    if ctx.textInputGridSel <= 45 then
      local ch = keyList[ctx.textInputGridSel]
      if ch and #ctx.textInputValue < ctx.textInputMaxLen then
        ctx.textInputValue = ctx.textInputValue:sub(1, ctx.textInputCursor - 1) ..
            ch .. ctx.textInputValue:sub(ctx.textInputCursor)
        ctx.textInputCursor = ctx.textInputCursor + 1
      end
    elseif not ctx.textInputTitleIdMode and ctx.textInputGridSel == 46 then
      if #ctx.textInputValue < ctx.textInputMaxLen then
        ctx.textInputValue = ctx.textInputValue:sub(1, ctx.textInputCursor - 1) ..
            " " .. ctx.textInputValue:sub(ctx.textInputCursor)
        ctx.textInputCursor = ctx.textInputCursor + 1
      end
    end
  end
  if (_.padEffective & _.PAD_START) ~= 0 then
    ctx.textInputCallback(ctx.textInputValue)
    ctx.textInputCallback = nil
    -- Callback sets ctx.state (e.g. applyManualPath -> entry_paths); do not overwrite
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.textInputCallback = nil
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
end

return { run = run }
