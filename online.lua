-- online.lua – ZayForge API client for Love2D
--
-- Talks to https://zayforge.xyz/api to fetch player profile data
-- (username, avatar, etc.) when the game is launched with --online=true
-- and --account-id=<id> by the ZayForge Launcher.
--
-- Relies on Löve2D's built-in luasocket (socket.http / socket.url).

local logger = require("logger")

local online = {}

-- ===== Configuration =====
-- Primary: local API server started by the ZayForge Launcher (localhost:3131)
-- Fallback: public zayforge.xyz API for standalone / non-launcher usage
online.API_BASE = "http://localhost:3131/api"
online.REQUEST_TIMEOUT = 3 -- seconds (low: local API should respond fast)

-- Override with public API if the launcher API is unreachable
online.FALLBACK_API = "https://zayforge.xyz/api"

-- ===== State =====
online.enabled = false              -- true if --online=true was passed
online.accountId = nil              -- the account UUID from --account-id=
online.token = nil                  -- JWT received from launcher (if passed)
online.user = nil                   -- { id, username, email, avatar (data URL), createdAt }
online.avatarImage = nil            -- loaded love.graphics image from avatar data URL
online.avatarLoadFailed = false     -- true if avatar decoding failed
online.lastFetchError = nil         -- most recent error string

-- ===== Dependencies (loaded lazily) =====
local http
local ltn12
local json

-- ===== Internal Helpers =====

local function initDeps()
    if http and ltn12 then return true end
    local ok
    ok, http = pcall(require, "socket.http")
    if not ok then
        logger.warn("socket.http not available, online features disabled")
        return false
    end
    ok, ltn12 = pcall(require, "ltn12")
    if not ok then
        logger.warn("ltn12 not available, online features disabled")
        return false
    end
    http.TIMEOUT = online.REQUEST_TIMEOUT
    return true
end

local function initJson()
    if json then return true end
    local ok
    ok, json = pcall(require, "dkjson")
    if not ok then
        ok, json = pcall(require, "json")
    end
    if not ok then
        logger.warn("JSON library not available, online features disabled")
        return false
    end
    return true
end

local function decodeJSON(str)
    if not initJson() then return nil end
    local obj, pos, err = json.decode(str, 1, nil)
    if err then
        logger.warn("JSON decode error: " .. tostring(err))
        return nil
    end
    return obj
end

local function encodeJSON(tbl)
    if not initJson() then return "{}" end
    return json.encode(tbl)
end

-- Perform an HTTP request. Returns body string, HTTP status code, and optional error.
-- Tries the local launcher API first, falls back to zayforge.xyz.
local function request(method, path, opts)
    if not initDeps() then return nil, 0, "deps unavailable" end

    opts = opts or {}
    local headers = opts.headers or {}
    headers["accept"] = "application/json"
    local reqBody = opts.body

    -- Try local launcher API first, then fallback to public API
    local urls = { online.API_BASE, online.FALLBACK_API }

    for _, baseUrl in ipairs(urls) do
        local url = baseUrl .. path
        local respBody = {}
        local _, statusCode = http.request {
            url     = url,
            method  = method,
            headers = headers,
            source  = reqBody and ltn12.source.string(reqBody) or nil,
            sink    = ltn12.sink.table(respBody),
        }

        -- LuaSocket may return status as a string (e.g. "200")
        local sc = tonumber(statusCode) or 0
        if sc > 0 then
            local body = table.concat(respBody)
            return body, statusCode, nil
        end

        logger.debug("API unreachable at " .. baseUrl .. ", trying fallback...")
    end

    return nil, 0, "all endpoints unreachable"
end

-- ===== Public API =====

-- Parse command-line args for --online and --account-id.
-- Called from main.lua during love.load().
function online.parseArgs(rawArgs)
    if not rawArgs then return end

    for _, arg in ipairs(rawArgs) do
        local val

        val = arg:match("^%-%-online=(.+)$")
        if val then
            online.enabled = (val == "true")
            logger.debug("Online mode: " .. tostring(online.enabled))
        end

        val = arg:match("^%-%-account%-id=(.+)$")
        if val then
            online.accountId = val
            logger.debug("Account ID: " .. online.accountId)
        end

        val = arg:match("^%-%-token=(.+)$")
        if val then
            online.token = val
            logger.debug("Token provided directly")
        end
    end

    if not online.enabled then
        logger.info("Online mode disabled (--online not set or false)")
    elseif not online.accountId then
        logger.warn("Online mode enabled but --account-id missing, disabling online")
        online.enabled = false
    end
