-- ZayForge – Language Manager
-- Handles loading, switching, and translating languages

local logger = require("logger")
local lang = {}

-- ===== State =====
local currentLanguage = "en-US"
local translations = {}
local availableLanguages = {}

-- ===== Configuration =====
local LANG_DIR = "assets/lang"
local LANG_SAVE_KEY = "zayforge_language"

-- ===== Built-in language strings (fallbacks) =====
local builtInLanguages = {
    ["en-US"] = {
        ["Name"] = "English (US)",
        ["menu_title"] = "ZayForge",
        ["menu_singleplayer"] = "Single Player",
        ["menu_multiplayer"] = "Multiplayer",
        ["menu_options"] = "Options",
        ["menu_exit"] = "Exit",
        ["menu_comming_soon"] = "Coming Soon",
        ["menu_back"] = "Back",
        ["options_title"] = "Options",
        ["options_language"] = "Language",
        ["options_graphics"] = "Graphics",
        ["options_audio"] = "Audio",
        ["options_gameplay"] = "Gameplay",
        ["options_back"] = "Back to Menu",
        ["graphics_resolution"] = "Resolution",
        ["graphics_fullscreen"] = "Fullscreen",
        ["graphics_vsync"] = "V-Sync",
        ["graphics_quality"] = "Quality",
        ["graphics_on"] = "On",
        ["graphics_off"] = "Off",
        ["audio_master_volume"] = "Master Volume",
        ["audio_music_volume"] = "Music Volume",
        ["audio_sfx_volume"] = "Sound Effects Volume",
        ["audio_mute_all"] = "Mute All",
        ["gameplay_difficulty"] = "Difficulty",
        ["gameplay_difficulty_easy"] = "Easy",
        ["gameplay_difficulty_normal"] = "Normal",
        ["gameplay_difficulty_hard"] = "Hard",
        ["gameplay_show_debug"] = "Show Debug Info",
        ["confirm"] = "Confirm",
        ["cancel"] = "Cancel",
        ["apply"] = "Apply",
        ["default"] = "Default",
    },
    ["en-Slang"] = {
        ["Name"] = "English (Slang)",
        ["menu_title"] = "ZayForge",
        ["menu_singleplayer"] = "Play Solo",
        ["menu_multiplayer"] = "Play w Homies",
        ["menu_options"] = "Settings",
        ["menu_exit"] = "Touch Grass",
        ["menu_comming_soon"] = "not yet bro 💀",
        ["menu_back"] = "Nah fam",
        ["options_title"] = "Settings",
        ["options_language"] = "Language",
        ["options_graphics"] = "Visuals",
        ["options_audio"] = "Sound",
        ["options_gameplay"] = "How 2 Play",
        ["options_back"] = "Back Homie",
        ["graphics_resolution"] = "Screen Size",
        ["graphics_fullscreen"] = "Full Screen",
        ["graphics_vsync"] = "Smooth Mode",
        ["graphics_quality"] = "Looks Good",
        ["graphics_on"] = "Bet",
        ["graphics_off"] = "Nah",
        ["audio_master_volume"] = "Loudness",
        ["audio_music_volume"] = "Music Slaps",
        ["audio_sfx_volume"] = "Boom Boom",
        ["audio_mute_all"] = "Silent Mode",
        ["gameplay_difficulty"] = "How Hard",
        ["gameplay_difficulty_easy"] = "ez pz",
        ["gameplay_difficulty_normal"] = "mid",
        ["gameplay_difficulty_hard"] = "pain",
        ["gameplay_show_debug"] = "Show Nerd Stuff",
        ["confirm"] = "Yep",
        ["cancel"] = "Nope",
        ["apply"] = "Let's Go",
        ["default"] = "Reset",
    }
}

-- ===== Internal Functions =====
-- IMPORTANT: saveLanguagePreference must be defined BEFORE loadLanguage

local function saveLanguagePreference(langId)
    local success, content = pcall(function()
        return love.filesystem.read("settings.txt")
    end)
    
    local settings = {}
    if success and content then
        -- Use loadstring to safely parse the file content
        local chunk, err = loadstring("return " .. content)
        if chunk then
            local ok, result = pcall(chunk)
            if ok and type(result) == "table" then
                settings = result
            end
        end
    end
    
    settings.language = langId
    
    -- Simple manual serialization
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
end

