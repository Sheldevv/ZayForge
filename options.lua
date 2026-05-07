-- ZayForge – Options Menu Module
-- Comprehensive options/settings menu with language support

local logger = require("logger")
local lang = require("lang")
local options = {}

-- ===== State =====
local currentTab = "language"  -- 'language', 'graphics', 'audio', 'gameplay'
local selectedOption = 1
local hoveredOption = nil

local tabs = {"language", "graphics", "audio", "gameplay"}
local tabNames = {}

-- Current settings (will be populated from lang)
local settings = {
    language = "en-US",
    fullscreen = false,
    vsync = true,
    masterVolume = 100,
    musicVolume = 80,
    sfxVolume = 80,
    difficulty = "normal",
    showDebug = false,
}

-- ===== UI Configuration =====
local PADDING = 20
local TAB_HEIGHT = 50
local OPTION_HEIGHT = 45
local OPTION_PADDING = 15
local SLIDER_WIDTH = 250
local BUTTON_WIDTH = 140
local BUTTON_HEIGHT = 40

-- Fonts
local fontTab, fontOption, fontSmall
local TAB_FONT_SIZE = 20
local OPTION_FONT_SIZE = 18
local SMALL_FONT_SIZE = 14

-- ===== Helper Functions =====

local function loadFonts()
    local success = pcall(function()
        fontTab = love.graphics.newFont("assets/fonts/airstrike.ttf", TAB_FONT_SIZE)
        fontOption = love.graphics.newFont("assets/fonts/airstrike.ttf", OPTION_FONT_SIZE)
        fontSmall = love.graphics.newFont("assets/fonts/airstrike.ttf", SMALL_FONT_SIZE)
    end)
    
    if not success then
        fontTab = love.graphics.newFont(TAB_FONT_SIZE)
        fontOption = love.graphics.newFont(OPTION_FONT_SIZE)
        fontSmall = love.graphics.newFont(SMALL_FONT_SIZE)
    end
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

local function drawButton(x, y, w, h, text, isHovered, isSelected)
    local fillColor
    if isSelected then
        fillColor = {0.2, 0.6, 1, 0.9}
    elseif isHovered then
        fillColor = {0.15, 0.45, 0.8, 0.8}
    else
        fillColor = {0.08, 0.08, 0.12, 0.7}
    end
    
    drawRoundedRect(x, y, w, h, 8, fillColor, {0.4, 0.4, 0.5, 1}, 2)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fontOption)
    local textH = fontOption:getHeight()
    love.graphics.printf(text, x, y + (h - textH) / 2, w, "center")
end

local function drawSlider(x, y, w, h, value, maxValue)
    -- Background
    drawRoundedRect(x, y + h / 2 - 3, w, 6, 3, {0.1, 0.1, 0.1, 0.8}, {0.3, 0.3, 0.3, 1}, 1)
    
    -- Fill
    local fillWidth = (value / maxValue) * w
    drawRoundedRect(x, y + h / 2 - 3, fillWidth, 6, 3, {0.2, 0.7, 1, 1}, nil, 0)
    
    -- Thumb
    local thumbX = x + (value / maxValue) * w - 6
    drawRoundedRect(thumbX, y + h / 2 - 10, 12, 20, 4, {0.3, 0.8, 1, 1}, {0.5, 0.9, 1, 1}, 2)
end

local function pointInRect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

local function getOptionsByTab(tab)
    if tab == "language" then
        local languageList = lang.getAvailableLanguages()
        local languageOpts = {}
        for _, l in ipairs(languageList) do
            table.insert(languageOpts, {
                type = "language_button",
                label = l.name,
                langId = l.id,
                isCurrent = (l.id == settings.language)
            })
        end
        return languageOpts
    elseif tab == "graphics" then
        return {
            {type = "toggle", label = lang.t("graphics_fullscreen"), key = "fullscreen", value = settings.fullscreen},
            {type = "toggle", label = lang.t("graphics_vsync"), key = "vsync", value = settings.vsync},
        }
    elseif tab == "audio" then
        return {
            {type = "slider", label = lang.t("audio_master_volume"), key = "masterVolume", value = settings.masterVolume, max = 100},
            {type = "slider", label = lang.t("audio_music_volume"), key = "musicVolume", value = settings.musicVolume, max = 100},
            {type = "slider", label = lang.t("audio_sfx_volume"), key = "sfxVolume", value = settings.sfxVolume, max = 100},
        }
    elseif tab == "gameplay" then
        return {
            {type = "difficulty", label = lang.t("gameplay_difficulty"), key = "difficulty", value = settings.difficulty},
            {type = "toggle", label = lang.t("gameplay_show_debug"), key = "showDebug", value = settings.showDebug},
        }
    end
    return {}