end

-- Fetch the user profile from the API.
-- Uses /api/auth/me with Authorization header if token provided, otherwise
-- uses x-zayforge-account-id header (requires API support for that path).
function online.fetchProfile()
    if not online.enabled then return false end
    if not online.accountId then
        online.lastFetchError = "No account ID"
        return false
    end

    local path = "/auth/me"
    local headers = {}

    if online.token then
        headers["authorization"] = "Bearer " .. online.token
    else
        headers["x-zayforge-account-id"] = online.accountId
    end

    local bodyStr, status = request("GET", path, { headers = headers })

    if not bodyStr or status == 0 then
        online.lastFetchError = "Network error"
        logger.warn("Failed to fetch profile: network error")
        return false
    end

    if status ~= 200 then
        online.lastFetchError = "HTTP " .. tostring(status)
        logger.warn("Failed to fetch profile: HTTP " .. tostring(status))
        return false
    end

    local data = decodeJSON(bodyStr)
    if not data then
        online.lastFetchError = "JSON parse error"
        logger.warn("Failed to parse profile response")
        return false
    end

    if not data.ok then
        online.lastFetchError = data.error or "Unknown API error"
        logger.warn("API error: " .. (data.error or "unknown"))
        return false
    end

    online.user = data.user
    online.lastFetchError = nil

    online._loadAvatarImage()

    logger.info("Online profile loaded: " .. (online.user.username or "unknown"))
    return true
end

-- ===== Avatar Image Handling =====

function online._loadAvatarImage()
    if not online.user or not online.user.avatar then
        online.avatarImage = nil
        online.avatarLoadFailed = false
        return
    end

    local avatar = online.user.avatar
    -- Avatar is stored as "data:image/png;base64,...."
    local b64 = avatar:match("^data:image/png;base64,(.+)$")
    if not b64 then
        logger.warn("Avatar is not a valid PNG data URL")
        online.avatarLoadFailed = true
        online.avatarImage = nil
        return
    end

    -- Decode base64 to raw bytes
    local raw = love.data.decode("data", "base64", b64)
    if not raw then
        logger.warn("Failed to decode avatar base64")
        online.avatarLoadFailed = true
        online.avatarImage = nil
        return
    end

    -- Create ImageData from raw bytes
    local fd = love.filesystem.newFileData(raw, "avatar.png", "image/png")
    local ok, imageData = pcall(love.image.newImageData, fd)
    if not ok then
        logger.warn("Failed to create ImageData from avatar PNG data")
        online.avatarLoadFailed = true
        online.avatarImage = nil
        return
    end

    online.avatarImage = love.graphics.newImage(imageData)
    online.avatarLoadFailed = false

    logger.info("Avatar loaded (" ..
        online.avatarImage:getWidth() .. "x" ..
        online.avatarImage:getHeight() .. ")")
end

-- Draw the player avatar at the given position and size.
-- If no avatar is available, draws a fallback circle (the old behavior).
-- Returns true if an avatar was drawn, false if fallback was used.
function online.drawPlayerAvatar(x, y, size)
    local hasAvatar = online.enabled and online.avatarImage and not online.avatarLoadFailed

    if hasAvatar then
        -- Draw avatar image centered at (x, y), scaled to size*2 square
        local scaleX = (size * 2) / online.avatarImage:getWidth()
        local scaleY = (size * 2) / online.avatarImage:getHeight()
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(online.avatarImage, x - size, y - size, 0, scaleX, scaleY)
        -- Border
        love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", x - size, y - size, size * 2, size * 2)
        return true
    end

    -- Fallback: classic blue circle (existing behavior)
    love.graphics.setColor(0.2, 0.8, 1)
    love.graphics.circle("fill", x, y, size)
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.circle("line", x, y, size)
    return false
end

-- Draw the player's username above them (if online)
function online.drawPlayerName(x, y, size)
    if not online.enabled or not online.user then return end

    local name = online.user.username or "Player"
    local f = love.graphics.newFont(math.max(10, math.floor(size * 0.7)))
    love.graphics.setFont(f)
    local w = f:getWidth(name)
    local h = f:getHeight()

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.print(name, x - w / 2 + 1, y - size - h - 2 + 1)

    -- Text
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(name, x - w / 2, y - size - h - 2)
end

-- Check if online features are active
function online.isOnline()
    return online.enabled and online.user ~= nil
end

-- Get cached username (or nil)
function online.getUsername()
    if online.user then return online.user.username end
    return nil
end

return online