local function loadLanguage(langId)
    logger.info("Loading language: " .. langId)
    
    -- Try to load from file first
    local fullPath = LANG_DIR .. "/" .. langId .. ".lua"
    local success, chunk = pcall(function()
        return love.filesystem.load(fullPath)
    end)
    
    if success and chunk then
        local ok, langData = pcall(chunk)
        if ok and type(langData) == "table" then
            translations = langData
            currentLanguage = langId
            saveLanguagePreference(langId)
            logger.info("Loaded language from file: " .. langId)
            return true
        end
    end
    
    -- Fallback to built-in data
    if builtInLanguages[langId] then
        translations = builtInLanguages[langId]
        currentLanguage = langId
        saveLanguagePreference(langId)
        logger.info("Loaded built-in language: " .. langId)
        return true
    end
    
    -- Ultimate fallback: en-US
    logger.error("Failed to load language: " .. langId .. ". Using en-US built-in.")
    translations = builtInLanguages["en-US"]
    currentLanguage = "en-US"
    saveLanguagePreference("en-US")
    return true
end

local function scanLanguages()
    logger.debug("Scanning for available languages...")
    availableLanguages = {}
    
    -- Try to load language files from the assets/lang directory
    local success, langFiles = pcall(function()
        return love.filesystem.getDirectoryItems(LANG_DIR)
    end)
    
    if not success or not langFiles then
        logger.warn("Could not scan language directory, using built-in languages")
        for id, data in pairs(builtInLanguages) do
            table.insert(availableLanguages, {id = id, name = data.Name or id})
        end
        return
    end
    
    for _, file in ipairs(langFiles) do
        if file:match("%.lua$") then
            local langId = file:sub(1, -5) -- Remove .lua extension
            
            -- Try to load using love.filesystem.load
            local fullPath = LANG_DIR .. "/" .. file
            local success, chunk = pcall(function()
                return love.filesystem.load(fullPath)
            end)
            
            if success and chunk then
                local ok, langData = pcall(chunk)
                if ok and type(langData) == "table" and langData.Name then
                    table.insert(availableLanguages, {id = langId, name = langData.Name})
                    logger.debug("Loaded language file: " .. langId .. " (" .. langData.Name .. ")")
                else
                    -- Fallback: check if we have built-in data
                    if builtInLanguages[langId] then
                        table.insert(availableLanguages, {id = langId, name = builtInLanguages[langId].Name or langId})
                        logger.debug("Using built-in language fallback for: " .. langId)
                    end
                end
            elseif builtInLanguages[langId] then
                -- File exists but couldn't load, use built-in
                table.insert(availableLanguages, {id = langId, name = builtInLanguages[langId].Name or langId})
                logger.debug("Using built-in fallback for file: " .. file)
            end
        end
    end
    
    -- If no languages found, use the built-in defaults
    if #availableLanguages == 0 then
        logger.warn("No language files loaded, using defaults")
        availableLanguages = {
            {id = "en-US", name = "English (US)"},
            {id = "en-Slang", name = "English (Slang)"}
        }
    end
    
    logger.debug("Found " .. #availableLanguages .. " language(s)")
end

local function loadSavedLanguage()
    local success, content = pcall(function()
        return love.filesystem.read("settings.txt")
    end)
    
    if success and content then
        local chunk, err = loadstring("return " .. content)
        if chunk then
            local ok, result = pcall(chunk)
            if ok and type(result) == "table" and result.language then
                return result.language
            end
        end
    end
    
    return "en-US"
end

-- ===== Public API =====

function lang.init()
    logger.info("Initializing language system...")
    
    -- Scan for available languages
    scanLanguages()
    
    -- Load saved language or default
    local savedLang = loadSavedLanguage()
    local langExists = false
    for _, l in ipairs(availableLanguages) do
        if l.id == savedLang then
            langExists = true
            break
        end
    end
    
    if langExists then
        loadLanguage(savedLang)
    elseif #availableLanguages > 0 then
        loadLanguage(availableLanguages[1].id)
    else
        loadLanguage("en-US")
    end
    
    logger.info("Language system initialized with: " .. currentLanguage)
end

-- Get a translated string
function lang.t(key, default)
    if translations[key] then
        return translations[key]
    end
    
    if default then
        return default
    end
    
    -- Only log missing keys once to avoid spam
    logger.debug("Translation missing for key: " .. key)
    return "[" .. key .. "]"
end

-- Get all available languages
function lang.getAvailableLanguages()
    return availableLanguages
end

-- Get current language ID
function lang.getCurrent()
    return currentLanguage
end

-- Get current language name
function lang.getCurrentName()
    for _, l in ipairs(availableLanguages) do
        if l.id == currentLanguage then
            return l.name
        end
    end
    return currentLanguage
end

-- Switch language
function lang.setLanguage(langId)
    for _, l in ipairs(availableLanguages) do
        if l.id == langId then
            return loadLanguage(langId)
        end
    end
    
    logger.error("Language not found: " .. langId)
    return false
end

-- Get language name by ID
function lang.getLanguageName(langId)
    for _, l in ipairs(availableLanguages) do
        if l.id == langId then
            return l.name
        end
    end
    return langId
end

return lang