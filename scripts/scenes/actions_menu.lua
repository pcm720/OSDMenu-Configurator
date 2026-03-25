--[[ Shared centered actions menu (Square picker). ]]

local actions_menu = {}

local function closeMenu(ctx, opts)
  ctx[opts.openKey] = nil
  ctx[opts.selKey] = nil
  ctx[opts.scrollKey] = nil
end

local function normalizeRows(rows)
  local out = {}
  for i = 1, #(rows or {}) do
    local row = rows[i]
    if row and row.hidden ~= true then
      out[#out + 1] = {
        id = row.id or tostring(i),
        label = tostring(row.label or ""),
        enabled = (row.enabled ~= false),
        raw = row,
      }
    end
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

  local title = opts.title or "Actions"
  local boxW = math.min(460, (_.w or 640) - (_.MARGIN_X * 2))
  local boxH = math.floor(_.scaleY(64)) + maxVisible * _.LINE_H
  local boxX = math.floor(((_.w or 640) - boxW) / 2)
  local boxY = math.floor(((_.h or 448) - boxH) / 2)
  if _.Graphics and _.Graphics.drawRect then
    _.Graphics.drawRect(boxX, boxY, boxW, boxH, Color.new(40, 40, 48, 120))
  end

  _.drawText(_.font, _.drawMode, boxX + 18, boxY + 14, 0.95, title, _.WHITE)
  local maxLabelW = boxW - 36
  local rowStateKeyPrefix = opts.rowStateKeyPrefix or "actions_menu_row_"
  for i = ctx[scrollKey] + 1, math.min(ctx[scrollKey] + maxVisible, #rows) do
    local row = rows[i]
    local y = boxY + math.floor(_.scaleY(42)) + (i - ctx[scrollKey] - 1) * _.LINE_H
    local label = row.label
    if _.common.fitListRowText then
      label = _.common.fitListRowText(ctx, rowStateKeyPrefix .. tostring(i), _.font, label, maxLabelW, _.FONT_SCALE,
        i == ctx[selKey])
    elseif _.common.truncateTextToWidth then
      label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
    end
    local col = row.enabled and ((i == ctx[selKey]) and _.SELECTED_ENTRY or _.WHITE) or (_.DIM_ENTRY or _.DIM)
    _.drawListRow(boxX + 18, y, i == ctx[selKey], label, col)
  end

  local hintItems = opts.hints or {
    { pad = "cross", label = "Select", row = 1 },
    { pad = "circle", label = "Back", row = 1 },
  }
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
