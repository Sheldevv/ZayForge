-- ZayForge – Options Menu Module
-- Comprehensive options/settings menu with language support
-- Refactored to use gui.lua for all drawing and hit-testing

local logger = require("logger")
local lang = require("lang")
local menu = require("menu")
local gui = require("gui")
local options = {}

-- ===== State =====
local currentTab = "language" -- 'language', 'graphics', 'audio', 'gameplay'
local selectedOption = 1
local hoveredOption = nil

local tabs = { "language", "graphics", "audio", "gameplay" }
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

-- Base font sizes (will be scaled by gui.scale() on load)
local BASE_TAB_FONT_SIZE = 20
local BASE_OPTION_FONT_SIZE = 18
local BASE_SMALL_FONT_SIZE = 14

-- Fonts (loaded in options.load)
local fontTab, fontOption, fontSmall

-- ===== Settings File Path =====

local function getSettingsDir()
    local osName = love.system.getOS()
    if osName == "Windows" then
        return (os.getenv("APPDATA") or os.getenv("USERPROFILE") .. "\\AppData\\Roaming") .. "\\ZayForge"
    else
        return (os.getenv("HOME") or "/tmp") .. "/.zayforge"
    end
end

local function getSettingsPath()
    local dir = getSettingsDir()
    local sep = (love.system.getOS() == "Windows") and "\\" or "/"
    return dir .. sep .. "settings.txt"
end

-- ===== Settings I/O (key=value format, stored outside sandbox) =====

local function loadSettings()
    local path = getSettingsPath()
    local file, err = io.open(path, "r")
    if not file then
        return -- no saved settings yet, use defaults
    end

    for line in file:lines() do
        -- Parse "key = value"
        local key, value = line:match("^%s*([^=]+)%s*=%s*(.+)$")
        if key and value then
            key = key:match("^%s*(.-)%s*$")    -- trim
            value = value:match("^%s*(.-)%s*$") -- trim
            if settings[key] ~= nil then
                if value == "true" then
                    settings[key] = true
                elseif value == "false" then
                    settings[key] = false
                elseif tonumber(value) then
                    settings[key] = tonumber(value)
                else
                    settings[key] = value
                end
            end
        end
    end
    file:close()
end

local function saveSettings()
    local path = getSettingsPath()
    local dir = getSettingsDir()

    -- Ensure the directory exists
    if love.system.getOS() == "Windows" then
        os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '"')
    else
        os.execute('mkdir -p "' .. dir .. '"')
    end

    local file, err = io.open(path, "w")
    if not file then
        logger.warn("Could not write settings to " .. path .. ": " .. (err or "unknown"))
        return
    end

    for k, v in pairs(settings) do
        file:write(k .. "=" .. tostring(v) .. "\n")
    end
    file:close()
    logger.debug("Settings saved to " .. path)
end

-- ===== Option Definitions =====

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
            { type = "toggle", label = lang.t("graphics_fullscreen"), key = "fullscreen", value = settings.fullscreen },
            { type = "toggle", label = lang.t("graphics_vsync"),      key = "vsync",      value = settings.vsync },
        }
    elseif tab == "audio" then
        return {
            { type = "slider", label = lang.t("audio_master_volume"), key = "masterVolume", value = settings.masterVolume, max = 100 },
            { type = "slider", label = lang.t("audio_music_volume"),  key = "musicVolume",  value = settings.musicVolume,  max = 100 },
            { type = "slider", label = lang.t("audio_sfx_volume"),    key = "sfxVolume",    value = settings.sfxVolume,    max = 100 },
        }
    elseif tab == "gameplay" then
        return {
            { type = "difficulty", label = lang.t("gameplay_difficulty"), key = "difficulty", value = settings.difficulty },
            { type = "toggle",     label = lang.t("gameplay_show_debug"), key = "showDebug",  value = settings.showDebug },
        }
    end
    return {}
end

-- ===== Public Functions =====

