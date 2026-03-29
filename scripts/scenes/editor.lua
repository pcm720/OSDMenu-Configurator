--[[ Editor state: config option list and category list (OSDMENU). ]]

local actions_menu = dofile("scripts/scenes/actions_menu.lua")

local function formatTimerSeconds(msText, unitSingular, unitPlural)
  local ms = tonumber(msText or "")
  if not ms then return msText end
  local singular = unitSingular or "second"
  local plural = unitPlural or "seconds"
  local sec = math.max(0, math.floor((ms + 500) / 1000))
  local unit = (sec == 1) and singular or plural
  local secText = string.format("%3d", sec)
  return secText .. " " .. unit
end

local function formatArgCount(n)
  local count = tonumber(n) or 0
  if count == 1 then return "(1 arg)" end
  return "(" .. tostring(count) .. " args)"
end

local function getOsdmbrHotkeyPadName(key)
  if key == "boot_start" then return "start" end
  if key == "boot_triangle" then return "triangle" end
  if key == "boot_circle" then return "circle" end
  if key == "boot_cross" then return "cross" end
  if key == "boot_square" then return "square" end
  return nil
end

local function getCategoryOptSel(ctx, categoryIdx)
  if not categoryIdx or categoryIdx < 1 then return 1 end
  local byFile = ctx.editorCategoryOptSelByFile
  if type(byFile) ~= "table" then return 1 end
  local fileKey = ctx.fileType or "__none__"
  local byCategory = byFile[fileKey]
  if type(byCategory) ~= "table" then return 1 end
  local sel = byCategory[categoryIdx]
  if type(sel) ~= "number" then return 1 end
  return math.max(1, math.floor(sel))
end

local function setCategoryOptSel(ctx, categoryIdx, sel)
  if not categoryIdx or categoryIdx < 1 then return end
  if type(ctx.editorCategoryOptSelByFile) ~= "table" then
    ctx.editorCategoryOptSelByFile = {}
  end
  local fileKey = ctx.fileType or "__none__"
  if type(ctx.editorCategoryOptSelByFile[fileKey]) ~= "table" then
    ctx.editorCategoryOptSelByFile[fileKey] = {}
  end
  ctx.editorCategoryOptSelByFile[fileKey][categoryIdx] = math.max(1, math.floor(tonumber(sel) or 1))
end

local function getEditorBackState(ctx)
  local context = ctx and ctx.context or nil
  local fileType = ctx and ctx.fileType or nil
  if context == "ps2bbl" or context == "psxbbl" then
    return "select_config"
  end
  if context == "osdmenu" or context == "freemcboot" then
    if fileType == "osdmenu_cnf" or fileType == "osdgsm_cnf" or fileType == "freemcboot_cnf" then
      local common = ctx and ctx._ and ctx._.common or nil
      local slots = (common and common.getPresentMcSlots and common.getPresentMcSlots()) or {}
      if type(slots) == "table" and #slots > 1 then
        return "choose_mc"
      end
      return "main"
    end
  end
  return "main"
end

local OSD_VISUAL_COORD_KEYS = {
  OSDSYS_menu_x = true,
  OSDSYS_menu_y = true,
  OSDSYS_enter_x = true,
  OSDSYS_enter_y = true,
  OSDSYS_version_x = true,
  OSDSYS_version_y = true,
}

-- OSDMenu patcher defaults from thirdparty/OSDMenu/patcher/src/settings.c (initConfig).
local OSD_VISUAL_PATCHED_DEFAULTS = {
  OSDSYS_menu_x = "320",
  OSDSYS_menu_y = "110",
  OSDSYS_enter_x = "30",
  OSDSYS_enter_y = "-1",
  OSDSYS_version_x = "-1",
  OSDSYS_version_y = "-1",
}

-- Original PS2 OSDSYS look from thirdparty/OSDMenu/patcher/README.md and patches_fmcb.c comments.
local OSD_VISUAL_PS2_DEFAULTS = {
  OSDSYS_menu_x = "430",
  OSDSYS_menu_y = "110",
  OSDSYS_enter_x = "-1",
  OSDSYS_enter_y = "-1",
  OSDSYS_version_x = "-1",
  OSDSYS_version_y = "-1",
}

local function isOsdVisualCoordKey(key)
  local k = tostring(key or "")
  return OSD_VISUAL_COORD_KEYS[k] == true
end

local function applyOsdVisualPreset(ctx, _, preset)
  if not (ctx and _ and ctx.lines and preset) then return end
  for key, value in pairs(preset) do
    _.config_parse.set(ctx.lines, key, tostring(value or ""))
  end
  if _.common and _.common.refreshConfigModified then
    _.common.refreshConfigModified(ctx)
  else
    ctx.configModified = true
  end
end

local function valuesEquivalent(a, b)
  local sa = tostring(a or "")
  local sb = tostring(b or "")
  if sa == sb then return true end
  local na = tonumber(sa)
  local nb = tonumber(sb)
  if na ~= nil and nb ~= nil then
    return na == nb
  end
  return false
end

local function optionMatchesDefault(ctx, _, key, def, getValue)
  if not (ctx and _ and key) then return false end
  if def == nil then return false end
  local getter = getValue or _.config_parse.get
  local cur = getter(ctx.lines, key)
  local effective = (cur ~= nil) and cur or def
  return valuesEquivalent(effective, def)
end

local function osdVisualGroupMatchesPreset(ctx, _, preset, getValue)
  if not (ctx and _ and preset) then return false end
  local getter = getValue or _.config_parse.get
  for key, _present in pairs(OSD_VISUAL_COORD_KEYS) do
    local def = preset[key]
    local cur = getter(ctx.lines, key)
    local effective = (cur ~= nil) and cur or def
    if not valuesEquivalent(effective, def) then
      return false
    end
  end
  return true
end

local function makeFrameParseCache(_, lines)
  local getCache = {}
  local getWithCommentCache = {}
  local getMultiCache = {}
  local getBootPathsCache = {}
  local getBblSlotCache = {}
  local isBootKeyDisabledCache = {}

  local function cacheKeyForSlot(keyId, slot)
    return tostring(keyId or "") .. ":" .. tostring(slot or "")
  end

  return {
    get = function(_ignored, key)
      if key == nil then return nil end
      if getCache[key] == nil then
        getCache[key] = { _.config_parse.get(lines, key) }
      end
      return getCache[key][1]
    end,
    getWithComment = function(_ignored, key)
      if key == nil then return nil, nil end
      if getWithCommentCache[key] == nil then
        getWithCommentCache[key] = { _.config_parse.getWithComment(lines, key) }
      end
      return getWithCommentCache[key][1], getWithCommentCache[key][2]
    end,
    getMulti = function(_ignored, key)
      if key == nil then return {} end
      if getMultiCache[key] == nil then
        getMultiCache[key] = _.config_parse.getMulti(lines, key)
      end
      return getMultiCache[key]
    end,
    getBootPaths = function(_ignored, key)
      if key == nil then return {} end
      if getBootPathsCache[key] == nil then
        getBootPathsCache[key] = _.config_parse.getBootPaths(lines, key)
      end
      return getBootPathsCache[key]
    end,
    getBblHotkeySlot = function(_ignored, keyId, slot)
      if keyId == nil or slot == nil then return nil end
      local ck = cacheKeyForSlot(keyId, slot)
      if getBblSlotCache[ck] == nil then
        getBblSlotCache[ck] = _.config_parse.getBblHotkeySlot(lines, keyId, slot)
      end
      return getBblSlotCache[ck]
    end,
    isBootKeyDisabled = function(_ignored, key)
      if key == nil then return false end
      if isBootKeyDisabledCache[key] == nil then
        isBootKeyDisabledCache[key] = (_.config_parse.isBootKeyDisabled and _.config_parse.isBootKeyDisabled(lines, key)) and
            true or false
      end
      return isBootKeyDisabledCache[key]
    end,
  }
end

local function getEditorParseCache(ctx, _)
  local sceneEpoch = ctx._sceneEpoch or 0
  local inputEpoch = ctx._inputEpoch or 0
  local cache = ctx.editorFrameParseCache
  if cache and cache.linesRef == ctx.lines and cache.sceneEpoch == sceneEpoch and cache.inputEpoch == inputEpoch then
    return cache
  end
  cache = makeFrameParseCache(_, ctx.lines or {})
  cache.linesRef = ctx.lines
  cache.sceneEpoch = sceneEpoch
  cache.inputEpoch = inputEpoch
  ctx.editorFrameParseCache = cache
  return cache
end

