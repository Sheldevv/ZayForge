-- ZayForge – Main Menu Module

local logger = require("logger")
local lang = require("lang")
local online = require("online")
local saveLib = require("save")
local menu = {}

-- Button configuration
local BUTTON_WIDTH = 300
local BUTTON_HEIGHT = 68
local MENU_BUTTONS_Y_RATIO = 0.45 -- Position buttons higher on screen (was 0.50)

-- Internal state
local state = "main"
local options = {
    { key = "menu_singleplayer" },
    { key = "menu_multiplayer" },
    { key = "menu_options" },
    { key = "menu_exit" }
}
local selected = 1

-- World selection state
local worldSelectSelected = 1
local worldList = {}      -- Cached list of worlds for display
local worldListButtons = {} -- Hit areas for each world row

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

function menu.load(argv)
    logger.info("Loading main menu...")

    state = "main"

    -- Parse online args if passed from main.lua (may be nil on direct launch)
    if argv then
        online.parseArgs(argv)
    end

    -- Fetch profile if online but not yet loaded
    if online.enabled and not online.isOnline() then
        coroutine.wrap(function()
            online.fetchProfile()
        end)()
    end

    logoImage = love.graphics.newImage("assets/images/header.png")

    -- Scale font sizes for mobile screens
    local ww, wh = love.graphics.getDimensions()
    local scale = math.min(ww / 1280, wh / 720, 1.5)
    local baseFontSize = math.floor(36 * scale)
    local baseHintSize = math.floor(16 * scale)
    local baseTooltipSize = math.floor(18 * scale)

    local success = pcall(function()
        fontButton = love.graphics.newFont("assets/fonts/airstrike.ttf", baseFontSize)
        fontHint = love.graphics.newFont("assets/fonts/airstrikeacad.ttf", baseHintSize)
        fontTooltip = love.graphics.newFont("assets/fonts/airstrike.ttf", baseTooltipSize)
    end)

    if not success or not fontButton then
        logger.warn("Custom fonts not found, using fallback")
        fontButton = love.graphics.newFont(baseFontSize)
        fontHint = love.graphics.newFont(baseHintSize)
        fontTooltip = love.graphics.newFont(baseTooltipSize)
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
    local scale = math.min(ww / 1280, wh / 720, 1.5)
    local btnW = math.floor(BUTTON_WIDTH * scale)
    local btnH = math.floor(BUTTON_HEIGHT * scale)
    local spacing = math.floor(buttonSpacing * scale)
    buttonYStart = wh * MENU_BUTTONS_Y_RATIO
    buttons = {}
    for i, _ in ipairs(options) do
        local bx = ww / 2 - btnW / 2
        local by = buttonYStart + (i - 1) * (btnH + spacing)
        buttons[i] = { x = bx, y = by, w = btnW, h = btnH }
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
    if state == "world_select" then
        local maxItems = #worldList + 1 -- +1 for "Create New"
        if key == "up" then
            worldSelectSelected = worldSelectSelected - 1
            if worldSelectSelected < 1 then worldSelectSelected = maxItems end
        elseif key == "down" then
            worldSelectSelected = worldSelectSelected + 1
            if worldSelectSelected > maxItems then worldSelectSelected = 1 end
        elseif key == "return" or key == "kpenter" or key == "space" then
            if worldSelectSelected <= #worldList then
                local w = worldList[worldSelectSelected]
                startWorld(w.slot, w.name)
            else
                createNewWorld()
            end
        elseif key == "escape" or key == "back" then
            state = "main"
        elseif key == "delete" or key == "x" then
            if worldSelectSelected <= #worldList then
                local w = worldList[worldSelectSelected]
                saveLib.deleteWorld(w.slot)
                refreshWorldList()
                if worldSelectSelected > #worldList + 1 then
                    worldSelectSelected = math.max(1, #worldList + 1)
                end
            end
        end
        return
    end

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
    if state == "world_select" then
        for i, btn in ipairs(worldListButtons) do
            if pointInRect(x, y, btn) then
                worldSelectSelected = i
            end
        end
        return
    end

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
    if state == "world_select" and button == 1 then
        for i, btn in ipairs(worldListButtons) do
            if pointInRect(x, y, btn) then
                if i <= #worldList then
                    local w = worldList[i]
                    startWorld(w.slot, w.name)
                else
                    createNewWorld()
                end
                return
            end
        end
        return
    end

    if state == "main" and button == 1 then
        for i, btn in ipairs(buttons) do
            if pointInRect(x, y, btn) then
                if i == 2 then return end -- Multiplayer disabled
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
        -- Go to world selection
        logger.info("Opening world selection")
        state = "world_select"
        worldSelectSelected = 1
        refreshWorldList()
    elseif idx == 3 then
        logger.info("Opening options menu")
        GameState.current = "options"
        GameState.options.load()
    elseif idx == 4 then
        logger.info("Exiting game")
        love.event.quit()
    end
end

-- ---- World Selection ----

function refreshWorldList()
    worldList = {}
    worldListButtons = {}
    local saves = saveLib.getSaves()
    for _, s in pairs(saves) do
        if s then
            worldList[#worldList + 1] = s
        end
    end
    table.sort(worldList, function(a, b) return (a.lastPlayed or "") > (b.lastPlayed or "") end)
end

function startWorld(slot, name)
    logger.info("Starting world: " .. (name or "New World"))
    GameState.current = "game"
    GameState.game.load({slot = slot, name = name})
end

function createNewWorld()
    local slot = saveLib.getNextSlot()
    local name = "World " .. tostring(slot)
    startWorld(slot, name)
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
    love.graphics.printf(tooltipText, tx + padding, ty + padding / 2, textW, "center")
end

function drawButton(btn, optionText, isSelected, glowAmount, buttonIndex)
    local glow = isSelected and glowAmount or 0
    local isDisabled = (buttonIndex == 2)

    local fillBase, fillGlow, borderBase, borderGlow
    if isDisabled then
        fillBase, fillGlow = { 0.15, 0.15, 0.15, 0.7 }, { 0.2, 0.2, 0.2, 0.7 }
        borderBase, borderGlow = { 0.3, 0.3, 0.3, 0.5 }, { 0.4, 0.4, 0.4, 0.5 }
    elseif buttonIndex == 4 then
        fillBase, fillGlow = { 0.08, 0.08, 0.12, 0.9 }, { 0.85, 0.15, 0.15, 0.85 }
        borderBase, borderGlow = { 0.25, 0.25, 0.35, 1 }, { 1, 0.2, 0.2, 1 }
    else
        fillBase, fillGlow = { 0.08, 0.08, 0.12, 0.9 }, { 0.95, 0.55, 0.1, 0.85 }
        borderBase, borderGlow = { 0.25, 0.25, 0.35, 1 }, { 1, 0.7, 0.2, 1 }
    end

    local function lerpColor(a, b, t)
        return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t }
    end

    local fill = lerpColor(fillBase, fillGlow, glow)
    local border = lerpColor(borderBase, borderGlow, glow)

    drawRoundedRect(btn.x + 3, btn.y + 3, btn.w, btn.h, 20, { 0, 0, 0, 0.4 }, nil, 0)
    drawRoundedRect(btn.x, btn.y, btn.w, btn.h, 20, fill, nil, 0)
    drawRoundedRect(btn.x, btn.y, btn.w, btn.h, 20, nil, border, 3)

    if glow > 0.01 and not isDisabled then
        love.graphics.setColor(buttonIndex == 4 and { 1, 0.3, 0.3, glow * 0.5 } or { 1, 0.75, 0.3, glow * 0.5 })
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", btn.x + 2, btn.y + 2, btn.w - 4, btn.h - 4, 19, 19)
    end

    love.graphics.setFont(fontButton)
    local textH = fontButton:getHeight()
    local textY = btn.y + (btn.h - textH) / 2

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.printf(optionText, btn.x + 2, textY + 2, btn.w, "center")

    local textColor
    if isDisabled then
        textColor = { 0.4, 0.4, 0.4, 1 }
    elseif isSelected then
        textColor = { 0.05, 0.05, 0.1, 1 }
    else
        textColor = { 0.95, 0.95, 0.95, 1 }
    end

    love.graphics.setColor(textColor)
    love.graphics.printf(optionText, btn.x, textY, btn.w, "center")

    if isDisabled and isSelected then drawTooltip(btn) end
end

function menu.draw()
    if state == "world_select" then
        drawWorldSelect()
        return
    end

    drawBackground()
    drawLogo()

    for i, option in ipairs(options) do
        local optionText = lang.t(option.key)
        drawButton(buttons[i], optionText, i == selected, selectedGlow, i)
    end

    if online.isOnline() then
        local uname = online.getUsername() or "Player"
        love.graphics.setColor(0, 0.686, 1)
        love.graphics.printf("Welcome, " .. uname .. "!", 0, love.graphics.getHeight() / 2 - 80, love.graphics.getWidth(), "center")
    elseif online.enabled then
        love.graphics.setColor(0.8, 0.6, 0.2)
        love.graphics.printf("Connecting...", 0, love.graphics.getHeight() / 2 - 80, love.graphics.getWidth(), "center")
    end
end

function menu.touchpressed(id, x, y, dx, dy, pressure)
    if state == "world_select" then
        menu.mousepressed(x, y, 1)
        return
    end
    menu.mousepressed(x, y, 1) -- simulate left click
end

function menu.touchmoved(id, x, y, dx, dy, pressure)
    if state == "world_select" then
        menu.mousemoved(x, y, dx, dy)
        return
    end
    menu.mousemoved(x, y, dx, dy)
end

function menu.touchreleased() end

-- ---- World Selection Drawing ----

function drawWorldSelect()
    local ww, wh = love.graphics.getDimensions()
    local scale = math.min(ww / 1280, wh / 720, 1.5)

    -- Dark background
    love.graphics.setColor(0.04, 0.04, 0.10)
    love.graphics.rectangle("fill", 0, 0, ww, wh)

    -- Title
    local titleFont = love.graphics.newFont(math.floor(32 * scale))
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.printf("Select World", 0, 20, ww, "center")

    -- World list
    local listY = math.floor(80 * scale)
    local rowH = math.floor(56 * scale)
    local rowW = math.floor(600 * scale)
    local rowX = (ww - rowW) / 2
    local smallFont = love.graphics.newFont(math.floor(14 * scale))
    local tinyFont = love.graphics.newFont(math.floor(11 * scale))

    worldListButtons = {}

    for i, w in ipairs(worldList) do
        local y = listY + (i - 1) * (rowH + 4)
        local isSelected = (i == worldSelectSelected)
        local btn = {x = rowX, y = y, w = rowW, h = rowH}
        worldListButtons[i] = btn

        -- Row background
        if isSelected then
            love.graphics.setColor(0.15, 0.40, 0.70, 0.8)
        else
            love.graphics.setColor(0.08, 0.08, 0.14, 0.7)
        end
        love.graphics.rectangle("fill", rowX, y, rowW, rowH, 8, 8)
        love.graphics.setColor(0.25, 0.25, 0.35, 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", rowX, y, rowW, rowH, 8, 8)

        -- World name
        love.graphics.setFont(smallFont)
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.print(w.name or "Unknown", rowX + 14, y + 6)

        -- Play time / info
        love.graphics.setFont(tinyFont)
        love.graphics.setColor(0.6, 0.6, 0.7)
        local info = "Play time: " .. math.floor((w.playTime or 0) / 60) .. "m"
        if w.lastPlayed then
            info = info .. "  |  Last played: " .. w.lastPlayed
        end
        love.graphics.print(info, rowX + 14, y + 28)

        -- Delete hint
        if isSelected then
            love.graphics.setColor(0.8, 0.3, 0.3, 0.8)
            love.graphics.print("Press X to delete", rowX + rowW - 130, y + 28)
        end
    end

    -- "Create New World" button
    local newIdx = #worldList + 1
    local newY = listY + (#worldList) * (rowH + 4) + 10
    local newBtn = {x = rowX, y = newY, w = rowW, h = rowH}
    worldListButtons[newIdx] = newBtn
    local isNewSelected = (newIdx == worldSelectSelected)

    if isNewSelected then
        love.graphics.setColor(0.15, 0.55, 0.25, 0.8)
    else
        love.graphics.setColor(0.08, 0.18, 0.08, 0.7)
    end
    love.graphics.rectangle("fill", rowX, newY, rowW, rowH, 8, 8)
    love.graphics.setColor(0.25, 0.45, 0.25, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", rowX, newY, rowW, rowH, 8, 8)
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.3, 0.9, 0.3)
    love.graphics.printf("+ Create New World", rowX, newY + 16, rowW, "center")

    -- Empty state
    if #worldList == 0 then
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.printf("No worlds yet. Create one below!", 0, listY + 40, ww, "center")
    end

    -- Back hint
    love.graphics.setFont(tinyFont)
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.printf("ESC: Back to menu  |  Enter: Load  |  X: Delete", 0, wh - 30, ww, "center")
end

return menu
