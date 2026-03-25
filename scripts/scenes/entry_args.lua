--[[ Arguments list for a menu entry or MBR boot key (when ctx.bootKey is set and we're in MBR). ]]

local arg_presets = dofile("scripts/scenes/arg_presets.lua")
local arg_profiles = dofile("scripts/scenes/arg_profiles.lua")
local arg_gsm_picker = dofile("scripts/scenes/arg_gsm_picker.lua")
local arg_add_menu = dofile("scripts/scenes/arg_add_menu.lua")
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

  local paths = isBoot and (_.config_parse.getBootPaths(ctx.lines, ctx.bootKey) or {}) or
      _.config_parse.getMenuEntryPaths(ctx.lines, ctx.entryIdx)
  local hasOsdOrShutdown = false
  for _, p in ipairs(paths or {}) do
    local pv = type(p) == "table" and p.value or p
    if (pv or ""):upper() == "OSDSYS" or (pv or ""):upper() == "POWEROFF" then
      hasOsdOrShutdown = true; break
    end
  end
  if not isBoot and hasOsdOrShutdown then
    ctx.state = "menu_entry_edit"; return
  end

  local hasCdrom = arg_presets.hasCdromPath(paths)
  local hasNhddlElfPath = arg_presets.hasNhddlElfPath(paths)

  local function getArgs()
    if isBoot then
      return _.config_parse.getBootArgEntries(ctx.lines, ctx.bootKey) or {}
    end
    return _.config_parse.getMenuEntryArgs(ctx.lines, ctx.entryIdx) or {}
  end

  local function setArgs(a)
    if isBoot then
      _.config_parse.setBootArgEntries(ctx.lines, ctx.bootKey, a or {})
      ctx.configModified = true
    else
      _.config_parse.setMenuEntryArgs(ctx.lines, ctx.entryIdx, a)
      ctx.configModified = true
    end
  end

  local function addArgValue(v)
    local value = tostring(v or "")
    if value == "" then return end
    if isBoot and ctx.entryArgInsertBelow and ctx.entryArgInsertBelow >= 0 then
      local insertAt = _.config_parse.insertBootArgBelow(ctx.lines, ctx.bootKey, ctx.entryArgInsertBelow, value)
      ctx.configModified = true
      ctx.entryArgSel = insertAt or (ctx.entryArgInsertBelow + 1)
    else
      local args2 = getArgs()
      table.insert(args2, { value = value, disabled = false })
      setArgs(args2)
      ctx.entryArgSel = #args2
    end
    ctx.entryArgInsertBelow = nil
  end

  local function openNewArgumentInput(prompt, maxLen, callback)
    _.common.beginTextInput(ctx, {
      clearArgEditIdx = true,
      titleIdMode = nil,
      prompt = prompt,
      value = "",
      maxLen = maxLen,
      callback = callback,
      returnState = "entry_args",
      gridSel = 1,
      cursor = 1,
      scroll = 1,
      state = "text_input",
    })
  end

  local function addUdpbdPair(ipValue)
    local args2, ok = arg_presets.addUdpbdPair(getArgs(), ipValue)
    if not ok then return false end
    setArgs(args2)
    ctx.entryArgSel = #args2
    return true
  end

  local args = getArgs()
  local total = #args
  local usedKnown, usedModes = arg_presets.collectUsedArgs(args)
  local profileState = arg_profiles.resolve({
    surface = "entry_args",
    context = ctx.context,
    fileType = ctx.fileType,
    isBoot = isBoot,
    hasNhddlPath = hasNhddlElfPath,
  })
  local addRows = arg_profiles.buildAddRows(profileState)
  local removeNhddlPair = arg_profiles.profileUsesNhddl(profileState.activeProfileId)
  if not arg_presets.pathsSupportPatinfo(paths) then
    local filteredRows = {}
    for i = 1, #addRows do
      if addRows[i].uniqueKey ~= "patinfo" then
        filteredRows[#filteredRows + 1] = addRows[i]
      end
    end
    addRows = filteredRows
  end
  if not hasCdrom then
    local filteredRows = {}
    for i = 1, #addRows do
      if not addRows[i].cdromOnly then
        filteredRows[#filteredRows + 1] = addRows[i]
      end
    end
    addRows = filteredRows
  end
  local gsmKeys = {
    openKey = "entryArgGsmPickerMenu",
    selKey = "entryArgGsmPickerSel",
    videoKey = "entryArgGsmVideoIdx",
    compatKey = "entryArgGsmCompatIdx",
    argKeyKey = "entryArgGsmArgKey",
    lastVideoKey = "entryArgGsmLastVideoIdx",
    editIdxKey = "entryArgGsmEditIdx",
    rowStateKeyPrefix = "entry_args_gsm_picker_row_",
  }

  local function clearGsmMenus()
    arg_gsm_picker.clearState(ctx, gsmKeys)
  end

  local function reopenAddMenu()
    ctx.entryArgAddMenu = true
    ctx.entryArgAddSel = ctx.entryArgAddSel or 1
    ctx.entryArgAddScroll = ctx.entryArgAddScroll or 0
  end

  local function openGsmPicker(row)
    arg_gsm_picker.open(ctx, gsmKeys, (row and row.egsmArgKey) or "-gsm")
  end

  if hasCdrom and not isBoot then
    ctx.entryArgAddMenu = nil
    ctx.entryArgAddSel = nil
    ctx.entryArgAddScroll = nil
    clearGsmMenus()
  end

  local function openUdpbdIpInput()
    openNewArgumentInput("UDPBD IP (x.x.x.x)", 15, function(val)
      local ip = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if ip ~= "" then addUdpbdPair(ip) end
      ctx.state = "entry_args"
    end)
  end

  local function openTitleIdInput()
    openNewArgumentInput("TITLEID (up to 11 chars)", 11, function(val)
      local titleId = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if titleId ~= "" then
        addArgValue("-titleid=" .. titleId)
      end
      ctx.state = "entry_args"
    end)
  end

  local function openDkwdrvPathInput()
    openNewArgumentInput("DKWDRV path", 79, function(val)
      local p = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if p ~= "" then
        addArgValue("-dkwdrv=" .. p)
      end
      ctx.state = "entry_args"
    end)
  end

  if arg_gsm_picker.run(ctx, {
        keys = gsmKeys,
        onSubmit = function(arg, editIdx)
          local idx = math.floor(tonumber(editIdx) or 0)
          if idx >= 1 then
            local args2 = getArgs()
            if type(args2[idx]) == "table" then
              args2[idx].value = arg
            else
              args2[idx] = { value = arg, disabled = false }
            end
            setArgs(args2)
            ctx.entryArgSel = _.common.clampListSelection(idx, #args2)
          else
            addArgValue(arg)
          end
        end,
        onCancel = function(editIdx)
          local idx = math.floor(tonumber(editIdx) or 0)
          if idx < 1 then
            reopenAddMenu()
          end
        end,
      }) then
    return
  end

  if ctx.entryArgAddMenu and #addRows > 0 then
    if arg_add_menu.run(ctx, {
          menuOpenKey = "entryArgAddMenu",
          selKey = "entryArgAddSel",
          scrollKey = "entryArgAddScroll",
          rows = addRows,
          title = "Add argument [" .. arg_profiles.getMenuTag(profileState) .. "]",
          descDefault = "Enter any custom argument manually.",
          rowStateKeyPrefix = "entry_args_add_row_",
          rowDisabledReason = function(row)
            return arg_presets.rowDisabled(row, usedKnown, usedModes, total)
          end,
          onSelect = function(row)
            if row.kind == "manual" then
              openNewArgumentInput(_.menu_str.new_argument_prompt, 79, function(val)
                local v = val or ""
                if v ~= "" then addArgValue(v) end
                ctx.state = "entry_args"
              end)
            elseif row.kind == "titleid" then
              openTitleIdInput()
            elseif row.kind == "egsm" or row.kind == "gsm" then
              openGsmPicker(row)
            elseif row.kind == "dkwdrv_path" then
              openDkwdrvPathInput()
            elseif row.kind == "udpbd_ip" then
              openUdpbdIpInput()
            elseif row.modeValue == "udpbd" and usedKnown.udpbd_ip ~= true then
              openUdpbdIpInput()
            else
              addArgValue(row.value or "")
            end
          end,
        }) then
        return
    end
  end

  ctx.entryArgSel = _.common.clampListSelection(ctx.entryArgSel or 1, total)
  ctx.entryArgScroll = _.common.centeredListScroll(ctx.entryArgSel, total, _.MAX_VISIBLE_LIST)

  local titleStr
  if isBoot then
    titleStr = ((_.strings.options and _.strings.options[ctx.bootKey] and _.strings.options[ctx.bootKey].label) or ctx.bootKey) ..
        " - " .. _.menu_str.arguments
  else
    local name = _.config_parse.getMenuEntryName(ctx.lines, ctx.entryIdx) or ""
    name = name ~= "" and name or _.common_str.empty
    local prefix = "Arguments for "
    local suffix = " (entry " .. tostring(ctx.entryIdx) .. ")"
    local prefixW = _.common.calcTextWidth(_.font, prefix, 1) or 0
    local suffixW = _.common.calcTextWidth(_.font, suffix, 1) or 0
    local availableW = (_.w or 640) - 2 * _.MARGIN_X - prefixW - suffixW
    if availableW > 0 then
      name = _.common.truncateTextToWidth(_.font, name, availableW, 1)
    end
    titleStr = string.format(_.menu_str.args_for_entry_title, name, ctx.entryIdx)
  end
  if isBoot then
    drawBootTitle(_, ctx.bootKey, titleStr)
  else
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, titleStr, _.WHITE)
  end
  if not isBoot and hasCdrom then
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(24), 0.75, _.menu_str.cdrom_hint, _.DIM)
  end

  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X
  for i = ctx.entryArgScroll + 1, math.min(ctx.entryArgScroll + _.MAX_VISIBLE_LIST, total) do
    local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.entryArgScroll - 1) * _.LINE_H
    local a = args[i]
    local av = type(a) == "table" and a.value or a
    local label = (av and av ~= "" and av) or _.common_str.empty
    if ctx.entryArgGrab and i == ctx.entryArgSel then
      label = "[" .. (_.menu_str.grabbed_tag or "GRAB") .. "] " .. label
    end
    if _.common.fitListRowText then
      label = _.common.fitListRowText(ctx, "entry_args_row_" .. tostring(i), _.font, label, maxLabelW, _.FONT_SCALE,
        i == ctx.entryArgSel)
    elseif _.common.truncateTextToWidth then
      label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
    end
    local col = (i == ctx.entryArgSel) and _.SELECTED_ENTRY or _.WHITE
    if not isBoot and type(a) == "table" and a.disabled then
      col = (i == ctx.entryArgSel) and (_.SELECTED_ENTRY_DIM or _.SELECTED_ENTRY) or (_.DIM_ENTRY or _.DIM)
    end
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.entryArgSel, label, col)
  end

  local hasSelection = (ctx.entryArgSel >= 1 and ctx.entryArgSel <= total)
  local canAddArg = (isBoot or not hasCdrom)
  local selectedDisabled = hasSelection and type(args[ctx.entryArgSel]) == "table" and args[ctx.entryArgSel].disabled
  local argHints = {
    { pad = hasSelection and "cross" or "", label = hasSelection and (_.menu_str.edit_label or "Edit") or "", row = 1 },
    { pad = "square", label = (_.menu_str.actions_label or "Actions"), row = 1 },
    {
      pad = ctx.configModified and "start" or "",
      label = ctx.configModified and (_.menu_str.save_config_label or "Save Config") or "",
      row = 1
    },
    {
      pad = hasSelection and "triangle" or "",
      label = hasSelection and
          (selectedDisabled and (_.menu_str.enable_label or "Enable") or (_.menu_str.disable_label or "Disable")) or "",
      row = 1
    },
    { pad = "circle", label = _.menu_str.back_label or "Back", row = 1 },
  }
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, argHints, nil, _.DIM, _.w - 2 * _.MARGIN_X)

  local function toggleSelectedArgDisabled()
    if ctx.entryArgSel >= 1 and ctx.entryArgSel <= total and type(args[ctx.entryArgSel]) == "table" then
      if isBoot then
        _.config_parse.setBootArgDisabled(ctx.lines, ctx.bootKey, ctx.entryArgSel, not args[ctx.entryArgSel].disabled)
      else
        _.config_parse.setArgDisabled(ctx.lines, ctx.entryIdx, ctx.entryArgSel, not args[ctx.entryArgSel].disabled)
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

  local function moveSelectedArg(step)
    if not hasSelection or total <= 1 then return end
    local dst = ctx.entryArgSel + step
    if dst < 1 or dst > total then return end
    local args2 = getArgs()
    args2[ctx.entryArgSel], args2[dst] = args2[dst], args2[ctx.entryArgSel]
    setArgs(args2)
    ctx.entryArgSel = dst
  end

  local function removeSelectedArg()
    if not hasSelection then return end
    local args2 = arg_presets.removeArgAndPairedUdpbd(getArgs(), ctx.entryArgSel, removeNhddlPair)
    setArgs(args2)
    ctx.entryArgSel = _.common.clampListSelection(ctx.entryArgSel, #args2)
    if #args2 == 0 then
      ctx.entryArgGrab = nil
    end
  end

  local function beginAddArg()
    if not canAddArg then return end
    if isBoot and total > 0 and hasSelection then
      ctx.entryArgInsertBelow = ctx.entryArgSel
    else
      ctx.entryArgInsertBelow = nil
    end
    ctx.entryArgGrab = nil
    ctx.entryArgAddMenu = true
    ctx.entryArgAddSel = ctx.entryArgAddSel or 1
    ctx.entryArgAddScroll = ctx.entryArgAddScroll or 0
  end

  if ctx.entryArgsActionsOpen then
    local actionRows = {}
    if hasSelection then
      actionRows[#actionRows + 1] = {
        id = "grab",
        label = ctx.entryArgGrab and (_.menu_str.release_grab_label or "Release") or (_.menu_str.grab_label or "Grab"),
      }
      actionRows[#actionRows + 1] = { id = "remove", label = (_.menu_str.remove_label or "Remove") }
    end
    if canAddArg then
      actionRows[#actionRows + 1] = { id = "add", label = (_.menu_str.add_label or "Add") }
    end
    if actions_menu.run(ctx, {
          openKey = "entryArgsActionsOpen",
          selKey = "entryArgsActionsSel",
          scrollKey = "entryArgsActionsScroll",
          title = (_.menu_str.actions_title or "Actions"),
          rows = actionRows,
          rowStateKeyPrefix = "entry_args_actions_row_",
          onSelect = function(row)
            if row.id == "grab" then
              ctx.entryArgGrab = not ctx.entryArgGrab
            elseif row.id == "add" then
              beginAddArg()
            elseif row.id == "remove" then
              removeSelectedArg()
            end
          end,
        }) then
      return
    end
  end

  if (_.padEffective & _.PAD_UP) ~= 0 then
    if ctx.entryArgGrab then
      moveSelectedArg(-1)
    else
      ctx.entryArgSel = _.common.wrapListSelection(ctx.entryArgSel, total, -1)
    end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    if ctx.entryArgGrab then
      moveSelectedArg(1)
    else
      ctx.entryArgSel = _.common.wrapListSelection(ctx.entryArgSel, total, 1)
    end
  end

  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
    toggleSelectedArgDisabled()
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    if ctx.entryArgSel >= 1 and ctx.entryArgSel <= #args then
      local editIdx = ctx.entryArgSel
      local editValue = type(args[editIdx]) == "table" and args[editIdx].value or args[editIdx]
      local gsmArgKey, gsmVideoIdx, gsmCompatIdx = arg_gsm_picker.parseExistingGsmArg(_, editValue)
      if gsmArgKey then
        arg_gsm_picker.open(ctx, gsmKeys, gsmArgKey, gsmVideoIdx, gsmCompatIdx)
        ctx[gsmKeys.editIdxKey] = editIdx
      else
        _.common.beginTextInput(ctx, {
          argEditIdx = editIdx,
          titleIdMode = nil,
          prompt = _.menu_str.edit_argument_prompt,
          value = editValue,
          maxLen = 79,
          callback = function(val)
            local args2 = getArgs()
            if type(args2[ctx.argEditIdx]) == "table" then
              args2[ctx.argEditIdx].value = val or ""
            else
              args2[ctx.argEditIdx] = { value = val or "", disabled = false }
            end
            setArgs(args2)
            ctx.state = "entry_args"
          end,
          returnState = "entry_args",
          gridSel = 1,
          scroll = 1,
          state = "text_input",
        })
      end
    end
  end

  if (_.padEffective & _.PAD_SQUARE) ~= 0 then
    ctx.entryArgsActionsOpen = true
    ctx.entryArgsActionsSel = ctx.entryArgsActionsSel or 1
    ctx.entryArgsActionsScroll = ctx.entryArgsActionsScroll or 0
  end
  if ctx.configModified and (_.padEffective & _.PAD_START) ~= 0 then
    saveAndStay()
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.entryArgGrab = nil
    ctx.state = isBoot and "entry_paths" or "menu_entry_edit"
  end
end

return { run = run }