end

-- ===== Public Functions =====

function options.load()
    logger.info("Loading options menu...")
    loadFonts()
    
    -- Load saved settings
    local success, content = pcall(function()
        return love.filesystem.read("settings.txt")
    end)
    
    if success and content then
        local chunk, err = loadstring("return " .. content)
        if chunk then
            local ok, savedSettings = pcall(chunk)
            if ok and type(savedSettings) == "table" then
                -- Load saved settings while keeping defaults for missing keys
                for k, v in pairs(savedSettings) do
                    if settings[k] ~= nil then
                        settings[k] = v
                    end
                end
            end
        end
    end
    
    -- Sync with current state
    settings.language = lang.getCurrent()
    settings.showDebug = GameState.debug or false
    settings.fullscreen = love.window.getFullscreen()
    
    -- Update tab names with translations
    tabNames = {
        language = lang.t("options_language"),
        graphics = lang.t("options_graphics"),
        audio = lang.t("options_audio"),
        gameplay = lang.t("options_gameplay"),
    }
    
    selectedOption = 1
    hoveredOption = nil
end

function options.save()
    -- Save current settings to file
    local serialized = "return {\n"
    for k, v in pairs(settings) do
        if type(v) == "string" then
            serialized = serialized .. "  " .. k .. " = \"" .. v:gsub('"', '\\"') .. "\",\n"
        elseif type(v) == "boolean" then
            serialized = serialized .. "  " .. k .. " = " .. tostring(v) .. ",\n"
        elseif type(v) == "number" then
            serialized = serialized .. "  " .. k .. " = " .. v .. ",\n"
        end
    end
    serialized = serialized .. "}\n"
    
    love.filesystem.write("settings.txt", serialized)
    logger.debug("Settings saved")
end

function options.update(dt)
    -- Animation/UI updates can go here
end

