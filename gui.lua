-- gui.lua – Reusable ZayForge GUI Library
--
-- Provides: rounded rects, hit testing, button rendering, text fields,
-- screen scaling, safe font loading, and a consistent color palette.

local gui = {}

-- ===== Color Palette =====

gui.colors = {
    bg          = { 0.04, 0.04, 0.10 },
    panel       = { 0.08, 0.08, 0.14, 0.95 },
    panelBorder = { 0.25, 0.25, 0.35, 0.8 },
    text        = { 0.95, 0.95, 0.95 },
    textDim     = { 0.50, 0.50, 0.60 },
    textMuted   = { 0.35, 0.35, 0.40 },
    accent      = { 0.95, 0.55, 0.10 },
    accentGlow  = { 1.00, 0.75, 0.30 },
    danger      = { 0.85, 0.15, 0.15 },
    dangerGlow  = { 1.00, 0.20, 0.20 },
    success     = { 0.15, 0.55, 0.25 },
    info        = { 0.20, 0.50, 0.80 },
    selected    = { 0.15, 0.40, 0.70, 0.80 },
    hover       = { 0.15, 0.45, 0.80, 0.80 },
    inputBg     = { 0.08, 0.08, 0.14, 0.90 },
    inputFocus  = { 0.15, 0.15, 0.25 },
    fieldBorder = { 0.40, 0.60, 1.00 },
}

-- ===== Screen Scaling =====

function gui.scale()
    local ww, wh = love.graphics.getDimensions()
    return math.min(ww / 1280, wh / 720, 1.5)
end

-- ===== Drawing Primitives =====

--- Draw a rounded rectangle with optional fill and border.
--- Color tables should have 3 components (RGB) or 4 (RGBA).
function gui.drawRect(x, y, w, h, r, fillColor, borderColor, borderWidth)
    if fillColor then
        love.graphics.setColor(fillColor)
        love.graphics.rectangle("fill", x, y, w, h, r, r)
    end
    if borderColor and borderWidth and borderWidth > 0 then
        love.graphics.setColor(borderColor)
        love.graphics.setLineWidth(borderWidth)
        love.graphics.rectangle("line", x, y, w, h, r, r)
    end
end

-- ===== Hit Testing =====

--- Check if a point is inside a rect {x, y, w, h}.
function gui.hitTest(px, py, rect)
    return px >= rect.x and px <= rect.x + rect.w
       and py >= rect.y and py <= rect.y + rect.h
end

-- ===== Font Helpers =====

--- Try to load a custom font, fall back to default size.
function gui.loadFont(path, size)
    local ok, font = pcall(love.graphics.newFont, path, size)
    if not ok or not font then
        font = love.graphics.newFont(size)
    end
    return font
end

-- ===== Label & Title =====

--- Draw a simple left-aligned text label.
--- @param text  string
--- @param x     number  left x coordinate
--- @param y     number  top y coordinate
--- @param font  love.Font (optional, defaults to 16px)
--- @param color table (optional, defaults to gui.colors.text)
function gui.drawLabel(text, x, y, font, color)
    font = font or love.graphics.newFont(16)
    love.graphics.setFont(font)
    love.graphics.setColor(color or gui.colors.text)
    love.graphics.print(text, x, y)
end

--- Draw a centered title text across the full screen width.
--- @param text string
--- @param y    number  top y coordinate
--- @param font love.Font (optional, defaults to 24px)
function gui.drawTitle(text, y, font)
    font = font or love.graphics.newFont(24)
    love.graphics.setFont(font)
    love.graphics.setColor(gui.colors.text)
    love.graphics.printf(text, 0, y, love.graphics.getWidth(), "center")
end

-- ===== Slider =====

--- Draw a horizontal slider with track, fill, and draggable thumb.
--- @param x         number  left x of the track
--- @param y         number  center y of the track
--- @param w         number  track width in pixels
--- @param value     number  current slider value
--- @param minVal    number  minimum bound
--- @param maxVal    number  maximum bound
--- @param isHovered boolean (optional) slightly enlarges the thumb
function gui.drawSlider(x, y, w, value, minVal, maxVal, isHovered)
    local trackH = 6
    local trackY = y - trackH / 2
    local trackR = trackH / 2

    -- Fraction [0, 1]
    local range = maxVal - minVal
    local t = range ~= 0 and ((value - minVal) / range) or 0
    t = math.max(0, math.min(1, t))

    local thumbX = x + t * w
    local thumbR = isHovered and 9 or 7

    -- Track (full-width background)
    love.graphics.setColor(gui.colors.panelBorder)
    love.graphics.rectangle("fill", x, trackY, w, trackH, trackR, trackR)

    -- Filled portion of the track
    local fillW = thumbX - x
    if fillW > 0 then
        love.graphics.setColor(gui.colors.info)
        love.graphics.rectangle("fill", x, trackY, fillW, trackH, trackR, trackR)
    end

    -- Thumb body
    love.graphics.setColor(gui.colors.accent)
    love.graphics.circle("fill", thumbX, y, thumbR)

    -- Thumb border for contrast
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", thumbX, y, thumbR)
end

-- ===== Button Rendering =====

--- opts table:
---   label      - button text (string)
---   font       - font to use for text
---   isSelected - highlight state (bool)
---   isDisabled - greyed-out state (bool)
---   isDanger   - red style for exit/delete (bool)
---   isHovered  - hover highlight (bool, nil=ignore)
---   glow       - animation glow factor (0-1)

