-- ZayForge – Main Menu Module

local logger = require("logger")
local lang = require("lang")
local menu = {}

-- Button configuration
local BUTTON_WIDTH = 300
local BUTTON_HEIGHT = 68
local MENU_BUTTONS_Y_RATIO = 0.45  -- Position buttons higher on screen (was 0.50)

-- Internal state
local state = "main"
local options = {
    {key = "menu_singleplayer"},
    {key = "menu_multiplayer"},
    {key = "menu_options"},
    {key = "menu_exit"}
}
local selected = 1

local logoImage = nil

-- Animation
local animTime = 0
local selectedGlow = 0
local tooltipAlpha = 0
local tooltipTarget = 0

-- Button layout
local buttons = {}
local buttonYStart = 0
local buttonSpacing = 24

-- Fonts
local fontButton, fontHint, fontTooltip
local arrowCursor = nil

-- Background particles
local particles = {}
local PARTICLE_COUNT = 80

-- ---- Helpers ----

local function createParticle()
    local ww, wh = love.graphics.getDimensions()
    return {
        x = love.math.random(0, ww),
        y = love.math.random(-10, wh + 10),
        speed = love.math.random(15, 40),
        radius = love.math.random(1, 2.5),
        alpha = love.math.random(150, 255) / 255,
    }
end

local function pointInRect(px, py, rect)
    return px >= rect.x and px <= rect.x + rect.w and
           py >= rect.y and py <= rect.y + rect.h
end

local function drawRoundedRect(x, y, w, h, r, fillColor, borderColor, borderWidth)
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

-- ---- Public functions ----

function menu.load()
    logger.info("Loading main menu...")
    
    logoImage = love.graphics.newImage("assets/images/header.png")
    
    local success = pcall(function()
        fontButton = love.graphics.newFont("assets/fonts/airstrike.ttf", 36)
        fontHint = love.graphics.newFont("assets/fonts/airstrikeacad.ttf", 16)
        fontTooltip = love.graphics.newFont("assets/fonts/airstrike.ttf", 18)
    end)
    
    if not success or not fontButton then
        logger.warn("Custom fonts not found, using fallback")
        fontButton = love.graphics.newFont(36)
        fontHint = love.graphics.newFont(16)
        fontTooltip = love.graphics.newFont(18)
    end

    arrowCursor = love.mouse.getSystemCursor("arrow")
    love.mouse.setCursor(arrowCursor)

    for i = 1, PARTICLE_COUNT do
        table.insert(particles, createParticle())
    end

    recalcButtons()
end

function recalcButtons()
    local ww, wh = love.graphics.getDimensions()
    buttonYStart = wh * MENU_BUTTONS_Y_RATIO
    buttons = {}
    for i, _ in ipairs(options) do
        local bx = ww / 2 - BUTTON_WIDTH / 2
        local by = buttonYStart + (i - 1) * (BUTTON_HEIGHT + buttonSpacing)
        buttons[i] = {x = bx, y = by, w = BUTTON_WIDTH, h = BUTTON_HEIGHT}
    end
end

function menu.update(dt)
    animTime = animTime + dt
    selectedGlow = selectedGlow + (1 - selectedGlow) * math.min(dt * 7, 1)
    tooltipAlpha = tooltipAlpha + (tooltipTarget - tooltipAlpha) * math.min(dt * 8, 1)

    for _, p in ipairs(particles) do
        p.y = p.y - p.speed * dt
        if p.y < -10 then
            p.y = love.graphics.getHeight() + 10
            p.x = love.math.random(0, love.graphics.getWidth())
        end
    end
end

function menu.keypressed(key)
    if state == "main" then
        if key == "up" then
            selected = selected - 1
            if selected < 1 then selected = #options end
            selectedGlow = 0
            updateTooltip()
        elseif key == "down" then
            selected = selected + 1
            if selected > #options then selected = 1 end
            selectedGlow = 0
            updateTooltip()
        elseif key == "return" or key == "kpenter" or key == "space" then
            activateOption(selected)
        end
    end
end

function menu.mousemoved(x, y, dx, dy)
    if state == "main" then
        local previousSelected = selected
        for i, btn in ipairs(buttons) do
            if pointInRect(x, y, btn) then
                if selected ~= i then
                    selected = i
                    selectedGlow = 0
                end
            end
        end
        if previousSelected ~= selected then
            updateTooltip()
        end
        love.mouse.setCursor(arrowCursor)
    end
end

function menu.mousepressed(x, y, button)
    if state == "main" and button == 1 then
        for i, btn in ipairs(buttons) do
            if pointInRect(x, y, btn) then
                if i == 2 then return end -- Multiplayer and Options disabled
                activateOption(i)
            end
        end
    end
end

function menu.resize(w, h)
    recalcButtons()
    particles = {}
    for i = 1, PARTICLE_COUNT do
        table.insert(particles, createParticle())
    end
end

-- ---- Internal ----

function updateTooltip()
    tooltipTarget = (selected == 2) and 1 or 0
end

function activateOption(idx)
    if idx == 1 then
        logger.info("Starting single player game")
        GameState.current = "game"
        GameState.game.load()
    elseif idx == 3 then
        logger.info("Opening options menu")
        GameState.current = "options"
        GameState.options.load()
    elseif idx == 4 then
        logger.info("Exiting game")
        love.event.quit()
    end