function options.load()
    logger.info("Loading options menu...")

    -- Load fonts with gui scaling
    local s = gui.scale()
    fontTab = gui.loadFont("assets/fonts/airstrike.ttf", math.floor(BASE_TAB_FONT_SIZE * s))
    fontOption = gui.loadFont("assets/fonts/airstrike.ttf", math.floor(BASE_OPTION_FONT_SIZE * s))
    fontSmall = gui.loadFont("assets/fonts/airstrike.ttf", math.floor(BASE_SMALL_FONT_SIZE * s))

    -- Load saved settings from ~/.zayforge/settings.txt (or %APPDATA%\ZayForge\settings.txt)
    loadSettings()

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
    -- Write settings in key=value format to the native config path
    saveSettings()
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
    local titleFont = gui.loadFont("assets/fonts/airstrike.ttf", math.floor(36 * gui.scale()))
    gui.drawTitle(lang.t("options_title"), 20, titleFont)

    -- Tab buttons
    local tabButtonWidth = 120
    local totalTabWidth = #tabs * (tabButtonWidth + 10)
    local tabStartX = ww / 2 - totalTabWidth / 2
    local tabY = 80

    for i, tab in ipairs(tabs) do
        local tabX = tabStartX + (i - 1) * (tabButtonWidth + 10)
        local isSelected = (tab == currentTab)
        local isHovered = (hoveredOption == "tab_" .. i)

        gui.drawButton(
            { x = tabX, y = tabY, w = tabButtonWidth, h = TAB_HEIGHT },
            { label = tabNames[tab] or tab, font = fontTab, isSelected = isSelected, isHovered = isHovered }
        )
    end

    -- Content area
    local contentY = tabY + TAB_HEIGHT + 30
    local contentX = PADDING
    local contentWidth = ww - 2 * PADDING
    local contentHeight = wh - contentY - PADDING - BUTTON_HEIGHT - 20

    -- Content background panel
    gui.drawRect(contentX, contentY - 10, contentWidth, contentHeight, 8,
        { 0.08, 0.08, 0.12, 0.6 }, { 0.3, 0.3, 0.4, 0.8 }, 2)

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
                love.graphics.printf("✓ " .. lang.t("apply"), contentX + 240, optY + (btnH - fontOption:getHeight()) / 2,
                    100, "left")
            else
                gui.drawButton(
                    { x = btnX, y = optY, w = btnW, h = btnH },
                    { label = opt.label, font = fontOption, isHovered = isHovered }
                )
            end
        elseif opt.type == "toggle" then
            -- Toggle option
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.printf(opt.label, contentX + 20, optY + 12, 250, "left")

            local toggleX = contentX + contentWidth - 120
            local toggleValue = settings[opt.key] and lang.t("graphics_on") or lang.t("graphics_off")
            local isHovered = (hoveredOption == "toggle_" .. i)

            gui.drawButton(
                { x = toggleX, y = optY + 2, w = 100, h = OPTION_HEIGHT - 4 },
                { label = toggleValue, font = fontOption, isSelected = settings[opt.key], isHovered = isHovered }
            )
        elseif opt.type == "slider" then
            -- Slider option
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.printf(opt.label, contentX + 20, optY + 12, 250, "left")

            local sliderX = contentX + 300
            -- gui.drawSlider expects y as the center of the track
            local trackCenterY = optY + 10 + (OPTION_HEIGHT - 10) / 2
            local isSliderHovered = (hoveredOption == "slider_" .. i)

            gui.drawSlider(sliderX, trackCenterY, SLIDER_WIDTH, settings[opt.key], 0, opt.max, isSliderHovered)

            -- Value display
            love.graphics.setFont(fontSmall)
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.printf(math.floor(settings[opt.key]) .. "%", sliderX + SLIDER_WIDTH + 10, optY + 12, 60, "left")
        elseif opt.type == "difficulty" then
            -- Difficulty selection
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.printf(opt.label, contentX + 20, optY + (OPTION_HEIGHT - fontOption:getHeight()) / 2, 250,
                "left")

            local difficulties = { "easy", "normal", "hard" }
            for j, diff in ipairs(difficulties) do
                local btnX = contentX + 250 + (j - 1) * 120
                local isSelected = (diff == settings.difficulty)
                local isHovered = (hoveredOption == "diff_" .. j)
                local diffLabel = lang.t("gameplay_difficulty_" .. diff)

                gui.drawButton(
                    { x = btnX, y = optY, w = 100, h = OPTION_HEIGHT - 4 },
                    { label = diffLabel, font = fontOption, isSelected = isSelected, isHovered = isHovered }
                )
            end
        end
    end

    -- Back button
    local backY = wh - BUTTON_HEIGHT - 20
    local backX = ww / 2 - BUTTON_WIDTH / 2
    local isBackHovered = (hoveredOption == "back")

    gui.drawButton(
        { x = backX, y = backY, w = BUTTON_WIDTH, h = BUTTON_HEIGHT },
        { label = lang.t("options_back"), font = fontOption, isHovered = isBackHovered }
    )
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
        if gui.hitTest(x, y, { x = tabX, y = tabY, w = tabButtonWidth, h = TAB_HEIGHT }) then
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
            if gui.hitTest(x, y, { x = btnX, y = optY, w = 160, h = OPTION_HEIGHT }) then
                hoveredOption = "lang_" .. i
                return
            end
        elseif opt.type == "toggle" then
            local toggleX = contentX + contentWidth - 120
            if gui.hitTest(x, y, { x = toggleX, y = optY + 2, w = 100, h = OPTION_HEIGHT - 4 }) then
                hoveredOption = "toggle_" .. i
                return
            end
        elseif opt.type == "slider" then
            local sliderX = contentX + 300
            local trackCenterY = optY + 10 + (OPTION_HEIGHT - 10) / 2
            -- Hit-test the slider track + thumb area
            if gui.hitTest(x, y, { x = sliderX - 10, y = trackCenterY - 12, w = SLIDER_WIDTH + 20, h = 24 }) then
                hoveredOption = "slider_" .. i
                return
            end
        elseif opt.type == "difficulty" then
            for j, diff in ipairs({ "easy", "normal", "hard" }) do
                local btnX = contentX + 250 + (j - 1) * 120
                if gui.hitTest(x, y, { x = btnX, y = optY, w = 100, h = OPTION_HEIGHT - 4 }) then
                    hoveredOption = "diff_" .. j
                    return
                end
            end
        end
    end

    -- Check back button
    local backY = wh - BUTTON_HEIGHT - 20
    local backX = ww / 2 - BUTTON_WIDTH / 2
    if gui.hitTest(x, y, { x = backX, y = backY, w = BUTTON_WIDTH, h = BUTTON_HEIGHT }) then
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
        if gui.hitTest(x, y, { x = tabX, y = tabY, w = tabButtonWidth, h = TAB_HEIGHT }) then
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
            if gui.hitTest(x, y, { x = btnX, y = optY, w = 160, h = OPTION_HEIGHT }) then
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
            if gui.hitTest(x, y, { x = toggleX, y = optY + 2, w = 100, h = OPTION_HEIGHT - 4 }) then
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
        elseif opt.type == "slider" then
            -- Slider click — snap to position
            local sliderX = contentX + 300
            local trackCenterY = optY + 10 + (OPTION_HEIGHT - 10) / 2
            if gui.hitTest(x, y, { x = sliderX - 10, y = trackCenterY - 12, w = SLIDER_WIDTH + 20, h = 24 }) then
                local t = math.max(0, math.min(1, (x - sliderX) / SLIDER_WIDTH))
                settings[opt.key] = math.floor(t * opt.max)
                options.save()
            end
        elseif opt.type == "difficulty" then
            -- Difficulty buttons
            local difficulties = { "easy", "normal", "hard" }
            for j, diff in ipairs(difficulties) do
                local btnX = contentX + 250 + (j - 1) * 120
                if gui.hitTest(x, y, { x = btnX, y = optY, w = 100, h = OPTION_HEIGHT - 4 }) then
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
    if gui.hitTest(x, y, { x = backX, y = backY, w = BUTTON_WIDTH, h = BUTTON_HEIGHT }) then
        logger.info("Returning to main menu from options")
        options.save()
        GameState.current = "menu"
        GameState.menu.load()
        return
    end
end

function options.mousereleased(x, y, button)
    -- Handle mouse release if needed
end

function options.wheelmoved(x, y)
    -- Could be used for slider adjustments
end

function options.resize(w, h)
    -- Reload fonts at the new scale
    local s = gui.scale()
    fontTab = gui.loadFont("assets/fonts/airstrike.ttf", math.floor(BASE_TAB_FONT_SIZE * s))
    fontOption = gui.loadFont("assets/fonts/airstrike.ttf", math.floor(BASE_OPTION_FONT_SIZE * s))
    fontSmall = gui.loadFont("assets/fonts/airstrike.ttf", math.floor(BASE_SMALL_FONT_SIZE * s))
end

function options.touchpressed(id, x, y, dx, dy, pressure)
    options.mousepressed(x, y, 1) -- simulate left click
end

function options.touchmoved(id, x, y, dx, dy, pressure)
    options.mousemoved(x, y, dx, dy)
end

function options.touchreleased(id, x, y, dx, dy, pressure)
    -- No special release handling needed for options
end

return options
