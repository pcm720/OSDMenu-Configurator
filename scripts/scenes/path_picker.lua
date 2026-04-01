--[[ Path picker: device list, partitions, or directory browse. ]]

local actions_menu = dofile("scripts/scenes/actions_menu.lua")

-- Apply chosen path for MBR boot key and return next state. Returns nil if not a boot-key pick.
local function applyBootPathAndReturn(ctx, val)
  if not ctx.pathPickerBootKey or not ctx.lines then return nil end
  local _ = ctx._
  if ctx.pathPickerEditIdx then
    local paths = _.config_parse.getBootPathEntries(ctx.lines, ctx.pathPickerBootKey) or {}
    local item = paths[ctx.pathPickerEditIdx]
    if type(item) == "table" then
      item.value = val
    else
      paths[ctx.pathPickerEditIdx] = { value = val, disabled = false }
    end
    _.config_parse.setBootPathEntries(ctx.lines, ctx.pathPickerBootKey, paths)
  elseif ctx.pathPickerInsertBelow then
    _.config_parse.insertBootPathBelow(ctx.lines, ctx.pathPickerBootKey, ctx.pathPickerInsertBelow, val)
  else
    _.config_parse.insertBootPathBelow(ctx.lines, ctx.pathPickerBootKey, 0x7fffffff, val)
  end
  ctx.state = ctx.pathPickerReturnState or "editor"
  ctx.pathPickerBootKey = nil
  ctx.pathPickerReturnState = nil
  ctx.pathPickerForEntryIdx = nil
  ctx.pathPickerEditIdx = nil
  ctx.pathPickerInsertBelow = nil
  return true
end

-- Apply chosen path for a BBL hotkey slot and return next state. Returns nil if not a BBL slot pick.
local function applyBblHotkeyPathAndReturn(ctx, val)
  if not ctx.pathPickerBblHotkeyKey or not ctx.pathPickerBblHotkeySlot or not ctx.lines then return nil end
  local _ = ctx._
  local slot = tonumber(ctx.pathPickerBblHotkeySlot)
  if not slot then return nil end
  _.config_parse.setBblHotkeyPath(ctx.lines, ctx.pathPickerBblHotkeyKey, slot, val,
    ctx.pathPickerBblHotkeyDisabled and true or false)
  ctx.state = ctx.pathPickerReturnState or "bbl_hotkey_entry"
  ctx.pathPickerBblHotkeyKey = nil
  ctx.pathPickerBblHotkeySlot = nil
  ctx.pathPickerBblHotkeyDisabled = nil
  ctx.pathPickerReturnState = nil
  ctx.pathPickerEditIdx = nil
  return true
end

local function applyBblIrxPathAndReturn(ctx, val)
  if not ctx.pathPickerBblIrxIdx or not ctx.lines then return nil end
  local _ = ctx._
  local entryIdx = tonumber(ctx.pathPickerBblIrxIdx)
  if not entryIdx then return nil end
  _.config_parse.setBblIrxEntry(ctx.lines, entryIdx, val, ctx.pathPickerBblIrxDisabled and true or false)
  ctx.state = ctx.pathPickerReturnState or "bbl_irx_entries"
  ctx.pathPickerBblIrxIdx = nil
  ctx.pathPickerBblIrxDisabled = nil
  ctx.pathPickerReturnState = nil
  ctx.pathPickerEditIdx = nil
  ctx.pathPickerFileExts = nil
  return true
end

-- Convert pfs path (pfs0:/ or pfs1:/...) to full partition path (hdd0:PART:pfs:...). Returns nil if not a pfs path.
local function pfsToPartitionPath(pfsPath, partitionPath)
  if not pfsPath or not partitionPath then return nil end
  local rest = pfsPath:match("^pfs[01]:/?(.*)$")
  if not rest then return nil end
  if rest == "" then return partitionPath .. ":pfs:/" end
  return partitionPath .. ":pfs:" .. rest
end

-- IOP reset (mx4sio/mmce) unloads all device drivers; clear all loaded flags.
local function clearLoadedIfIopReset(ctx)
  ctx.pathPickerLoadedDeviceTypes = {}
end

local function isConfigOpenTarget(ctx)
  return ctx and ctx.pathPickerTarget == "config_open"
end

local function hasIniFilter(ctx)
  if not ctx or type(ctx.pathPickerFileExts) ~= "table" then return false end
  for i = 1, #ctx.pathPickerFileExts do
    local ext = tostring(ctx.pathPickerFileExts[i] or ""):lower()
    if ext ~= "" and ext:sub(1, 1) ~= "." then ext = "." .. ext end
    if ext == ".ini" then return true end
  end
  return false
end

local function hasIrxFilter(ctx)
  if not ctx or type(ctx.pathPickerFileExts) ~= "table" then return false end
  for i = 1, #ctx.pathPickerFileExts do
    local ext = tostring(ctx.pathPickerFileExts[i] or ""):lower()
    if ext ~= "" and ext:sub(1, 1) ~= "." then ext = "." .. ext end
    if ext == ".irx" then return true end
  end
  return false
end

local function isBblIrxPath(path)
  local s = tostring(path or ""):gsub("^%s+", ""):gsub("%s+$", "")
  return s ~= "" and s:lower():match("%.irx$") ~= nil, s
end

local function listBrowseEntries(ctx, path)
  local _ = ctx._
  if isConfigOpenTarget(ctx) then
    local raw = _.file_selector.listDirectory(path) or {}
    local out = {}
    for i = 1, #raw do
      local e = raw[i]
      if e and e.directory then
        table.insert(out, e)
      elseif e and tostring(e.name or ""):lower() == "config.ini" then
        table.insert(out, e)
      end
    end
    return out
  end
  local exts = ctx.pathPickerFileExts
  if type(exts) == "table" and #exts > 0 and _.common and _.common.listDirectoryFiltered then
    return _.common.listDirectoryFiltered(path, _.file_selector, { extensions = exts })
  end
  return _.listDirectoryElfOnly(path)
end

local function clearPickerTransient(ctx)
  ctx.pathList = nil
  ctx.pathBrowsePath = nil
  ctx.pathPickerBdmPrefix = nil
  ctx.pathPickerBdmMountpoint = nil
  ctx.pathPickerBrowseSelStack = nil
end

local function clearConfigOpenPickerState(ctx)
  ctx.pathPickerTarget = nil
  ctx.pathPickerFileExts = nil
  ctx.pathPickerLockedDevice = nil
  ctx.pathPickerLockedDeviceStarted = nil
end

local function getPathFlagsCaseAware(fileSelector, pathVal)
  local getPathFlags = fileSelector and fileSelector.getPathFlags
  if not getPathFlags then return {} end
  local flags = getPathFlags(pathVal) or {}
  if (not flags.exclusive) and type(pathVal) == "string" then
    local lower = pathVal:lower()
    if lower ~= pathVal then
      local lowerFlags = getPathFlags(lower) or {}
      if lowerFlags.exclusive then
        flags = lowerFlags
      end
    end
  end
  return flags
end

local function isE1LockedPath(pathVal)
  local p = tostring(pathVal or "")
  if p:lower() == "cdrom" then return true end
  local up = p:upper()
  return up == "OSDSYS" or up == "POWEROFF" or up == "FASTBOOT"
end

local function isBblE1ExclusivePath(pathVal)
  local up = tostring(pathVal or ""):gsub("^%s+", ""):gsub("%s+$", ""):upper()
  return up == "$CDVD" or up == "$CDVD_NO_PS2LOGO" or up == "$CREDITS" or up == "$HDDCHECKER"
end

local function isFmcbEntryE1LockedPath(ctx, pathVal)
  if not ctx or ctx.pathPickerContext ~= "fmcb_entry" then return false end
  local up = tostring(pathVal or ""):gsub("^%s+", ""):gsub("%s+$", ""):upper()
  return up == "OSDSYS" or up == "POWEROFF" or up == "FASTBOOT"
end