end

-- ---- Drawing ----

function drawBackground()
    local ww, wh = love.graphics.getDimensions()
    love.graphics.setColor(0.02, 0.02, 0.08)
    love.graphics.rectangle("fill", 0, 0, ww, wh)

    for y = 0, wh do
        local t = y / wh
        love.graphics.setColor(0.03 + t * 0.02, 0.03 + t * 0.04, 0.12 + t * 0.10, 0.3)
        love.graphics.line(0, y, ww, y)
    end

    for _, p in ipairs(particles) do
        love.graphics.setColor(1, 1, 1, p.alpha * 0.7)
        love.graphics.circle("fill", p.x, p.y, p.radius)
    end
end

function drawLogo()
    if not logoImage then return end
    local ww, wh = love.graphics.getDimensions()
    local maxW, maxH = ww * 0.95, wh * 0.60
    local scale = math.min(maxW / logoImage:getWidth(), maxH / logoImage:getHeight())
    local bobOffset = math.sin(animTime * 1.5) * 8
    local pulse = 1 + math.sin(animTime * 2.2) * 0.03
    local finalScale = scale * pulse
    local lx = ww / 2 - logoImage:getWidth() * finalScale / 2
    local ly = wh * 0.01 + bobOffset

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(logoImage, lx, ly, 0, finalScale, finalScale)
end

function drawTooltip(btn)
    if tooltipAlpha <= 0.01 then return end
    
    local tooltipText = "(Coming Soon)"
    love.graphics.setFont(fontTooltip)
    local textW = fontTooltip:getWidth(tooltipText)
    local textH = fontTooltip:getHeight()
    local padding = 8
    
    local tx = btn.x + btn.w + 16
    local ty = btn.y + (btn.h - textH) / 2
    local bgW, bgH = textW + padding * 2, textH + padding
    
    love.graphics.setColor(0, 0, 0, 0.7 * tooltipAlpha)
    love.graphics.rectangle("fill", tx, ty, bgW, bgH, 8, 8)
    love.graphics.setColor(0.7, 0.7, 0.7, 0.5 * tooltipAlpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", tx, ty, bgW, bgH, 8, 8)
    love.graphics.setColor(1, 0.7, 0.3, tooltipAlpha)
    love.graphics.printf(tooltipText, tx + padding, ty + padding/2, textW, "center")
end

function drawButton(btn, optionText, isSelected, glowAmount, buttonIndex)
    local glow = isSelected and glowAmount or 0
    local isDisabled = (buttonIndex == 2)

    local fillBase, fillGlow, borderBase, borderGlow
    if isDisabled then
        fillBase, fillGlow = {0.15, 0.15, 0.15, 0.7}, {0.2, 0.2, 0.2, 0.7}
        borderBase, borderGlow = {0.3, 0.3, 0.3, 0.5}, {0.4, 0.4, 0.4, 0.5}
    elseif buttonIndex == 4 then
        fillBase, fillGlow = {0.08, 0.08, 0.12, 0.9}, {0.85, 0.15, 0.15, 0.85}
        borderBase, borderGlow = {0.25, 0.25, 0.35, 1}, {1, 0.2, 0.2, 1}
    else
        fillBase, fillGlow = {0.08, 0.08, 0.12, 0.9}, {0.95, 0.55, 0.1, 0.85}
        borderBase, borderGlow = {0.25, 0.25, 0.35, 1}, {1, 0.7, 0.2, 1}
    end

    local function lerpColor(a, b, t)
        return {a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t}
    end

    local fill = lerpColor(fillBase, fillGlow, glow)
    local border = lerpColor(borderBase, borderGlow, glow)

    drawRoundedRect(btn.x + 3, btn.y + 3, btn.w, btn.h, 20, {0,0,0,0.4}, nil, 0)
    drawRoundedRect(btn.x, btn.y, btn.w, btn.h, 20, fill, nil, 0)
    drawRoundedRect(btn.x, btn.y, btn.w, btn.h, 20, nil, border, 3)

    if glow > 0.01 and not isDisabled then
        love.graphics.setColor(buttonIndex == 4 and {1, 0.3, 0.3, glow * 0.5} or {1, 0.75, 0.3, glow * 0.5})
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", btn.x + 2, btn.y + 2, btn.w - 4, btn.h - 4, 19, 19)
    end

    love.graphics.setFont(fontButton)
    local textH = fontButton:getHeight()
    local textY = btn.y + (btn.h - textH) / 2
    
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.printf(optionText, btn.x + 2, textY + 2, btn.w, "center")
    
    local textColor
    if isDisabled then textColor = {0.4, 0.4, 0.4, 1}
    elseif isSelected then textColor = {0.05, 0.05, 0.1, 1}
    else textColor = {0.95, 0.95, 0.95, 1} end
    
    love.graphics.setColor(textColor)
    love.graphics.printf(optionText, btn.x, textY, btn.w, "center")
    
    if isDisabled and isSelected then drawTooltip(btn) end
end

function menu.draw()
    drawBackground()
    drawLogo()

    for i, option in ipairs(options) do
        local optionText = lang.t(option.key)
        drawButton(buttons[i], optionText, i == selected, selectedGlow, i)
    end
end

return menu