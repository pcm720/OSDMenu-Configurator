--[[ Shared centered actions menu (Square picker). ]]

local actions_menu = {}

local function copyHintItem(src)
  if type(src) ~= "table" then return nil end
  local out = {}
  for k, v in pairs(src) do
    out[k] = v
  end
  return out
end

local function buildOverlayHints(_, incoming, actionsLabel)
  local list = {}
  if type(incoming) == "table" then
    for i = 1, #incoming do
      local it = copyHintItem(incoming[i])
      if it then list[#list + 1] = it end
    end
  end

  if #list == 0 then
    list = {
      { pad = "cross", label = "Select", row = 1 },
      { pad = "square", label = actionsLabel, row = 1 },
      { pad = "circle", label = "Cancel", row = 1 },
    }
  end

  local hasSquare = false
  for i = 1, #list do
    local it = list[i]
    local pad = tostring(it.pad or ""):lower()
    if pad == "square" then
      it.pad = "square"
      it.label = actionsLabel
      it.row = it.row or 1
      hasSquare = true
    end
  end
  if not hasSquare then
    local insertAt = math.min(2, #list + 1)
    table.insert(list, insertAt, { pad = "square", label = actionsLabel, row = 1 })
  end

  return list
end

local function closeMenu(ctx, opts)
  ctx[opts.openKey] = nil
  ctx[opts.selKey] = nil
  ctx[opts.scrollKey] = nil
  ctx[tostring(opts.openKey or "actionsMenuOpen") .. "_anim"] = nil
  ctx[tostring(opts.openKey or "actionsMenuOpen") .. "_closing"] = nil
end

local function normalizeRows(rows)
  local out = {}
  local removeOut = {}
  for i = 1, #(rows or {}) do
    local row = rows[i]
    if row and row.hidden ~= true then
      local id = tostring(row.id or tostring(i))
      local normalized = {
        id = id,
        label = tostring(row.label or ""),
        enabled = (row.enabled ~= false),
        raw = row,
      }
      if id:lower() == "remove" then
        removeOut[#removeOut + 1] = normalized
      else
        out[#out + 1] = normalized
      end
    end
  end
  for i = 1, #removeOut do
    out[#out + 1] = removeOut[i]
  end
  return out
end

function actions_menu.run(ctx, opts)
  if not ctx or type(opts) ~= "table" then return false end
  local _ = ctx._
  if not _ then return false end

  local openKey = opts.openKey or "actionsMenuOpen"
  if not ctx[openKey] then return false end
  local animKey = tostring(openKey) .. "_anim"
  local closingKey = tostring(openKey) .. "_closing"

  local selKey = opts.selKey or "actionsMenuSel"
  local scrollKey = opts.scrollKey or "actionsMenuScroll"
  local rows = normalizeRows(opts.rows or {})

  if #rows == 0 then
    closeMenu(ctx, { openKey = openKey, selKey = selKey, scrollKey = scrollKey })
    return true
  end

  local function isSelectable(idx)
    local row = rows[idx]
    return row and row.enabled
  end

  local function moveSelection(step)
    local idx = ctx[selKey] or 1
    for _attempt = 1, #rows do
      idx = _.common.wrapListSelection(idx, #rows, step)
      if isSelectable(idx) then
        ctx[selKey] = idx
        return
      end
    end
  end

  ctx[selKey] = _.common.clampListSelection(ctx[selKey] or 1, #rows)
  if not isSelectable(ctx[selKey]) then
    moveSelection(1)
  end

  local maxVisible = math.max(1, math.min(#rows, math.floor(tonumber(opts.maxVisible) or 8)))
  ctx[scrollKey] = _.common.centeredListScroll(ctx[selKey], #rows, maxVisible)
  local closing = ctx[closingKey] == true
  local anim = tonumber(ctx[animKey])
  if type(anim) ~= "number" then
    anim = closing and 1 or 0
  end
  if closing then
    anim = math.max(0, anim - (1 / 6))
  else
    anim = math.min(1, anim + (1 / 6))
  end
  ctx[animKey] = anim

  local title = "Select Action:"
  if opts.titleOverride ~= nil and tostring(opts.titleOverride) ~= "" then
    title = tostring(opts.titleOverride)
  end
  local textScale = tonumber((_.common and _.common.PAD_HINT_TEXT_SCALE) or 0.75)
  local titleScale = (_.common and _.common.getHintLabelDrawScale and _.common.getHintLabelDrawScale(0.7)) or (0.7 * textScale)
  local rowScale = titleScale
  local rowStateKeyPrefix = opts.rowStateKeyPrefix or "actions_menu_row_"

  local hintFont = (_.common and _.common.getHintFont and _.common.getHintFont(_.font, _.drawMode, textScale)) or _.font
  local textH = (_.common and _.common.getHintLabelTextHeight and _.common.getHintLabelTextHeight()) or
      math.max(10, math.floor(((_.common and _.common.FT_PIXEL_H or 18) * textScale) + 0.5))

  local function textWidth(text)
    if _.common and _.common.calcTextWidth then
      return _.common.calcTextWidth(hintFont, tostring(text or ""), rowScale)
    end
    local s = tostring(text or "")
    return math.floor((8 * rowScale) * #s)
  end

  local titleW = textWidth(title)
  local spaceW = textWidth(" ")
  if spaceW < 1 then
    local probeW = textWidth("M")
    if probeW < 1 then probeW = math.floor((8 * rowScale) + 0.5) end
    spaceW = math.max(2, math.floor((probeW * 0.32) + 0.5))
  end
  local markerW = textWidth(">")
  if markerW < 1 then
    markerW = math.max(2, math.floor((spaceW * 1.2) + 0.5))
  end
  local baseIndentSpaces = 4 -- Was 2; add +2 spaces per UX request.
  local padX = math.floor((_.scaleY and _.scaleY(8) or 8) + 0.5)
  local padTop = math.floor((_.scaleY and _.scaleY(6) or 6) + 0.5)
  local rowIndentW = baseIndentSpaces * spaceW
  local titleH = textH + 2
  local titleGap = 0
  local padBottom = math.floor((_.scaleY and _.scaleY(6) or 6) + 0.5)
  local rowStep = textH + math.max(2, math.floor((_.scaleY and _.scaleY(3) or 3) + 0.5))

  -- Match hint-grid geometry so this feels like a popup anchored to Square.
  local sideMargin = (_.common and _.common.PAD_HINT_SIDE_MARGIN) or 0
  local hintGridXShift = (_.common and _.common.PAD_HINT_GRID_X_SHIFT) or 0
  local hintGridExtraW = (_.common and _.common.PAD_HINT_GRID_EXTRA_W) or 0
  local hintTotalW = ((_.w or 640) - (2 * (_.MARGIN_X or 0))) + hintGridExtraW
  local hintXEff = (_.MARGIN_X or 0) + sideMargin + hintGridXShift
  local hintWidthEff = hintTotalW - (2 * sideMargin)
  local slotW = hintWidthEff / 5
  local squareSlotLeft = hintXEff + slotW -- slot 2: square
  local squareSlotCenter = squareSlotLeft + (slotW / 2)
  local hintIconScale = 0.6
  local hintIconW = math.max(10, math.floor((((_.common and _.common.PAD_ICON_W) or 26) * hintIconScale) + 0.5))
  local squareButtonLeft = math.floor(squareSlotCenter - (hintIconW / 2))

  -- Width is fixed to the square slot cell (minus a small gutter).
  local cellGutter = math.max(4, math.floor((_.scaleY and _.scaleY(4) or 4) + 0.5))
  local boxW = math.floor(slotW - (cellGutter * 2))
  if boxW < 90 then boxW = 90 end

  -- Fit content within fixed width; choices align to title-left + 4 spaces.
  local maxVisByHeight = maxVisible
  local boxH = padTop + titleH + titleGap + (maxVisByHeight * rowStep) + padBottom
  local hintRowH = math.max(14, math.floor((((_.common and _.common.PAD_HINT_ROW_H) or 28) * textScale) + 0.5))
  local hintRowTop = math.floor(_.HINT_Y) - hintRowH
  local finalBoxY = hintRowTop - boxH - math.max(2, math.floor((_.scaleY and _.scaleY(2) or 2) + 0.5))
  local slideDist = math.max(10, math.floor((_.scaleY and _.scaleY(14) or 14) + 0.5))
  local boxY = finalBoxY + math.floor((1 - anim) * slideDist)
  local boxX = squareButtonLeft

  local minX = _.MARGIN_X or 0
  local maxX = (_.w or 640) - boxW - (_.MARGIN_X or 0)
  if boxX < minX then boxX = minX end
  if boxX > maxX then boxX = maxX end

  local bgAlpha = math.floor(120 * anim + 0.5)
  if bgAlpha < 0 then bgAlpha = 0 end
  if bgAlpha > 120 then bgAlpha = 120 end
  if _.Graphics and _.Graphics.drawRect then
    _.Graphics.drawRect(boxX, boxY, boxW, boxH, Color.new(40, 40, 48, bgAlpha))
  end

  local titleX = boxX + math.floor((boxW - titleW) / 2)
  local titleY = boxY + padTop
  _.drawText(hintFont, _.drawMode, titleX, titleY, titleScale, title, _.WHITE, textH)

  local rowStartY = titleY + titleH + titleGap
  local rowLabelX = titleX + rowIndentW
  local rowMarkerX = rowLabelX - markerW
  local maxLabelW = (boxX + boxW) - padX - rowLabelX
  if maxLabelW < 1 then maxLabelW = 1 end
  for i = ctx[scrollKey] + 1, math.min(ctx[scrollKey] + maxVisible, #rows) do
    local row = rows[i]
    local y = rowStartY + (i - ctx[scrollKey] - 1) * rowStep
    local label = row.label
    if _.common.fitListRowText then
      label = _.common.fitListRowText(ctx, rowStateKeyPrefix .. tostring(i), hintFont, label, maxLabelW, rowScale,
        i == ctx[selKey])
    elseif _.common.truncateTextToWidth then
      label = _.common.truncateTextToWidth(hintFont, label, maxLabelW, rowScale)
    end
    local col = row.enabled and ((i == ctx[selKey]) and _.SELECTED_ENTRY or _.WHITE) or (_.DIM_ENTRY or _.DIM)
    if i == ctx[selKey] then
      _.drawText(hintFont, _.drawMode, rowMarkerX, y, rowScale, ">", col, textH)
    end
    _.drawText(hintFont, _.drawMode, rowLabelX, y, rowScale, label, col, textH)
  end

  local hintItems = buildOverlayHints(_, opts.hints, (_.menu_str and _.menu_str.actions_label) or "Actions")
  if _.Graphics and _.Graphics.drawRect then
    local hintBg = (_.common and _.common.BGCOLOR) or Color.new(20, 20, 20, 255)
    local hintRowH = math.max(14, math.floor(((_.common and _.common.PAD_HINT_ROW_H) or 28) * 0.75 + 0.5))
    local hintRowTop = math.floor(_.HINT_Y) - hintRowH
    local hintW = (_.w or 640) - (2 * (_.MARGIN_X or 0))
    _.Graphics.drawRect(_.MARGIN_X or 0, hintRowTop, hintW, hintRowH, hintBg)
  end
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hintItems, nil, _.DIM, _.w - 2 * _.MARGIN_X)

  if not closing then
    if (_.padEffective & _.PAD_UP) ~= 0 then
      moveSelection(-1)
    end
    if (_.padEffective & _.PAD_DOWN) ~= 0 then
      moveSelection(1)
    end

    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      local row = rows[ctx[selKey]]
      if row and row.enabled then
        if opts.closeOnSelect ~= false then
          closeMenu(ctx, { openKey = openKey, selKey = selKey, scrollKey = scrollKey })
        end
        if type(opts.onSelect) == "function" then
          opts.onSelect(row.raw, row.id, ctx[selKey])
        end
      end
    end

    if (_.padEffective & _.PAD_CIRCLE) ~= 0 or (_.padEffective & _.PAD_SQUARE) ~= 0 then
      ctx[closingKey] = true
      if ctx[animKey] < 0.001 then
        ctx[animKey] = 1
      end
    end
  end

  if closing and anim <= 0.001 then
    closeMenu(ctx, { openKey = openKey, selKey = selKey, scrollKey = scrollKey })
    if type(opts.onCancel) == "function" then
      opts.onCancel()
    end
  end

  return true
end

return actions_menu
