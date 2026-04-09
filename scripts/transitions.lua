--[[
  Shared scene transition logic for configurator UI.
  Installed into ui_common.lua via transitions.install(common).
]]

local transitions = {}

function transitions.install(common)
  if type(common) ~= "table" then return end

  local function clamp01(v)
    local n = tonumber(v) or 0
    if n < 0 then return 0 end
    if n > 1 then return 1 end
    return n
  end

  local function easeInOutCubic(t)
    local x = clamp01(t)
    if x < 0.5 then
      return 4 * x * x * x
    end
    local a = (-2 * x + 2)
    return 1 - ((a * a * a) / 2)
  end

  local function easeOutQuart(t)
    local x = clamp01(t)
    local a = 1 - x
    return 1 - (a * a * a * a)
  end

  local function easeOutCubic(t)
    local x = clamp01(t)
    local a = 1 - x
    return 1 - (a * a * a)
  end

  local function applySceneMotionCurve(transitionType, progress)
    local t = common.normalizeSceneTransitionType(transitionType)
    if t == "slide" then
      -- Slide should immediately move content on frame 1 (no apparent blank hold).
      return easeOutCubic(progress)
    end
    if t == "whip_pan" then
      return easeOutQuart(progress)
    end
    return clamp01(progress)
  end

  local function getRawGraphics()
    local runtime = _G and _G.CONFIG_UI
    if runtime and runtime.rawGraphics then
      return runtime.rawGraphics
    end
    return Graphics
  end

  function common.normalizeSceneTransitionType(raw)
    local value = tostring(raw or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    value = value:gsub("%s+", "_")
    if value == "crossdissolve" or value == "dissolve" then value = "cross_dissolve" end
    if value == "cross-dissolve" then value = "cross_dissolve" end
    if value == "whippan" then value = "whip_pan" end
    if value == "whip-pan" then value = "whip_pan" end
    if value == "fliph" or value == "flip_h" or value == "horizontal_flip" then value = "flip_horizontal" end
    if value == "flipv" or value == "flip_v" or value == "vertical_flip" then value = "flip_vertical" end
    if value == "cut" or value == "slide" or value == "cross_dissolve" or value == "whip_pan" or
        value == "zoom" or value == "flip_horizontal" or value == "flip_vertical" then
      return value
    end
    return common.SCENE_TRANSITION_DEFAULT_TYPE
  end

  function common.normalizeSceneTransitionFrames(raw)
    local n = math.floor(tonumber(raw) or common.SCENE_TRANSITION_DEFAULT_FRAMES)
    local minFrames = tonumber(common.SCENE_TRANSITION_MIN_FRAMES) or 1
    local maxFrames = tonumber(common.SCENE_TRANSITION_MAX_FRAMES) or 60
    if n < minFrames then n = minFrames end
    if n > maxFrames then n = maxFrames end
    return n
  end

  function common.shouldRunSceneTransition(transitionType, transitionFrames)
    local t = common.normalizeSceneTransitionType(transitionType)
    local frames = common.normalizeSceneTransitionFrames(transitionFrames)
    return t ~= "cut" and frames >= 1
  end

  local function getTransitionScreenSize(ctx)
    local w = tonumber(ctx and ctx.w)
    local h = tonumber(ctx and ctx.h)
    if w and h and w > 0 and h > 0 then
      return math.floor(w), math.floor(h)
    end
    local mode = (Screen and Screen.getMode) and Screen.getMode() or nil
    local mw = tonumber(mode and mode.width) or common.DEFAULT_W
    local mh = tonumber(mode and mode.height) or common.DEFAULT_H
    return math.floor(mw), math.floor(mh)
  end

  local function drawRectSafe(x, y, w, h, color)
    local gfx = getRawGraphics()
    if not (gfx and gfx.drawRect) then return end
    local rw = math.floor(tonumber(w) or 0)
    local rh = math.floor(tonumber(h) or 0)
    if rw <= 0 or rh <= 0 then return end
    gfx.drawRect(math.floor(tonumber(x) or 0), math.floor(tonumber(y) or 0), rw, rh, color)
  end

  function common.drawSceneTransitionOverlay(ctx, spec)
    if not (spec and Graphics and Graphics.drawRect and Color and Color.new) then return end
    local phase = tostring(spec.phase or "in")
    local t = clamp01(spec.progress)
    local transitionType = common.normalizeSceneTransitionType(spec.type)
    if transitionType == "cut" then return end

    local cover = (phase == "in") and (1 - t) or t
    cover = clamp01(cover)
    if cover <= 0 then return end

    local w, h = getTransitionScreenSize(ctx)
    local maxAlpha = 0x80
    local baseAlpha = maxAlpha
    if transitionType == "cross_dissolve" then
      baseAlpha = math.floor(maxAlpha * cover + 0.5)
    end
    local frame = math.max(0, math.floor(tonumber(spec.frame) or 0))

    if transitionType == "cross_dissolve" then
      local mainAlpha = math.floor((maxAlpha * 0.78) * cover + 0.5)
      drawRectSafe(0, 0, w, h, Color.new(0, 0, 0, mainAlpha))
      local stripeStep = 3
      local stripeAlpha = math.floor((maxAlpha * 0.55) * cover + 0.5)
      local offset = frame % stripeStep
      for y = offset, h - 1, stripeStep do
        drawRectSafe(0, y, w, 1, Color.new(0, 0, 0, stripeAlpha))
      end
      return
    end

    if transitionType == "slide" or transitionType == "whip_pan" then
      local wipeW = math.floor((w * cover) + 0.5)
      local maskX = 0
      if phase == "out" then
        -- Back/cancel: grow cover from right so direction opposes forward reveal.
        maskX = w - wipeW
      end
      drawRectSafe(maskX, 0, wipeW, h, Color.new(0, 0, 0, baseAlpha))
      if transitionType == "whip_pan" and wipeW > 0 then
        local edgeW = math.max(3, math.floor(w * 0.03))
        local edgeX = maskX + wipeW - edgeW
        if phase == "out" then
          edgeX = maskX
        end
        drawRectSafe(edgeX, 0, edgeW, h, Color.new(28, 28, 34, math.min(maxAlpha, baseAlpha + 18)))
        local streakX = edgeX + math.floor(edgeW * 0.6)
        if phase == "out" then
          streakX = edgeX + math.max(0, edgeW - math.max(2, math.floor(edgeW * 0.25)))
        end
        drawRectSafe(streakX, 0, math.max(2, math.floor(edgeW * 0.25)), h,
          Color.new(200, 200, 200, math.floor(baseAlpha * 0.35 + 0.5)))
      end
      return
    end

    if transitionType == "zoom" then
      local zoomCover = easeInOutCubic(cover)
      -- Keep a meaningful visible area at all times to avoid apparent blank frames.
      local minVisibleScale = 0.35
      local visibleScale = minVisibleScale + ((1 - minVisibleScale) * (1 - zoomCover))
      if visibleScale < minVisibleScale then visibleScale = minVisibleScale end
      if visibleScale > 1 then visibleScale = 1 end
      local visibleW = math.floor((w * visibleScale) + 0.5)
      local visibleH = math.floor((h * visibleScale) + 0.5)
      local left = math.floor((w - visibleW) / 2)
      local top = math.floor((h - visibleH) / 2)
      local alpha = math.floor((0x58 * (0.25 + 0.75 * zoomCover)) + 0.5)
      drawRectSafe(0, 0, w, top, Color.new(0, 0, 0, alpha))
      drawRectSafe(0, top + visibleH, w, h - (top + visibleH), Color.new(0, 0, 0, alpha))
      drawRectSafe(0, top, left, visibleH, Color.new(0, 0, 0, alpha))
      drawRectSafe(left + visibleW, top, w - (left + visibleW), visibleH, Color.new(0, 0, 0, alpha))
      return
    end

    -- Fallback: generic mask behavior.
    drawRectSafe(0, 0, w, h, Color.new(0, 0, 0, baseAlpha))
  end

  local function isSceneSlideTransition(t)
    local n = common.normalizeSceneTransitionType(t)
    return n == "slide" or n == "whip_pan"
  end

  local function drawWhipPanOverlay(ctx, transitionDirection, progress, frame)
    local w, h = getTransitionScreenSize(ctx)
    local runtime = _G and _G.CONFIG_UI
    local offsetX = math.floor(tonumber(runtime and runtime.sceneDrawOffsetX) or 0)
    local movingRight = (tostring(transitionDirection or "in") == "out") or
        (tostring(transitionDirection or "in") == "back")
    local edgeX = movingRight and (offsetX + w) or offsetX
    local motionStrength = clamp01(1 - progress)
    -- Longer, more dramatic whip streak body.
    local trailW = math.max(28, math.floor((w * 0.10) + (w * 0.28 * motionStrength)))
    local bands = 10
    local bandW = math.max(2, math.floor(trailW / bands))

    for i = 0, bands - 1 do
      local falloff = 1 - (i / math.max(1, bands - 1))
      local alpha = math.floor((0x52 * motionStrength * falloff) + 0.5)
      if alpha > 0 then
        local x
        if movingRight then
          x = edgeX - trailW + (i * bandW)
        else
          x = edgeX + (i * bandW)
        end
        drawRectSafe(x, 0, bandW, h, Color.new(26, 26, 32, alpha))
      end
    end

    local edgeAlpha = math.floor((0x6A * (0.35 + 0.65 * motionStrength)) + 0.5)
    if edgeAlpha > 0 then
      local edgeW = math.max(3, math.floor(w * 0.006))
      local x = movingRight and (edgeX - edgeW) or edgeX
      drawRectSafe(x, 0, edgeW, h, Color.new(208, 208, 216, edgeAlpha))
    end

    local streakAlpha = math.floor((0x44 * motionStrength) + 0.5)
    if streakAlpha > 0 then
      local rowStep = 9
      local startY = ((math.max(0, math.floor(frame or 0)) * 6) % rowStep)
      local streakW = math.max(12, math.floor(trailW * 0.72))
      for y = startY, h - 1, rowStep do
        local x = movingRight and (edgeX - streakW) or edgeX
        drawRectSafe(x, y, streakW, 1, Color.new(180, 180, 192, streakAlpha))
      end

      -- Fainter long tail behind the main streak to exaggerate speed.
      local ghostAlpha = math.floor(streakAlpha * 0.45 + 0.5)
      if ghostAlpha > 0 then
        local ghostW = math.max(streakW + math.floor(trailW * 0.35), streakW + 12)
        local ghostStep = 13
        local ghostStartY = ((math.max(0, math.floor(frame or 0)) * 3) % ghostStep)
        for y = ghostStartY, h - 1, ghostStep do
          local x = movingRight and (edgeX - ghostW) or edgeX
          drawRectSafe(x, y, ghostW, 1, Color.new(128, 128, 144, ghostAlpha))
        end
      end
    end
  end

  local function drawFlipOverlay(ctx)
    local runtime = _G and _G.CONFIG_UI
    if type(runtime) ~= "table" then return end
    if runtime.sceneFlipActive ~= true then return end
    if tostring(runtime.sceneFlipPhase or "") ~= "out" then return end
    local flipType = common.normalizeSceneTransitionType(runtime.sceneFlipType)
    if flipType ~= "flip_horizontal" and flipType ~= "flip_vertical" then return end
    local w, h = getTransitionScreenSize(ctx)
    local axisScale = clamp01(runtime.sceneFlipAxisScale or 1)
    local fullAlpha = 0x80

    if flipType == "flip_horizontal" then
      local cx = math.floor(tonumber(runtime.sceneFlipCenterX) or (w / 2))
      local visibleW = math.max(1, math.floor((w * axisScale) + 0.5))
      local left = cx - math.floor(visibleW / 2)
      local right = left + visibleW
      if left < 0 then
        right = right - left
        left = 0
      end
      if right > w then
        left = left - (right - w)
        right = w
      end
      if left < 0 then left = 0 end
      if right < left then right = left end
      drawRectSafe(0, 0, left, h, Color.new(0, 0, 0, fullAlpha))
      drawRectSafe(right, 0, w - right, h, Color.new(0, 0, 0, fullAlpha))
    else
      local cy = math.floor(tonumber(runtime.sceneFlipCenterY) or (h / 2))
      local visibleH = math.max(1, math.floor((h * axisScale) + 0.5))
      local top = cy - math.floor(visibleH / 2)
      local bottom = top + visibleH
      if top < 0 then
        bottom = bottom - top
        top = 0
      end
      if bottom > h then
        top = top - (bottom - h)
        bottom = h
      end
      if top < 0 then top = 0 end
      if bottom < top then bottom = top end
      drawRectSafe(0, 0, w, top, Color.new(0, 0, 0, fullAlpha))
      drawRectSafe(0, bottom, w, h - bottom, Color.new(0, 0, 0, fullAlpha))
    end
  end

  function common.beginSceneTransitionIn(ctx, transitionType, transitionFrames, opts)
    if not ctx then return end
    local t = common.normalizeSceneTransitionType(transitionType)
    local frames = common.normalizeSceneTransitionFrames(transitionFrames)
    if not common.shouldRunSceneTransition(t, frames) then
      ctx.sceneTransitionIn = nil
      return
    end
    ctx.sceneTransitionIn = {
      type = t,
      frames = frames,
      frame = 0,
      direction = (opts and tostring(opts.direction or "")) or "in",
      phase = (opts and tostring(opts.phase or "")) or "in",
    }
  end

  function common.isSceneTransitionInActive(ctx)
    local tr = ctx and ctx.sceneTransitionIn
    if type(tr) ~= "table" then return false end
    if not common.shouldRunSceneTransition(tr.type, tr.frames) then return false end
    return (tonumber(tr.frame) or 0) < (tonumber(tr.frames) or 0)
  end

  function common.shouldBlockInputForSceneTransition(ctx)
    return common.isSceneTransitionInActive(ctx)
  end

  function common.applySceneDrawOffsetForCurrentFrame(ctx)
    local runtime = _G and _G.CONFIG_UI
    local w, h = getTransitionScreenSize(ctx)
    if runtime then
      runtime.sceneDrawOffsetX = 0
      runtime.sceneDrawAlpha = 1
      runtime.sceneDrawScale = 1
      runtime.sceneDrawScaleX = 1
      runtime.sceneDrawScaleY = 1
      runtime.sceneDrawCenterX = math.floor((w or 0) / 2)
      runtime.sceneDrawCenterY = math.floor((h or 0) / 2)
      runtime.currentSceneWidth = w
      runtime.currentSceneHeight = h
      runtime.sceneFlipActive = false
      runtime.sceneFlipType = nil
      runtime.sceneFlipAxisScale = 1
      runtime.sceneFlipDirSign = 0
      runtime.sceneFlipCenterX = runtime.sceneDrawCenterX
      runtime.sceneFlipCenterY = runtime.sceneDrawCenterY
      runtime.sceneFlipPhase = nil
    end
    if not common.isSceneTransitionInActive(ctx) then
      return 0
    end
    local tr = ctx.sceneTransitionIn
    if tr.type == "cross_dissolve" then
      local frames = common.normalizeSceneTransitionFrames(tr.frames)
      local frame = math.max(0, math.floor(tonumber(tr.frame) or 0))
      local progress = clamp01((frame + 1) / math.max(1, frames))
      local prevProgress = clamp01(frame / math.max(1, frames))
      -- We preserve previous framebuffer for dissolve frames, so alpha must be
      -- incremental (delta blend), not absolute. This yields:
      --   out = old*(1-progress) + new*progress
      -- instead of repeatedly re-blending absolute alpha onto prior mixed frames.
      local remainingOld = 1 - prevProgress
      local blendAlpha = progress
      if remainingOld > 0 then
        blendAlpha = (progress - prevProgress) / remainingOld
      end
      blendAlpha = clamp01(blendAlpha)
      if runtime then
        runtime.sceneDrawAlpha = blendAlpha
      end
      return 0
    end
    if not isSceneSlideTransition(tr.type) then
      if tr.type == "zoom" then
        local frames = common.normalizeSceneTransitionFrames(tr.frames)
        local frame = math.max(0, math.floor(tonumber(tr.frame) or 0))
        local progress = clamp01((frame + 1) / math.max(1, frames))
        local curved = easeInOutCubic(progress)
        local direction = tostring(tr.direction or "in")
        -- Forward and back use opposite zoom directions while both settle at 1.0.
        -- "in" starts smaller; "out/back" starts larger.
        local startScale = (direction == "out" or direction == "back") and 1.50 or 0.40
        local scale = startScale + ((1 - startScale) * curved)
        if runtime then
          runtime.sceneDrawScale = scale
          runtime.sceneDrawScaleX = scale
          runtime.sceneDrawScaleY = scale
        end
      elseif tr.type == "flip_horizontal" or tr.type == "flip_vertical" then
        local frames = common.normalizeSceneTransitionFrames(tr.frames)
        local frame = math.max(0, math.floor(tonumber(tr.frame) or 0))
        local progress = clamp01((frame + 1) / math.max(1, frames))
        local curved = easeInOutCubic(progress)
        local phase = tostring(tr.phase or "in")
        local incoming = (phase ~= "out")
        -- Flip phase model:
        -- out: full -> edge-on, in: edge-on -> full.
        local axisScale
        if incoming then
          axisScale = math.sin((math.pi * 0.5) * curved)
        else
          axisScale = math.cos((math.pi * 0.5) * curved)
        end
        if axisScale < 0 then axisScale = 0 end
        if axisScale > 1 then axisScale = 1 end
        local direction = tostring(tr.direction or "in")
        -- Forward behaves like "down", back/cancel behaves like "up".
        local dirSign = ((direction == "out" or direction == "back") and -1) or 1
        local centerX = math.floor((w or 0) / 2)
        local centerY = math.floor((h or 0) / 2)
        local shiftX = math.floor(((1 - axisScale) * (w * 0.16)) + 0.5)
        local shiftY = math.floor(((1 - axisScale) * (h * 0.16)) + 0.5)
        if runtime then
          runtime.sceneDrawScale = axisScale
          runtime.sceneDrawScaleX = 1
          runtime.sceneDrawScaleY = 1
          runtime.sceneDrawCenterX = centerX
          runtime.sceneDrawCenterY = centerY
          runtime.sceneDrawAlpha = axisScale
          runtime.sceneFlipPhase = phase
          if tr.type == "flip_horizontal" then
            runtime.sceneDrawScaleX = axisScale
            runtime.sceneDrawCenterX = centerX + (dirSign * shiftX)
          else
            runtime.sceneDrawScaleY = axisScale
            runtime.sceneDrawCenterY = centerY + (dirSign * shiftY)
          end
        end
      end
      return 0
    end
    local frames = common.normalizeSceneTransitionFrames(tr.frames)
    local frame = math.max(0, math.floor(tonumber(tr.frame) or 0))
    -- Use a 1-based step for slide-like motion so the very first transition frame
    -- already shows incoming content (avoids an initial fully blank frame).
    local progress = clamp01((frame + 1) / math.max(1, frames))
    local curved = applySceneMotionCurve(tr.type, progress)
    local w, _h = getTransitionScreenSize(ctx)
    local remaining = math.floor(((1 - curved) * w) + 0.5)
    local direction = tostring(tr.direction or "in")
    local offsetX = remaining
    if direction == "out" or direction == "back" then
      offsetX = -remaining
    end
    if runtime then
      runtime.sceneDrawOffsetX = offsetX
    end
    return offsetX
  end

  function common.shouldSkipSceneClearForTransition(ctx)
    if not common.isSceneTransitionInActive(ctx) then return false end
    local tr = ctx and ctx.sceneTransitionIn
    local t = common.normalizeSceneTransitionType(tr and tr.type)
    -- Dissolve always preserves previous framebuffer.
    if t == "cross_dissolve" then
      return true
    end
    return false
  end

  function common.shouldDrawBackgroundLayerForTransition(ctx)
    if not common.isSceneTransitionInActive(ctx) then
      return true
    end
    local tr = ctx and ctx.sceneTransitionIn
    local t = common.normalizeSceneTransitionType(tr and tr.type)
    -- Preserve prior logo/background only while framebuffer-preserve phase is active.
    if t == "cross_dissolve" then
      return false
    end
    return true
  end

  function common.drawWithoutSceneTransform(drawFn)
    if type(drawFn) ~= "function" then return nil end
    local runtime = _G and _G.CONFIG_UI
    if type(runtime) ~= "table" then
      return drawFn()
    end
    local prevOffsetX = runtime.sceneDrawOffsetX
    local prevAlpha = runtime.sceneDrawAlpha
    local prevScale = runtime.sceneDrawScale
    local prevScaleX = runtime.sceneDrawScaleX
    local prevScaleY = runtime.sceneDrawScaleY
    local prevCenterX = runtime.sceneDrawCenterX
    local prevCenterY = runtime.sceneDrawCenterY
    runtime.sceneDrawOffsetX = 0
    runtime.sceneDrawAlpha = 1
    runtime.sceneDrawScale = 1
    runtime.sceneDrawScaleX = 1
    runtime.sceneDrawScaleY = 1
    local ok, r1, r2, r3, r4 = pcall(drawFn)
    runtime.sceneDrawOffsetX = prevOffsetX
    runtime.sceneDrawAlpha = prevAlpha
    runtime.sceneDrawScale = prevScale
    runtime.sceneDrawScaleX = prevScaleX
    runtime.sceneDrawScaleY = prevScaleY
    runtime.sceneDrawCenterX = prevCenterX
    runtime.sceneDrawCenterY = prevCenterY
    if not ok then
      error(r1)
    end
    return r1, r2, r3, r4
  end

  function common.drawAndAdvanceSceneTransitionIn(ctx)
    if not common.isSceneTransitionInActive(ctx) then
      if ctx then ctx.sceneTransitionIn = nil end
      local runtime = _G and _G.CONFIG_UI
      if runtime then
        runtime.sceneDrawOffsetX = 0
        runtime.sceneDrawAlpha = 1
        runtime.sceneDrawScale = 1
        runtime.sceneDrawScaleX = 1
        runtime.sceneDrawScaleY = 1
        runtime.sceneFlipActive = false
        runtime.sceneFlipType = nil
        runtime.sceneFlipPhase = nil
      end
      return
    end
    local tr = ctx.sceneTransitionIn
    local frames = common.normalizeSceneTransitionFrames(tr.frames)
    local frame = math.max(0, math.floor(tonumber(tr.frame) or 0))
    if tr.type == "whip_pan" then
      local progress = clamp01((frame + 1) / math.max(1, frames))
      drawWhipPanOverlay(ctx, tr.direction, progress, frame)
    elseif tr.type == "cross_dissolve" then
      -- True dissolve approximation: preserve previous frame in buffer and
      -- draw incoming scene with rising alpha (handled by sceneDrawAlpha).
    elseif tr.type == "zoom" then
      -- Zoom transition is handled through sceneDrawScale in applySceneDrawOffsetForCurrentFrame.
    elseif tr.type == "flip_horizontal" or tr.type == "flip_vertical" then
      -- Flip transitions are handled through sceneDrawScaleX/sceneDrawScaleY in applySceneDrawOffsetForCurrentFrame.
    elseif not isSceneSlideTransition(tr.type) then
      -- For incoming non-slide transitions, start at step 1
      -- to avoid a fully blank first frame right after scene switch.
      local progress = clamp01((frame + 1) / math.max(1, frames))
      common.drawSceneTransitionOverlay(ctx, {
        phase = "in",
        type = tr.type,
        progress = progress,
        frame = frame,
        frames = frames,
      })
    end
    frame = frame + 1
    if frame >= frames then
      ctx.sceneTransitionIn = nil
      local runtime = _G and _G.CONFIG_UI
      if runtime then
        runtime.sceneDrawOffsetX = 0
        runtime.sceneDrawAlpha = 1
        runtime.sceneDrawScale = 1
        runtime.sceneDrawScaleX = 1
        runtime.sceneDrawScaleY = 1
        runtime.sceneFlipActive = false
        runtime.sceneFlipType = nil
        runtime.sceneFlipPhase = nil
      end
    else
      tr.frame = frame
    end
  end

  function common.playSceneTransitionOnCurrentFrame(ctx, phase, transitionType, transitionFrames)
    local t = common.normalizeSceneTransitionType(transitionType)
    local frames = common.normalizeSceneTransitionFrames(transitionFrames)
    if not common.shouldRunSceneTransition(t, frames) then return end
    if isSceneSlideTransition(t) or t == "cross_dissolve" or t == "zoom" or t == "flip_horizontal" or
        t == "flip_vertical" then
      return
    end
    local runtime = _G and _G.CONFIG_UI
    if runtime then
      runtime.sceneDrawOffsetX = 0
      runtime.sceneDrawAlpha = 1
      runtime.sceneDrawScale = 1
      runtime.sceneDrawScaleX = 1
      runtime.sceneDrawScaleY = 1
      runtime.sceneFlipActive = false
      runtime.sceneFlipType = nil
      runtime.sceneFlipPhase = nil
    end
    local p = (tostring(phase or "out") == "in") and "in" or "out"
    for i = 1, frames do
      local progress = clamp01(i / frames)
      common.drawSceneTransitionOverlay(ctx, {
        phase = p,
        type = t,
        progress = progress,
        frame = i,
        frames = frames,
      })
      Screen.waitVblankStart()
      Screen.flip()
    end
  end
end

return transitions