local function removeHintPad(items, padName)
  local out = {}
  local target = tostring(padName or ""):lower()
  for i = 1, #(items or {}) do
    local item = items[i]
    if tostring(item and item.pad or ""):lower() ~= target then
      out[#out + 1] = item
    end
  end
  return out
end

local function prettifyBblGlobalLabel(ctx, o, label)
  if not (ctx and o and label) then return label end
  if (ctx.fileType ~= "ps2bbl_ini" and ctx.fileType ~= "psxbbl_ini") then
    return label
  end
  if ctx.editorCategoryIdx ~= 1 then
    return label
  end
  return tostring(label):gsub("_", " ")
end

local function withStartHintVisibility(items, showStart)
  if showStart then return items end
  local out = {}
  for _, item in ipairs(items or {}) do
    if item.pad ~= "start" then
      out[#out + 1] = item
    else
      out[#out + 1] = { pad = "", label = "", row = item.row }
    end
  end
  return out
end

local function isTimerDigitEditKey(key)
  return key == "KEY_READ_WAIT_TIME" or key == "pad_delay"
end

local function clampNumber(n, minV, maxV)
  if n < minV then return minV end
  if n > maxV then return maxV end
  return n
end

local function formatTimerDigitValue(ms)
  local seconds = math.max(0, math.floor(((tonumber(ms) or 0) + 500) / 1000))
  return string.format("%03d", seconds)
end

local function startTimerDigitEdit(ctx, _, opt)
  if not (ctx and _ and opt and opt.key) then return end
  local raw = _.config_parse.get(ctx.lines, opt.key) or opt.default or "0"
  local num = tonumber(raw)
  if not num then num = tonumber(opt.default or "0") end
  if not num then num = 0 end
  local minV = tonumber(opt.min) or 0
  local maxV = tonumber(opt.max) or 999900
  num = clampNumber(math.floor((num + 500) / 1000) * 1000, minV, maxV)
  local label = (_.strings.options and _.strings.options[opt.key] and _.strings.options[opt.key].label) or opt.label or opt.key
  ctx.timerDigitEdit = {
    key = opt.key,
    label = label,
    value = num,
    min = minV,
    max = maxV,
    digit = 1, -- 1=hundreds sec, 2=tens, 3=ones
  }
end

local function drawTimerDigitInlineValue(_, edit, x, y, scale)
  local valueText = formatTimerDigitValue(edit.value)
  local selectedCharIndex = edit.digit
  local cursorX = x
  for i = 1, #valueText do
    local ch = valueText:sub(i, i)
    local col = (i == selectedCharIndex) and (_.SELECTED_ENTRY or _.WHITE) or _.WHITE
    _.drawText(_.font, _.drawMode, cursorX, y, scale, ch, col)
    local cw = (_.common.calcTextWidth and _.common.calcTextWidth(_.font, ch, scale)) or 10
    cursorX = cursorX + cw
  end
  local secondsLabel = (_.common_str and _.common_str.seconds) or "seconds"
  if secondsLabel ~= "" then
    _.drawText(_.font, _.drawMode, cursorX, y, scale, " " .. tostring(secondsLabel), _.WHITE)
  end
end

local function runTimerDigitInlineInput(ctx, _)
  local edit = ctx.timerDigitEdit
  if not edit then return false end

  if (_.padEffective & _.PAD_LEFT) ~= 0 then
    edit.digit = edit.digit - 1
    if edit.digit < 1 then edit.digit = 3 end
  end
  if (_.padEffective & _.PAD_RIGHT) ~= 0 then
    edit.digit = edit.digit + 1
    if edit.digit > 3 then edit.digit = 1 end
  end

  local weightByDigit = { 100000, 10000, 1000 }
  local weight = weightByDigit[edit.digit] or 1000
  if (_.padEffective & _.PAD_UP) ~= 0 then
    edit.value = clampNumber(edit.value + weight, edit.min, edit.max)
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    edit.value = clampNumber(edit.value - weight, edit.min, edit.max)
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    _.config_parse.set(ctx.lines, edit.key, tostring(edit.value))
    ctx.configModified = true
    ctx.timerDigitEdit = nil
  elseif (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.timerDigitEdit = nil
  end

  return true
end

local function resolveIntBounds(opt, currentNum)
  local minV = tonumber(opt and opt.min)
  local maxV = tonumber(opt and opt.max)
  if minV == nil then minV = 0 end
  if maxV == nil then maxV = 9999 end

  if opt and opt.min == nil and opt.max == nil then
    local key = tostring(opt.key or "")
    if key == "OSDSYS_enter_x" or key == "OSDSYS_enter_y" or key == "OSDSYS_version_x" or key == "OSDSYS_version_y" then
      minV, maxV = -999, 999
    elseif key:match("^OSDSYS_.*_x$") then
      maxV = 639
    elseif key:match("^OSDSYS_.*_y$") then
      maxV = 447
    elseif key:match("num_displayed") then
      minV, maxV = 1, 30
    end
  end

  local defNum = tonumber(opt and opt.default or nil)
  if defNum and defNum < minV then minV = defNum end
  if currentNum and currentNum < minV then minV = currentNum end
  if maxV < minV then maxV = minV end
  return minV, maxV
end

local function intDigitCountForRange(minV, maxV)
  local maxAbs = math.max(math.abs(math.floor(minV or 0)), math.abs(math.floor(maxV or 0)), 0)
  local digits = #tostring(maxAbs)
  if digits < 1 then digits = 1 end
  return digits
end

local function formatIntDigitValue(edit)
  local n = tonumber(edit.value) or 0
  n = math.floor(n)
  local digits = math.max(1, tonumber(edit.digits) or 1)
  local absText = string.format("%0" .. tostring(digits) .. "d", math.abs(n))
  if edit.showSign then
    return ((n < 0) and "-" or " ") .. absText
  end
  return absText
end

local function startIntDigitEdit(ctx, _, opt)
  if not (ctx and _ and opt and opt.key) then return end
  local raw = _.config_parse.get(ctx.lines, opt.key) or opt.default or "0"
  local num = tonumber(raw)
  if not num then num = tonumber(opt.default or "0") end
  if not num then num = 0 end
  if num >= 0 then
    num = math.floor(num + 0.5)
  else
    num = math.ceil(num - 0.5)
  end
  local minV, maxV = resolveIntBounds(opt, num)
  num = clampNumber(num, minV, maxV)
  local digits = intDigitCountForRange(minV, maxV)
  ctx.intDigitEdit = {
    key = opt.key,
    value = num,
    min = minV,
    max = maxV,
    digit = 1, -- 1=highest place, N=ones
    digits = digits,
    showSign = (minV < 0),
  }
end

local function drawIntDigitInlineValue(_, edit, x, y, scale)
  local valueText = formatIntDigitValue(edit)
  local selectedCharIndex = edit.digit
  if edit.showSign then selectedCharIndex = selectedCharIndex + 1 end
  local cursorX = x
  for i = 1, #valueText do
    local ch = valueText:sub(i, i)
    local isSign = edit.showSign and (i == 1)
    local col = isSign and _.DIM or _.WHITE
    if i == selectedCharIndex then
      col = _.SELECTED_ENTRY or _.WHITE
    end
    _.drawText(_.font, _.drawMode, cursorX, y, scale, ch, col)
    local cw = (_.common.calcTextWidth and _.common.calcTextWidth(_.font, ch, scale)) or 10
    cursorX = cursorX + cw
  end
end

local function runIntDigitInlineInput(ctx, _)
  local edit = ctx.intDigitEdit
  if not edit then return false end

  if (_.padEffective & _.PAD_LEFT) ~= 0 then
    edit.digit = edit.digit - 1
    if edit.digit < 1 then edit.digit = edit.digits end
  end
  if (_.padEffective & _.PAD_RIGHT) ~= 0 then
    edit.digit = edit.digit + 1
    if edit.digit > edit.digits then edit.digit = 1 end
  end

  local place = edit.digits - edit.digit
  local weight = 10 ^ place
  if (_.padEffective & _.PAD_UP) ~= 0 then
    edit.value = clampNumber((tonumber(edit.value) or 0) + weight, edit.min, edit.max)
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    edit.value = clampNumber((tonumber(edit.value) or 0) - weight, edit.min, edit.max)
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    _.config_parse.set(ctx.lines, edit.key, tostring(math.floor(tonumber(edit.value) or 0)))
    ctx.configModified = true
    ctx.intDigitEdit = nil
  elseif (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.intDigitEdit = nil
  end

  return true
end

local function startInlineColorEdit(ctx, _, opt)
  if not (ctx and _ and opt and opt.key) then return end
  local r, g, b, a = _.parseColor(_.config_parse.get(ctx.lines, opt.key) or opt.default)
  ctx.colorInlineEdit = {
    key = opt.key,
    values = { r, g, b, a },
    orig = { r, g, b, a },
    channel = 1,
    digit = 1, -- 1=hundreds, 2=tens, 3=ones
    highlightX = nil,
    highlightW = nil,
  }
end

local function drawInlineColorEditValue(_, edit, x, y, scale)
  if not edit then return end
  local labels = { "R", "G", "B", "A" }
  local calcTextWidth = _.common and _.common.calcTextWidth
  local function textWidth(s)
    if calcTextWidth then
      return calcTextWidth(_.font, s, scale)
    end
    return #tostring(s or "") * 8
  end

  local blockGap = textWidth(" ")
  local channelBlocks = {}
  local cursorX = x

  for ch = 1, 4 do
    local val = clampNumber(tonumber(edit.values[ch]) or 0, 0, 255)
    local valStr = string.format("%03d", val)
    local blockText = labels[ch] .. valStr
    local blockW = textWidth(blockText)
    channelBlocks[ch] = { x = cursorX, w = blockW, valStr = valStr }
    cursorX = cursorX + blockW
    if ch < 4 then
      cursorX = cursorX + blockGap
    end
  end

  local activeBlock = channelBlocks[edit.channel]
  if activeBlock then
    local padX = math.max(1, math.floor((_.scaleX and _.scaleX(2)) or 2))
    local padY = math.max(1, math.floor((_.scaleY and _.scaleY(2)) or 2))
    local fontPixelH = (_.common and _.common.FT_PIXEL_H) or 18
    local blockH = math.max(8, math.floor(fontPixelH * (scale or 1) + 0.5))
    local targetX = activeBlock.x - padX
    local targetW = activeBlock.w + padX * 2

    -- Slide highlight to the currently selected channel for smoother channel changes.
    if type(edit.highlightX) ~= "number" then edit.highlightX = targetX end
    if type(edit.highlightW) ~= "number" then edit.highlightW = targetW end
    local function smoothStep(cur, target, factor)
      local delta = target - cur
      if math.abs(delta) < 0.6 then return target end
      return cur + (delta * factor)
    end
    edit.highlightX = smoothStep(edit.highlightX, targetX, 0.45)
    edit.highlightW = smoothStep(edit.highlightW, targetW, 0.45)

    local underlay = _.Color.new(96, 96, 96, 110)
    _.Graphics.drawRect(math.floor(edit.highlightX + 0.5), y - padY, math.floor(edit.highlightW + 0.5), blockH + padY * 2,
      underlay)
  end

  cursorX = x
  for ch = 1, 4 do
    local prefix = labels[ch]
    local prefixCol = _.WHITE
    if ch == 1 then
      prefixCol = _.Color.new(230, 70, 70, 128)
    elseif ch == 2 then
      prefixCol = _.Color.new(80, 200, 80, 128)
    elseif ch == 3 then
      prefixCol = _.Color.new(60, 80, 170, 128)
    elseif ch == 4 then
      prefixCol = _.Color.new(210, 210, 210, 255)
    end
    _.drawText(_.font, _.drawMode, cursorX, y, scale, prefix, prefixCol)
    cursorX = cursorX + textWidth(prefix)

    local valStr = channelBlocks[ch] and channelBlocks[ch].valStr or "000"
    for i = 1, #valStr do
      local digit = valStr:sub(i, i)
      local col = (ch == edit.channel and i == edit.digit) and (_.SELECTED_ENTRY or _.WHITE) or _.WHITE
      _.drawText(_.font, _.drawMode, cursorX, y, scale, digit, col)
      cursorX = cursorX + textWidth(digit)
    end
    if ch < 4 then
      _.drawText(_.font, _.drawMode, cursorX, y, scale, " ", _.WHITE)
      cursorX = cursorX + blockGap
    end
  end
end

local function runInlineColorEditInput(ctx, _)
  local edit = ctx.colorInlineEdit
  if not edit then return false end

  local function toLinear(ch, digit)
    return ((ch - 1) * 3) + digit
  end

  local function fromLinear(idx)
    local safe = idx
    if safe < 1 then safe = 1 end
    if safe > 12 then safe = 12 end
    local ch = math.floor((safe - 1) / 3) + 1
    local digit = ((safe - 1) % 3) + 1
    return ch, digit
  end

  if (_.padEffective & _.PAD_LEFT) ~= 0 then
    local idx = toLinear(edit.channel, edit.digit) - 1
    if idx < 1 then idx = 12 end
    edit.channel, edit.digit = fromLinear(idx)
  end
  if (_.padEffective & _.PAD_RIGHT) ~= 0 then
    local idx = toLinear(edit.channel, edit.digit) + 1
    if idx > 12 then idx = 1 end
    edit.channel, edit.digit = fromLinear(idx)
  end
  if (_.padEffective & _.PAD_SQUARE) ~= 0 then
    edit.channel = edit.channel + 1
    if edit.channel > 4 then edit.channel = 1 end
  end

  local weightByDigit = { 100, 10, 1 }
  local weight = weightByDigit[edit.digit] or 1
  if (_.padEffective & _.PAD_UP) ~= 0 then
    edit.values[edit.channel] = clampNumber((tonumber(edit.values[edit.channel]) or 0) + weight, 0, 255)
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    edit.values[edit.channel] = clampNumber((tonumber(edit.values[edit.channel]) or 0) - weight, 0, 255)
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    _.config_parse.set(ctx.lines, edit.key, _.formatColor(edit.values[1], edit.values[2], edit.values[3], edit.values[4]))
    ctx.configModified = true
    ctx.colorInlineEdit = nil
  elseif (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.colorInlineEdit = nil
  end

  return true
end

local function drawLeaveSavePromptModal(_)
  local prompt = tostring((_ and _.editor_str and _.editor_str.leave_save_prompt) or "Save changes before leaving?")
  local padX = 24
  local padY = 14
  local lineH = _.LINE_H or 22
  local maxTextW = math.max(80, (_.w or 640) - (((_.MARGIN_X or 40) * 2) + (padX * 2)))
  if _.common and _.common.truncateTextToWidth then
    prompt = _.common.truncateTextToWidth(_.font, prompt, maxTextW, 1)
  end
  local textW = (_.common and _.common.calcTextWidth and _.common.calcTextWidth(_.font, prompt, 1)) or (#prompt * 14)
  local boxW = textW + (padX * 2)
  local boxH = lineH + (padY * 2)
  local boxX = math.floor(((_.w or 640) - boxW) / 2)
  local boxY = math.floor(((_.h or 448) - boxH) / 2)
  local bg = (_.Color and _.Color.new and _.Color.new(40, 40, 48, 110)) or _.DIM
  if _.Graphics and _.Graphics.drawRect then
    _.Graphics.drawRect(boxX, boxY, boxW, boxH, bg)
  end
  local textX = boxX + math.floor((boxW - textW) / 2)
  local textY = boxY + math.floor((boxH - lineH) / 2)
  _.drawText(_.font, _.drawMode, textX, textY, 1, prompt, _.WHITE)
end

local function run(ctx)
  local _ = ctx._
  local frameParse = getEditorParseCache(ctx, _)
  local cachedGet = frameParse.get
  local cachedGetWithComment = frameParse.getWithComment
  local cachedGetMulti = frameParse.getMulti
  local cachedGetBootPaths = frameParse.getBootPaths
  local cachedGetBblHotkeySlot = frameParse.getBblHotkeySlot
  local cachedIsBootKeyDisabled = frameParse.isBootKeyDisabled
  -- Leave-save prompt when going back to file select with unsaved changes
  if ctx.editorLeavePrompt then
    drawLeaveSavePromptModal(_)
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.editor_str.leave_save_hint_items, nil, _.DIM,
      _.w - 2 * _.MARGIN_X)
    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      ctx.editorLeavePrompt = nil
      ctx.saveSplash = nil
      local locations = _.getLocations(ctx.context, ctx.fileType, ctx.chosenMcSlot)
      if ctx.fileType == "osdmenu_cnf" and #locations >= 2 then
        ctx.returnToSelectConfigAfterSave = getEditorBackState(ctx)
        ctx.saveChoices = locations
        ctx.saveSel = ctx.saveSel or 1
        ctx.state = "choose_save"
      else
        local path = ctx.currentPath or (locations and locations[1])
        if path and path ~= "" then
          ctx.lines = _.config_parse.regenerateForSave(ctx.lines, ctx.fileType, _.config_options)
          local parentDir = path:match("^(.+)/[^/]+$")
          local ok, err = _.common.saveConfig(ctx, path, ctx.lines, parentDir)
              if ok then
                ctx.currentPath = path
                ctx.saveSplash = { kind = "saved", detail = path or "", framesLeft = 60 }
                ctx.configModified = false
                ctx.returnStateAfterSaveFlash = getEditorBackState(ctx)
                ctx.returnToSelectConfigAfterSaveFlash = true
              else
            ctx.saveSplash = {
              kind = "failed",
              detail = _.common.localizeParseError(err, _.editor_str) or
                  _.editor_str.save_failed,
              framesLeft = 120
            }
          end
        else
          ctx.saveSplash = { kind = "failed", detail = _.editor_str.no_save_location, framesLeft = 120 }
        end
      end
    elseif (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
      ctx.editorLeavePrompt = nil
      ctx.state = getEditorBackState(ctx)
      ctx.currentPath = nil
      ctx.lines = nil
      ctx.optList = nil
      ctx.editorCategoryIdx = 0
      ctx.saveSplash = nil
    elseif (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      ctx.editorLeavePrompt = nil
    end
    return
  end

  local pathStr = ctx.currentPath or ""
  if #pathStr > 56 then
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 0.8, pathStr:sub(1, 56), _.DIM)
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(18), 0.8, pathStr:sub(57), _.DIM)
  else
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 0.8, pathStr, _.DIM)
  end

  if ctx.saveSplash and ctx.saveSplash.framesLeft > 0 and ctx.saveSplash.kind == "saved" and ctx.returnToSelectConfigAfterSaveFlash then
    return
  end

  local isCategorizedFile = (ctx.fileType == "osdmenu_cnf" or ctx.fileType == "freemcboot_cnf" or
      ctx.fileType == "ps2bbl_ini" or ctx.fileType == "psxbbl_ini")
  local categories = {}
  if ctx.fileType == "osdmenu_cnf" then
    categories = _.config_options.osdmenu_cnf_categories or {}
  elseif ctx.fileType == "freemcboot_cnf" then
    categories = _.config_options.freemcboot_cnf_categories or _.config_options.osdmenu_cnf_categories or {}
  elseif ctx.fileType == "ps2bbl_ini" then
    categories = _.config_options.ps2bbl_ini_categories or {}
  elseif ctx.fileType == "psxbbl_ini" then
    categories = _.config_options.psxbbl_ini_categories or {}
  end

  if isCategorizedFile and ctx.editorCategoryIdx == 0 then
    local cats = categories
    local maxVis = _.MAX_VISIBLE
    ctx.optSel = _.common.clampListSelection(ctx.optSel or 1, #cats)
    ctx.optScroll = _.common.centeredListScroll(ctx.optSel, #cats, maxVis)
    local maxCatLabelW = (_.w or 640) - (_.MARGIN_X + 16) - (_.MARGIN_X + 8)
    for i = ctx.optScroll + 1, math.min(ctx.optScroll + maxVis, #cats) do
      local cat = cats[i]
      local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.optScroll - 1) * _.ROW_H
      local col = (i == ctx.optSel) and _.SELECTED_ENTRY or _.WHITE
      local catLabel = cat.name or _.common_str.empty
      if ctx.fileType == "osdmenu_cnf" then
        catLabel = (_.strings.categories and _.strings.categories[i]) or catLabel
      elseif ctx.fileType == "freemcboot_cnf" then
        catLabel = (_.strings.categories_freemcboot and _.strings.categories_freemcboot[i]) or catLabel
      end
      if _.common.fitListRowText then
        catLabel = _.common.fitListRowText(ctx, "editor_cat_row_" .. tostring(i), _.font, catLabel, maxCatLabelW,
          _.FONT_SCALE, i == ctx.optSel)
      elseif _.common.truncateTextToWidth then
        catLabel = _.common.truncateTextToWidth(_.font, catLabel, maxCatLabelW, _.FONT_SCALE)
      end
      _.drawListRow(_.MARGIN_X + 16, y, i == ctx.optSel,
        catLabel, col)
    end
    local categoryHints = withStartHintVisibility(_.editor_str.cross_open_circle_back_items, ctx.configModified == true)
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, categoryHints, nil,
      _.DIM, _.w - 2 * _.MARGIN_X)
    if (_.padEffective & _.PAD_UP) ~= 0 then
      ctx.optSel = _.common.wrapListSelection(ctx.optSel, #cats, -1)
    end
    if (_.padEffective & _.PAD_DOWN) ~= 0 then
      ctx.optSel = _.common.wrapListSelection(ctx.optSel, #cats, 1)
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 and #cats > 0 then
      local cat = cats[ctx.optSel]
      local actionKey = cat and #(cat.options or {}) == 1 and cat.options[1].key or nil
      if actionKey == "_menu_entries" then
        ctx.state = "menu_entries"
        ctx.entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
        ctx.entrySel = ctx.entrySel or 1
        ctx.entryScroll = ctx.entryScroll or 0
      elseif actionKey == "_bbl_irx_entries" then
        ctx.bblIrxSel = ctx.bblIrxSel or 1
        ctx.bblIrxScroll = ctx.bblIrxScroll or 0
        ctx.state = "bbl_irx_entries"
      elseif actionKey == "_bbl_hotkeys" then
        ctx.bblHotkeySel = ctx.bblHotkeySel or 1
        ctx.state = "bbl_hotkeys"
      else
        local selectedCategoryIdx = ctx.optSel
        ctx.editorCategoryIdx = selectedCategoryIdx
        local rawOpts = cat.options or {}
        -- DKWDRV custom path not applicable for HOSDMenu (no MC path)
        if ctx.context == "hosdmenu" and ctx.fileType == "osdmenu_cnf" then
          ctx.optList = {}
          for _, o in ipairs(rawOpts) do
            if o.key ~= "path_DKWDRV_ELF" then ctx.optList[#ctx.optList + 1] = o end
          end
        else
          ctx.optList = rawOpts
        end
        local rememberedSel = getCategoryOptSel(ctx, selectedCategoryIdx)
        if #ctx.optList > 0 then
          ctx.optSel = math.max(1, math.min(rememberedSel, #ctx.optList))
        else
          ctx.optSel = 1
        end
        ctx.optScroll = ctx.optScroll or 0
      end
    end
    if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      if ctx.configModified then
        ctx.editorLeavePrompt = true
      else
        ctx.state = getEditorBackState(ctx); ctx.currentPath = nil; ctx.lines = nil; ctx.optList = nil; ctx.editorCategoryIdx = 0
      end
    end
  elseif ctx.optList and #ctx.optList > 0 then
    local startY = _.MARGIN_Y + _.scaleY(58)
    local maxVis = _.MAX_VISIBLE
    ctx.optSel = _.common.clampListSelection(ctx.optSel or 1, #ctx.optList)
    ctx.optScroll = _.common.centeredListScroll(ctx.optSel, #ctx.optList, maxVis)
    for i = ctx.optScroll + 1, math.min(ctx.optScroll + maxVis, #ctx.optList) do
      local o = ctx.optList[i]
      local y = startY + (i - ctx.optScroll - 1) * _.ROW_H
      local col = (i == ctx.optSel) and _.SELECTED_ENTRY or _.WHITE
      local bootKeyDisabled = false
      local lab = (_.strings.options and _.strings.options[o.key] and _.strings.options[o.key].label) or o.label
      lab = prettifyBblGlobalLabel(ctx, o, lab)
      local valDisplay
      if o.optType == "header" or o.optType == "action" then
        valDisplay = ""
      elseif o.optType == "color" then
        valDisplay = nil
      elseif o.optType == "bool" then
        local v = cachedGet(ctx.lines, o.key) or o.default or "0"
        valDisplay = (v == "1") and _.common_str.on or _.common_str.off
      elseif o.optType == "boot_paths" then
        bootKeyDisabled = cachedIsBootKeyDisabled(ctx.lines, o.key)
        local paths = cachedGetBootPaths(ctx.lines, o.key)
        local count = paths and #paths or 0
        if ctx.fileType == "osdmbr_cnf" then
          if count <= 0 then
            valDisplay = _.common_str.not_set
          elseif count == 1 then
            valDisplay = "(1 path)"
          else
            valDisplay = "(" .. tostring(count) .. " paths)"
          end
        else
          if count <= 0 then
            valDisplay = ""
          else
            valDisplay = count .. _.menu_str.path_s
          end
        end
      elseif o.optType == "bbl_slot" then
        local keyId = o.bblKeyId or "AUTO"
        local slotIdx = tonumber(o.bblEntrySlot)
        local slot = (slotIdx and _.config_parse.getBblHotkeySlot) and cachedGetBblHotkeySlot(ctx.lines, keyId, slotIdx) or
            nil
        if slot and (slot.used or slot.pathExists) then
          local p = _.common_str.not_set
          if slot.path ~= "" then
            p = slot.path
          elseif slot.pathExists then
            p = _.common_str.empty
          end
          if ctx.fileType == "freemcboot_cnf" then
            valDisplay = p
          else
            valDisplay = p .. " " .. formatArgCount(slot.argCount)
          end
        else
          valDisplay = _.common_str.not_set
        end
      elseif o.optType == "enum" then
        local raw = cachedGet(ctx.lines, o.key) or o.default or ""
        if raw ~= "" and o.enumDisplayMap and o.enumDisplayMap[raw] then
          valDisplay = o.enumDisplayMap[raw]
        else
          valDisplay = raw
        end
      else
        local multi = cachedGetMulti(ctx.lines, o.key)
        if multi and #multi > 1 then
          valDisplay = #multi .. " paths"
        else
          valDisplay = cachedGet(ctx.lines, o.key) or o.default or ""
        end
      end
      if (o.key == "KEY_READ_WAIT_TIME" or o.key == "pad_delay") and valDisplay and valDisplay ~= "" then
        local commonStrings = _.common_str or {}
        local unitSingular = commonStrings.second or "second"
        local unitPlural = commonStrings.seconds or "seconds"
        valDisplay = formatTimerSeconds(valDisplay, unitSingular, unitPlural)
      end
      local inlineAutoRow = false
      local bootHotkeyPad = nil
      local bootHotkeyIcon = nil
      local bootHotkeyIconW, bootHotkeyIconH, bootHotkeyIconGap = 0, 0, 0
      if ctx.fileType == "osdmbr_cnf" and o.optType == "boot_paths" then
        bootHotkeyPad = getOsdmbrHotkeyPadName(o.key)
        if bootHotkeyPad then
          bootHotkeyIcon = _.common.getPadIcon and _.common.getPadIcon(bootHotkeyPad) or nil
          if bootHotkeyIcon then
            local baseIconW = _.common.PAD_ICON_W or 26
            local baseIconH = _.common.PAD_ICON_H or 26
            local textH = (_.common and _.common.FT_PIXEL_H) or 18
            bootHotkeyIconH = math.min(baseIconH, textH)
            bootHotkeyIconW = math.max(1, math.floor((baseIconW * bootHotkeyIconH) / baseIconH + 0.5))
            bootHotkeyIconGap = 8
          end
        end
      end
      if bootHotkeyIcon then
        lab = (_.menu_str.launch_key_label or "Launch Key")
      end
      if o.key == "NAME_AUTO" then
        inlineAutoRow = true
        local nameVal = cachedGet(ctx.lines, o.key) or o.default or ""
        local nameDisp = (nameVal ~= "" and nameVal) or _.common_str.empty
        lab = (_.menu_str.name or "Name: ") .. nameDisp
        valDisplay = ""
      elseif ctx.fileType == "freemcboot_cnf" and o.key and o.key:match("^ESR_Path_E%d+$") then
        inlineAutoRow = true
        local pathVal, pathCommented = nil, nil
        if _.config_parse.getWithComment then
          pathVal, pathCommented = cachedGetWithComment(ctx.lines, o.key)
        end
        if pathVal == nil then
          pathVal = ""
        end
        local pathDisp = (pathVal ~= "" and pathVal) or _.common_str.not_set
        lab = "  " .. pathDisp
        if ctx.editorEsrPathGrab and i == ctx.optSel then
          lab = "[" .. (_.menu_str.grabbed_tag or "Move") .. "] " .. lab
        end
        if pathCommented then
          col = (i == ctx.optSel) and (_.SELECTED_ENTRY_DIM or _.SELECTED_ENTRY) or (_.DIM_ENTRY or _.DIM)
        end
        valDisplay = ""
      elseif o.optType == "bbl_slot" and (o.bblKeyId == "AUTO" or (o.key and o.key:match("^_auto_e%d+$"))) then
        inlineAutoRow = true
        local slotIdx = tonumber(o.bblEntrySlot) or 0
        local slot = _.config_parse.getBblHotkeySlot and cachedGetBblHotkeySlot(ctx.lines, "AUTO", slotIdx) or nil
        local pathDisp = _.common_str.not_set
        if slot and slot.path and slot.path ~= "" then
          pathDisp = slot.path
        elseif slot and slot.pathExists then
          pathDisp = _.common_str.empty
        end
        if ctx.fileType == "freemcboot_cnf" then
          lab = pathDisp
        else
          local argCount = (slot and slot.argCount) or 0
          lab = pathDisp .. " " .. formatArgCount(argCount)
        end
        if ctx.editorAutoSlotGrab and i == ctx.optSel then
          lab = "[" .. (_.menu_str.grabbed_tag or "Move") .. "] " .. lab
        end
        if slot and (slot.used or slot.pathExists) and slot.disabled then
          col = (i == ctx.optSel) and (_.SELECTED_ENTRY_DIM or _.SELECTED_ENTRY) or (_.DIM_ENTRY or _.DIM)
        end
        valDisplay = ""
      end
      if o.optType == "boot_paths" and bootKeyDisabled then
        col = (i == ctx.optSel) and (_.SELECTED_ENTRY_DIM or _.SELECTED_ENTRY) or (_.DIM_ENTRY or _.DIM)
      end
      if inlineAutoRow then
        local maxInlineW = (_.w or 640) - (_.MARGIN_X + 16) - (_.MARGIN_X + 8)
        if _.common.fitListRowText then
          lab = _.common.fitListRowText(ctx, "editor_autoboot_row_" .. tostring(i), _.font, lab, maxInlineW, _.FONT_SCALE,
            i == ctx.optSel)
        elseif _.common.truncateTextToWidth then
          lab = _.common.truncateTextToWidth(_.font, lab, maxInlineW, _.FONT_SCALE)
        end
      elseif bootHotkeyIcon then
        local rowTextX = (_.MARGIN_X + 16) + bootHotkeyIconW + bootHotkeyIconGap
        local maxInlineW = (_.w or 640) - rowTextX - (_.MARGIN_X + 8)
        if _.common.fitListRowText then
          lab = _.common.fitListRowText(ctx, "editor_boot_hotkey_row_" .. tostring(i), _.font, lab, maxInlineW, _.FONT_SCALE,
            i == ctx.optSel)
        elseif _.common.truncateTextToWidth then
          lab = _.common.truncateTextToWidth(_.font, lab, maxInlineW, _.FONT_SCALE)
        end
      else
        local valueColX = _.VALUE_X or 360
        local maxInlineW = valueColX - (_.MARGIN_X + 16) - 14
        if valDisplay == nil then
          maxInlineW = (_.w or 640) - (_.MARGIN_X + 16) - (_.MARGIN_X + 8)
        end
        if _.common.fitListRowText then
          lab = _.common.fitListRowText(ctx, "editor_opt_row_" .. tostring(i), _.font, lab, maxInlineW, _.FONT_SCALE,
            i == ctx.optSel)
        elseif _.common.truncateTextToWidth then
          lab = _.common.truncateTextToWidth(_.font, lab, maxInlineW, _.FONT_SCALE)
        end
      end
      if bootHotkeyIcon then
        local rowX = _.MARGIN_X + 16
        local iconY = y + math.floor(((_.LINE_H or bootHotkeyIconH) - bootHotkeyIconH) / 2)
        if _.Graphics.drawScaleImage then
          _.Graphics.drawScaleImage(bootHotkeyIcon, rowX, iconY, bootHotkeyIconW, bootHotkeyIconH)
        else
          _.Graphics.drawImage(bootHotkeyIcon, rowX, iconY)
        end
        _.drawText(_.font, _.drawMode, rowX + bootHotkeyIconW + bootHotkeyIconGap, y, _.FONT_SCALE, lab, col)
      else
        _.drawListRow(_.MARGIN_X + 16, y, i == ctx.optSel, lab, col)
      end
      local timerInlineEdit = (i == ctx.optSel) and ctx.timerDigitEdit and ctx.timerDigitEdit.key == o.key
      local intInlineEdit = (i == ctx.optSel) and ctx.intDigitEdit and ctx.intDigitEdit.key == o.key
      local colorInlineEdit = (i == ctx.optSel) and ctx.colorInlineEdit and ctx.colorInlineEdit.key == o.key

      if (not inlineAutoRow) and valDisplay == "" and (o.optType == "path" or o.optType == "boot_paths" or o.optType == "text" or o.optType == "enum") then
        valDisplay = _.common_str.not_set
      end
      if timerInlineEdit then
        drawTimerDigitInlineValue(_, ctx.timerDigitEdit, _.VALUE_X, y, _.FONT_SCALE)
      elseif intInlineEdit then
        drawIntDigitInlineValue(_, ctx.intDigitEdit, _.VALUE_X, y, _.FONT_SCALE)
      elseif colorInlineEdit then
        local edit = ctx.colorInlineEdit
        local swatchColor = _.Color.new(edit.values[1], edit.values[2], edit.values[3], edit.values[4])
        _.Graphics.drawRect(_.VALUE_X, y, 28, _.scaleY(18), swatchColor)
        drawInlineColorEditValue(_, edit, _.VALUE_X + 34, y, _.FONT_SCALE)
      elseif valDisplay then
        if valDisplay ~= "" then
          local valCol = (valDisplay == _.common_str.off or valDisplay == _.common_str.not_set) and _.DIM or
              ((i == ctx.optSel) and _.WHITE or _.GRAY)
          local valueAreaWidth = (_.w or 640) - 72 - _.VALUE_X
          local drawVal
          if _.common.fitValueText then
            drawVal = _.common.fitValueText(ctx, "editor_value_row_" .. tostring(i), _.font, valDisplay, valueAreaWidth,
              _.FONT_SCALE, i == ctx.optSel, { holdStart = 50, stepFrames = 18, holdEnd = 70 })
          elseif _.common.fitListRowText then
            drawVal = _.common.fitListRowText(ctx, "editor_value_row_" .. tostring(i), _.font, valDisplay, valueAreaWidth,
              _.FONT_SCALE, i == ctx.optSel, { holdStart = 50, stepFrames = 18, holdEnd = 70 })
          elseif _.common.truncateTextToWidth then
            drawVal = (i == ctx.optSel) and valDisplay or
                _.common.truncateTextToWidth(_.font, valDisplay, valueAreaWidth, _.FONT_SCALE)
          else
            drawVal = valDisplay
          end
          _.drawText(_.font, _.drawMode, _.VALUE_X, y, _.FONT_SCALE, drawVal, valCol)
        end
      elseif o.optType == "color" then
        local r, g, b, a = _.parseColor(cachedGet(ctx.lines, o.key) or o.default)
        local swatchColor = _.Color.new(r, g, b, a)
        _.Graphics.drawRect(_.VALUE_X, y, 28, _.scaleY(18), swatchColor)
      end
    end
    local selOpt = ctx.optList[ctx.optSel]
    if selOpt then
      local descStr = (_.strings.options and _.strings.options[selOpt.key] and _.strings.options[selOpt.key].desc) or
          selOpt.desc or ""
      if ctx.colorInlineEdit and ctx.colorInlineEdit.key == selOpt.key then
        descStr = (_.editor_str.inline_color_edit_hint or "D-pad: Left/Right digit or channel, Up/Down change, Square channel")
      end
      if selOpt.key == "LOGO_DISPLAY" then
        local cur = cachedGet(ctx.lines, selOpt.key) or selOpt.default or ""
        local n = tonumber(cur) or 0
        descStr = (n >= 4) and "Display speed: SLOWER (4-5)" or "Display speed: FAST (0-3)"
      end
      if descStr ~= "" then
        local hintTextScale = tonumber(_.common.PAD_HINT_TEXT_SCALE) or 0.75
        local hintDrawScale = (_.common.getHintLabelDrawScale and _.common.getHintLabelDrawScale(0.7)) or (0.7 * hintTextScale)
        local hintFont = (_.common.getHintFont and _.common.getHintFont(_.font, _.drawMode, hintTextScale)) or _.font
        local hintTextH = (_.common.getHintLabelTextHeight and _.common.getHintLabelTextHeight()) or
            math.max(10, math.floor(((_.common.FT_PIXEL_H or 18) * hintTextScale) + 0.5))
        local hintColor = (_.common.OPTION_HINT_COLOR or _.HIGHLIGHT or _.WHITE)
        local descMaxW = (_.w or 640) - (_.MARGIN_X * 2)
        if _.common.fitListRowText then
          descStr = _.common.fitListRowText(ctx,
            "editor_desc_" .. tostring(selOpt.key or ""),
            hintFont,
            descStr,
            descMaxW,
            hintDrawScale,
            true,
            { holdStart = 55, stepFrames = 16, holdEnd = 85 })
        elseif _.common.truncateTextToWidth then
          descStr = _.common.truncateTextToWidth(hintFont, descStr, descMaxW, hintDrawScale)
        end
        local tw = _.common.calcTextWidth(hintFont, descStr, hintDrawScale)
        local x = _.common.centerX(_, tw)
        _.drawText(hintFont, _.drawMode, x, _.DESC_Y_BOTTOM, hintDrawScale, descStr, hintColor, hintTextH)
      end
    end
    local isAutoSlotRow = selOpt and selOpt.optType == "bbl_slot" and selOpt.bblKeyId == "AUTO" and selOpt.bblEntrySlot
    local autoSlotNum = isAutoSlotRow and tonumber(selOpt.bblEntrySlot) or nil
    local isEsrPathRow = selOpt and ctx.fileType == "freemcboot_cnf" and selOpt.key and selOpt.key:match("^ESR_Path_E%d+$")
    local esrSlotNum = isEsrPathRow and tonumber(selOpt.key:match("^ESR_Path_E(%d+)$")) or nil
    local isOsdVisualCoordRow = selOpt and
        (ctx.fileType == "osdmenu_cnf" or ctx.fileType == "freemcboot_cnf") and
        selOpt.optType == "int" and isOsdVisualCoordKey(selOpt.key)
    local function resetDefaultFn(key)
      local keyStr = tostring(key or "")
      if ctx.fileType == "freemcboot_cnf" then
        if _.config_options and _.config_options.getFreemcbootDefault then
          local v = _.config_options.getFreemcbootDefault(keyStr)
          if v ~= nil then return v end
        end
      elseif ctx.fileType == "osdmenu_cnf" then
        if _.config_options and _.config_options.getOsdmenuDefault then
          local v = _.config_options.getOsdmenuDefault(keyStr)
          if v ~= nil then return v end
        end
      end
      if selOpt and selOpt.key == keyStr and selOpt.default ~= nil then
        return selOpt.default
      end
      return nil
    end
    local hintItems = _.common.buildEditorHintItems(selOpt, _.editor_str.hint_edit_items,
      resetDefaultFn,
      { left = _.common_str.hint_prev, right = _.common_str.hint_next })
    local canResetFromTriangle = false
    if selOpt and selOpt.key and selOpt.key:sub(1, 1) ~= "_" and selOpt.optType ~= "header" then
      if isOsdVisualCoordRow then
        canResetFromTriangle = not osdVisualGroupMatchesPreset(ctx, _, OSD_VISUAL_PATCHED_DEFAULTS, cachedGet)
      else
        local def = resetDefaultFn and resetDefaultFn(selOpt.key)
        if def ~= nil then
          canResetFromTriangle = not optionMatchesDefault(ctx, _, selOpt.key, def, cachedGet)
        end
      end
    end
    if not canResetFromTriangle then
      hintItems = removeHintPad(hintItems, "triangle")
    end
    if selOpt and selOpt.optType == "header" then
      hintItems = removeHintPad(hintItems, "cross")
    end
    local isFmcbAuto = (ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot")
    local maxAutoSlots = isFmcbAuto and ((_.config_options and _.config_options.FMCB_BBL_MAX_ENTRIES) or 3) or
        ((_.config_parse.getBblMaxEntries and _.config_parse.getBblMaxEntries()) or 10)
    local autoSlotData = (isAutoSlotRow and autoSlotNum and _.config_parse.getBblHotkeySlot) and
        cachedGetBblHotkeySlot(ctx.lines, "AUTO", autoSlotNum) or nil

    local function esrKey(slot)
      return "ESR_Path_E" .. tostring(slot or "")
    end

    local function getEsrSlot(slot)
      local key = esrKey(slot)
      local value, commented = nil, nil
      if _.config_parse.getWithComment then
        value, commented = _.config_parse.getWithComment(ctx.lines, key)
      end
      return {
        key = key,
        value = value or "",
        present = (value ~= nil),
        disabled = commented and true or false
      }
    end

    local function setEsrSlot(slot, value, disabled)
      local key = esrKey(slot)
      _.config_parse.set(ctx.lines, key, value or "")
      for _, entry in ipairs(ctx.lines or {}) do
        if entry.key and entry.key == key then
          entry.comment = disabled and true or nil
          break
        end
      end
    end

    local function getEsrSlots()
      local out = {}
      for s = 1, 3 do
        out[s] = getEsrSlot(s)
      end
      return out
    end

    local function applyEsrSlots(slots)
      for s = 1, 3 do
        local row = slots[s] or {}
        setEsrSlot(s, row.value or "", row.disabled and true or false)
      end
    end

    local function countFilledEsrSlots()
      local count = 0
      for s = 1, 3 do
        local slot = getEsrSlot(s)
        if slot.value ~= "" then count = count + 1 end
      end
      return count
    end

    local function focusEsrSlot(slot)
      local key = esrKey(slot)
      for idx, opt in ipairs(ctx.optList or {}) do
        if opt and opt.key == key then
          ctx.optSel = idx
          return
        end
      end
    end
    local function clearAutoMoveState()
      ctx.editorAutoSlotGrab = nil
      ctx.editorAutoSlotMoveSnapshot = nil
      ctx.editorAutoSlotMoveSel = nil
    end
    local function beginAutoMoveState()
      if ctx.editorAutoSlotGrab then return end
      if _.common and _.common.cloneConfigLines then
        ctx.editorAutoSlotMoveSnapshot = _.common.cloneConfigLines(ctx.lines)
      else
        ctx.editorAutoSlotMoveSnapshot = nil
      end
      ctx.editorAutoSlotMoveSel = ctx.optSel
      ctx.editorAutoSlotGrab = true
    end
    local function confirmAutoMoveState()
      clearAutoMoveState()
    end
    local function cancelAutoMoveState()
      if ctx.editorAutoSlotMoveSnapshot then
        if _.common and _.common.cloneConfigLines then
          ctx.lines = _.common.cloneConfigLines(ctx.editorAutoSlotMoveSnapshot)
        else
          ctx.lines = ctx.editorAutoSlotMoveSnapshot
        end
        ctx.optSel = _.common.clampListSelection(ctx.editorAutoSlotMoveSel or ctx.optSel, #ctx.optList)
        _.common.refreshConfigModified(ctx)
      end
      clearAutoMoveState()
    end
    if not isAutoSlotRow then
      confirmAutoMoveState()
      ctx.editorAutoSlotActionsOpen = nil
    end

    local function countUsedAutoSlots()
      local usedCount = 0
      for i = 1, maxAutoSlots do
        local s = _.config_parse.getBblHotkeySlot and cachedGetBblHotkeySlot(ctx.lines, "AUTO", i) or nil
        if s and s.used then usedCount = usedCount + 1 end
      end
      return usedCount
    end

    local function cloneBblArgs(args)
      local out = {}
      for i = 1, #(args or {}) do
        local a = args[i]
        if type(a) == "table" then
          out[#out + 1] = {
            value = a.value or "",
            disabled = a.disabled and true or false
          }
        else
          out[#out + 1] = {
            value = tostring(a or ""),
            disabled = false
          }
        end
      end
      return out
    end

    local function autoSlotHasPresence(slotData)
      if not slotData then return false end
      if slotData.pathExists then return true end
      if slotData.used then return true end
      local argCount = tonumber(slotData.argCount) or 0
      return argCount > 0
    end

    local function canRemoveAutoSlot(slotNum)
      if not slotNum then return false end
      local getSlot = _.config_parse.getBblHotkeySlot
      if not getSlot then return false end
      local current = getSlot(ctx.lines, "AUTO", slotNum)
      if autoSlotHasPresence(current) then return true end
      for i = slotNum + 1, maxAutoSlots do
        local s = getSlot(ctx.lines, "AUTO", i)
        if autoSlotHasPresence(s) then
          return true
        end
      end
      return false
    end

    local function moveAutoSlot(step)
      if not (isAutoSlotRow and autoSlotNum) then return end
      local dst = autoSlotNum + step
      if dst < 1 or dst > maxAutoSlots then return end
      _.config_parse.swapBblHotkeySlots(ctx.lines, "AUTO", autoSlotNum, dst)
      ctx.configModified = true
      if ctx.optSel > 1 then
        ctx.optSel = _.common.clampListSelection(ctx.optSel + step, #ctx.optList)
      end
    end

    local function insertAutoSlotBelow()
      if not (isAutoSlotRow and autoSlotNum) then return end
      local usedCount = countUsedAutoSlots()
      if usedCount >= maxAutoSlots then return end
      local newSlot = _.config_parse.insertBblHotkeySlotBelow(ctx.lines, "AUTO", autoSlotNum, maxAutoSlots)
      if newSlot then
        ctx.configModified = true
        confirmAutoMoveState()
        if newSlot < autoSlotNum and ctx.optSel > 1 then
          ctx.optSel = ctx.optSel + (newSlot - autoSlotNum)
        elseif newSlot > autoSlotNum and ctx.optSel < #ctx.optList then
          ctx.optSel = ctx.optSel + 1
        end
      end
    end

    local function removeAutoSlot()
      if not (isAutoSlotRow and autoSlotNum and canRemoveAutoSlot(autoSlotNum)) then return end
      local getSlot = _.config_parse.getBblHotkeySlot
      local packed = {}
      for i = 1, maxAutoSlots do
        if i ~= autoSlotNum then
          local s = getSlot and getSlot(ctx.lines, "AUTO", i) or nil
          if s and s.used then
            packed[#packed + 1] = {
              pathExists = s.pathExists and true or false,
              path = s.path or "",
              disabled = s.disabled and true or false,
              args = cloneBblArgs(s.args),
            }
          end
        end
      end
      for i = 1, maxAutoSlots do
        local row = packed[i]
        if row then
          _.config_parse.setBblHotkeyPath(ctx.lines, "AUTO", i, row.pathExists and row.path or nil, row.disabled)
          _.config_parse.setBblHotkeyArgs(ctx.lines, "AUTO", i, row.args)
        else
          _.config_parse.setBblHotkeyPath(ctx.lines, "AUTO", i, nil, false)
          _.config_parse.setBblHotkeyArgs(ctx.lines, "AUTO", i, {})
        end
      end
      ctx.configModified = true
      confirmAutoMoveState()
    end

    local function clearEsrMoveState()
      ctx.editorEsrPathGrab = nil
      ctx.editorEsrPathMoveSnapshot = nil
      ctx.editorEsrPathMoveSel = nil
    end

    local function beginEsrMoveState()
      if ctx.editorEsrPathGrab then return end
      if _.common and _.common.cloneConfigLines then
        ctx.editorEsrPathMoveSnapshot = _.common.cloneConfigLines(ctx.lines)
      else
        ctx.editorEsrPathMoveSnapshot = nil
      end
      ctx.editorEsrPathMoveSel = ctx.optSel
      ctx.editorEsrPathGrab = true
    end

    local function confirmEsrMoveState()
      clearEsrMoveState()
    end

    local function cancelEsrMoveState()
      if ctx.editorEsrPathMoveSnapshot then
        if _.common and _.common.cloneConfigLines then
          ctx.lines = _.common.cloneConfigLines(ctx.editorEsrPathMoveSnapshot)
        else
          ctx.lines = ctx.editorEsrPathMoveSnapshot
        end
        ctx.optSel = _.common.clampListSelection(ctx.editorEsrPathMoveSel or ctx.optSel, #ctx.optList)
        _.common.refreshConfigModified(ctx)
      end
      clearEsrMoveState()
    end

    if not isEsrPathRow then
      confirmEsrMoveState()
      ctx.editorEsrPathActionsOpen = nil
    end

    local function moveEsrSlot(step)
      if not (isEsrPathRow and esrSlotNum) then return end
      local dst = esrSlotNum + step
      if dst < 1 or dst > 3 then return end
      local slots = getEsrSlots()
      slots[esrSlotNum], slots[dst] = slots[dst], slots[esrSlotNum]
      applyEsrSlots(slots)
      ctx.configModified = true
      focusEsrSlot(dst)
    end

    local function insertEsrSlotBelow()
      if not (isEsrPathRow and esrSlotNum and esrSlotNum < 3) then return end
      if countFilledEsrSlots() >= 3 then return end
      local slots = getEsrSlots()
      for s = 3, esrSlotNum + 2, -1 do
        slots[s] = {
          value = slots[s - 1].value or "",
          disabled = slots[s - 1].disabled and true or false
        }
      end
      slots[esrSlotNum + 1] = { value = "", disabled = false }
      applyEsrSlots(slots)
      ctx.configModified = true
      confirmEsrMoveState()
      focusEsrSlot(esrSlotNum + 1)
    end

    local function removeEsrSlot()
      if not (isEsrPathRow and esrSlotNum) then return end
      if countFilledEsrSlots() <= 0 then return end
      local slots = getEsrSlots()
      for s = esrSlotNum, 2 do
        slots[s] = {
          value = slots[s + 1].value or "",
          disabled = slots[s + 1].disabled and true or false
        }
      end
      slots[3] = { value = "", disabled = false }
      applyEsrSlots(slots)
      ctx.configModified = true
      confirmEsrMoveState()
      focusEsrSlot(math.min(esrSlotNum, 3))
    end

    local function toggleEsrSlotDisabled()
      if not (isEsrPathRow and esrSlotNum) then return end
      local slot = getEsrSlot(esrSlotNum)
      setEsrSlot(esrSlotNum, slot.value or "", not slot.disabled)
      ctx.configModified = true
    end

    if isAutoSlotRow then
      hintItems = {
        {
          pad = "cross",
          label = ctx.editorAutoSlotGrab and (_.menu_str.confirm_label or "Confirm") or (_.menu_str.edit_label or "Edit"),
          row = 1
        },
        { pad = "square", label = (_.menu_str.actions_label or "Actions"), row = 1 },
        {
          pad = ctx.configModified and "start" or "",
          label = ctx.configModified and (_.menu_str.save_config_label or "Save") or "",
          row = 1
        },
        {
          pad = autoSlotHasPresence(autoSlotData) and "triangle" or "",
          label = autoSlotHasPresence(autoSlotData) and
              ((autoSlotData.disabled and (_.menu_str.enable_label or "Enable")) or
                (_.menu_str.disable_label or "Disable")) or "",
          row = 1
        },
        {
          pad = "circle",
          label = ctx.editorAutoSlotGrab and (_.menu_str.cancel_label or "Cancel") or (_.menu_str.back_label or "Back"),
          row = 1
        },
      }
    end

    if isEsrPathRow then
      local esrSel = getEsrSlot(esrSlotNum or 1)
      hintItems = {
        {
          pad = "cross",
          label = ctx.editorEsrPathGrab and (_.menu_str.confirm_label or "Confirm") or (_.menu_str.edit_label or "Edit"),
          row = 1
        },
        { pad = "square", label = (_.menu_str.actions_label or "Actions"), row = 1 },
        {
          pad = ctx.configModified and "start" or "",
          label = ctx.configModified and (_.menu_str.save_config_label or "Save") or "",
          row = 1
        },
        {
          pad = "triangle",
          label = esrSel.disabled and (_.menu_str.enable_label or "Enable") or (_.menu_str.disable_label or "Disable"),
          row = 1
        },
        {
          pad = "circle",
          label = ctx.editorEsrPathGrab and (_.menu_str.cancel_label or "Cancel") or (_.menu_str.back_label or "Back"),
          row = 1
        },
      }
    end

    if selOpt and ctx.timerDigitEdit and ctx.timerDigitEdit.key == selOpt.key then
      hintItems = {
        { pad = "cross", label = (_.menu_str.confirm_label or "Confirm"), row = 1 },
        { pad = "circle", label = (_.menu_str.cancel_label or "Cancel"), row = 1 },
      }
    elseif selOpt and ctx.intDigitEdit and ctx.intDigitEdit.key == selOpt.key then
      hintItems = {
        { pad = "cross", label = (_.menu_str.confirm_label or "Confirm"), row = 1 },
        { pad = "circle", label = (_.menu_str.cancel_label or "Cancel"), row = 1 },
      }
    elseif selOpt and ctx.colorInlineEdit and ctx.colorInlineEdit.key == selOpt.key then
      hintItems = {
        { pad = "cross", label = (_.menu_str.confirm_label or "Confirm"), row = 1 },
        { pad = "square", label = (_.menu_str.channel_label or "Channel"), row = 1 },
        { pad = "circle", label = (_.menu_str.cancel_label or "Cancel"), row = 1 },
      }
    end

    hintItems = withStartHintVisibility(hintItems, ctx.configModified == true)
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hintItems, nil, _.DIM, _.w - 2 * _.MARGIN_X)

    if runTimerDigitInlineInput(ctx, _) then
      return
    end
    if runIntDigitInlineInput(ctx, _) then
      return
    end
    if runInlineColorEditInput(ctx, _) then
      return
    end

    if ctx.editorOsdVisualRestoreOpen then
      if actions_menu.run(ctx, {
            openKey = "editorOsdVisualRestoreOpen",
            selKey = "editorOsdVisualRestoreSel",
            scrollKey = "editorOsdVisualRestoreScroll",
            anchorPad = "triangle",
            anchorLabel = (_.menu_str.reset_label or "Reset"),
            rows = {
              { id = "patched", label = "Patched Defaults" },
              { id = "ps2", label = "PS2 Defaults" },
            },
            rowStateKeyPrefix = "editor_osd_visual_restore_row_",
            onSelect = function(row)
              if row.id == "patched" then
                applyOsdVisualPreset(ctx, _, OSD_VISUAL_PATCHED_DEFAULTS)
              elseif row.id == "ps2" then
                applyOsdVisualPreset(ctx, _, OSD_VISUAL_PS2_DEFAULTS)
              end
            end,
          }) then
        return
      end
    end

    if ctx.editorAutoSlotActionsOpen and isAutoSlotRow then
      local actionRows = {}
      local usedAutoSlots = countUsedAutoSlots()
      local canMoveAutoSlots = usedAutoSlots > 1
      if not canMoveAutoSlots then
        confirmAutoMoveState()
      end
      if autoSlotData and autoSlotData.used and canMoveAutoSlots then
        actionRows[#actionRows + 1] = {
          id = "grab",
          label = ctx.editorAutoSlotGrab and (_.menu_str.cancel_move_label or "Cancel move") or
              (_.menu_str.grab_label or "Move")
        }
      end
      if canRemoveAutoSlot(autoSlotNum) then
        actionRows[#actionRows + 1] = { id = "remove", label = (_.menu_str.remove_label or "Remove") }
      end
      if usedAutoSlots < maxAutoSlots then
        actionRows[#actionRows + 1] = { id = "insert", label = (_.menu_str.insert_label or "Insert") }
      end
      if actions_menu.run(ctx, {
            openKey = "editorAutoSlotActionsOpen",
            selKey = "editorAutoSlotActionsSel",
            scrollKey = "editorAutoSlotActionsScroll",
            title = (_.menu_str.actions_title or "Actions"),
            rows = actionRows,
            rowStateKeyPrefix = "editor_auto_slot_actions_row_",
            onSelect = function(row)
              if row.id == "grab" then
                if ctx.editorAutoSlotGrab then
                  cancelAutoMoveState()
                else
                  beginAutoMoveState()
                end
              elseif row.id == "insert" then
                insertAutoSlotBelow()
              elseif row.id == "remove" then
                removeAutoSlot()
              end
            end,
          }) then
        return
      end
    end

    if ctx.editorEsrPathActionsOpen and isEsrPathRow then
      local actionRows = {}
      local filledEsrSlots = countFilledEsrSlots()
      local canMoveEsrSlots = filledEsrSlots > 1
      local canInsertEsrSlot = (esrSlotNum or 0) < 3 and filledEsrSlots < 3
      local canRemoveEsrSlot = filledEsrSlots > 0
      if not canMoveEsrSlots then
        confirmEsrMoveState()
      end
      if canMoveEsrSlots then
        actionRows[#actionRows + 1] = {
          id = "grab",
          label = ctx.editorEsrPathGrab and (_.menu_str.cancel_move_label or "Cancel move") or
              (_.menu_str.grab_label or "Move")
        }
      end
      if canInsertEsrSlot then
        actionRows[#actionRows + 1] = { id = "insert", label = (_.menu_str.insert_label or "Insert") }
      end
      if canRemoveEsrSlot then
        actionRows[#actionRows + 1] = { id = "remove", label = (_.menu_str.remove_label or "Remove") }
      end
      if actions_menu.run(ctx, {
            openKey = "editorEsrPathActionsOpen",
            selKey = "editorEsrPathActionsSel",
            scrollKey = "editorEsrPathActionsScroll",
            title = (_.menu_str.actions_title or "Actions"),
            rows = actionRows,
            rowStateKeyPrefix = "editor_esr_path_actions_row_",
            onSelect = function(row)
              if row.id == "grab" then
                if ctx.editorEsrPathGrab then
                  cancelEsrMoveState()
                else
                  beginEsrMoveState()
                end
              elseif row.id == "insert" then
                insertEsrSlotBelow()
              elseif row.id == "remove" then
                removeEsrSlot()
              end
            end,
          }) then
        return
      end
    end

    if (_.padEffective & _.PAD_UP) ~= 0 then
      if isAutoSlotRow and ctx.editorAutoSlotGrab then
        moveAutoSlot(-1)
      elseif isEsrPathRow and ctx.editorEsrPathGrab then
        moveEsrSlot(-1)
      else
        ctx.optSel = _.common.wrapListSelection(ctx.optSel, #ctx.optList, -1)
      end
    end
    if (_.padEffective & _.PAD_DOWN) ~= 0 then
      if isAutoSlotRow and ctx.editorAutoSlotGrab then
        moveAutoSlot(1)
      elseif isEsrPathRow and ctx.editorEsrPathGrab then
        moveEsrSlot(1)
      else
        ctx.optSel = _.common.wrapListSelection(ctx.optSel, #ctx.optList, 1)
      end
    end
    if (_.padEffective & (_.PAD_LEFT | _.PAD_RIGHT)) ~= 0 then
      local o = ctx.optList[ctx.optSel]
      if o.optType == "enum" and o.enumVals and #o.enumVals > 0 then
        local cur = _.config_parse.get(ctx.lines, o.key) or o.default or ""
        local allowUnset = (o.default == "")
        local idx = 0
        if cur == "" then
          idx = allowUnset and 0 or 1
        else
          for ei, v in ipairs(o.enumVals) do
            if v == cur then
              idx = ei; break
            end
          end
          if idx == 0 then idx = 1 end
        end
        if (_.padEffective & _.PAD_LEFT) ~= 0 then
          idx = idx - 1
          if idx < 0 then idx = #o.enumVals end
          if idx == 0 and not allowUnset then idx = #o.enumVals end
        end
        if (_.padEffective & _.PAD_RIGHT) ~= 0 then
          idx = idx + 1
          if idx > #o.enumVals then idx = (allowUnset and 0 or 1) end
        end
        _.config_parse.set(ctx.lines, o.key, (idx == 0) and "" or o.enumVals[idx])
        ctx.configModified = true
      elseif o.optType == "bool" then
        local cur = _.config_parse.get(ctx.lines, o.key) or o.default or "0"
        _.config_parse.set(ctx.lines, o.key, (cur == "1") and "0" or "1")
        ctx.configModified = true
      elseif o.optType == "int" then
        local cur = _.config_parse.get(ctx.lines, o.key) or o.default or "0"
        local num = tonumber(cur)
        if not num then num = tonumber(o.default or "0") end
        if not num then num = 0 end
        if num >= 0 then
          num = math.floor(num + 0.5)
        else
          num = math.ceil(num - 0.5)
        end
        local minV, maxV = resolveIntBounds(o, num)
        num = clampNumber(num, minV, maxV)
        local delta = 0
        if isTimerDigitEditKey(o.key) then
          if (_.padEffective & _.PAD_RIGHT) ~= 0 then delta = 1000 end
          if (_.padEffective & _.PAD_LEFT) ~= 0 then delta = -1000 end
        elseif o.intPadDeltas then
          local d = o.intPadDeltas
          if (_.padEffective & _.PAD_RIGHT) ~= 0 then delta = tonumber(d.right) or delta end
          if (_.padEffective & _.PAD_LEFT) ~= 0 then delta = tonumber(d.left) or delta end
        else
          if (_.padEffective & _.PAD_RIGHT) ~= 0 then delta = 1 end
          if (_.padEffective & _.PAD_LEFT) ~= 0 then delta = -1 end
        end
        if delta ~= 0 then
          num = clampNumber(num + delta, minV, maxV)
          _.config_parse.set(ctx.lines, o.key, tostring(math.floor(num)))
          ctx.configModified = true
        end
      elseif o.optType == "string" then
        local cur = _.config_parse.get(ctx.lines, o.key) or o.default or "0"
        local num = tonumber(cur)
        if num then
          local minV = tonumber(o.min)
          local maxV = tonumber(o.max)
          if minV == nil then minV = 0 end
          if maxV == nil then maxV = 9999 end
          if o.min == nil and o.max == nil then
            if o.key and o.key:match("menu_x") then
              maxV = 639
            elseif o.key and o.key:match("menu_y") then
              maxV = 447
            elseif o.key and o.key:match("num_displayed") then
              minV, maxV = 1, 30
            end
          end
          local delta = 0
          if o.intPadDeltas then
            local d = o.intPadDeltas
            if (_.padEffective & _.PAD_RIGHT) ~= 0 then delta = tonumber(d.right) or delta end
            if (_.padEffective & _.PAD_LEFT) ~= 0 then delta = tonumber(d.left) or delta end
          else
            if (_.padEffective & _.PAD_RIGHT) ~= 0 then delta = 1 end
            if (_.padEffective & _.PAD_LEFT) ~= 0 then delta = -1 end
          end
          if delta ~= 0 then
            num = num + delta
            if num < minV then num = minV end
            if num > maxV then num = maxV end
            _.config_parse.set(ctx.lines, o.key, tostring(num))
            ctx.configModified = true
          end
        end
      end
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      if isAutoSlotRow and ctx.editorAutoSlotGrab then
        confirmAutoMoveState()
        return
      end
      if isEsrPathRow and ctx.editorEsrPathGrab then
        confirmEsrMoveState()
        return
      end
      local o = ctx.optList[ctx.optSel]
      if o.optType == "enum" and o.enumVals and #o.enumVals > 0 and
          (((ctx.fileType == "ps2bbl_ini" or ctx.fileType == "psxbbl_ini") and
            (o.key == "VIDEO_MODE" or o.key == "LOGO_DISPLAY")) or
            (ctx.fileType == "osdmenu_cnf" and (o.key == "OSDSYS_video_mode" or o.key == "OSDSYS_region")) or
            (ctx.fileType == "osdmbr_cnf" and (o.key == "osd_screentype" or o.key == "osd_language"))) then
        local cur = _.config_parse.get(ctx.lines, o.key) or o.default or ""
        local idx = 0
        for ei, v in ipairs(o.enumVals) do
          if v == cur then
            idx = ei
            break
          end
        end
        idx = idx + 1
        if idx > #o.enumVals then idx = 1 end
        _.config_parse.set(ctx.lines, o.key, o.enumVals[idx])
        ctx.configModified = true
      elseif o.optType == "bool" then
        local cur = _.config_parse.get(ctx.lines, o.key) or o.default or "0"
        _.config_parse.set(ctx.lines, o.key, (cur == "1") and "0" or "1")
        ctx.configModified = true
      elseif o.optType == "int" then
        if isTimerDigitEditKey(o.key) then
          startTimerDigitEdit(ctx, _, o)
        else
          startIntDigitEdit(ctx, _, o)
        end
      elseif o.optType == "color" then
        startInlineColorEdit(ctx, _, o)
      elseif o.optType == "text" or o.optType == "string" then
        ctx.textInputTitleIdMode = nil
        ctx.textInputPrompt = (_.strings.options and _.strings.options[o.key] and _.strings.options[o.key].label) or
            o.label or _.common_str.enter_text
        ctx.textInputValue = _.config_parse.get(ctx.lines, o.key) or o.default or ""
        ctx.textInputMaxLen = (o.maxLen and o.maxLen > 0) and o.maxLen or 79
        ctx.textInputCallback = function(val)
          _.config_parse.set(ctx.lines, o.key, val or "")
          ctx.configModified = true
          ctx.state = "editor"
        end
        ctx.textInputReturnState = "editor"
        ctx.textInputGridSel = 1
        ctx.textInputCursor = #ctx.textInputValue + 1
        ctx.textInputScroll = 1
        ctx.state = "text_input"
      elseif o.key == "_menu_entries" then
        ctx.state = "menu_entries"
        ctx.entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
        ctx.entrySel = ctx.entrySel or 1
        ctx.entryScroll = ctx.entryScroll or 0
      elseif o.key == "_bbl_irx_entries" then
        local irxEntries = (_.config_parse.getBblIrxEntryIndices and _.config_parse.getBblIrxEntryIndices(ctx.lines)) or {}
        local targetIrxIdx, targetIrxDisabled = nil, false
        local hasUsableIrx = false
        for ii = 1, #irxEntries do
          local idx = irxEntries[ii] and tonumber(irxEntries[ii].idx) or nil
          if idx and not targetIrxIdx then
            targetIrxIdx = idx
            targetIrxDisabled = irxEntries[ii].disabled and true or false
          end
          if idx and _.config_parse.getBblIrxEntry then
            local v = _.config_parse.getBblIrxEntry(ctx.lines, idx)
            if tostring(v or "") ~= "" then
              hasUsableIrx = true
              break
            end
          end
        end
        if not hasUsableIrx then
          if not targetIrxIdx and _.config_parse.insertBblIrxEntryBelow then
            targetIrxIdx = _.config_parse.insertBblIrxEntryBelow(ctx.lines, 0, "")
            if targetIrxIdx then
              ctx.configModified = true
            end
          end
          if targetIrxIdx then
            ctx.bblIrxSel = 1
            ctx.bblIrxScroll = 0
            ctx.editKey = nil
            ctx.isAddPath = false
            ctx.addPathKey = nil
            ctx.pathPickerBootKey = nil
            ctx.pathPickerForEntryIdx = nil
            ctx.pathPickerEditIdx = nil
            ctx.pathPickerBblHotkeyKey = nil
            ctx.pathPickerBblHotkeySlot = nil
            ctx.pathPickerBblHotkeyDisabled = nil
            ctx.pathPickerBblIrxIdx = targetIrxIdx
            ctx.pathPickerBblIrxDisabled = targetIrxDisabled and true or false
            ctx.pathPickerContext = "path_only"
            ctx.pathPickerSub = "device"
            ctx.pathList = _.file_selector.getDevices("path_only") or {}
            ctx.pathPickerSel = 1
            ctx.pathPickerScroll = 0
            ctx.pathBrowsePath = nil
            ctx.pathPickerTarget = nil
            ctx.pathPickerFileExts = { ".irx" }
            ctx.pathPickerReturnState = "bbl_irx_entries"
            ctx.state = "path_picker"
          else
            ctx.bblIrxSel = ctx.bblIrxSel or 1
            ctx.bblIrxScroll = ctx.bblIrxScroll or 0
            ctx.state = "bbl_irx_entries"
          end
        else
          ctx.bblIrxSel = ctx.bblIrxSel or 1
          ctx.bblIrxScroll = ctx.bblIrxScroll or 0
          ctx.state = "bbl_irx_entries"
        end
      elseif o.key == "_bbl_hotkeys" then
        ctx.bblHotkeySel = ctx.bblHotkeySel or 1
        ctx.state = "bbl_hotkeys"
      elseif o.optType == "bbl_slot" and o.bblEntrySlot then
        ctx.bblHotkeyKey = o.bblKeyId or "AUTO"
        local isAutoKey = tostring(ctx.bblHotkeyKey or ""):upper() == "AUTO"
        local slotNum = tonumber(o.bblEntrySlot)
        local slotData = (slotNum and _.config_parse.getBblHotkeySlot and
          _.config_parse.getBblHotkeySlot(ctx.lines, ctx.bblHotkeyKey, slotNum)) or nil
        local isFmcbAuto = isAutoKey and ((ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot"))
        local isBblAutoEmptyOrNotSet = isAutoKey and (not isFmcbAuto) and slotData and
            ((not slotData.pathExists or tostring(slotData.path or "") == "") and ((tonumber(slotData.argCount) or 0) == 0))
        if isFmcbAuto or isBblAutoEmptyOrNotSet then
          if slotNum then
            ctx.editKey = nil
            ctx.isAddPath = false
            ctx.addPathKey = nil
            ctx.pathPickerTarget = nil
            ctx.pathPickerFileExts = nil
            ctx.pathPickerBootKey = nil
            ctx.pathPickerForEntryIdx = nil
            ctx.pathPickerEditIdx = nil
            ctx.pathPickerBblIrxIdx = nil
            ctx.pathPickerBblIrxDisabled = nil
            ctx.pathPickerBblHotkeyKey = ctx.bblHotkeyKey
            ctx.pathPickerBblHotkeySlot = slotNum
            ctx.pathPickerBblHotkeyDisabled = (slotData and slotData.disabled) and true or false
            if isFmcbAuto then
              ctx.pathPickerReturnState = "editor"
            else
              ctx.pathPickerReturnState = "bbl_hotkey_entry"
              ctx.bblEntrySlot = slotNum
              ctx.bblEntryDetailSel = ctx.bblEntryDetailSel or 1
              ctx.bblEntryDetailReturnState = "editor"
            end
            ctx.pathPickerContext = "path_only"
            ctx.pathPickerSub = "device"
            ctx.pathList = _.file_selector.getDevices("path_only") or {}
            ctx.pathPickerSel = 1
            ctx.pathPickerScroll = 0
            ctx.pathBrowsePath = nil
            ctx.state = "path_picker"
          else
            ctx.bblEntrySlot = tonumber(o.bblEntrySlot)
            ctx.bblEntryDetailSel = ctx.bblEntryDetailSel or 1
            ctx.bblEntryDetailReturnState = "editor"
            ctx.state = "bbl_hotkey_entry"
          end
        else
          ctx.bblEntrySlot = tonumber(o.bblEntrySlot)
          ctx.bblEntryDetailSel = ctx.bblEntryDetailSel or 1
          ctx.bblEntryDetailReturnState = "editor"
          ctx.state = "bbl_hotkey_entry"
        end
      elseif o.optType == "boot_paths" then
        local bootEntries = (_.config_parse.getBootPathEntries and _.config_parse.getBootPathEntries(ctx.lines, o.key)) or {}
        local hasUsableBootPath = false
        for bi = 1, #bootEntries do
          local item = bootEntries[bi]
          local value = type(item) == "table" and item.value or item
          if tostring(value or "") ~= "" then
            hasUsableBootPath = true
            break
          end
        end
        if ctx.fileType == "osdmbr_cnf" and not hasUsableBootPath then
          -- OSDMenu MBR empty/not-set launch keys: go directly to device picker and create first path slot.
          local firstEntry = bootEntries[1]
          local firstEntryValue = type(firstEntry) == "table" and firstEntry.value or firstEntry
          ctx.editKey = nil
          ctx.isAddPath = false
          ctx.addPathKey = nil
          ctx.bootKey = nil
          ctx.pathPickerTarget = nil
          ctx.pathPickerFileExts = nil
          ctx.pathPickerForEntryIdx = nil
          ctx.pathPickerBblHotkeyKey = nil
          ctx.pathPickerBblHotkeySlot = nil
          ctx.pathPickerBblHotkeyDisabled = nil
          ctx.pathPickerBblIrxIdx = nil
          ctx.pathPickerBblIrxDisabled = nil
          ctx.pathPickerBootKey = o.key
          if firstEntry ~= nil and tostring(firstEntryValue or "") == "" then
            ctx.pathPickerEditIdx = 1
            ctx.pathPickerInsertBelow = nil
          else
            ctx.pathPickerEditIdx = nil
            ctx.pathPickerInsertBelow = 0
          end
          ctx.pathPickerReturnState = "editor"
          ctx.pathPickerContext = "mbr"
          ctx.pathPickerSub = "device"
          ctx.pathList = _.file_selector.getDevices("mbr") or {}
          ctx.pathPickerSel = 1
          ctx.pathPickerScroll = 0
          ctx.pathBrowsePath = nil
          ctx.state = "path_picker"
        else
          ctx.bootKey = o.key
          ctx.entryIdx = nil
          ctx.entryPathSel = ctx.entryPathSel or 1
          ctx.entryPathScroll = ctx.entryPathScroll or 0
          ctx.state = "entry_paths"
        end
      elseif o.optType == "path" then
        ctx.editKey = o.key
        ctx.isAddPath = false
        ctx.addPathKey = nil
        local isBblLoadIrx = (ctx.fileType == "ps2bbl_ini" or ctx.fileType == "psxbbl_ini") and o.key and
            o.key:match("^LOAD_IRX_E%d+$")
        local isFmcbLaunchPath = ((ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot")) and o.key and
            o.key:match("^ESR_Path_E%d+$")
        ctx.pathPickerTarget = nil
        ctx.pathPickerFileExts = isBblLoadIrx and { ".irx" } or nil
        ctx.pathPickerBootKey = nil
        ctx.pathPickerForEntryIdx = nil
        ctx.pathPickerBblHotkeyKey = nil
        ctx.pathPickerBblHotkeySlot = nil
        ctx.pathPickerBblHotkeyDisabled = nil
        ctx.pathPickerBblIrxIdx = nil
        ctx.pathPickerBblIrxDisabled = nil
        ctx.pathPickerReturnState = nil
        ctx.pathPickerContext = isBblLoadIrx and "path_only" or
            (isFmcbLaunchPath and "fmcb_launch" or
              ((o.key == "path_DKWDRV_ELF") and "mc_only" or ((ctx.context == "mbr") and "mbr" or "osdmenu")))
        ctx.pathPickerSub = "device"
        ctx.pathList = _.file_selector.getDevices(ctx.pathPickerContext) or {}
        ctx.pathPickerSel = ctx.pathPickerSel or 1
        ctx.pathPickerScroll = ctx.pathPickerScroll or 0
        ctx.state = "path_picker"
      end
    end
    if (_.padEffective & _.PAD_SQUARE) ~= 0 then
      if isAutoSlotRow then
        ctx.editorAutoSlotActionsOpen = true
        ctx.editorAutoSlotActionsSel = ctx.editorAutoSlotActionsSel or 1
        ctx.editorAutoSlotActionsScroll = ctx.editorAutoSlotActionsScroll or 0
      elseif isEsrPathRow then
        ctx.editorEsrPathActionsOpen = true
        ctx.editorEsrPathActionsSel = ctx.editorEsrPathActionsSel or 1
        ctx.editorEsrPathActionsScroll = ctx.editorEsrPathActionsScroll or 0
      end
    end
    if (_.padEffective & _.PAD_TRIANGLE) ~= 0 and ctx.optList and #ctx.optList > 0 then
      local o = ctx.optList[ctx.optSel]
      if o and o.optType == "boot_paths" and ctx.fileType == "osdmbr_cnf" and o.key then
        local disabled = _.config_parse.isBootKeyDisabled and _.config_parse.isBootKeyDisabled(ctx.lines, o.key)
        _.config_parse.setBootKeyDisabled(ctx.lines, o.key, not disabled)
        ctx.configModified = true
      elseif isOsdVisualCoordRow then
        if not osdVisualGroupMatchesPreset(ctx, _, OSD_VISUAL_PATCHED_DEFAULTS, cachedGet) then
          ctx.editorOsdVisualRestoreOpen = true
          ctx.editorOsdVisualRestoreSel = ctx.editorOsdVisualRestoreSel or 1
          ctx.editorOsdVisualRestoreScroll = ctx.editorOsdVisualRestoreScroll or 0
        end
      elseif o and o.key and o.key:match("^ESR_Path_E%d+$") and ctx.fileType == "freemcboot_cnf" then
        toggleEsrSlotDisabled()
      elseif o and o.optType == "bbl_slot" and o.bblKeyId == "AUTO" and o.bblEntrySlot then
        local slotNum = tonumber(o.bblEntrySlot)
        local slot = _.config_parse.getBblHotkeySlot and _.config_parse.getBblHotkeySlot(ctx.lines, "AUTO", slotNum) or nil
        if autoSlotHasPresence(slot) then
          local changed = _.config_parse.setBblHotkeySlotDisabled and
              _.config_parse.setBblHotkeySlotDisabled(ctx.lines, "AUTO", slotNum, not slot.disabled)
          if changed then
            ctx.configModified = true
          end
        end
      elseif o and o.key and o.key:sub(1, 1) ~= "_" and o.optType ~= "header" then
        local def = resetDefaultFn and resetDefaultFn(o.key)
        if def ~= nil and not optionMatchesDefault(ctx, _, o.key, def, cachedGet) then
          _.config_parse.set(ctx.lines, o.key, def)
          if _.common and _.common.refreshConfigModified then
            _.common.refreshConfigModified(ctx)
          else
            ctx.configModified = true
          end
        end
      end
    end
  else
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(60), _.FONT_SCALE, _.editor_str.no_option_list,
      _.GRAY)
    local emptyHints = withStartHintVisibility(_.editor_str.start_save_circle_back_items, ctx.configModified == true)
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, emptyHints, nil,
      _.DIM, _.w - 2 * _.MARGIN_X)
  end

  if ctx.configModified and ((_.padEffective & _.PAD_START) ~= 0) then
    ctx.saveSplash = nil
    local locations = _.getLocations(ctx.context, ctx.fileType, ctx.chosenMcSlot)
    if ctx.fileType == "osdmenu_cnf" and #locations >= 2 then
      ctx.saveChoices = locations
      ctx.saveSel = ctx.saveSel or 1
      ctx.state = "choose_save"
    else
      local path = ctx.currentPath or (locations and locations[1])
      if path and path ~= "" then
        ctx.lines = _.config_parse.regenerateForSave(ctx.lines, ctx.fileType, _.config_options)
        local parentDir = path:match("^(.+)/[^/]+$")
        local ok, err = _.common.saveConfig(ctx, path, ctx.lines, parentDir)
        if ok then
          ctx.currentPath = path
          ctx.saveSplash = { kind = "saved", detail = path or "", framesLeft = 60 }
          ctx.configModified = false
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
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.timerDigitEdit = nil
    ctx.intDigitEdit = nil
    ctx.colorInlineEdit = nil
    if ctx.editorAutoSlotGrab then
      if _.common and _.common.cloneConfigLines then
        if ctx.editorAutoSlotMoveSnapshot then
          ctx.lines = _.common.cloneConfigLines(ctx.editorAutoSlotMoveSnapshot)
          ctx.optSel = _.common.clampListSelection(ctx.editorAutoSlotMoveSel or ctx.optSel, #(ctx.optList or {}))
          _.common.refreshConfigModified(ctx)
        end
      elseif ctx.editorAutoSlotMoveSnapshot then
        ctx.lines = ctx.editorAutoSlotMoveSnapshot
        ctx.optSel = _.common.clampListSelection(ctx.editorAutoSlotMoveSel or ctx.optSel, #(ctx.optList or {}))
        _.common.refreshConfigModified(ctx)
      end
      ctx.editorAutoSlotGrab = nil
      ctx.editorAutoSlotMoveSnapshot = nil
      ctx.editorAutoSlotMoveSel = nil
      return
    end
    if ctx.editorEsrPathGrab then
      if _.common and _.common.cloneConfigLines then
        if ctx.editorEsrPathMoveSnapshot then
          ctx.lines = _.common.cloneConfigLines(ctx.editorEsrPathMoveSnapshot)
          ctx.optSel = _.common.clampListSelection(ctx.editorEsrPathMoveSel or ctx.optSel, #(ctx.optList or {}))
          _.common.refreshConfigModified(ctx)
        end
      elseif ctx.editorEsrPathMoveSnapshot then
        ctx.lines = ctx.editorEsrPathMoveSnapshot
        ctx.optSel = _.common.clampListSelection(ctx.editorEsrPathMoveSel or ctx.optSel, #(ctx.optList or {}))
        _.common.refreshConfigModified(ctx)
      end
      ctx.editorEsrPathGrab = nil
      ctx.editorEsrPathMoveSnapshot = nil
      ctx.editorEsrPathMoveSel = nil
      return
    end
    if isCategorizedFile and ctx.editorCategoryIdx and ctx.editorCategoryIdx > 0 then
      setCategoryOptSel(ctx, ctx.editorCategoryIdx, ctx.optSel)
      local prevCategoryIdx = ctx.editorCategoryIdx
      ctx.editorCategoryIdx = 0
      ctx.optList = nil
      ctx.optSel = prevCategoryIdx
      ctx.saveSplash = nil
    else
      if ctx.configModified then
        ctx.editorLeavePrompt = true
      else
        ctx.state = getEditorBackState(ctx); ctx.currentPath = nil; ctx.lines = nil; ctx.optList = nil; ctx.editorCategoryIdx = 0; ctx.saveSplash = nil
      end
    end
  end
end

return { run = run }
