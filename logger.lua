-- ZayForge – Logger Module
-- Provides colored, timestamped logging with file output support

local logger = {}

-- ===== Configuration =====
local config = {
    -- Enable/disable log levels
    showInfo = true,
    showWarn = true,
    showError = true,
    showDebug = true,
    
    -- File logging
    logToFile = false,           -- Set to true to save logs to file
    logFilePath = "zayforge.log", -- Log file path
    
    -- Time format (Lua's os.date format)
    -- %Y-%m-%d %H:%M:%S = "2024-01-15 14:30:45"
    -- %d%b%Y %H:%M:%S   = "15Jan2024 14:30:45"
    -- %X               = "14:30:45" (time only)
    timeFormat = "%Y-%m-%d %H:%M:%S",
    
    -- Prefix options
    showTimestamp = true,
    showLevel = true,
}

-- ===== ANSI Color Codes =====
local colors = {
    -- Foreground
    info  = "\27[32m",  -- Green
    warn  = "\27[33m",  -- Yellow
    error = "\27[31m",  -- Red
    debug = "\27[34m",  -- Blue
    trace = "\27[35m",  -- Magenta
    success = "\27[36m", -- Cyan
    
    -- Styles
    bold      = "\27[1m",
    underline = "\27[4m",
    reset     = "\27[0m",
    
    -- Background (for special messages)
    bgRed   = "\27[41m",
    bgGreen = "\27[42m",
}

-- ===== File Handle (for file logging) =====
local logFile = nil

-- ===== Internal Functions =====

local function getTimestamp()
    return os.date(config.timeFormat)
end

local function formatMessage(level, message)
    local parts = {}
    
    if config.showTimestamp then
        table.insert(parts, "[" .. getTimestamp() .. "]")
    end
    
    if config.showLevel then
        table.insert(parts, "[" .. level .. "]")
    end
    
    table.insert(parts, message)
    
    return table.concat(parts, " ")
end

local function writeToFile(formattedMessage)
    if not config.logToFile then return end
    
    -- Open file on first write
    if not logFile then
        local success, err = pcall(function()
            logFile = io.open(config.logFilePath, "a") -- Append mode
        end)
        
        if not success then
            print(colors.warn .. "[LOGGER] Could not open log file: " .. tostring(err) .. colors.reset)
            config.logToFile = false -- Disable file logging on failure
            return
        end
    end
    
    if logFile then
        logFile:write(formattedMessage .. "\n")
        logFile:flush() -- Ensure immediate write
    end
end

-- ===== Public Logging Functions =====

function logger.info(message)
    if not config.showInfo then return end
    
    local formatted = formatMessage("INFO", message)
    print(colors.info .. formatted .. colors.reset)
    writeToFile("[INFO] " .. getTimestamp() .. " " .. message)
end

function logger.warn(message)
    if not config.showWarn then return end
    
    local formatted = formatMessage("WARN", message)
    print(colors.warn .. formatted .. colors.reset)
    writeToFile("[WARN] " .. getTimestamp() .. " " .. message)
end

function logger.error(message)
    if not config.showError then return end
    
    local formatted = formatMessage("ERROR", message)
    print(colors.error .. colors.bold .. formatted .. colors.reset)
    writeToFile("[ERROR] " .. getTimestamp() .. " " .. message)
end

function logger.debug(message)
    if not config.showDebug then return end
    
    local formatted = formatMessage("DEBUG", message)
    print(colors.debug .. formatted .. colors.reset)
    writeToFile("[DEBUG] " .. getTimestamp() .. " " .. message)
end

-- Trace logging (for function entry/exit tracing)
function logger.trace(message)
    local formatted = formatMessage("TRACE", message)
    print(colors.trace .. formatted .. colors.reset)
    writeToFile("[TRACE] " .. getTimestamp() .. " " .. message)
end

-- Success messages (green with bold)
function logger.success(message)
    local formatted = formatMessage("SUCCESS", message)
    print(colors.success .. colors.bold .. formatted .. colors.reset)
    writeToFile("[SUCCESS] " .. getTimestamp() .. " " .. message)
end

-- Plain log without color/level
function logger.log(message)
    print(message)
    writeToFile("[LOG] " .. getTimestamp() .. " " .. message)
end

-- ===== Special Formatting =====

-- Section header (for major game events)
function logger.header(message)
    local line = string.rep("=", 50)
    print(colors.info .. colors.bold .. line .. colors.reset)
    print(colors.info .. colors.bold .. "  " .. message .. colors.reset)
    print(colors.info .. colors.bold .. line .. colors.reset)
    writeToFile(line)
    writeToFile("  " .. message)
    writeToFile(line)
end

-- Critical error (white text on red background)
function logger.critical(message)
    local formatted = formatMessage("CRITICAL", message)
    print(colors.bgRed .. colors.bold .. formatted .. colors.reset)
    writeToFile("[CRITICAL] " .. getTimestamp() .. " " .. message)
end

-- Game event logging (player actions, world events)
function logger.gameEvent(message)
    local formatted = formatMessage("GAME", message)
    print(colors.success .. formatted .. colors.reset)
    writeToFile("[GAME] " .. getTimestamp() .. " " .. message)
end

-- ===== Configuration Functions =====

function logger.configure(newConfig)
    for key, value in pairs(newConfig) do
        if config[key] ~= nil then
            config[key] = value
        end
    end
    logger.debug("Logger configuration updated")
end

function logger.enableFileLogging(filePath)
    config.logToFile = true
    if filePath then
        config.logFilePath = filePath
    end
    logger.info("File logging enabled: " .. config.logFilePath)
end

function logger.disableFileLogging()
    config.logToFile = false
    if logFile then
        logFile:close()
        logFile = nil
    end
    logger.info("File logging disabled")
end

-- Cleanup function (call on game exit)
function logger.close()
    if logFile then
        logger.info("Closing log file")
        logFile:close()
        logFile = nil
    end
end

-- ===== Utility Functions =====

-- Log a table contents (for debugging)
function logger.dumpTable(tbl, indent, maxDepth)
    if not config.showDebug then return end
    
    indent = indent or 0
    maxDepth = maxDepth or 3
    
    if indent > maxDepth * 2 then
        logger.debug(string.rep("  ", indent) .. "...")
        return
    end
    
    for k, v in pairs(tbl) do
        local keyStr = tostring(k)
        if type(v) == "table" then
            logger.debug(string.rep("  ", indent) .. keyStr .. " = {")
            logger.dumpTable(v, indent + 1, maxDepth)
            logger.debug(string.rep("  ", indent) .. "}")
        else
            logger.debug(string.rep("  ", indent) .. keyStr .. " = " .. tostring(v))
        end
    end
end

-- Performance timer
local timers = {}
function logger.startTimer(name)
    timers[name] = love.timer.getTime()
end

function logger.stopTimer(name)
    if timers[name] then
        local elapsed = love.timer.getTime() - timers[name]
        logger.debug("Timer [" .. name .. "]: " .. string.format("%.3f", elapsed) .. "s")
        timers[name] = nil
        return elapsed
    end
end

-- Memory usage (if available)
function logger.memoryUsage()
    local mem = collectgarbage("count")
    logger.debug("Memory usage: " .. string.format("%.2f", mem) .. " KB")
    return mem
end

return logger