function options.draw()
    local ww, wh = love.graphics.getDimensions()
    
    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1)
    love.graphics.rectangle("fill", 0, 0, ww, wh)
    
    -- Title
    love.graphics.setColor(0.95, 0.95, 0.95, 1)
    local titleFont = love.graphics.newFont(36)
    love.graphics.setFont(titleFont)
    love.graphics.printf(lang.t("options_title"), 0, 20, ww, "center")
    
    -- Tab buttons
    local tabButtonWidth = 120
    local totalTabWidth = #tabs * (tabButtonWidth + 10)
    local tabStartX = ww / 2 - totalTabWidth / 2
    local tabY = 80
    
    for i, tab in ipairs(tabs) do
        local tabX = tabStartX + (i - 1) * (tabButtonWidth + 10)
        local isSelected = (tab == currentTab)
        local isHovered = (hoveredOption == "tab_" .. i)
        
        drawButton(tabX, tabY, tabButtonWidth, TAB_HEIGHT, tabNames[tab] or tab, isHovered, isSelected)
    end
    
    -- Content area
    local contentY = tabY + TAB_HEIGHT + 30
    local contentX = PADDING
    local contentWidth = ww - 2 * PADDING
    local contentHeight = wh - contentY - PADDING - BUTTON_HEIGHT - 20
    
    -- Content background
    drawRoundedRect(contentX, contentY - 10, contentWidth, contentHeight, 8, 
        {0.08, 0.08, 0.12, 0.6}, {0.3, 0.3, 0.4, 0.8}, 2)
    
    -- Draw options based on current tab
    local opts = getOptionsByTab(currentTab)
    love.graphics.setFont(fontOption)
    
    for i, opt in ipairs(opts) do
        local optY = contentY + (i - 1) * (OPTION_HEIGHT + OPTION_PADDING)
        
        if currentTab == "language" then
            -- Language selection buttons
            local btnW = 160
            local btnH = OPTION_HEIGHT
            local btnX = contentX + contentWidth / 2 - btnW / 2
            local isCurrent = opt.isCurrent
            local isHovered = (hoveredOption == "lang_" .. i)
            
            -- Label
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.printf(opt.label, contentX + 20, optY + (btnH - fontOption:getHeight()) / 2, 200, "left")
            
            -- Current language indicator
            if isCurrent then
                love.graphics.setColor(0.2, 0.8, 0.2, 1)
                love.graphics.printf("✓ " .. lang.t("apply"), contentX + 240, optY + (btnH - fontOption:getHeight()) / 2, 100, "left")
            else
                drawButton(btnX, optY, btnW, btnH, opt.label, isHovered, false)
            end
            
        elseif opt.type == "toggle" then
            -- Toggle option
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.printf(opt.label, contentX + 20, optY + 12, 250, "left")
            
            local toggleX = contentX + contentWidth - 120
            local toggleValue = settings[opt.key] and lang.t("graphics_on") or lang.t("graphics_off")
            local isHovered = (hoveredOption == "toggle_" .. i)
            
            -- On/Off color indicator
            if settings[opt.key] then
                drawButton(toggleX, optY + 2, 100, OPTION_HEIGHT - 4, toggleValue, isHovered, true)
            else
                drawButton(toggleX, optY + 2, 100, OPTION_HEIGHT - 4, toggleValue, isHovered, false)
            end
            
        elseif opt.type == "slider" then
            -- Slider option
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.printf(opt.label, contentX + 20, optY + 12, 250, "left")
            
            local sliderX = contentX + 300
            drawSlider(sliderX, optY + 10, SLIDER_WIDTH, OPTION_HEIGHT - 10, settings[opt.key], opt.max)
            
            -- Value display
            love.graphics.setFont(fontSmall)
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.printf(math.floor(settings[opt.key]) .. "%", sliderX + SLIDER_WIDTH + 10, optY + 12, 60, "left")
            
        elseif opt.type == "difficulty" then
            -- Difficulty selection
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.printf(opt.label, contentX + 20, optY + (OPTION_HEIGHT - fontOption:getHeight()) / 2, 250, "left")
            
            local difficulties = {"easy", "normal", "hard"}
            for j, diff in ipairs(difficulties) do
                local btnX = contentX + 250 + (j - 1) * 120
                local isSelected = (diff == settings.difficulty)
                local isHovered = (hoveredOption == "diff_" .. j)
                local diffLabel = lang.t("gameplay_difficulty_" .. diff)
                drawButton(btnX, optY, 100, OPTION_HEIGHT - 4, diffLabel, isHovered, isSelected)
            end
        end
    end
    
    -- Back button
    local backY = wh - BUTTON_HEIGHT - 20
    local backX = ww / 2 - BUTTON_WIDTH / 2
    local isBackHovered = (hoveredOption == "back")
    drawButton(backX, backY, BUTTON_WIDTH, BUTTON_HEIGHT, lang.t("options_back"), isBackHovered, false)
end

function options.keypressed(key)
    if key == "escape" then
        logger.info("Returning to main menu from options")
        options.save()
        GameState.current = "menu"
        GameState.menu.load()
    end
end

function options.mousemoved(x, y, dx, dy)
    local ww, wh = love.graphics.getDimensions()
    hoveredOption = nil
    
    -- Check tab buttons
    local tabButtonWidth = 120
    local totalTabWidth = #tabs * (tabButtonWidth + 10)
    local tabStartX = ww / 2 - totalTabWidth / 2
    local tabY = 80
    
    for i, tab in ipairs(tabs) do
        local tabX = tabStartX + (i - 1) * (tabButtonWidth + 10)
        if pointInRect(x, y, tabX, tabY, tabButtonWidth, TAB_HEIGHT) then
            hoveredOption = "tab_" .. i
            return
        end
    end
    
    -- Check option buttons based on current tab
    local opts = getOptionsByTab(currentTab)
    local contentY = tabY + TAB_HEIGHT + 30
    local contentX = PADDING
    local contentWidth = ww - 2 * PADDING
    
    for i, opt in ipairs(opts) do
        local optY = contentY + (i - 1) * (OPTION_HEIGHT + OPTION_PADDING)
        
        if currentTab == "language" and not opt.isCurrent then
            local btnX = contentX + contentWidth / 2 - 80
            if pointInRect(x, y, btnX, optY, 160, OPTION_HEIGHT) then
                hoveredOption = "lang_" .. i
                return
            end
        elseif opt.type == "toggle" then
            local toggleX = contentX + contentWidth - 120
            if pointInRect(x, y, toggleX, optY + 2, 100, OPTION_HEIGHT - 4) then
                hoveredOption = "toggle_" .. i
                return
            end
        elseif opt.type == "difficulty" then
            for j, diff in ipairs({"easy", "normal", "hard"}) do
                local btnX = contentX + 250 + (j - 1) * 120
                if pointInRect(x, y, btnX, optY, 100, OPTION_HEIGHT - 4) then
                    hoveredOption = "diff_" .. j
                    return
                end
            end
        end
    end
    
    -- Check back button
    local backY = wh - BUTTON_HEIGHT - 20
    local backX = ww / 2 - BUTTON_WIDTH / 2
    if pointInRect(x, y, backX, backY, BUTTON_WIDTH, BUTTON_HEIGHT) then
        hoveredOption = "back"
        return
    end
