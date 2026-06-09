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

function gui.drawField(rect, text, font, focused)
    -- Background
    love.graphics.setColor(focused and gui.colors.inputFocus or gui.colors.inputBg)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
    -- Border
    love.graphics.setColor(focused and gui.colors.fieldBorder or gui.colors.panelBorder)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 6, 6)
    -- Text
    font = font or love.graphics.newFont(18)
    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1)
    local display = text .. (focused and "_" or "")
    love.graphics.print(display, rect.x + 10, rect.y + 8)
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
