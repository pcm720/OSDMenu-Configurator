--[[ Hidden joystick easter egg screen. ]]

local MESSAGE_LINES = {
  "We love Katamari too!",
  "However please refrain from",
  "flicking your stick and play",
  "your PlayStation 2.",
}

local MESSAGE_SCALE = 0.9

local function calcTextWidth(_, text)
  if _.common and _.common.calcTextWidth then
    local w = _.common.calcTextWidth(_.font, text, MESSAGE_SCALE)
    if type(w) == "number" and w > 0 then
      return w
    end
  end
  return math.max(1, math.floor((8 * MESSAGE_SCALE) * #tostring(text or "")))
end

local function run(ctx)
  local _ = ctx._
  local bodyColor = _.WHITE
  local backLabel = (_.menu_str and _.menu_str.back_label) or "Back"
  local hintItems = { { pad = "circle", label = backLabel } }
  local lineH = math.max((_.LINE_H or 22), _.scaleY and _.scaleY(28) or 28)
  local totalH = lineH * #MESSAGE_LINES
  local startY = math.floor(((_.h or 448) - totalH) / 2)

  for i = 1, #MESSAGE_LINES do
    local line = MESSAGE_LINES[i]
    local tw = calcTextWidth(_, line)
    local x = math.floor(((_.w or 640) - tw) / 2)
    local y = startY + ((i - 1) * lineH)
    _.drawText(_.font, _.drawMode, x, y, MESSAGE_SCALE, line, bodyColor)
  end

  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hintItems, nil, _.DIM_COLOR, _.w - 2 * _.MARGIN_X)

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    local returnState = tostring(ctx.katamariEasterEggReturnState or "")
    if returnState == "" or returnState == "katamari_easter_egg" then
      returnState = "main"
    end
    ctx.katamariEasterEggReturnState = nil
    ctx._katamariStickActiveFrames = 0
    ctx._katamariStickCountdownFrames = 0
    ctx._katamariStickNeutralFrames = 0
    ctx.state = returnState
  end
end

return { run = run }