end

function options.mousepressed(x, y, button)
    if button ~= 1 then return end
    
    local ww, wh = love.graphics.getDimensions()
    
    -- Check tab buttons
    local tabButtonWidth = 120
    local totalTabWidth = #tabs * (tabButtonWidth + 10)
    local tabStartX = ww / 2 - totalTabWidth / 2
    local tabY = 80
    
    for i, tab in ipairs(tabs) do
        local tabX = tabStartX + (i - 1) * (tabButtonWidth + 10)
        if pointInRect(x, y, tabX, tabY, tabButtonWidth, TAB_HEIGHT) then
            currentTab = tab
            selectedOption = 1
            logger.debug("Switched to tab: " .. tab)
            return
        end
    end
    
    -- Handle option interactions
    local opts = getOptionsByTab(currentTab)
    local contentY = tabY + TAB_HEIGHT + 30
    local contentX = PADDING
    local contentWidth = ww - 2 * PADDING
    
    for i, opt in ipairs(opts) do
        local optY = contentY + (i - 1) * (OPTION_HEIGHT + OPTION_PADDING)
        
        if currentTab == "language" and not opt.isCurrent then
            -- Language selection
            local btnX = contentX + contentWidth / 2 - 80
            if pointInRect(x, y, btnX, optY, 160, OPTION_HEIGHT) then
                local success = lang.setLanguage(opt.langId)
                if success then
                    settings.language = opt.langId
                    options.save()
                    options.load() -- Reload to update all labels
                    logger.info("Language changed to: " .. opt.langId)
                end
                return
            end
            
        elseif opt.type == "toggle" then
            -- Toggle button
            local toggleX = contentX + contentWidth - 120
            if pointInRect(x, y, toggleX, optY + 2, 100, OPTION_HEIGHT - 4) then
                settings[opt.key] = not settings[opt.key]
                
                -- Apply changes immediately for certain settings
                if opt.key == "fullscreen" then
                    love.window.setFullscreen(settings.fullscreen)
                    logger.debug("Fullscreen: " .. tostring(settings.fullscreen))
                elseif opt.key == "showDebug" then
                    GameState.debug = settings.showDebug
                    logger.debug("Debug mode: " .. tostring(settings.showDebug))
                end
                
                options.save()
                return
            end
            
        elseif opt.type == "difficulty" then
            -- Difficulty buttons
            local difficulties = {"easy", "normal", "hard"}
            for j, diff in ipairs(difficulties) do
                local btnX = contentX + 250 + (j - 1) * 120
                if pointInRect(x, y, btnX, optY, 100, OPTION_HEIGHT - 4) then
                    settings.difficulty = diff
                    logger.debug("Difficulty changed to: " .. diff)
                    options.save()
                    return
                end
            end
        end
    end
    
    -- Check back button
    local backY = wh - BUTTON_HEIGHT - 20
    local backX = ww / 2 - BUTTON_WIDTH / 2
    if pointInRect(x, y, backX, backY, BUTTON_WIDTH, BUTTON_HEIGHT) then
        logger.info("Returning to main menu from options")
        options.save()
        GameState.current = "menu"
        GameState.menu.load()
        return
    end
end

function options.mousereleased(x, y, button)
    -- Handle mouse release if needed (for sliders in the future)
end

function options.wheelmoved(x, y)
    -- Could be used for slider adjustments
end

function options.resize(w, h)
    -- Handle window resizing if necessary
    -- Reload fonts if needed
    loadFonts()
end

return options