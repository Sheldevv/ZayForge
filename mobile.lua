-- mobile.lua – Touch controls & mobile layout for ZayForge

local mobile = {}

-- ===== Device Detection =====
mobile.isTouchDevice = false -- set during init

-- ===== Fonts (set externally) =====
local fonts = {}

-- ===== Joystick State =====
local joystick = {
    active = false,
    touchId = nil,
    baseX = 0,
    baseY = 0,
    stickX = 0,
    stickY = 0,
    radius = 0,   -- computed dynamically
    deadzone = 0, -- computed dynamically
    direction = { x = 0, y = 0 }
}

-- ===== On-Screen Buttons =====
local buttons = {
    mine      = { x = 0, y = 0, w = 0, h = 0, active = false, touchId = nil },
    place     = { x = 0, y = 0, w = 0, h = 0, active = false, touchId = nil },
    inventory = { x = 0, y = 0, w = 0, h = 0, active = false, touchId = nil },
}

-- ===== Internal =====

local function isMobileOS()
    local osName = love.system.getOS()
    return osName == "Android" or osName == "iOS"
end

-- ===== Public API =====

function mobile.init()
    mobile.isTouchDevice = isMobileOS()
end

function mobile.setFonts(uiFont, smallFont)
    fonts.ui = uiFont
    fonts.small = smallFont
end

-- Scale-aware layout.  Call on load and on every resize.
function mobile.updateLayout(screenW, screenH)
    local scale         = math.min(screenW / 1280, screenH / 720, 1.5)

    -- -------- Joystick (bottom-left) --------
    joystick.radius     = math.floor(64 * scale)
    joystick.deadzone   = math.floor(16 * scale)
    joystick.baseX      = math.floor(screenW * 0.12)
    joystick.baseY      = screenH - math.floor(screenH * 0.12)
    joystick.stickX     = joystick.baseX
    joystick.stickY     = joystick.baseY

    -- -------- Action buttons (bottom-right, vertical column) --------
    local btnSize       = math.floor(64 * scale)
    local margin        = math.floor(20 * scale)
    local startX        = screenW - margin - btnSize
    local startY        = screenH - margin - btnSize

    buttons.mine.x      = startX
    buttons.mine.y      = startY - (btnSize + margin) * 2
    buttons.mine.w      = btnSize
    buttons.mine.h      = btnSize

    buttons.place.x     = startX
    buttons.place.y     = startY - (btnSize + margin)
    buttons.place.w     = btnSize
    buttons.place.h     = btnSize

    buttons.inventory.x = startX
    buttons.inventory.y = startY
    buttons.inventory.w = btnSize
    buttons.inventory.h = btnSize
end

-- ===== Touch Handlers =====

function mobile.touchpressed(id, x, y)
    -- Check action buttons first (they are on top drawn last)
    for name, btn in pairs(buttons) do
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            btn.active = true
            btn.touchId = id
            return name
        end
    end

    -- Joystick area (left half of screen)
    local dx = x - joystick.baseX
    local dy = y - joystick.baseY
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist <= joystick.radius * 1.5 then -- generous hit area
        joystick.active = true
        joystick.touchId = id
        joystick.stickX = x
        joystick.stickY = y
        -- Set direction
        local dirX, dirY = mobile._updateJoystickDir(dx, dy)
        return "joystick"
    end

    return nil
end

function mobile.touchmoved(id, x, y)
    if joystick.active and joystick.touchId == id then
        local dx = x - joystick.baseX
        local dy = y - joystick.baseY
        local dist = math.sqrt(dx * dx + dy * dy)

        -- Clamp to radius
        if dist > joystick.radius then
            local ratio = joystick.radius / dist
            dx = dx * ratio
            dy = dy * ratio
        end

        joystick.stickX = joystick.baseX + dx
        joystick.stickY = joystick.baseY + dy
        mobile._updateJoystickDir(dx, dy)
        return true
    end
    return false
end

function mobile.touchreleased(id, x, y)
    -- Joystick release
    if joystick.active and joystick.touchId == id then
        joystick.active = false
        joystick.touchId = nil
        joystick.stickX = joystick.baseX
        joystick.stickY = joystick.baseY
        joystick.direction.x = 0
        joystick.direction.y = 0
        return "joystick"
    end

    -- Button release
    for name, btn in pairs(buttons) do
        if btn.active and btn.touchId == id then
            btn.active = false
            btn.touchId = nil
            return name
        end
    end

    return nil
end

-- ===== Direction / Input =====

function mobile.getDirection()
    return joystick.direction.x, joystick.direction.y
end

function mobile.isButtonActive(name)
    return buttons[name] and buttons[name].active
end

-- ===== Internal Helpers =====

function mobile._updateJoystickDir(dx, dy)
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 0 then
        joystick.direction.x = dx / dist
        joystick.direction.y = dy / dist
    else
        joystick.direction.x = 0
        joystick.direction.y = 0
    end

    -- Deadzone
    if dist < joystick.deadzone then
        joystick.direction.x = 0
        joystick.direction.y = 0
    end

    return joystick.direction.x, joystick.direction.y
end

-- ===== Drawing =====

function mobile.draw()
    -- Joystick base
    love.graphics.setColor(0.15, 0.15, 0.25, 0.55)
    love.graphics.circle("fill", joystick.baseX, joystick.baseY, joystick.radius)
    love.graphics.setColor(0.4, 0.4, 0.5, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", joystick.baseX, joystick.baseY, joystick.radius)

    -- Joystick stick
    love.graphics.setColor(0.85, 0.85, 0.95, 0.75)
    love.graphics.circle("fill", joystick.stickX, joystick.stickY, joystick.radius * 0.38)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.circle("line", joystick.stickX, joystick.stickY, joystick.radius * 0.38)

    -- -------- Buttons --------
    local function drawButton(btn, label, r, g, b)
        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.rectangle("fill", btn.x + 3, btn.y + 3, btn.w, btn.h, btn.w * 0.2)

        -- Body
        local alpha = btn.active and 1.0 or 0.75
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, btn.w * 0.2)

        -- Border
        love.graphics.setColor(1, 1, 1, 0.3 * alpha)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, btn.w * 0.2)

        -- Label
        local f = fonts.small or love.graphics.newFont(12)
        love.graphics.setFont(f)
        love.graphics.setColor(1, 1, 1, 0.9)
        local fh = f:getHeight()
        love.graphics.printf(label, btn.x, btn.y + (btn.h - fh) / 2, btn.w, "center")
    end

    drawButton(buttons.place, "Place", 0.25, 0.55, 0.25)
    drawButton(buttons.mine, "Mine", 0.25, 0.25, 0.55)
    drawButton(buttons.inventory, "Inv", 0.55, 0.30, 0.30)

    -- -------- Crosshair / aim point (middle of screen) --------
    local cx = love.graphics.getWidth() / 2
    local cy = love.graphics.getHeight() / 2
    local cr = 6
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", cx, cy, cr)
    love.graphics.line(cx - cr - 3, cy, cx + cr + 3, cy)
    love.graphics.line(cx, cy - cr - 3, cx, cy + cr + 3)
end

return mobile