local function isFmcbLaunchE1LockedPath(ctx, pathVal)
  if not ctx or not ctx.pathPickerBblHotkeyKey then return false end
  local isFmcb = (ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot")
  if not isFmcb then return false end
  local up = tostring(pathVal or ""):gsub("^%s+", ""):gsub("%s+$", ""):upper()
  return up == "FASTBOOT" or up == "POWEROFF"
end

local function isE1RestrictedPathForContext(ctx, pathVal)
  if isBblE1ExclusivePath(pathVal) then return true end
  if isFmcbEntryE1LockedPath(ctx, pathVal) then return true end
  if isFmcbLaunchE1LockedPath(ctx, pathVal) then return true end
  return false
end

local function hasUsablePathValue(pathVal)
  local s = tostring(pathVal or "")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s ~= ""
end

local function getFirstEmptyPathIndex(paths)
  for i = 1, #(paths or {}) do
    local item = paths[i]
    local pv = type(item) == "table" and item.value or item
    if not hasUsablePathValue(pv) then
      return i
    end
  end
  return nil
end

local function setMenuEntryPathValue(paths, editIdx, val)
  if editIdx and editIdx >= 1 then
    local item = paths[editIdx]
    if type(item) == "table" then
      item.value = val
      item.disabled = false
    else
      paths[editIdx] = { value = val, disabled = false }
    end
    return
  end
  local firstEmptyIdx = getFirstEmptyPathIndex(paths)
  if firstEmptyIdx then
    local item = paths[firstEmptyIdx]
    if type(item) == "table" then
      item.value = val
      item.disabled = false
    else
      paths[firstEmptyIdx] = { value = val, disabled = false }
    end
    return
  end
  table.insert(paths, { value = val, disabled = false })
end

local function getOtherTargetPathStats(ctx)
  local _ = ctx._
  local editIdx = tonumber(ctx.pathPickerEditIdx)
  local out = { count = 0, firstExclusive = false, firstCdrom = false, targetIndex = nil }
  local paths = nil
  if ctx.pathPickerBblHotkeyKey and ctx.pathPickerBblHotkeySlot and ctx.lines and _.config_parse.getBblHotkeySlot then
    local keyId = ctx.pathPickerBblHotkeyKey
    local slot = tonumber(ctx.pathPickerBblHotkeySlot) or 1
    out.targetIndex = slot

    local maxEntries = (_.config_parse.getBblMaxEntries and _.config_parse.getBblMaxEntries()) or 10
    local isFmcb = (ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot")
    if isFmcb then
      local fmcbCap = (_.config_options and _.config_options.FMCB_BBL_MAX_ENTRIES) or 3
      maxEntries = math.max(1, math.min(maxEntries, fmcbCap))
    end

    if slot ~= 1 then
      local first = _.config_parse.getBblHotkeySlot(ctx.lines, keyId, 1)
      local firstPv = first and first.path or nil
      if first and first.pathExists and hasUsablePathValue(firstPv) then
        out.firstExclusive = (isE1LockedPath(firstPv) or isBblE1ExclusivePath(firstPv)) and true or false
        out.firstCdrom = (type(firstPv) == "string" and firstPv:lower() == "cdrom") and true or false
      end
    end

    for i = 1, maxEntries do
      if i ~= slot then
        local s = _.config_parse.getBblHotkeySlot(ctx.lines, keyId, i)
        local pv = s and s.path or nil
        if s and s.pathExists and hasUsablePathValue(pv) then
          out.count = out.count + 1
        end
      end
    end
    return out
  end

  if ctx.pathPickerForEntryIdx and ctx.lines then
    paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx) or {}
  elseif ctx.pathPickerBootKey and ctx.lines then
    paths = _.config_parse.getBootPathEntries(ctx.lines, ctx.pathPickerBootKey) or {}
  end
  if not paths then return out end

  if editIdx and editIdx >= 1 then
    out.targetIndex = editIdx
  else
    local insertBelow = tonumber(ctx.pathPickerInsertBelow)
    if insertBelow and insertBelow >= 1 then
      out.targetIndex = math.max(1, math.min(#paths + 1, insertBelow + 1))
    else
      out.targetIndex = getFirstEmptyPathIndex(paths) or (#paths + 1)
    end
  end

  -- E1-only rule: only the first path controls whether additional paths are blocked.
  if (not editIdx or editIdx ~= 1) and paths[1] then
    local firstPv = type(paths[1]) == "table" and paths[1].value or paths[1]
    if hasUsablePathValue(firstPv) then
      out.firstExclusive = isE1LockedPath(firstPv) and true or false
      out.firstCdrom = (type(firstPv) == "string" and firstPv:lower() == "cdrom") and true or false
    end
  end

  for i = 1, #paths do
    if not editIdx or i ~= editIdx then
      local item = paths[i]
      local pv = type(item) == "table" and item.value or item
      if hasUsablePathValue(pv) then
        out.count = out.count + 1
      end
    end
  end
  return out
end

local function showExclusivePathWarning(ctx, pathVal)
  local _ = ctx._
  local p = tostring(pathVal or "")
  local pLower = p:lower()
  local detail
  if pLower == "cdrom" then
    detail = _.menu_str and _.menu_str.cdrom_exclusive_warning
  end
  if not detail or detail == "" then
    detail = (_.path_str and _.path_str.exclusive_path_warning) or
        "This path must be the first and only path for this entry."
  end
  ctx.saveSplash = {
    kind = "failed",
    title = (_.menu_str and _.menu_str.invalid_selection_title) or
        (_.path_str and _.path_str.invalid_selection_title) or "Invalid selection",
    detail = detail,
    framesLeft = 120
  }
end

local function canUsePathSelection(ctx, pathVal)
  local _ = ctx._
  local flags = getPathFlagsCaseAware(_.file_selector, pathVal)
  local stats = getOtherTargetPathStats(ctx)
  local targetIndex = tonumber(stats.targetIndex)
  if targetIndex and targetIndex ~= 1 and isE1RestrictedPathForContext(ctx, pathVal) then
    showExclusivePathWarning(ctx, pathVal)
    return false
  end
  if targetIndex and isBblE1ExclusivePath(pathVal) then
    if stats.count == 0 then return true end
    showExclusivePathWarning(ctx, pathVal)
    return false
  end
  if flags.exclusive then
    if stats.count == 0 then return true end
    showExclusivePathWarning(ctx, pathVal)
    return false
  end
  if stats.firstExclusive then
    showExclusivePathWarning(ctx, stats.firstCdrom and "cdrom" or pathVal)
    return false
  end
  return true
end

local function leaveLockedConfigBrowse(ctx)
  if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
  if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
  ctx.pfs0Mounted = nil
  ctx.pfs1Mounted = nil
  clearPickerTransient(ctx)
  ctx.pathPickerLoading = nil
  ctx.pathPickerLoadingFrames = nil
  ctx.pathPickerModulesLoaded = nil
  ctx.pathPickerLoadingTimeoutMsg = nil
  ctx.state = ctx.pathPickerReturnState or "select_config"
  ctx.pathPickerReturnState = nil
  clearConfigOpenPickerState(ctx)
end

local function applyConfigOpenPathAndReturn(ctx, val)
  if not isConfigOpenTarget(ctx) then return nil end
  if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
  if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
  ctx.pfs0Mounted = nil
  ctx.pfs1Mounted = nil
  clearPickerTransient(ctx)
  ctx.currentPath = tostring(val or ""):gsub("/$", "")
  ctx.openExplicitPath = true
  ctx.state = "open"
  ctx.pathPickerReturnState = nil
  clearConfigOpenPickerState(ctx)
  return true
end

-- Apply a manually entered path and leave path picker (used by "Enter path manually" text input callback).
local function applyManualPath(ctx, val)
  if not val or val == "" then
    if isConfigOpenTarget(ctx) then
      if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
      if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
      ctx.pfs0Mounted = nil
      ctx.pfs1Mounted = nil
      ctx.state = ctx.pathPickerReturnState or "select_config"
      clearPickerTransient(ctx)
      ctx.pathPickerReturnState = nil
      clearConfigOpenPickerState(ctx)
      return
    end
    -- Done with empty path: return to entry paths or path_picker so we don't show "Choose device" / "No devices"
    if ctx.pathPickerForEntryIdx then
      ctx.entryIdx = ctx.pathPickerForEntryIdx
      ctx.state = (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
      ctx.pathPickerForEntryIdx = nil
      ctx.pathPickerEditIdx = nil
      ctx.pathPickerInsertBelow = nil
    elseif ctx.pathPickerBblHotkeyKey then
      ctx.state = ctx.pathPickerReturnState or "bbl_hotkey_entry"
      ctx.pathPickerBblHotkeyKey = nil
      ctx.pathPickerBblHotkeySlot = nil
      ctx.pathPickerBblHotkeyDisabled = nil
    elseif ctx.pathPickerBblIrxIdx then
      ctx.state = ctx.pathPickerReturnState or "bbl_irx_entries"
      ctx.pathPickerBblIrxIdx = nil
      ctx.pathPickerBblIrxDisabled = nil
      ctx.pathPickerFileExts = nil
    else
      ctx.state = ctx.pathPickerReturnState or "editor"
    end
    ctx.pathList = nil
    ctx.pathPickerReturnState = nil
    return
  end
  local _ = ctx._
  if ctx.pathPickerBblIrxIdx then
    local okIrx, normalizedVal = isBblIrxPath(val)
    if not okIrx then
      ctx.saveSplash = {
        kind = "failed",
        title = (_.editor_str and _.editor_str.save_failed) or "Save failed",
        textColor = _.HIGHLIGHT,
        detail = (_.path_str and _.path_str.irx_extension_required) or "Path must end in .irx",
        framesLeft = 60
      }
      ctx.state = "path_picker"
      ctx.pathPickerSub = "device"
      ctx.pathList = _.file_selector.getDevices(ctx.pathPickerContext) or {}
      ctx.pathPickerScroll = 0
      return
    end
    val = normalizedVal
  end
  if not canUsePathSelection(ctx, val) then
    ctx.state = "path_picker"
    ctx.pathPickerSub = "device"
    ctx.pathList = _.file_selector.getDevices(ctx.pathPickerContext) or {}
    ctx.pathPickerScroll = 0
    return
  end
  if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
  if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
  ctx.pathList = nil
  ctx.pathBrowsePath = nil
  ctx.pfs0Mounted = nil
  ctx.pfs1Mounted = nil
  if applyConfigOpenPathAndReturn(ctx, val) then
    return
  end
  ctx.configModified = true
  if applyBootPathAndReturn(ctx, val) then
  elseif applyBblHotkeyPathAndReturn(ctx, val) then
  elseif applyBblIrxPathAndReturn(ctx, val) then
  elseif ctx.pathPickerForEntryIdx then
    local paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx)
    setMenuEntryPathValue(paths, ctx.pathPickerEditIdx, val)
    _.config_parse.setMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx, paths)
    ctx.entryIdx = ctx.pathPickerForEntryIdx
    ctx.state = (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
    ctx.pathPickerForEntryIdx = nil
    ctx.pathPickerEditIdx = nil
  elseif ctx.isAddPath then
    local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or ctx.addPathKey
    _.config_parse.append(ctx.lines, key, val)
    ctx.state = "editor"
  else
    _.config_parse.set(ctx.lines, ctx.editKey or "", val)
    ctx.state = "editor"
  end
  ctx.pathPickerBootKey = nil
  ctx.pathPickerReturnState = nil
  ctx.pathPickerInsertBelow = nil
  ctx.pathPickerBdmPrefix = nil
  ctx.pathPickerBdmMountpoint = nil
  clearConfigOpenPickerState(ctx)
end

local function ensureBblCommandRows(ctx)
  if not ctx or ctx.pathPickerContext ~= "path_only" or not ctx.pathPickerBblHotkeyKey then return end
  if not ctx.pathList then return end
  for _, row in ipairs(ctx.pathList) do
    if row and row.special == "bbl_cmd" then
      return
    end
  end
  local _ = ctx._
  local p = _.path_str or {}
  local cmdRows
  if ctx.fileType == "freemcboot_cnf" then
    cmdRows = {
      { name = "OSDSYS", desc = p.fmcb_cmd_osdsys or "Boot hacked OSDSYS", special = "bbl_cmd" },
      { name = "OSDMENU", desc = p.fmcb_cmd_osdmenu or "Boot hacked OSDSYS, enforce skip disc boot", special = "bbl_cmd" },
      { name = "FASTBOOT", desc = p.fmcb_cmd_fastboot or "Boot PS2 Disc without logo", special = "bbl_cmd" },
      {
        name = "POWEROFF",
        desc = p.fmcb_cmd_poweroff or "Shutdown the console: FMCB 1.966 only, else use POWEROFF.ELF",
        special = "bbl_cmd"
      },
    }
  else
    cmdRows = {
      { name = "$CDVD", desc = p.bbl_cmd_cdvd_label or "Launch Disc", special = "bbl_cmd", exclusive = true },
      {
        name = "$CDVD_NO_PS2LOGO",
        desc = p.bbl_cmd_cdvd_no_logo_label or "Launch Disc no PS2 Logo",
        special = "bbl_cmd",
        exclusive = true
      },
      { name = "$OSDSYS", desc = p.bbl_cmd_osdsys_label or "OSDSYS", special = "bbl_cmd" },
      { name = "$CREDITS", desc = p.bbl_cmd_credits_label or "Credits", special = "bbl_cmd", exclusive = true },
      { name = "$HDDCHECKER", desc = p.bbl_cmd_hddchecker_label or "Check HDD", special = "bbl_cmd", exclusive = true },
    }
  end
  for i = 1, #cmdRows do
    table.insert(ctx.pathList, cmdRows[i])
  end
end

local function centeredScroll(sel, total, maxVis)
  if total <= maxVis then return 0 end
  local s = sel - math.floor(maxVis / 2)
  return math.max(0, math.min(s, total - maxVis))
end

local function getSelectedBblName(ctx)
  local ft = ctx and ctx.fileType or nil
  if ft == "freemcboot_cnf" then return "FreeMCBoot" end
  if ft == "psxbbl_ini" then return "PSXBBL" end
  if ft == "ps2bbl_ini" then return "PS2BBL" end
  local c = ctx and ctx.context or nil
  if c == "freemcboot" then return "FreeMCBoot" end
  if c == "psxbbl" then return "PSXBBL" end
  return "PS2BBL"
end

local function beginBrowseForDevice(ctx, e)
  if not e then return end
  local _ = ctx._
  if e.deviceType == "hdd" and not e.deviceId then
    ctx.pathPickerDeviceSel = ctx.pathPickerSel
    ctx.pathPickerLoadedDeviceTypes = ctx.pathPickerLoadedDeviceTypes or {}
    if ctx.pathPickerLoadedDeviceTypes["hdd"] then
      if System and System.loadModules then System.loadModules("hdd") end
      if _.common.isHddPresent and _.common.isHddPresent() then
        ctx.pathPickerSub = "partitions"
        ctx.pathList = _.file_selector.getHddPartitions(0) or {}
        ctx.pathBrowsePath = "hdd0:"
        ctx.pathPickerSel = 1
        ctx.pathPickerScroll = 0
      else
        ctx.pathPickerLoading = { deviceType = "hdd", staticHdd = true }
        ctx.pathPickerLoadingFrames = 0
      end
    else
      ctx.pathPickerLoading = { deviceType = "hdd", staticHdd = true }
      ctx.pathPickerLoadingFrames = 0
    end
  elseif e.deviceId and e.deviceType then
    ctx.pathPickerDeviceSel = ctx.pathPickerSel
    ctx.pathPickerLoadedDeviceTypes = ctx.pathPickerLoadedDeviceTypes or {}
    if e.deviceType == "mx4sio" and ctx.pathPickerLoadedDeviceTypes["mmce"] then clearLoadedIfIopReset(ctx) end
    if ctx.pathPickerLoadedDeviceTypes[e.deviceType] then
      if System and System.loadModules then System.loadModules(e.deviceType) end
      local mp = (System and System.getDeviceMountpoint) and System.getDeviceMountpoint(e.deviceId) or nil
      if mp and mp ~= "" then
        local mpNorm = (mp:sub(-1) == ":") and mp or (mp .. ":")
        ctx.pathPickerBdmMountpoint = mpNorm
        ctx.pathPickerBdmPrefix = _.file_selector.getBdmPathPrefix(e.deviceId)
        ctx.pathBrowsePath = (mp:sub(-1) == ":") and (mp .. "/") or mp
        ctx.pathList = listBrowseEntries(ctx, ctx.pathBrowsePath)
        ctx.pathPickerSub = "browse"
        ctx.pathPickerSel = 1
        ctx.pathPickerScroll = 0
      else
        ctx.pathPickerLoading = { deviceId = e.deviceId, deviceType = e.deviceType }
        ctx.pathPickerLoadingFrames = 0
      end
    else
      ctx.pathPickerLoading = { deviceId = e.deviceId, deviceType = e.deviceType }
      ctx.pathPickerLoadingFrames = 0
    end
  else
    ctx.pathPickerDeviceSel = ctx.pathPickerSel
    -- Static device (mc, mmce) without deviceId: use name as path. Load MMCE module when selecting mmce.
    ctx.pathPickerLoadedDeviceTypes = ctx.pathPickerLoadedDeviceTypes or {}
    if e.deviceType == "mmce" and ctx.pathPickerLoadedDeviceTypes["mx4sio"] then clearLoadedIfIopReset(ctx) end
    if e.deviceType and System and System.loadModules then System.loadModules(e.deviceType) end
    local browsePath = e.name or ""
    if browsePath and browsePath ~= "" and browsePath:find(":") then
      ctx.pathBrowsePath = (browsePath:sub(-1) == ":") and (browsePath .. "/") or browsePath
      ctx.pathList = listBrowseEntries(ctx, ctx.pathBrowsePath)
    else
      ctx.pathBrowsePath = nil
      ctx.pathList = {}
    end
    ctx.pathPickerSub = "browse"
    ctx.pathPickerSel = 1
    if e.deviceType then ctx.pathPickerLoadedDeviceTypes[e.deviceType] = true end
  end
end

local function run(ctx)
  local _ = ctx._
  -- Wildcard confirm: path is mc0/mc1/mmce0/mmce1; Cross = Yes (use wildcard), Circle = No (use as-is)
  if ctx.pathPickerWildcardConfirm and ctx.pathPickerPendingPath then
    local val = ctx.pathPickerPendingPath
    local mode = ctx.pathPickerWildcardMode or "single"
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.path_str.wildcard_confirm_title, _.WHITE)
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(28), _.FONT_SCALE, val, _.GRAY)
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.path_str.wildcard_confirm_hint, nil, _.DIM,
      _.w - 2 * _.MARGIN_X)
    local function applyAndExit(chosenVal)
      ctx.configModified = true
      if mode == "single" then
        _.config_parse.set(ctx.lines, ctx.editKey, chosenVal)
        ctx.state = "editor"
      elseif mode == "bbl_hotkey" then
        local slot = tonumber(ctx.pathPickerBblHotkeySlot)
        if slot then
          _.config_parse.setBblHotkeyPath(ctx.lines, ctx.pathPickerBblHotkeyKey, slot, chosenVal,
            ctx.pathPickerBblHotkeyDisabled and true or false)
        end
        ctx.state = ctx.pathPickerReturnState or "bbl_hotkey_entry"
        ctx.pathPickerBblHotkeyKey = nil
        ctx.pathPickerBblHotkeySlot = nil
        ctx.pathPickerBblHotkeyDisabled = nil
        ctx.pathPickerReturnState = nil
      elseif mode == "bbl_irx" then
        local entryIdx = tonumber(ctx.pathPickerBblIrxIdx)
        if entryIdx then
          _.config_parse.setBblIrxEntry(ctx.lines, entryIdx, chosenVal, ctx.pathPickerBblIrxDisabled and true or false)
        end
        ctx.state = ctx.pathPickerReturnState or "bbl_irx_entries"
        ctx.pathPickerBblIrxIdx = nil
        ctx.pathPickerBblIrxDisabled = nil
        ctx.pathPickerReturnState = nil
        ctx.pathPickerFileExts = nil
      elseif mode == "entry" then
        local paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx)
        setMenuEntryPathValue(paths, ctx.pathPickerEditIdx, chosenVal)
        _.config_parse.setMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx, paths)
        ctx.entryIdx = ctx.pathPickerForEntryIdx
        ctx.state = ctx.pathPickerReturnState or (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
        ctx.pathPickerForEntryIdx = nil
        ctx.pathPickerEditIdx = nil
        ctx.pathPickerReturnState = nil
      elseif mode == "add" then
        local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or ctx.addPathKey
        _.config_parse.append(ctx.lines, key, chosenVal)
        ctx.state = "editor"
      elseif mode == "boot" then
        applyBootPathAndReturn(ctx, chosenVal)
      end
      ctx.pathPickerWildcardConfirm = nil
      ctx.pathPickerPendingPath = nil
      ctx.pathPickerWildcardMode = nil
      ctx.pathPickerBdmPrefix = nil
      ctx.pathPickerBdmMountpoint = nil
      if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
      if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
      ctx.pathList = nil
      ctx.pathBrowsePath = nil
      ctx.pfs0Mounted = nil
      ctx.pfs1Mounted = nil
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      applyAndExit(_.file_selector.toWildcard(val))
    elseif (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      applyAndExit(val)
    end
    return
  end
  if ctx.pathPickerSub == "device" then
    ensureBblCommandRows(ctx)
    if isConfigOpenTarget(ctx) and ctx.pathPickerLockedDevice and not ctx.pathPickerLockedDeviceStarted then
      ctx.pathPickerLockedDeviceStarted = true
      beginBrowseForDevice(ctx, ctx.pathPickerLockedDevice)
      if ctx.pathPickerSub ~= "device" then
        return
      end
    end
    -- Loading state: probe every ~200ms, 3s timeout; show splash only when waiting
    if ctx.pathPickerLoading then
      local load = ctx.pathPickerLoading
      local PROBE_INTERVAL_FRAMES = 12 -- ~200ms at 60fps
      local LOAD_TIMEOUT_FRAMES = 180  -- 3s at 60fps
      -- Draw splash first so it shows before any blocking loadModules()
      if not (ctx.pathPickerLoadingFrames and ctx.pathPickerLoadingFrames >= LOAD_TIMEOUT_FRAMES) then
        local msg = _.path_str.waiting_for_device_drivers
        local tw = _.common.calcTextWidth(_.font, msg, 1)
        local cx = _.common.centerX(_, tw)
        local cy = math.floor((_.MARGIN_Y + _.HINT_Y) / 2) - math.floor(_.LINE_H / 2)
        _.drawText(_.font, _.drawMode, cx, cy, 1, msg, _.WHITE)
      end
      _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7,
        _.path_str.circle_back_items, nil, _.DIM, _.w - 2 * _.MARGIN_X)
      ctx.pathPickerLoadingFrames = (ctx.pathPickerLoadingFrames or 0) + 1
      -- Load drivers on frame 2 so the first splash frame is presented before blocking (same for all HDD/BDM)
      if ctx.pathPickerLoadingFrames == 2 and not ctx.pathPickerModulesLoaded and load.deviceType and System and System.loadModules then
        System.loadModules(load.deviceType)
        ctx.pathPickerModulesLoaded = true
      end
      local mp = nil
      if load.staticHdd then
        if ctx.pathPickerLoadingFrames > 0 and ctx.pathPickerLoadingFrames % PROBE_INTERVAL_FRAMES == 0 then
          if _.common.isHddPresent and _.common.isHddPresent() then
            ctx.pathPickerLoading = nil
            ctx.pathPickerLoadingFrames = nil
            ctx.pathPickerModulesLoaded = nil
            ctx.pathPickerLoadedDeviceTypes = ctx.pathPickerLoadedDeviceTypes or {}
            ctx.pathPickerLoadedDeviceTypes["hdd"] = true
            ctx.pathPickerSub = "partitions"
            ctx.pathList = _.file_selector.getHddPartitions(0) or {}
            ctx.pathBrowsePath = "hdd0:"
            ctx.pathPickerSel = 1
            ctx.pathPickerScroll = 0
          end
        end
      else
        if ctx.pathPickerLoadingFrames > 0 and ctx.pathPickerLoadingFrames % PROBE_INTERVAL_FRAMES == 0 then
          mp = (System and System.getDeviceMountpoint) and System.getDeviceMountpoint(load.deviceId) or nil
        end
        if mp and mp ~= "" then
          ctx.pathPickerLoading = nil
          ctx.pathPickerLoadingFrames = nil
          ctx.pathPickerModulesLoaded = nil
          ctx.pathPickerLoadedDeviceTypes = ctx.pathPickerLoadedDeviceTypes or {}
          ctx.pathPickerLoadedDeviceTypes[load.deviceType] = true
          local mpNorm = (mp:sub(-1) == ":") and mp or (mp .. ":")
          ctx.pathPickerBdmMountpoint = mpNorm
          ctx.pathPickerBdmPrefix = _.file_selector.getBdmPathPrefix(load.deviceId)
          ctx.pathBrowsePath = (mp:sub(-1) == ":") and (mp .. "/") or mp
          ctx.pathList = listBrowseEntries(ctx, ctx.pathBrowsePath)
          ctx.pathPickerSub = "browse"
          ctx.pathPickerSel = 1
          ctx.pathPickerScroll = 0
        end
      end
      if ctx.pathPickerLoading and ctx.pathPickerLoadingFrames >= LOAD_TIMEOUT_FRAMES then
        local timeoutDevice = load.deviceId or (load.staticHdd and "hdd0") or load.deviceType or "device"
        ctx.pathPickerLoading = nil
        ctx.pathPickerLoadingFrames = nil
        ctx.pathPickerModulesLoaded = nil
        ctx.pathPickerLoadingTimeoutMsg = tostring(timeoutDevice)
      end
    else
      if ctx.pathPickerLoadingTimeoutMsg then
        local timeoutDevice = tostring(ctx.pathPickerLoadingTimeoutMsg)
        local msg = _.path_str.device_timeout
        if type(msg) == "string" and msg:find("%%DEVICE%%") then
          msg = msg:gsub("%%DEVICE%%", function() return timeoutDevice end)
        else
          msg = timeoutDevice .. " not found"
        end
        local tw = _.common.calcTextWidth(_.font, msg, _.FONT_SCALE)
        local cx = _.common.centerX(_, tw)
        local cy = math.floor((_.MARGIN_Y + _.HINT_Y) / 2) - math.floor(_.LINE_H / 2)
        _.drawText(_.font, _.drawMode, cx, cy, _.FONT_SCALE, msg, _.DIM)
      end
    end
    if not ctx.pathPickerLoadingTimeoutMsg and not ctx.pathPickerLoading then
      _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1,
        ctx.isAddPath and _.path_str.add_path_choose_device or _.path_str.choose_device, _.WHITE)
      if (ctx.pathPickerContext == "path_only" or ctx.pathPickerContext == "config_ini") and _.path_str.bbl_build_device_hint then
        local hint = _.path_str.bbl_build_device_hint
        hint = hint:gsub("PS%?BBL", getSelectedBblName(ctx))
        if _.common.truncateTextToWidth then
          hint = _.common.truncateTextToWidth(_.font, hint, _.w - (_.MARGIN_X * 2), 0.55)
        end
        _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(20), 0.55, hint, _.DIM)
      end
      if ctx.pathList and #ctx.pathList > 0 and not ctx.pathPickerLoading then
        local lockedConfigBrowse = isConfigOpenTarget(ctx) and ctx.pathPickerLockedDevice
        local includeManualEntry = not lockedConfigBrowse
        local manualOffset = includeManualEntry and 1 or 0
        local rawCount = #ctx.pathList + manualOffset
        local function deviceFromRawIndex(rawIdx)
          local devIdx = rawIdx - manualOffset
          if devIdx < 1 or devIdx > #ctx.pathList then return nil end
          return ctx.pathList[devIdx]
        end
        local otherStats = getOtherTargetPathStats(ctx)
        local targetIndex = tonumber(otherStats.targetIndex)
        local function isGreyed(e)
          if not e then return true end
          if targetIndex and targetIndex ~= 1 and isE1RestrictedPathForContext(ctx, e.name) then
            return true
          end
          if e.exclusive then return otherStats.count > 0 end
          if otherStats.firstExclusive then return true end
          return false
        end
        local function isSelectableRaw(rawIdx)
          if includeManualEntry and rawIdx == 1 then return true end
          local e = deviceFromRawIndex(rawIdx)
          return e ~= nil and not isGreyed(e)
        end
        local selectableRaw = {}
        local inactiveRaw = {}
        local inactiveHasE1Restricted = false
        for rawIdx = 1, rawCount do
          if isSelectableRaw(rawIdx) then
            selectableRaw[#selectableRaw + 1] = rawIdx
          else
            inactiveRaw[#inactiveRaw + 1] = rawIdx
            local e = deviceFromRawIndex(rawIdx)
            if targetIndex and targetIndex ~= 1 and e and isE1RestrictedPathForContext(ctx, e.name) then
              inactiveHasE1Restricted = true
            end
          end
        end
        local displayRows = {}
        for i = 1, #selectableRaw do
          displayRows[#displayRows + 1] = { kind = "entry", rawIdx = selectableRaw[i], selectable = true }
        end
        local showE1Divider = inactiveHasE1Restricted and (#inactiveRaw > 0)
        if showE1Divider then
          displayRows[#displayRows + 1] = { kind = "separator", selectable = false }
        end
        for i = 1, #inactiveRaw do
          displayRows[#displayRows + 1] = { kind = "entry", rawIdx = inactiveRaw[i], selectable = false }
        end
        local totalCount = #displayRows
        if ctx.pathPickerSel < 1 then ctx.pathPickerSel = 1 end
        if ctx.pathPickerSel > totalCount then ctx.pathPickerSel = totalCount end
        local function rawIndexFromDisplay(displayIdx)
          local row = displayRows[displayIdx]
          if not row or row.kind ~= "entry" then return nil end
          return row.rawIdx
        end
        local function isSelectableDisplay(displayIdx)
          local row = displayRows[displayIdx]
          return row and row.selectable == true
        end
        if not isSelectableDisplay(ctx.pathPickerSel) then
          local found = nil
          for idx = 1, totalCount do
            if isSelectableDisplay(idx) then
              found = idx
              break
            end
          end
          if not found then
            for idx = 1, totalCount do
              if rawIndexFromDisplay(idx) then
                found = idx
                break
              end
            end
          end
          ctx.pathPickerSel = found or 1
        end
        local selectedProgress = 0
        for idx = 1, ctx.pathPickerSel do
          if rawIndexFromDisplay(idx) then
            selectedProgress = selectedProgress + 1
          end
        end
        if selectedProgress < 1 then selectedProgress = 1 end
        _.drawText(_.font, _.drawMode, _.w - _.MARGIN_X - 56, _.MARGIN_Y, 0.9,
          selectedProgress .. " / " .. rawCount, _.DIM)
        local maxVis = _.MAX_VISIBLE_LIST
        if totalCount > maxVis then
          ctx.pathPickerScroll = ctx.pathPickerSel - math.floor(maxVis / 2)
          ctx.pathPickerScroll = math.max(0, math.min(ctx.pathPickerScroll, totalCount - maxVis))
        else
          ctx.pathPickerScroll = 0
        end
        local maxLabelW = (_.w or 640) - (_.MARGIN_X + 20) - _.MARGIN_X
        for i = 1, math.min(maxVis, totalCount - ctx.pathPickerScroll) do
          local displayIdx = ctx.pathPickerScroll + i
          local row = displayRows[displayIdx] or {}
          local listIdx = rawIndexFromDisplay(displayIdx)
          local displayName
          local greyed = false
          local e = nil
          if row.kind == "separator" then
            displayName = "-- Items below must be E1 --"
          else
            if includeManualEntry and listIdx == 1 then
              displayName = _.path_str.enter_path_manually
            else
              e = deviceFromRawIndex(listIdx)
              if e and e.special == "bbl_cmd" and ctx.fileType == "freemcboot_cnf" then
                displayName = e.name or e.desc or _.common_str.empty
              else
                displayName = e and (e.desc or e.name or _.common_str.empty) or _.common_str.empty
              end
              greyed = isGreyed(e)
            end
          end
          local y = _.MARGIN_Y + _.scaleY(50) + (i - 1) * _.LINE_H
          local isSelectedEntryRow = (row.kind == "entry") and isSelectableDisplay(displayIdx) and
              (displayIdx == ctx.pathPickerSel)
          local col = _.DIM
          if row.kind ~= "separator" then
            col = greyed and _.DIM or (isSelectedEntryRow and _.SELECTED_ENTRY or _.GRAY)
          end
          if _.common.fitListRowText then
            local rowStateKey = (row.kind == "separator") and "path_picker_device_sep" or
                ("path_picker_device_row_" .. tostring(listIdx))
            displayName = _.common.fitListRowText(ctx, rowStateKey, _.font, displayName,
              maxLabelW, _.FONT_SCALE, isSelectedEntryRow)
          elseif _.common.truncateTextToWidth then
            displayName = _.common.truncateTextToWidth(_.font, displayName or "", maxLabelW, _.FONT_SCALE)
          end
          _.drawListRow(_.MARGIN_X + 20, y, isSelectedEntryRow, displayName, col)
        end
        do
          local function getFmcbCommandHelper(entry)
            if not entry then return nil end
            local isFmcbPicker = (ctx.pathPickerContext == "fmcb_entry" or ctx.pathPickerContext == "fmcb_launch")
            local isFmcbPathOnly = (ctx.pathPickerContext == "path_only") and
                ((ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot"))
            if not (isFmcbPicker or isFmcbPathOnly) then return nil end
            local key = tostring(entry.name or ""):upper()
            local p = _.path_str or {}
            if key == "OSDSYS" then
              return p.fmcb_cmd_osdsys or "Boot hacked OSDSYS"
            elseif key == "OSDMENU" then
              return p.fmcb_cmd_osdmenu or "Boot hacked OSDSYS, enforce skip disc boot"
            elseif key == "FASTBOOT" then
              return p.fmcb_cmd_fastboot or "Boot PS2 Disc without logo"
            elseif key == "POWEROFF" then
              return p.fmcb_cmd_poweroff or "Shutdown the console: FMCB 1.966 only, else use POWEROFF.ELF"
            end
            return nil
          end

          local selectedHelper = nil
          local selectedRawIdx = rawIndexFromDisplay(ctx.pathPickerSel)
          if not (includeManualEntry and selectedRawIdx == 1) then
            local selectedEntry = selectedRawIdx and deviceFromRawIndex(selectedRawIdx) or nil
            selectedHelper = getFmcbCommandHelper(selectedEntry)
          end
          if selectedHelper and selectedHelper ~= "" then
            local hintTextScale = tonumber(_.common.PAD_HINT_TEXT_SCALE) or 0.75
            local hintDrawScale = (_.common.getHintLabelDrawScale and _.common.getHintLabelDrawScale(0.7)) or
                (0.7 * hintTextScale)
            local hintFont = (_.common.getHintFont and _.common.getHintFont(_.font, _.drawMode, hintTextScale)) or _.font
            local hintTextH = (_.common.getHintLabelTextHeight and _.common.getHintLabelTextHeight()) or nil
            local descMaxW = (_.w or 640) - (_.MARGIN_X * 2)
            if _.common.fitListRowText then
              selectedHelper = _.common.fitListRowText(ctx, "path_picker_device_helper", hintFont, selectedHelper,
                descMaxW, hintDrawScale, true, { holdStart = 55, stepFrames = 16, holdEnd = 85 })
            elseif _.common.truncateTextToWidth then
              selectedHelper = _.common.truncateTextToWidth(hintFont, selectedHelper, descMaxW, hintDrawScale)
            end
            local tw = _.common.calcTextWidth(hintFont, selectedHelper, hintDrawScale)
            local x = _.common.centerX(_, tw)
            local hintColor = (_.common.OPTION_HINT_COLOR or _.DIM)
            _.drawText(hintFont, _.drawMode, x, _.DESC_Y_BOTTOM, hintDrawScale, selectedHelper, hintColor, hintTextH)
          end
        end
        if (_.padEffective & _.PAD_UP) ~= 0 then
          local idx = ctx.pathPickerSel
          for _ = 1, totalCount do
            idx = idx - 1; if idx < 1 then idx = totalCount end
            if isSelectableDisplay(idx) then
              ctx.pathPickerSel = idx; break
            end
          end
        end
        if (_.padEffective & _.PAD_DOWN) ~= 0 then
          local idx = ctx.pathPickerSel
          for _ = 1, totalCount do
            idx = idx + 1; if idx > totalCount then idx = 1 end
            if isSelectableDisplay(idx) then
              ctx.pathPickerSel = idx; break
            end
          end
        end
        if (_.padEffective & _.PAD_CROSS) ~= 0 then
          local selectedRawIdx = rawIndexFromDisplay(ctx.pathPickerSel)
          if includeManualEntry and selectedRawIdx == 1 then
            ctx.textInputTitleIdMode = nil
            ctx.textInputPrompt = _.path_str.enter_path_prompt
            ctx.textInputValue = ""
            ctx.textInputMaxLen = 79
            ctx.textInputCallback = function(val)
              applyManualPath(ctx, val)
            end
            ctx.textInputReturnState = "path_picker"
            ctx.textInputGridSel = 1
            ctx.textInputCursor = 1
            ctx.textInputScroll = 1
            ctx.state = "text_input"
          else
            if not isSelectableDisplay(ctx.pathPickerSel) then
              -- Unselectable helper/inactive rows ignore Cross.
            else
              local e = selectedRawIdx and deviceFromRawIndex(selectedRawIdx) or nil
              if isGreyed(e) then
              showExclusivePathWarning(ctx, e and e.name)
              elseif e.special then
                local pathVal = e.name or ""
                if canUsePathSelection(ctx, pathVal) then
                  if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
                  if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
                  ctx.pathList = nil
                  ctx.pfs0Mounted = nil
                  ctx.pfs1Mounted = nil
                  if ctx.pathPickerBootKey and ctx.lines then
                    local bootKey = ctx.pathPickerBootKey
                    applyBootPathAndReturn(ctx, pathVal)
                    if e.noargs then _.config_parse.setBootArgs(ctx.lines, bootKey, {}) end
                  elseif applyBblHotkeyPathAndReturn(ctx, pathVal) then
                  elseif applyBblIrxPathAndReturn(ctx, pathVal) then
                  elseif ctx.pathPickerForEntryIdx then
                    local paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx)
                    setMenuEntryPathValue(paths, ctx.pathPickerEditIdx, pathVal)
                    _.config_parse.setMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx, paths)
                    if e.noargs then _.config_parse.setMenuEntryArgs(ctx.lines, ctx.pathPickerForEntryIdx, {}) end
                    ctx.entryIdx = ctx.pathPickerForEntryIdx
                    ctx.state = (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
                    ctx.pathPickerForEntryIdx = nil
                    ctx.pathPickerEditIdx = nil
                  elseif ctx.isAddPath then
                    local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or
                        ctx.addPathKey
                    _.config_parse.append(ctx.lines, key, pathVal)
                    ctx.state = "editor"
                  else
                    _.config_parse.set(ctx.lines, ctx.editKey or "", pathVal)
                    ctx.state = "editor"
                  end
                  ctx.configModified = true
                end
              else
                beginBrowseForDevice(ctx, e)
              end
            end
          end
        end
      else
        _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(60), _.FONT_SCALE, _.path_str.no_devices, _
          .GRAY)
      end
    end
    if ctx.pathPickerLoading then
    elseif ctx.pathPickerLoadingTimeoutMsg then
      _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.path_str.circle_back_items, nil, _.DIM,
        _.w - 2 * _.MARGIN_X)
    else
      _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.path_str.cross_select_circle_back_items, nil,
        _.DIM, _.w - 2 * _.MARGIN_X)
    end
    if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      if isConfigOpenTarget(ctx) and ctx.pathPickerLockedDevice then
        leaveLockedConfigBrowse(ctx)
        return
      end
      if ctx.pathPickerLoading or ctx.pathPickerLoadingTimeoutMsg then
        ctx.pathPickerLoading = nil
        ctx.pathPickerLoadingFrames = nil
        ctx.pathPickerModulesLoaded = nil
        ctx.pathPickerLoadingTimeoutMsg = nil
        ctx.pathList = _.file_selector.getDevices(ctx.pathPickerContext) or {}
      else
        if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
        if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
        if ctx.pathPickerBootKey then
          ctx.state = ctx.pathPickerReturnState or "editor"
          ctx.pathPickerBootKey = nil; ctx.pathPickerReturnState = nil
        elseif ctx.pathPickerBblHotkeyKey then
          ctx.state = ctx.pathPickerReturnState or "bbl_hotkey_entry"
          ctx.pathPickerBblHotkeyKey = nil
          ctx.pathPickerBblHotkeySlot = nil
          ctx.pathPickerBblHotkeyDisabled = nil
          ctx.pathPickerReturnState = nil
        elseif ctx.pathPickerBblIrxIdx then
          ctx.state = ctx.pathPickerReturnState or "bbl_irx_entries"
          ctx.pathPickerBblIrxIdx = nil
          ctx.pathPickerBblIrxDisabled = nil
          ctx.pathPickerReturnState = nil
          ctx.pathPickerFileExts = nil
        elseif ctx.pathPickerForEntryIdx then
          ctx.entryIdx = ctx.pathPickerForEntryIdx
          ctx.state = (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
          ctx.pathPickerForEntryIdx = nil; ctx.pathPickerEditIdx = nil
        elseif isConfigOpenTarget(ctx) then
          ctx.state = ctx.pathPickerReturnState or "select_config"
          ctx.pathPickerReturnState = nil
          clearConfigOpenPickerState(ctx)
        else
          ctx.state = "editor"
        end
        ctx.pathList = nil; ctx.pathBrowsePath = nil; ctx.pathPickerBdmPrefix = nil; ctx.pathPickerBdmMountpoint = nil
        ctx.pfs0Mounted = nil; ctx.pfs1Mounted = nil
      end
    end
  elseif ctx.pathPickerSub == "partitions" then
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.path_str.select_hdd_partition, _.WHITE)
    local parts = ctx.pathList or {}
    if ctx.pathPickerSel < 1 then ctx.pathPickerSel = 1 end
    if ctx.pathPickerSel > #parts then ctx.pathPickerSel = #parts end
    local maxVis = _.MAX_VISIBLE_LIST
    if #parts > maxVis then
      ctx.pathPickerScroll = ctx.pathPickerSel - math.floor(maxVis / 2)
      ctx.pathPickerScroll = math.max(0, math.min(ctx.pathPickerScroll, #parts - maxVis))
    else
      ctx.pathPickerScroll = 0
    end
    if #parts > 0 then
      _.drawText(_.font, _.drawMode, _.w - _.MARGIN_X - 56, _.MARGIN_Y, 0.9, ctx.pathPickerSel .. " / " .. #parts,
        _.DIM)
    end
    local maxLabelW = (_.w or 640) - (_.MARGIN_X + 20) - _.MARGIN_X
    for i = ctx.pathPickerScroll + 1, math.min(ctx.pathPickerScroll + maxVis, #parts) do
      local p = parts[i]
      if not p then break end
      local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.pathPickerScroll - 1) * _.LINE_H
      local col = (i == ctx.pathPickerSel) and _.SELECTED_ENTRY or _.GRAY
      local label = p.name or _.common_str.empty
      if _.common.fitListRowText then
        label = _.common.fitListRowText(ctx, "path_picker_part_row_" .. tostring(i), _.font, label, maxLabelW,
          _.FONT_SCALE, i == ctx.pathPickerSel)
      elseif _.common.truncateTextToWidth then
        label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
      end
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.pathPickerSel, label, col)
    end
    if #parts == 0 then
      _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(60), _.FONT_SCALE, _.path_str.no_partitions, _
        .DIM)
    end
    local hasFileFilter = type(ctx.pathPickerFileExts) == "table" and #ctx.pathPickerFileExts > 0
    local allowPatinfo = (not isConfigOpenTarget(ctx)) and (not hasFileFilter)
    local partHint = isConfigOpenTarget(ctx) and _.path_str.cross_open_circle_back_items or
        (allowPatinfo and (_.path_str.cross_open_square_patinfo_circle_back_items or _.path_str.cross_open_circle_back_items) or
          _.path_str.cross_open_circle_back_items)
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, partHint, nil, _.DIM, _.w - 2 * _.MARGIN_X)
    if (_.padEffective & _.PAD_UP) ~= 0 then
      ctx.pathPickerSel = ctx.pathPickerSel - 1; if ctx.pathPickerSel < 1 then ctx.pathPickerSel = #parts end
    end
    if (_.padEffective & _.PAD_DOWN) ~= 0 then
      ctx.pathPickerSel = ctx.pathPickerSel + 1; if ctx.pathPickerSel > #parts then ctx.pathPickerSel = 1 end
    end
    if (_.padEffective & _.PAD_LEFT) ~= 0 then
      ctx.pathPickerSel = math.max(1, ctx.pathPickerSel - maxVis)
    end
    if (_.padEffective & _.PAD_RIGHT) ~= 0 then
      ctx.pathPickerSel = math.min(#parts, ctx.pathPickerSel + maxVis)
    end
    if allowPatinfo and (_.padEffective & _.PAD_SQUARE) ~= 0 and #parts > 0 then
      local p = parts[ctx.pathPickerSel]
      if not p then p = {} end
      local partFull = p.full or ("hdd0:" .. (p.name or ""))
      local val = partFull .. ":PATINFO"
      if not canUsePathSelection(ctx, val) then
        return
      end
      if applyBootPathAndReturn(ctx, val) then
      elseif applyBblHotkeyPathAndReturn(ctx, val) then
      elseif applyBblIrxPathAndReturn(ctx, val) then
      elseif ctx.pathPickerForEntryIdx then
        local paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx)
        setMenuEntryPathValue(paths, ctx.pathPickerEditIdx, val)
        _.config_parse.setMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx, paths)
        ctx.entryIdx = ctx.pathPickerForEntryIdx
        ctx.state = (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
        ctx.pathPickerForEntryIdx = nil; ctx.pathPickerEditIdx = nil
      elseif ctx.isAddPath then
        local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or ctx.addPathKey
        _.config_parse.append(ctx.lines, key, val)
        ctx.state = "editor"
      else
        _.config_parse.set(ctx.lines, ctx.editKey, val); ctx.state = "editor"
      end
      ctx.configModified = true
      ctx.pathList = nil; ctx.pathBrowsePath = nil; ctx.pathPickerBdmPrefix = nil; ctx.pathPickerBdmMountpoint = nil
      ctx.pathPickerSub = "device"
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 and #parts > 0 then
      local p = parts[ctx.pathPickerSel]
      if not p then p = {} end
      ctx.pathPickerPartitionSel = ctx.pathPickerSel
      local partName = p.name or ""
      local partFull = p.full or ("hdd0:" .. partName)
      if partName == "__sysconf" then
        if System.fileXioMount then System.fileXioMount("pfs0:", partFull) end
        ctx.pfs0Mounted = partFull
        ctx.pathBrowsePath = "pfs0:/"
        ctx.pathList = listBrowseEntries(ctx, "pfs0:/")
        ctx.pathPickerSub = "browse"
        ctx.pathPickerSel = 1; ctx.pathPickerScroll = 0
      else
        if System.fileXioMount then System.fileXioMount("pfs1:", partFull) end
        ctx.pfs1Mounted = partFull
        ctx.pathBrowsePath = "pfs1:/"
        local ok, list = pcall(listBrowseEntries, ctx, "pfs1:/")
        ctx.pathList = (ok and list) and list or {}
        ctx.pathPickerSub = "browse"
        ctx.pathPickerSel = 1; ctx.pathPickerScroll = 0
      end
    end
    if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      if isConfigOpenTarget(ctx) and ctx.pathPickerLockedDevice then
        leaveLockedConfigBrowse(ctx)
        return
      end
      ctx.pathPickerSub = "device"
      ctx.pathList = _.file_selector.getDevices(ctx.pathPickerContext) or {}
      ctx.pathBrowsePath = nil
      local n = #(ctx.pathList or {})
      ctx.pathPickerSel = math.max(1, math.min(ctx.pathPickerDeviceSel or 1, n))
      ctx.pathPickerScroll = centeredScroll(ctx.pathPickerSel, n, _.MAX_VISIBLE_LIST)
    end
  else
    local headerPath = ctx.pathBrowsePath or ""
    local partPath = ctx.pfs1Mounted or ctx.pfs0Mounted
    if partPath then
      local display = pfsToPartitionPath(headerPath, partPath)
      if display then headerPath = display end
    end
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 0.9, headerPath, _.DIM)
    local show = ctx.pathList or {}
    if #show == 0 then
      ctx.pathPickerSel = 0
    else
      ctx.pathPickerSel = math.max(1, math.min(ctx.pathPickerSel, #show))
    end
    local maxVis = _.MAX_VISIBLE_LIST
    if #show > maxVis and ctx.pathPickerSel > 0 then
      ctx.pathPickerScroll = ctx.pathPickerSel - math.floor(maxVis / 2)
      ctx.pathPickerScroll = math.max(0, math.min(ctx.pathPickerScroll, #show - maxVis))
    elseif #show <= maxVis then
      ctx.pathPickerScroll = 0
    end
    if #show > 0 then
      _.drawText(_.font, _.drawMode, _.w - _.MARGIN_X - 56, _.MARGIN_Y, 0.9, ctx.pathPickerSel .. " / " .. #show,
        _.DIM)
    end
    local maxLabelW = (_.w or 640) - (_.MARGIN_X + 20) - _.MARGIN_X
    for i = ctx.pathPickerScroll + 1, math.min(ctx.pathPickerScroll + maxVis, #show) do
      local e = show[i]
      if not e then break end
      local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.pathPickerScroll - 1) * _.LINE_H
      local label = e.name or _.common_str.empty
      if e.directory and label ~= "" then label = label .. "/" end
      local col = (i == ctx.pathPickerSel) and _.SELECTED_ENTRY or _.GRAY
      if _.common.fitListRowText then
        label = _.common.fitListRowText(ctx, "path_picker_browse_row_" .. tostring(i), _.font, label, maxLabelW,
          _.FONT_SCALE, i == ctx.pathPickerSel)
      elseif _.common.truncateTextToWidth then
        label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
      end
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.pathPickerSel, label, col)
    end
    if #show == 0 then
      local noFilesLabel
      if hasIniFilter(ctx) then
        noFilesLabel = _.path_str.no_ini_files or "No INI files or folders"
      elseif hasIrxFilter(ctx) then
        noFilesLabel = _.path_str.no_irx_files or "No IRX files or folders"
      else
        noFilesLabel = _.path_str.no_elf_files
      end
      _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(55), _.FONT_SCALE, noFilesLabel, _.DIM)
    end
    local canCreateConfigIni = isConfigOpenTarget(ctx) and ctx.pathBrowsePath
    if not canCreateConfigIni then
      ctx.pathBrowseActionsOpen = nil
      ctx.pathBrowseActionsSel = nil
      ctx.pathBrowseActionsScroll = nil
    end
    local createIniLabel = "Create CONFIG.INI"
    if canCreateConfigIni and type(_.path_str.cross_select_create_circle_back_items) == "table" then
      for i = 1, #_.path_str.cross_select_create_circle_back_items do
        local item = _.path_str.cross_select_create_circle_back_items[i]
        local pad = tostring(item and item.pad or ""):lower()
        if item and (pad == "square" or pad == "select") and item.label and item.label ~= "" then
          createIniLabel = tostring(item.label)
          break
        end
      end
    end
    local browseHint = {
      { pad = "cross", label = (_.path_str.cross_select_file_items and _.path_str.cross_select_file_items[1] and _.path_str.cross_select_file_items[1].label) or "Select", row = 1 },
      { pad = canCreateConfigIni and "square" or "", label = canCreateConfigIni and (_.menu_str.actions_label or "Actions") or "", row = 1 },
      { pad = "circle", label = (_.path_str.cross_select_file_items and _.path_str.cross_select_file_items[2] and _.path_str.cross_select_file_items[2].label) or "Back", row = 1 },
    }
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, browseHint, nil, _.DIM, _.w - 2 * _.MARGIN_X)

    local function createConfigIniInBrowseDir()
      local dir = tostring(ctx.pathBrowsePath):gsub("/$", "")
      local val = dir .. "/CONFIG.INI"
      local partPath = ctx.pfs1Mounted or ctx.pfs0Mounted
      if partPath then
        val = pfsToPartitionPath(val, partPath) or val
      end
      return applyConfigOpenPathAndReturn(ctx, val) == true
    end

    if ctx.pathBrowseActionsOpen and canCreateConfigIni then
      if actions_menu.run(ctx, {
            openKey = "pathBrowseActionsOpen",
            selKey = "pathBrowseActionsSel",
            scrollKey = "pathBrowseActionsScroll",
            title = (_.menu_str.actions_title or "Actions"),
            rows = {
              { id = "create_ini", label = createIniLabel },
            },
            rowStateKeyPrefix = "path_browse_actions_row_",
            onSelect = function(row)
              if row.id == "create_ini" then
                createConfigIniInBrowseDir()
              end
            end,
          }) then
        return
      end
    end

    if canCreateConfigIni and (_.padEffective & _.PAD_SQUARE) ~= 0 then
      ctx.pathBrowseActionsOpen = true
      ctx.pathBrowseActionsSel = ctx.pathBrowseActionsSel or 1
      ctx.pathBrowseActionsScroll = ctx.pathBrowseActionsScroll or 0
      return
    end
    if #show > 0 then
      if (_.padEffective & _.PAD_UP) ~= 0 then
        ctx.pathPickerSel = ctx.pathPickerSel - 1; if ctx.pathPickerSel < 1 then ctx.pathPickerSel = #show end
      end
      if (_.padEffective & _.PAD_DOWN) ~= 0 then
        ctx.pathPickerSel = ctx.pathPickerSel + 1; if ctx.pathPickerSel > #show then ctx.pathPickerSel = 1 end
      end
      if (_.padEffective & _.PAD_LEFT) ~= 0 then
        ctx.pathPickerSel = math.max(1, ctx.pathPickerSel - maxVis)
      end
      if (_.padEffective & _.PAD_RIGHT) ~= 0 then
        ctx.pathPickerSel = math.min(#show, ctx.pathPickerSel + maxVis)
      end
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      local e = (ctx.pathPickerSel > 0 and ctx.pathPickerSel <= #show) and show[ctx.pathPickerSel] or nil
      if e then
        if e.directory then
          ctx.pathPickerBrowseSelStack = ctx.pathPickerBrowseSelStack or {}
          table.insert(ctx.pathPickerBrowseSelStack, ctx.pathPickerSel)
          ctx.pathBrowsePath = e.full
          ctx.pathList = listBrowseEntries(ctx, ctx.pathBrowsePath)
          ctx.pathPickerSel = 1
          ctx.pathPickerScroll = 0
        else
          local rawPath = e.full and e.full:gsub("/$", "") or e.full
          local partPath = ctx.pfs1Mounted or ctx.pfs0Mounted
          local val = (partPath and pfsToPartitionPath(rawPath, partPath)) or rawPath
          if ctx.pathPickerBdmPrefix and ctx.pathPickerBdmMountpoint and rawPath then
            local mp = ctx.pathPickerBdmMountpoint
            if rawPath == mp or rawPath:sub(1, #mp) == mp then
              local rest = rawPath:sub(#mp + 1):gsub("^/", "")
              val = ctx.pathPickerBdmPrefix .. ":" .. (rest ~= "" and "/" .. rest or "")
            end
          end
          if not canUsePathSelection(ctx, val) then
            return
          end
          local openedConfig = false
          if applyConfigOpenPathAndReturn(ctx, val) then
            openedConfig = true
          elseif _.file_selector.canWildcard and _.file_selector.canWildcard(val) then
            ctx.pathPickerPendingPath = val
            ctx.pathPickerWildcardConfirm = true
            if ctx.pathPickerBootKey then
              ctx.pathPickerWildcardMode = "boot"
            elseif ctx.pathPickerBblHotkeyKey then
              ctx.pathPickerWildcardMode = "bbl_hotkey"
            elseif ctx.pathPickerBblIrxIdx then
              ctx.pathPickerWildcardMode = "bbl_irx"
            elseif ctx.pathPickerForEntryIdx then
              ctx.pathPickerWildcardMode = "entry"
            elseif ctx.isAddPath then
              ctx.pathPickerWildcardMode = "add"
            else
              ctx.pathPickerWildcardMode = "single"
            end
          elseif applyBootPathAndReturn(ctx, val) then
          elseif applyBblHotkeyPathAndReturn(ctx, val) then
          elseif applyBblIrxPathAndReturn(ctx, val) then
          elseif ctx.pathPickerForEntryIdx then
            local paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx)
            setMenuEntryPathValue(paths, ctx.pathPickerEditIdx, val)
            _.config_parse.setMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx, paths)
            ctx.entryIdx = ctx.pathPickerForEntryIdx
            ctx.state = ctx.pathPickerReturnState or (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
            ctx.pathPickerForEntryIdx = nil
            ctx.pathPickerEditIdx = nil
            ctx.pathPickerReturnState = nil
          elseif ctx.isAddPath then
            local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or
                ctx.addPathKey
            _.config_parse.append(ctx.lines, key, val)
            ctx.state = "editor"
          else
            _.config_parse.set(ctx.lines, ctx.editKey, val)
            ctx.state = "editor"
          end
          if not openedConfig then
            ctx.configModified = true
            if not ctx.pathPickerWildcardConfirm then
              if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
              if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
              clearPickerTransient(ctx)
              ctx.pfs0Mounted = nil
              ctx.pfs1Mounted = nil
              clearConfigOpenPickerState(ctx)
            end
          end
        end
      end
    end
    if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      if ctx.pathBrowsePath then
        local norm = ctx.pathBrowsePath:gsub("/$", "")
        -- At partition root (pfs0 = __sysconf, pfs1 = other HDD partition): go back to partition list, not device
        if norm == "pfs1:" or norm == "pfs1" or norm == "pfs0:" or norm == "pfs0" then
          if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
          if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
          ctx.pfs0Mounted = nil; ctx.pfs1Mounted = nil
          ctx.pathPickerSub = "partitions"
          ctx.pathList = _.file_selector.getHddPartitions(0) or {}
          ctx.pathBrowsePath = "hdd0:"
          local n = #(ctx.pathList or {})
          ctx.pathPickerSel = math.max(1, math.min(ctx.pathPickerPartitionSel or 1, n))
          ctx.pathPickerScroll = centeredScroll(ctx.pathPickerSel, n, _.MAX_VISIBLE_LIST)
        else
          local up = ctx.pathBrowsePath:gsub("/$", ""):gsub("/[^/]+$", "")
          if up == ctx.pathBrowsePath:gsub("/$", "") then
            if isConfigOpenTarget(ctx) and ctx.pathPickerLockedDevice then
              leaveLockedConfigBrowse(ctx)
              return
            end
            ctx.pathPickerSub = "device"
            ctx.pathPickerBrowseSelStack = nil
            ctx.pathPickerBdmPrefix = nil
            ctx.pathPickerBdmMountpoint = nil
            ctx.pathList = _.file_selector.getDevices(ctx.pathPickerContext) or {}
            ctx.pathBrowsePath = nil
            local n = #(ctx.pathList or {})
            ctx.pathPickerSel = math.max(1, math.min(ctx.pathPickerDeviceSel or 1, n))
            ctx.pathPickerScroll = centeredScroll(ctx.pathPickerSel, n, _.MAX_VISIBLE_LIST)
          else
            ctx.pathBrowsePath = (up:sub(-1) == ":") and (up .. "/") or up
            ctx.pathList = listBrowseEntries(ctx, ctx.pathBrowsePath)
            local stack = ctx.pathPickerBrowseSelStack or {}
            ctx.pathPickerSel = math.max(1, math.min(table.remove(stack) or 1, #(ctx.pathList or {})))
            ctx.pathPickerBrowseSelStack = #stack > 0 and stack or nil
            ctx.pathPickerScroll = centeredScroll(ctx.pathPickerSel, #(ctx.pathList or {}), _.MAX_VISIBLE_LIST)
          end
        end
      else
        -- No path (e.g. unresolved device or empty): go back to device list, not editor
        if isConfigOpenTarget(ctx) and ctx.pathPickerLockedDevice then
          leaveLockedConfigBrowse(ctx)
          return
        end
        ctx.pathPickerSub = "device"
        ctx.pathPickerBrowseSelStack = nil
        ctx.pathPickerBdmPrefix = nil
        ctx.pathPickerBdmMountpoint = nil
        ctx.pathList = _.file_selector.getDevices(ctx.pathPickerContext) or {}
        ctx.pathBrowsePath = nil
        local n = #(ctx.pathList or {})
        ctx.pathPickerSel = math.max(1, math.min(ctx.pathPickerDeviceSel or 1, n))
        ctx.pathPickerScroll = centeredScroll(ctx.pathPickerSel, n, _.MAX_VISIBLE_LIST)
      end
    end
  end
end

return { run = run }
