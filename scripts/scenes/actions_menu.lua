--[[ Shared centered actions menu (Square picker). ]]

local actions_menu = {}

local function closeMenu(ctx, opts)
  ctx[opts.openKey] = nil
  ctx[opts.selKey] = nil
  ctx[opts.scrollKey] = nil
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

  local title = "Select Action:"
  if opts.titleOverride ~= nil and tostring(opts.titleOverride) ~= "" then
    title = tostring(opts.titleOverride)
  end
  local titleScale = 0.95
  local rowScale = _.FONT_SCALE
  local rowStateKeyPrefix = opts.rowStateKeyPrefix or "actions_menu_row_"

  local function textWidth(text, scale)
    if _.common and _.common.calcTextWidth then
      return _.common.calcTextWidth(_.font, tostring(text or ""), scale)
    end
    local s = tostring(text or "")
    return math.floor((8 * (scale or 1)) * #s)
  end

  local titleW = textWidth(title, titleScale)
  local maxRowW = 0
  for i = 1, #rows do
    local w = textWidth(rows[i].label, rowScale)
    if w > maxRowW then maxRowW = w end
  end
  local contentW = math.max(titleW, maxRowW)
  local padX = 24
  local padTop = math.floor(_.scaleY(14))
  local titleH = _.LINE_H
  local titleGap = 0
  local padBottom = math.floor(_.scaleY(14))
  local rowStep = _.LINE_H

  local maxBoxW = math.min(380, (_.w or 640) - (_.MARGIN_X * 2))
  local minBoxW = math.min(280, maxBoxW)
  local boxW = contentW + (padX * 2)
  if boxW < minBoxW then boxW = minBoxW end
  if boxW > maxBoxW then boxW = maxBoxW end
  local boxH = padTop + titleH + titleGap + (maxVisible * rowStep) + padBottom
  local boxX = math.floor(((_.w or 640) - boxW) / 2)
  local boxY = math.floor(((_.h or 448) - boxH) / 2)
  if _.Graphics and _.Graphics.drawRect then
    _.Graphics.drawRect(boxX, boxY, boxW, boxH, Color.new(40, 40, 48, 120))
  end

  local titleX = boxX + math.floor((boxW - titleW) / 2)
  local titleY = boxY + padTop
  _.drawText(_.font, _.drawMode, titleX, titleY, titleScale, title, _.WHITE)

  local rowStartY = titleY + titleH + titleGap
  local rowIndentW = textWidth("  ", rowScale)
  local rowX = titleX + rowIndentW
  local rowRight = (boxX + boxW) - padX
  local maxLabelW = rowRight - rowX
  if maxLabelW < 1 then maxLabelW = 1 end
  for i = ctx[scrollKey] + 1, math.min(ctx[scrollKey] + maxVisible, #rows) do
    local row = rows[i]
    local y = rowStartY + (i - ctx[scrollKey] - 1) * rowStep
    local label = row.label
    if _.common.fitListRowText then
      label = _.common.fitListRowText(ctx, rowStateKeyPrefix .. tostring(i), _.font, label, maxLabelW, rowScale,
        i == ctx[selKey])
    elseif _.common.truncateTextToWidth then
      label = _.common.truncateTextToWidth(_.font, label, maxLabelW, rowScale)
    end
    local col = row.enabled and ((i == ctx[selKey]) and _.SELECTED_ENTRY or _.WHITE) or (_.DIM_ENTRY or _.DIM)
    _.drawListRow(rowX, y, i == ctx[selKey], label, col)
  end

  local hintItems = opts.hints or {
    { pad = "cross", label = "Select", row = 1 },
    { pad = "circle", label = "Cancel", row = 1 },
  }
  if _.Graphics and _.Graphics.drawRect then
    local hintBg = (_.common and _.common.BGCOLOR) or Color.new(20, 20, 20, 255)
    local hintRowH = math.max(14, math.floor(((_.common and _.common.PAD_HINT_ROW_H) or 28) * 0.75 + 0.5))
    local hintRowTop = math.floor(_.HINT_Y) - hintRowH
    local hintW = (_.w or 640) - (2 * (_.MARGIN_X or 0))
    _.Graphics.drawRect(_.MARGIN_X or 0, hintRowTop, hintW, hintRowH, hintBg)
  end
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hintItems, nil, _.DIM, _.w - 2 * _.MARGIN_X)

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

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    closeMenu(ctx, { openKey = openKey, selKey = selKey, scrollKey = scrollKey })
    if type(opts.onCancel) == "function" then
      opts.onCancel()
    end
  end

  return true
end

return actions_menu