function gui.drawButton(btn, opts)
    opts = opts or {}
    local isSelected = opts.isSelected
    local isDisabled = opts.isDisabled
    local isDanger   = opts.isDanger
    local glow       = opts.glow or (isSelected and 1 or 0)

    -- Colors
    local fill, border
    if isDisabled then
        fill   = { 0.15, 0.15, 0.15, 0.7 }
        border = { 0.30, 0.30, 0.30, 0.5 }
    elseif isDanger then
        fill   = { 0.08, 0.08, 0.12, 0.9 }
        border = { 0.25, 0.25, 0.35, 1.0 }
        if glow > 0.01 then
            fill   = gui._lerp(fill,   { 0.85, 0.15, 0.15, 0.85 }, glow)
            border = gui._lerp(border, { 1.00, 0.20, 0.20, 1.00 }, glow)
        end
    else
        fill   = { 0.08, 0.08, 0.12, 0.9 }
        border = { 0.25, 0.25, 0.35, 1.0 }
        if glow > 0.01 then
            fill   = gui._lerp(fill,   { 0.95, 0.55, 0.10, 0.85 }, glow)
            border = gui._lerp(border, { 1.00, 0.70, 0.20, 1.00 }, glow)
        end
    end

    -- Shadow
    gui.drawRect(btn.x + 3, btn.y + 3, btn.w, btn.h, 20, { 0, 0, 0, 0.4 }, nil, 0)
    -- Body
    gui.drawRect(btn.x, btn.y, btn.w, btn.h, 20, fill, nil, 0)
    -- Border
    gui.drawRect(btn.x, btn.y, btn.w, btn.h, 20, nil, border, 3)
    -- Glow ring
    if glow > 0.01 and not isDisabled then
        local glowColor = isDanger
            and { 1, 0.3, 0.3, glow * 0.5 }
            or  { 1, 0.75, 0.3, glow * 0.5 }
        love.graphics.setColor(glowColor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", btn.x + 2, btn.y + 2, btn.w - 4, btn.h - 4, 19, 19)
    end

    -- Text
    local font = opts.font or love.graphics.newFont(18)
    love.graphics.setFont(font)
    local textH = font:getHeight()
    local textY = btn.y + (btn.h - textH) / 2
    -- Text shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.printf(opts.label or "", btn.x + 2, textY + 2, btn.w, "center")
    -- Text
    local textColor
    if isDisabled then textColor = { 0.4, 0.4, 0.4, 1 }
    elseif isSelected then textColor = { 0.05, 0.05, 0.1, 1 }
    else textColor = { 0.95, 0.95, 0.95, 1 } end
    love.graphics.setColor(textColor)
    love.graphics.printf(opts.label or "", btn.x, textY, btn.w, "center")
end

-- ===== Text Input Field =====

--- Draw a text field with optional blinking cursor bar.
--- @param rect      table   { x, y, w, h }
--- @param text      string  the displayed text
--- @param font      love.Font (optional, defaults to 18px)
--- @param focused   boolean whether the field has keyboard focus
--- @param cursorPos number  1-based cursor position, or nil/0 to hide cursor
function gui.drawTextField(rect, text, font, focused, cursorPos)
    font = font or love.graphics.newFont(18)
    love.graphics.setFont(font)

    -- Background
    love.graphics.setColor(focused and gui.colors.inputFocus or gui.colors.inputBg)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)

    -- Border
    love.graphics.setColor(focused and gui.colors.fieldBorder or gui.colors.panelBorder)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 6, 6)

    -- Text (vertically centered in the field)
    local textH = font:getHeight()
    local tx = rect.x + 10
    local ty = rect.y + (rect.h - textH) / 2
    love.graphics.setColor(gui.colors.text)
    love.graphics.print(text, tx, ty)

    -- Blinking cursor bar
    if focused and cursorPos and cursorPos >= 1 then
        local blink = (love.timer.getTime() * 2) % 2 < 1
        if blink then
            local cursorX = tx + font:getWidth(text:sub(1, cursorPos - 1))
            local pad = 2
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.setLineWidth(1.5)
            love.graphics.line(cursorX, ty + pad, cursorX, ty + textH - pad)
        end
    end
end

--- Legacy text field (delegates to gui.drawTextField).
--- When focused, the cursor blinks at the end of the text.
function gui.drawField(rect, text, font, focused)
    gui.drawTextField(rect, text, font, focused, focused and (#text + 1) or nil)
end

-- ===== Text Manipulation =====

--- Remove the character before pos from str (backspace).
--- Returns the new string and adjusted cursor position.
--- @param str string
--- @param pos number  1-based cursor position
--- @return string, number  newStr, newPos
function gui.backspace(str, pos)
    if #str == 0 or pos <= 1 then
        return str, pos
    end
    local newStr = str:sub(1, pos - 2) .. str:sub(pos)
    return newStr, pos - 1
end

-- ===== Background =====

function gui.drawPanel(x, y, w, h, r)
    gui.drawRect(x, y, w, h, r or 10, gui.colors.panel, gui.colors.panelBorder, 2)
end

-- ===== Internal =====

function gui._lerp(a, b, t)
    return { a[1] + (b[1] - a[1]) * t,
             a[2] + (b[2] - a[2]) * t,
             a[3] + (b[3] - a[3]) * t,
             a[4] + (b[4] - a[4]) * t }
end

return gui
