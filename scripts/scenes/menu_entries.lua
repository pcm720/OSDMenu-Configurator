--[[ Menu entries list (OSDMENU). ]]

local actions_menu = dofile("scripts/scenes/actions_menu.lua")

local function buildEntryNameMap(lines)
  local out = {}
  for i = 1, #(lines or {}) do
    local entry = lines[i]
    local key = entry and entry.key
    if key then
      local idx = key:match("^name_OSDSYS_ITEM_(%d+)$")
      if idx then
        local n = tonumber(idx)
        if n and out[n] == nil then
          out[n] = entry.value or ""
        end
      end
    end
  end
  return out
end

local function run(ctx)
  local _ = ctx._
  if not ctx.lines then
    ctx.state = "editor"
    return
  end

  local sceneEpoch = ctx._sceneEpoch or 0
  local function getMenuEntriesCache()
    local cache = ctx.menuEntriesCache
    if not cache or cache.linesRef ~= ctx.lines or cache.sceneEpoch ~= sceneEpoch then
      cache = {
        linesRef = ctx.lines,
        sceneEpoch = sceneEpoch,
        entryList = _.config_parse.getMenuEntryIndices(ctx.lines),
        entryNameByIdx = buildEntryNameMap(ctx.lines),
      }
      ctx.menuEntriesCache = cache
    end
    return cache
  end
  local function invalidateMenuEntriesCache()
    ctx.menuEntriesCache = nil
  end

  local function refreshEntries()
    local cache = getMenuEntriesCache()
    ctx.entryList = cache.entryList or {}
    if #ctx.entryList == 0 then
      ctx.entrySel = 1
      ctx.menuEntryGrab = nil
    elseif ctx.entrySel < 1 then
      ctx.entrySel = 1
    elseif ctx.entrySel > #ctx.entryList then
      ctx.entrySel = #ctx.entryList
    end
    if #ctx.entryList <= 1 then
      ctx.menuEntryGrab = nil
    end
  end

  local function clearMoveState()
    ctx.menuEntryGrab = nil
    ctx.menuEntryMoveSnapshot = nil
    ctx.menuEntryMoveSel = nil
  end

  local function beginMoveState()
    if ctx.menuEntryGrab then return end
    if _.common and _.common.cloneConfigLines then
      ctx.menuEntryMoveSnapshot = _.common.cloneConfigLines(ctx.lines)
    else
      ctx.menuEntryMoveSnapshot = nil
    end
    ctx.menuEntryMoveSel = ctx.entrySel
    ctx.menuEntryGrab = true
  end

  local function confirmMoveState()
    clearMoveState()
  end

  local function cancelMoveState()
    if ctx.menuEntryMoveSnapshot then
      if _.common and _.common.cloneConfigLines then
        ctx.lines = _.common.cloneConfigLines(ctx.menuEntryMoveSnapshot)
      else
        ctx.lines = ctx.menuEntryMoveSnapshot
      end
      invalidateMenuEntriesCache()
      refreshEntries()
      ctx.entrySel = _.common.clampListSelection(ctx.menuEntryMoveSel or ctx.entrySel, #ctx.entryList)
      _.common.refreshConfigModified(ctx)
    end
    clearMoveState()
  end

  local function saveFromMenuEntries()
    ctx.saveSplash = nil
    local locations = _.getLocations(ctx.context, ctx.fileType, ctx.chosenMcSlot)
    if ctx.fileType == "osdmenu_cnf" and #locations >= 2 then
      ctx.saveChoices = locations
      ctx.saveSel = ctx.saveSel or 1
      ctx.returnToMenuEntriesAfterSave = true
      ctx.state = "choose_save"
      return
    end
    local path = ctx.currentPath or (locations and locations[1])
    if path and path ~= "" then
      ctx.lines = _.config_parse.regenerateForSave(ctx.lines, ctx.fileType, _.config_options)
      invalidateMenuEntriesCache()
      local parentDir = path:match("^(.+)/[^/]+$")
      local ok, err = _.common.saveConfig(ctx, path, ctx.lines, parentDir)
      if ok then
        ctx.currentPath = path
        ctx.saveSplash = { kind = "saved", detail = path or "", framesLeft = 60 }
      else
        ctx.saveSplash = {
          kind = "failed",
          detail = _.common.localizeParseError(err, _.editor_str) or _.editor_str.save_failed,
          framesLeft = 120
        }
      end
    else
      ctx.saveSplash = { kind = "failed", detail = _.editor_str.no_save_location, framesLeft = 120 }
    end
  end

  local function openPathPickerForEntry(entryIdx)
    local idx = tonumber(entryIdx)
    if not idx then return end
    ctx.editKey = nil
    ctx.pathPickerForEntryIdx = idx
    ctx.pathPickerBootKey = nil
    ctx.pathPickerBblHotkeyKey = nil
    ctx.pathPickerBblHotkeySlot = nil
    ctx.pathPickerBblHotkeyDisabled = nil
    ctx.pathPickerBblIrxIdx = nil
    ctx.pathPickerBblIrxDisabled = nil
    ctx.pathPickerTarget = nil
    ctx.pathPickerFileExts = nil
    ctx.pathPickerEditIdx = nil
    ctx.pathPickerInsertBelow = nil
    ctx.pathPickerSub = "device"
    ctx.pathList = _.file_selector.getDevices("osdmenu") or {}
    ctx.pathPickerSel = 1
    ctx.pathPickerScroll = 0
    ctx.pathPickerContext = "osdmenu"
    ctx.pathPickerReturnState = "menu_entry_edit"
    ctx.state = "path_picker"
  end

  local function insertBelowSelection(canAddEntry, total, directPicker)
    if not canAddEntry then return end
    local belowIdx = (total == 0) and 0 or ctx.entryList[ctx.entrySel].idx
    local newIdx = _.config_parse.insertMenuEntryBelow(ctx.lines, belowIdx, "")
    if not newIdx then return end
    ctx.configModified = true
    invalidateMenuEntriesCache()
    refreshEntries()
    ctx.entrySel = (total == 0) and 1 or math.min(ctx.entrySel + 1, #ctx.entryList)
    ctx.entryIdx = newIdx
    ctx.entryEditSub = ctx.entryEditSub or 1
    confirmMoveState()
    if directPicker then
      openPathPickerForEntry(newIdx)
    else
      ctx.state = "menu_entry_edit"
    end
  end

  refreshEntries()
  local entryNameByIdx = (getMenuEntriesCache().entryNameByIdx) or {}
  local startY = _.MARGIN_Y + _.scaleY(50)
  local total = #ctx.entryList
  local canMoveEntries = total > 1
  if not canMoveEntries then
    confirmMoveState()
  end
  local isFmcb = (ctx.fileType == "freemcboot_cnf")
  local maxEntries = (isFmcb and ((_.config_options and _.config_options.FMCB_MAX_ENTRIES) or 99)) or nil
  local canAddEntry = (not isFmcb) or (total < maxEntries)

  local counterStr = (total == 0 and "0 / 0") or (tostring(ctx.entrySel) .. " / " .. tostring(total))
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.menu_str.edit_menu_entries, _.WHITE)
  _.drawText(_.font, _.drawMode, 540, _.MARGIN_Y, 0.9, counterStr, _.DIM)

  local maxVis = _.MAX_VISIBLE_LIST
  if total > maxVis then
    ctx.entryScroll = ctx.entrySel - math.floor(maxVis / 2)
    ctx.entryScroll = math.max(0, math.min(ctx.entryScroll, total - maxVis))
  else
    ctx.entryScroll = 0
  end

  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 20) - _.MARGIN_X
  for i = ctx.entryScroll + 1, math.min(ctx.entryScroll + maxVis, total) do
    local ent = ctx.entryList[i]
    local idx = ent.idx
    local name = entryNameByIdx[idx]
    local label = (name == "" or not name) and _.common_str.empty or (name or (_.menu_str.item .. idx))
    if canMoveEntries and ctx.menuEntryGrab and i == ctx.entrySel then
      label = "[" .. (_.menu_str.grabbed_tag or "Move") .. "] " .. label
    end
    local y = startY + (i - ctx.entryScroll - 1) * _.LINE_H
    local col = (i == ctx.entrySel) and _.SELECTED_ENTRY or _.WHITE
    if label == _.common_str.empty then
      col = (i == ctx.entrySel) and _.SELECTED_ENTRY or _.DIM
    end
    if ent.disabled then
      col = (i == ctx.entrySel) and (_.SELECTED_ENTRY_DIM or _.SELECTED_ENTRY) or (_.DIM_ENTRY or _.DIM)
    end
    if _.common.fitListRowText then
      label = _.common.fitListRowText(ctx, "menu_entries_row_" .. tostring(i), _.font, label, maxLabelW, _.FONT_SCALE,
        i == ctx.entrySel)
    elseif _.common.truncateTextToWidth then
      label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
    end
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.entrySel, label, col)
  end

  local hasSelection = (ctx.entrySel >= 1 and ctx.entrySel <= total)
  local canCrossOpen = hasSelection or canAddEntry
  local selectedDisabled = hasSelection and ctx.entryList[ctx.entrySel].disabled
  local hintItems = {
    {
      pad = canCrossOpen and "cross" or "",
      label = canCrossOpen and
          (hasSelection and (ctx.menuEntryGrab and (_.menu_str.confirm_label or "Confirm") or (_.menu_str.enter_label or "Enter")) or
            (_.menu_str.edit_label or "Edit")) or "",
      row = 1
    },
    { pad = "square", label = (_.menu_str.actions_label or "Actions"), row = 1 },
    {
      pad = ctx.configModified and "start" or "",
      label = ctx.configModified and (_.menu_str.save_config_label or "Save") or "",
      row = 1
    },
    {
      pad = hasSelection and "triangle" or "",
      label = hasSelection and (selectedDisabled and (_.menu_str.enable_label or "Enable") or (_.menu_str.disable_label or "Disable")) or "",
      row = 1
    },
    {
      pad = "circle",
      label = ctx.menuEntryGrab and (_.menu_str.cancel_label or "Cancel") or (_.menu_str.back_label or "Back"),
      row = 1
    },
  }
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hintItems, nil, _.DIM, _.w - 2 * _.MARGIN_X)

  if ctx.menuEntriesActionsOpen then
    local actionRows = {}
    if hasSelection and canMoveEntries then
      actionRows[#actionRows + 1] = {
        id = "grab",
        label = ctx.menuEntryGrab and (_.menu_str.cancel_move_label or "Cancel move") or (_.menu_str.grab_label or "Move"),
      }
    end
    if canAddEntry then
      actionRows[#actionRows + 1] = { id = "insert", label = (_.menu_str.insert_label or "Insert") }
    end
    if hasSelection then
      actionRows[#actionRows + 1] = { id = "remove", label = (_.menu_str.remove_label or "Remove") }
    end
    if actions_menu.run(ctx, {
          openKey = "menuEntriesActionsOpen",
          selKey = "menuEntriesActionsSel",
          scrollKey = "menuEntriesActionsScroll",
          title = (_.menu_str.actions_title or "Actions"),
          rows = actionRows,
          rowStateKeyPrefix = "menu_entries_actions_row_",
          onSelect = function(row)
            if row.id == "grab" then
              if ctx.menuEntryGrab then
                cancelMoveState()
              else
                beginMoveState()
              end
            elseif row.id == "insert" then
              insertBelowSelection(canAddEntry, total)
            elseif row.id == "remove" and hasSelection then
              local idx = ctx.entryList[ctx.entrySel].idx
              _.config_parse.removeMenuEntry(ctx.lines, idx)
              ctx.configModified = true
              invalidateMenuEntriesCache()
              refreshEntries()
            end
          end,
        }) then
      return
    end
  end

  if (_.padEffective & _.PAD_UP) ~= 0 then
    if ctx.menuEntryGrab and hasSelection and ctx.entrySel > 1 then
      local curIdx = ctx.entryList[ctx.entrySel].idx
      local prevIdx = ctx.entryList[ctx.entrySel - 1].idx
      if _.config_parse.swapMenuEntryContent(ctx.lines, curIdx, prevIdx) then
        ctx.configModified = true
        invalidateMenuEntriesCache()
        refreshEntries()
        ctx.entrySel = ctx.entrySel - 1
      end
    else
      ctx.entrySel = ctx.entrySel - 1
      if ctx.entrySel < 1 then ctx.entrySel = total end
    end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    if ctx.menuEntryGrab and hasSelection and ctx.entrySel < total then
      local curIdx = ctx.entryList[ctx.entrySel].idx
      local nextIdx = ctx.entryList[ctx.entrySel + 1].idx
      if _.config_parse.swapMenuEntryContent(ctx.lines, curIdx, nextIdx) then
        ctx.configModified = true
        invalidateMenuEntriesCache()
        refreshEntries()
        ctx.entrySel = ctx.entrySel + 1
      end
    else
      ctx.entrySel = ctx.entrySel + 1
      if ctx.entrySel > total then ctx.entrySel = 1 end
    end
  end

  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 and hasSelection then
    local ent = ctx.entryList[ctx.entrySel]
    _.config_parse.setMenuEntryDisabled(ctx.lines, ent.idx, not ent.disabled)
    ctx.configModified = true
    invalidateMenuEntriesCache()
    refreshEntries()
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    if hasSelection then
      if ctx.menuEntryGrab then
        confirmMoveState()
        return
      end
      ctx.entryIdx = ctx.entryList[ctx.entrySel].idx
      ctx.entryEditSub = ctx.entryEditSub or 1
      ctx.state = "menu_entry_edit"
    elseif canAddEntry then
      insertBelowSelection(canAddEntry, total, true)
    end
  end

  if (_.padEffective & _.PAD_SQUARE) ~= 0 then
    ctx.menuEntriesActionsOpen = true
    ctx.menuEntriesActionsSel = ctx.menuEntriesActionsSel or 1
    ctx.menuEntriesActionsScroll = ctx.menuEntriesActionsScroll or 0
  end

  if ctx.configModified and (_.padEffective & _.PAD_START) ~= 0 then
    saveFromMenuEntries()
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    if ctx.menuEntryGrab then
      cancelMoveState()
      return
    end
    ctx.state = "editor"
  end
end

return { run = run }
