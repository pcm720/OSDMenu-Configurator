--[[ Color editor (RGBA channels). ]]

local function clamp255(v)
  if v < 0 then return 0 end
  if v > 255 then return 255 end
  return v
end

local function run(ctx)
  local _ = ctx._
  if not (ctx.colorOpt and ctx.colorVals and ctx.lines) then
    ctx.state = "editor"
    return
  end

  local colorLabel = (_.strings.options and _.strings.options[ctx.colorOpt.key] and _.strings.options[ctx.colorOpt.key].label) or
      ctx.colorOpt.key
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, colorLabel .. _.editor_str.edit_color_suffix, _.WHITE)

  local r, g, b, a = ctx.colorVals[1], ctx.colorVals[2], ctx.colorVals[3], ctx.colorVals[4]
  local rawStr = _.formatColor(r, g, b, a)
  local boxSize = 180
  local centerY = math.floor((_.MARGIN_Y + _.HINT_Y) / 2)
  local row0Y = centerY - 2 * _.LINE_H
  local rightBlockH = boxSize + 4 + _.LINE_H
  local previewTop = centerY - math.floor(rightBlockH / 2)
  local rightX = _.w - _.MARGIN_X - boxSize
  _.Graphics.drawRect(rightX, previewTop, boxSize, boxSize, _.Color.new(r, g, b, a))
  local rawW = (_.common and _.common.calcTextWidth and _.common.calcTextWidth(_.font, rawStr, 0.8)) or (22 * #rawStr)
  local rawTextX = rightX + math.floor((boxSize - rawW) / 2)
  _.drawText(_.font, _.drawMode, rawTextX, previewTop + boxSize + 4, 0.8, rawStr, _.GRAY)

  local valueColRight = rightX - 48
  local chNames = { _.editor_str.red, _.editor_str.green, _.editor_str.blue, _.editor_str.alpha }
  local edit = ctx.colorDigitEdit
  local selectedDigit = edit and edit.digit or 1 -- 1=hundreds, 2=tens, 3=ones

  for ch = 1, 4 do
    local y = row0Y + (ch - 1) * _.LINE_H
    local labelCol = (ch == ctx.colorCh) and _.SELECTED_ENTRY or _.WHITE
    _.drawListRow(_.MARGIN_X + 20, y, ch == ctx.colorCh, chNames[ch], labelCol)

    local val = clamp255(tonumber(ctx.colorVals[ch]) or 0)
    local valStr = string.format("%03d", val)
    local valW = (_.common and _.common.calcTextWidth and _.common.calcTextWidth(_.font, valStr, _.FONT_SCALE)) or
        (18 * #valStr)
    local drawX = valueColRight - valW
    if edit and ch == ctx.colorCh then
      local x = drawX
      for i = 1, #valStr do
        local c = valStr:sub(i, i)
        local col = (i == selectedDigit) and (_.SELECTED_ENTRY or _.WHITE) or _.WHITE
        _.drawText(_.font, _.drawMode, x, y, _.FONT_SCALE, c, col)
        local cw = (_.common and _.common.calcTextWidth and _.common.calcTextWidth(_.font, c, _.FONT_SCALE)) or 10
        x = x + cw
      end
    else
      local valCol = (ch == ctx.colorCh) and _.WHITE or _.GRAY
      _.drawText(_.font, _.drawMode, drawX, y, _.FONT_SCALE, valStr, valCol)
    end
  end

  if edit then
    local helperStr = _.editor_str.inline_color_edit_hint or "D-pad: Left/Right digit, Up/Down change, Square channel"
    local helperMaxW = (_.w or 640) - (_.MARGIN_X * 2)
    if _.common.fitListRowText then
      helperStr = _.common.fitListRowText(ctx, "color_edit_helper", _.font, helperStr, helperMaxW, 0.62, true,
        { holdStart = 55, stepFrames = 16, holdEnd = 85 })
    elseif _.common.truncateTextToWidth then
      helperStr = _.common.truncateTextToWidth(_.font, helperStr, helperMaxW, 0.62)
    end
    local helperW = (_.common.calcTextWidth and _.common.calcTextWidth(_.font, helperStr, 0.62)) or (10 * #helperStr)
    local helperX = _.common.centerX(_, helperW)
    _.drawText(_.font, _.drawMode, helperX, _.DESC_Y_BOTTOM, 0.62, helperStr, _.DIM)
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, {
      { pad = "cross", label = "Confirm", row = 1 },
      { pad = "circle", label = "Cancel", row = 1 },
    }, nil, _.DIM, _.w - 2 * _.MARGIN_X)

    if (_.padEffective & _.PAD_LEFT) ~= 0 then
      edit.digit = edit.digit - 1
      if edit.digit < 1 then edit.digit = 3 end
    end
    if (_.padEffective & _.PAD_RIGHT) ~= 0 then
      edit.digit = edit.digit + 1
      if edit.digit > 3 then edit.digit = 1 end
    end

    local weightByDigit = { 100, 10, 1 }
    local weight = weightByDigit[edit.digit] or 1
    if (_.padEffective & _.PAD_UP) ~= 0 then
      ctx.colorVals[ctx.colorCh] = clamp255((ctx.colorVals[ctx.colorCh] or 0) + weight)
    end
    if (_.padEffective & _.PAD_DOWN) ~= 0 then
      ctx.colorVals[ctx.colorCh] = clamp255((ctx.colorVals[ctx.colorCh] or 0) - weight)
    end

    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      _.config_parse.set(ctx.lines, ctx.colorOpt.key, _.formatColor(ctx.colorVals[1], ctx.colorVals[2], ctx.colorVals[3],
        ctx.colorVals[4]))
      ctx.configModified = true
      ctx.state = "editor"
      ctx.colorOpt = nil
      ctx.colorDigitEdit = nil
      ctx.colorChannelOrig = nil
    elseif (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      if ctx.colorChannelOrig ~= nil then
        ctx.colorVals[ctx.colorCh] = clamp255(ctx.colorChannelOrig)
      end
      ctx.colorDigitEdit = nil
      ctx.colorChannelOrig = nil
    end
    return
  end

  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, {
    { pad = "cross", label = "Edit", row = 1 },
    { pad = "circle", label = "Back", row = 1 },
  }, nil, _.DIM, _.w - 2 * _.MARGIN_X)

  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.colorCh = ctx.colorCh - 1
    if ctx.colorCh < 1 then ctx.colorCh = 4 end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.colorCh = ctx.colorCh + 1
    if ctx.colorCh > 4 then ctx.colorCh = 1 end
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    ctx.colorDigitEdit = { digit = 1 }
    ctx.colorChannelOrig = ctx.colorVals[ctx.colorCh]
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.state = "editor"
    ctx.colorOpt = nil
    ctx.colorDigitEdit = nil
    ctx.colorChannelOrig = nil
  end
end

return { run = run }
