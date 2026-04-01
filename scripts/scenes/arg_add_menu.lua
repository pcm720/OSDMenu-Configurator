--[[ Shared add-argument preset menu renderer/input handler. ]]

local arg_add_menu = {}

local function closeMenu(ctx, opts)
  ctx[opts.menuOpenKey] = nil
  ctx[opts.selKey] = nil
  ctx[opts.scrollKey] = nil
end

local function buildDefaultHints(_)
  return {
    { pad = "cross", label = (_ and _.menu_str and (_.menu_str.enter_label or _.menu_str.confirm_label)) or "Select", row = 1 },
    { pad = "circle", label = (_ and _.menu_str and _.menu_str.cancel_label) or "Cancel", row = 1 },
  }
end

function arg_add_menu.run(ctx, opts)
  if not ctx or not opts then return false end
  local _ = ctx._
  if not _ then return false end

  local menuOpenKey = opts.menuOpenKey
  if not menuOpenKey or not ctx[menuOpenKey] then return false end

  local selKey = opts.selKey or "argAddSel"
  local scrollKey = opts.scrollKey or "argAddScroll"
  local rows = opts.rows or {}
  local maxVisible = math.max(1, math.floor(tonumber(opts.maxVisible) or (_.MAX_VISIBLE_LIST or 12)))
  if _.common and _.common.computeVisibleRows then
    local startY = _.MARGIN_Y + _.scaleY(50)
    local fitVisible = _.common.computeVisibleRows(_, startY, _.LINE_H, maxVisible, {
      reserveRows = 1,
      reserveDescription = true,
    })
    maxVisible = math.max(1, math.min(maxVisible, fitVisible))
  end
  local rowStateKeyPrefix = opts.rowStateKeyPrefix or "arg_add_row_"
  local rowDisabledReason = opts.rowDisabledReason or function()
    return false, nil
  end

  if #rows == 0 then
    closeMenu(ctx, opts)
    return true
  end

  local function rowDisabled(row)
    local disabled = rowDisabledReason(row)
    return disabled
  end

  local function isSelectable(index)
    local row = rows[index]
    return row ~= nil and (not rowDisabled(row))
  end

  local function moveSelection(step)
    local idx = ctx[selKey] or 1
    for attempt = 1, #rows do
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
  ctx[scrollKey] = _.common.centeredListScroll(ctx[selKey], #rows, maxVisible)

  local title = opts.title or (_.menu_str.new_argument_prompt or "Add argument")
  local selectedRow = rows[ctx[selKey]]
  local desc = (selectedRow and selectedRow.desc) or (opts.descDefault or "")

  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, title, _.WHITE)

  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X
  local inUseSuffix = opts.inUseSuffix or " (in use)"
  local needsTwoSuffix = opts.needsTwoSlotsSuffix or " (needs 2 slots)"
  for i = ctx[scrollKey] + 1, math.min(ctx[scrollKey] + maxVisible, #rows) do
    local row = rows[i]
    local label = row.label or ""
    local disabled, reason = rowDisabledReason(row)
    if disabled then
      label = label .. ((reason == "needs_two_slots") and needsTwoSuffix or inUseSuffix)
    end
    if _.common.fitListRowText then
      label = _.common.fitListRowText(ctx, rowStateKeyPrefix .. tostring(i), _.font, label, maxLabelW,
        _.FONT_SCALE, i == ctx[selKey])
    elseif _.common.truncateTextToWidth then
      label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
    end
    local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx[scrollKey] - 1) * _.LINE_H
    local col = disabled and (_.DIM_ENTRY or _.DIM) or ((i == ctx[selKey]) and _.SELECTED_ENTRY or _.WHITE)
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx[selKey], label, col)
  end

  if desc ~= "" then
    local hintTextScale = tonumber(_.common.PAD_HINT_TEXT_SCALE) or 0.75
    local hintDrawScale = (_.common.getHintLabelDrawScale and _.common.getHintLabelDrawScale(0.7)) or
        (0.7 * hintTextScale)
    local hintFont = (_.common.getHintFont and _.common.getHintFont(_.font, _.drawMode, hintTextScale)) or _.font
    local hintTextH = (_.common.getHintLabelTextHeight and _.common.getHintLabelTextHeight()) or
        math.max(10, math.floor(((_.common.FT_PIXEL_H or 18) * hintTextScale) + 0.5))
    local hintColor = (_.common.OPTION_HINT_COLOR or _.HIGHLIGHT or _.WHITE)
    local descMaxW = (_.w or 640) - (_.MARGIN_X * 2)
    if _.common.fitListRowText then
      desc = _.common.fitListRowText(ctx, (rowStateKeyPrefix or "arg_add_row_") .. "desc", hintFont, desc, descMaxW,
        hintDrawScale, true, { holdStart = 55, stepFrames = 16, holdEnd = 85 })
    elseif _.common.truncateTextToWidth then
      desc = _.common.truncateTextToWidth(hintFont, desc, descMaxW, hintDrawScale)
    end
    local tw = (_.common.calcTextWidth and _.common.calcTextWidth(hintFont, desc, hintDrawScale)) or (#desc * 8)
    local x = (_.common.centerX and _.common.centerX(_, tw)) or _.MARGIN_X
    _.drawText(hintFont, _.drawMode, x, _.DESC_Y_BOTTOM, hintDrawScale, desc, hintColor, hintTextH)
  end

  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, opts.hints or buildDefaultHints(_), nil, _.DIM,
    _.w - 2 * _.MARGIN_X)

  if (_.padEffective & _.PAD_UP) ~= 0 then
    moveSelection(-1)
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    moveSelection(1)
  end
  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    local row = rows[ctx[selKey]]
    if row and not rowDisabled(row) then
      local selectedIndex = ctx[selKey]
      closeMenu(ctx, opts)
      if type(opts.onSelect) == "function" then
        opts.onSelect(row, selectedIndex)
      end
    end
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    closeMenu(ctx, opts)
    if type(opts.onCancel) == "function" then
      opts.onCancel()
    end
  end

  return true
end

return arg_add_menu
