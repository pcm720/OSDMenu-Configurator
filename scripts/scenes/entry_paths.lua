--[[ Paths list for a menu entry or MBR boot key (when ctx.bootKey is set and we're in MBR). ]]

local actions_menu = dofile("scripts/scenes/actions_menu.lua")

local function getBootPadName(key)
  if key == "boot_start" then return "start" end
  if key == "boot_triangle" then return "triangle" end
  if key == "boot_circle" then return "circle" end
  if key == "boot_cross" then return "cross" end
  if key == "boot_square" then return "square" end
  return nil
end

local function drawBootTitle(_, bootKey, titleLabel)
  local padName = getBootPadName(bootKey)
  local icon = padName and _.common.getPadIcon and _.common.getPadIcon(padName) or nil
  local baseIconW = _.common.PAD_ICON_W or 26
  local baseIconH = _.common.PAD_ICON_H or 26
  local textH = (_.common and _.common.FT_PIXEL_H) or 18
  local iconH = math.min(baseIconH, textH)
  local iconW = math.max(1, math.floor((baseIconW * iconH) / baseIconH + 0.5))
  local iconGap = 8
  local iconY = _.MARGIN_Y + math.floor(((_.LINE_H or iconH) - iconH) / 2)

  if icon then
    if _.Graphics.drawScaleImage then
      _.Graphics.drawScaleImage(icon, _.MARGIN_X, iconY, iconW, iconH)
    else
      _.Graphics.drawImage(icon, _.MARGIN_X, iconY)
    end
  end
  _.drawText(_.font, _.drawMode, _.MARGIN_X + iconW + iconGap, _.MARGIN_Y, 1, "- " .. titleLabel, _.WHITE)
end

local function run(ctx)
  local _ = ctx._
  local isBoot = not not (ctx.bootKey and (ctx.context == "mbr" or ctx.fileType == "osdmbr_cnf"))
  if not ctx.lines then
    ctx.state = isBoot and "editor" or "menu_entry_edit"; return
  end
  if not isBoot and not ctx.entryIdx then
    ctx.state = "menu_entry_edit"; return
  end
  if isBoot and not ctx.bootKey then
    ctx.state = "editor"; return
  end
  local paths = isBoot and (_.config_parse.getBootPathEntries(ctx.lines, ctx.bootKey) or {}) or
      _.config_parse.getMenuEntryPaths(ctx.lines, ctx.entryIdx)
  local function refreshPaths()
    paths = isBoot and (_.config_parse.getBootPathEntries(ctx.lines, ctx.bootKey) or {}) or
        _.config_parse.getMenuEntryPaths(ctx.lines, ctx.entryIdx)
    if #paths <= 1 then
      ctx.entryPathGrab = nil
    end
  end
  local function clearMoveState()
    ctx.entryPathGrab = nil
    ctx.entryPathMoveSnapshot = nil
    ctx.entryPathMoveSel = nil
  end
  local function beginMoveState()
    if ctx.entryPathGrab then return end
    if _.common and _.common.cloneConfigLines then
      ctx.entryPathMoveSnapshot = _.common.cloneConfigLines(ctx.lines)
    else
      ctx.entryPathMoveSnapshot = nil
    end
    ctx.entryPathMoveSel = ctx.entryPathSel
    ctx.entryPathGrab = true
  end
  local function confirmMoveState()
    clearMoveState()
  end
  local function cancelMoveState()
    if ctx.entryPathMoveSnapshot then
      if _.common and _.common.cloneConfigLines then
        ctx.lines = _.common.cloneConfigLines(ctx.entryPathMoveSnapshot)
      else
        ctx.lines = ctx.entryPathMoveSnapshot
      end
      refreshPaths()
      ctx.entryPathSel = _.common.clampListSelection(ctx.entryPathMoveSel or ctx.entryPathSel, #paths)
      _.common.refreshConfigModified(ctx)
    end
    clearMoveState()
  end
  local hasExclusivePath = false
  local hasArgsPaths = false
  local hasSpecialArgsPath = false
  for i, p in ipairs(paths) do
    local pv = type(p) == "table" and p.value or p
    local flags = _.file_selector.getPathFlags and _.file_selector.getPathFlags(pv) or {}
    if flags.exclusive then hasExclusivePath = true end
    if not flags.noargs then hasArgsPaths = true end
    if flags.specialargs then hasSpecialArgsPath = true end
  end
  local pathRows = #paths
  local canMovePaths = pathRows > 1
  if not canMovePaths then
    confirmMoveState()
  end
  local isFmcbEntry = (not isBoot) and (ctx.fileType == "freemcboot_cnf")
  local maxPathsPerEntry = (isFmcbEntry and ((_.config_options and _.config_options.FMCB_MAX_PATHS_PER_ENTRY) or 3)) or nil
  local canAddPath = (not isFmcbEntry) or (pathRows < maxPathsPerEntry)
  local total = pathRows
  if isBoot and (hasArgsPaths or hasSpecialArgsPath) then total = total + 1 end -- Arguments or Launch Disc options row
  if ctx.entryPathSel < 1 then ctx.entryPathSel = 1 end
  if ctx.entryPathSel > total then ctx.entryPathSel = (total > 0) and total or 1 end
  if total > _.MAX_VISIBLE_LIST then
    ctx.entryPathScroll = ctx.entryPathSel - math.floor(_.MAX_VISIBLE_LIST / 2)
    ctx.entryPathScroll = math.max(0, math.min(ctx.entryPathScroll, total - _.MAX_VISIBLE_LIST))
  else
    ctx.entryPathScroll = 0
  end
  local titleStr
  if isBoot then
    titleStr = (_.strings.options and _.strings.options[ctx.bootKey] and _.strings.options[ctx.bootKey].label) or
        ctx.bootKey
  else
    local name = _.config_parse.getMenuEntryName(ctx.lines, ctx.entryIdx) or ""
    name = name ~= "" and name or _.common_str.empty
    local prefix = "Paths for "
    local suffix = " (entry " .. tostring(ctx.entryIdx) .. ")"
    local prefixW = _.common.calcTextWidth(_.font, prefix, 1) or 0
    local suffixW = _.common.calcTextWidth(_.font, suffix, 1) or 0
    local availableW = (_.w or 640) - 2 * _.MARGIN_X - prefixW - suffixW
    if availableW > 0 then
      name = _.common.truncateTextToWidth(_.font, name, availableW, 1)
    end
    titleStr = string.format(_.menu_str.paths_for_entry_title, name, ctx.entryIdx)
  end
  if isBoot then
    drawBootTitle(_, ctx.bootKey, titleStr)
  else
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, titleStr, _.WHITE)
  end
  local argsRow = pathRows + 1
  local argsRowIsSpecial = hasSpecialArgsPath and (not hasArgsPaths or #paths == 1)
  local function pathLabel(p)
    if p == "" then return _.common_str.empty end
    if p == "cdrom" then return _.dev_str.launch_disc end
    if p == "dvd" then return _.dev_str.dvd_player end
    if (p or ""):upper() == "$HOSDSYS" then return _.dev_str.hosdsys end
    if (p or ""):upper() == "$PSBBN" then return _.dev_str.psbbn end
    if p == "OSDSYS" or p == "osdsys" then return _.dev_str.osd end
    if p == "POWEROFF" or p == "poweroff" then return _.dev_str.shutdown end
    return p
  end
  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X
  for i = ctx.entryPathScroll + 1, math.min(ctx.entryPathScroll + _.MAX_VISIBLE_LIST, total) do
    local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.entryPathScroll - 1) * _.LINE_H
    local label
    if isBoot and (hasArgsPaths or hasSpecialArgsPath) and i == argsRow then
      if argsRowIsSpecial then
        local args = _.config_parse.getBootArgs(ctx.lines, ctx.bootKey) or {}
        label = _.menu_str.launch_disc_options .. (#args == 0 and "" or (" (" .. #args .. ")"))
      else
        local args = _.config_parse.getBootArgs(ctx.lines, ctx.bootKey) or {}
        label = _.menu_str.arguments .. (#args == 0 and "" or (" (" .. #args .. ")"))
      end
    else
      local pathStr = type(paths[i]) == "table" and paths[i].value or paths[i]
      label = pathLabel(pathStr or "")
    end
    if _.common.fitListRowText then
      label = _.common.fitListRowText(ctx, "entry_paths_row_" .. tostring(i), _.font, label, maxLabelW, _.FONT_SCALE,
        i == ctx.entryPathSel)
    elseif _.common.truncateTextToWidth then
      label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
    end
    local col = (i == ctx.entryPathSel) and _.SELECTED_ENTRY or _.WHITE
    if i <= pathRows and type(paths[i]) == "table" and paths[i].disabled then
      col = (i == ctx.entryPathSel) and (_.SELECTED_ENTRY_DIM or _.SELECTED_ENTRY) or (_.DIM_ENTRY or _.DIM)
    end
    if canMovePaths and ctx.entryPathGrab and i == ctx.entryPathSel and i <= pathRows then
      label = "[" .. (_.menu_str.grabbed_tag or "Move") .. "] " .. label
    end
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.entryPathSel, label, col)
  end
  local hasPathSelection = (ctx.entryPathSel >= 1 and ctx.entryPathSel <= pathRows)
  local selectedPathDisabled = hasPathSelection and type(paths[ctx.entryPathSel]) == "table" and paths[ctx.entryPathSel].disabled
  local pathHints = {
    {
      pad = "cross",
      label = ctx.entryPathGrab and (_.menu_str.confirm_label or "Confirm") or (_.menu_str.edit_label or "Edit"),
      row = 1
    },
    { pad = "square", label = _.menu_str.actions_label or "Actions", row = 1 },
    {
      pad = ctx.configModified and "start" or "",
      label = ctx.configModified and (_.menu_str.save_config_label or "Save") or "",
      row = 1
    },
    {
      pad = hasPathSelection and "triangle" or "",
      label = hasPathSelection and
          (selectedPathDisabled and (_.menu_str.enable_label or "Enable") or (_.menu_str.disable_label or "Disable")) or "",
      row = 1
    },
    {
      pad = "circle",
      label = ctx.entryPathGrab and (_.menu_str.cancel_label or "Cancel") or (_.menu_str.back_label or "Back"),
      row = 1
    },
  }
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, pathHints, nil, _.DIM,
    _.w - 2 * _.MARGIN_X)

  local function openPathPicker(editIdx)
    ctx.editKey = nil
    ctx.pathPickerForEntryIdx = isBoot and nil or ctx.entryIdx
    ctx.pathPickerBootKey = isBoot and ctx.bootKey or nil
    ctx.pathPickerBblHotkeyKey = nil
    ctx.pathPickerBblHotkeySlot = nil
    ctx.pathPickerBblHotkeyDisabled = nil
    ctx.pathPickerBblIrxIdx = nil
    ctx.pathPickerBblIrxDisabled = nil
    ctx.pathPickerTarget = nil
    ctx.pathPickerFileExts = nil
    ctx.pathPickerEditIdx = editIdx
    ctx.pathPickerInsertBelow = nil
    ctx.pathPickerSub = "device"
    ctx.pathList = _.file_selector.getDevices(isBoot and "mbr" or "osdmenu") or {}
    ctx.pathPickerSel = ctx.pathPickerSel or 1
    ctx.pathPickerScroll = ctx.pathPickerScroll or 0
    ctx.pathPickerContext = isBoot and "mbr" or "osdmenu"
    ctx.pathPickerReturnState = "entry_paths"
    ctx.state = "path_picker"
  end
  local function toggleSelectedPathDisabled()
    if ctx.entryPathSel >= 1 and ctx.entryPathSel <= pathRows and type(paths[ctx.entryPathSel]) == "table" then
      if isBoot then
        _.config_parse.setBootPathDisabled(ctx.lines, ctx.bootKey, ctx.entryPathSel, not paths[ctx.entryPathSel].disabled)
      else
        _.config_parse.setPathDisabled(ctx.lines, ctx.entryIdx, ctx.entryPathSel, not paths[ctx.entryPathSel].disabled)
      end
      ctx.configModified = true
    end
  end
  local function saveAndStay()
    ctx.saveSplash = nil
    local locations = _.getLocations(ctx.context, ctx.fileType, ctx.chosenMcSlot)
    local path = ctx.currentPath or (locations and locations[1])
    if path and path ~= "" then
      ctx.lines = _.config_parse.regenerateForSave(ctx.lines, ctx.fileType, _.config_options)
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
  local function removeSelectedPath()
    if not hasPathSelection then return end
    refreshPaths()
    table.remove(paths, ctx.entryPathSel)
    if isBoot then
      _.config_parse.setBootPathEntries(ctx.lines, ctx.bootKey, paths)
    else
      _.config_parse.setMenuEntryPaths(ctx.lines, ctx.entryIdx, paths)
    end
    ctx.configModified = true
    refreshPaths()
    if ctx.entryPathSel > #paths then
      ctx.entryPathSel = math.max(1, #paths)
    end
  end
  local function insertPathFromActions()
    if not canAddPath then return end
    if isBoot and hasPathSelection then
      ctx.pathPickerInsertBelow = ctx.entryPathSel
    else
      ctx.pathPickerInsertBelow = nil
    end
    confirmMoveState()
    openPathPicker(nil)
  end
  local function swapSelectedPath(step)
    refreshPaths()
    if not hasPathSelection then return end
    local dst = ctx.entryPathSel + step
    if dst < 1 or dst > #paths then return end
    paths[ctx.entryPathSel], paths[dst] = paths[dst], paths[ctx.entryPathSel]
    if isBoot then
      _.config_parse.setBootPathEntries(ctx.lines, ctx.bootKey, paths)
    else
      _.config_parse.setMenuEntryPaths(ctx.lines, ctx.entryIdx, paths)
    end
    ctx.configModified = true
    ctx.entryPathSel = dst
    refreshPaths()
  end

  if ctx.entryPathsActionsOpen then
    local actionRows = {}
    if hasPathSelection and canMovePaths then
      actionRows[#actionRows + 1] = {
        id = "grab",
        label = ctx.entryPathGrab and (_.menu_str.cancel_move_label or "Cancel move") or
            (_.menu_str.grab_label or "Move"),
      }
    end
    if canAddPath then
      actionRows[#actionRows + 1] = { id = "insert", label = (_.menu_str.insert_label or "Insert") }
    end
    if hasPathSelection then
      actionRows[#actionRows + 1] = { id = "remove", label = (_.menu_str.remove_label or "Remove") }
    end
    if actions_menu.run(ctx, {
          openKey = "entryPathsActionsOpen",
          selKey = "entryPathsActionsSel",
          scrollKey = "entryPathsActionsScroll",
          title = (_.menu_str.actions_title or "Actions"),
          rows = actionRows,
          rowStateKeyPrefix = "entry_paths_actions_row_",
          onSelect = function(row)
            if row.id == "grab" then
              if ctx.entryPathGrab then
                cancelMoveState()
              else
                beginMoveState()
              end
            elseif row.id == "insert" then
              insertPathFromActions()
            elseif row.id == "remove" then
              removeSelectedPath()
            end
          end,
        }) then
      return
    end
  end

  if (_.padEffective & _.PAD_UP) ~= 0 then
    if ctx.entryPathGrab and hasPathSelection then
      swapSelectedPath(-1)
    else
      ctx.entryPathSel = ctx.entryPathSel - 1
      if ctx.entryPathSel < 1 then ctx.entryPathSel = total end
    end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    if ctx.entryPathGrab and hasPathSelection then
      swapSelectedPath(1)
    else
      ctx.entryPathSel = ctx.entryPathSel + 1
      if ctx.entryPathSel > total then ctx.entryPathSel = 1 end
    end
  end

  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
    toggleSelectedPathDisabled()
  end
  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    if ctx.entryPathGrab then
      confirmMoveState()
      return
    end
    if isBoot and (hasArgsPaths or hasSpecialArgsPath) and ctx.entryPathSel == argsRow then
      if argsRowIsSpecial then
        ctx.cdromOptSel = ctx.cdromOptSel or 1
        ctx.state = "entry_cdrom_options"
      else
        local args = _.config_parse.getBootArgs(ctx.lines, ctx.bootKey) or {}
        if #args == 0 then
          ctx.entryArgAddMenu = true
          ctx.entryArgAddSel = 1
          ctx.entryArgAddScroll = 0
        end
        ctx.entryArgSel = ctx.entryArgSel or 1
        ctx.entryArgScroll = ctx.entryArgScroll or 0
        ctx.state = "entry_args"
      end
    elseif ctx.entryPathSel >= 1 and ctx.entryPathSel <= #paths then
      openPathPicker(ctx.entryPathSel)
    end
  end
  if (_.padEffective & _.PAD_SQUARE) ~= 0 then
    ctx.entryPathsActionsOpen = true
    ctx.entryPathsActionsSel = ctx.entryPathsActionsSel or 1
    ctx.entryPathsActionsScroll = ctx.entryPathsActionsScroll or 0
  end
  if ctx.configModified and (_.padEffective & _.PAD_START) ~= 0 then
    saveAndStay()
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    if ctx.entryPathGrab then
      cancelMoveState()
      return
    end
    ctx.state = isBoot and "editor" or "menu_entry_edit"
  end
end

return { run = run }
