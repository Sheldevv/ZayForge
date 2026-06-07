-- online.lua – ZayForge API client for Love2D
--
-- Connects directly to the Neon PostgreSQL database via pgmoon
-- (same DB the launcher/server use).  Fetches player profile:
-- username and 16x16 PNG avatar.
--
-- Connection string:
--   postgresql://neondb_owner:npg_KZHr0QmOF6Vw@
--     ep-falling-cherry-aqiltlp5.c-8.us-east-1.aws.neon.tech/
--     neondb?sslmode=require

local logger = require("logger")
local pgmoon = require("pgmoon.init")

local online = {}

-- ===== Configuration =====
online.DB_URL = "postgresql://neondb_owner:npg_KZHr0QmOF6Vw@ep-falling-cherry-aqiltlp5.c-8.us-east-1.aws.neon.tech/neondb?sslmode=require"

-- ===== State =====
online.enabled = false              -- true if --online=true was passed
online.accountId = nil              -- the account UUID from --account-id=
online.token = nil                  -- JWT received from launcher (if passed)
online.user = nil                   -- { id, username, email, avatar (data URL), createdAt }
online.avatarImage = nil            -- loaded love.graphics image from avatar data URL
online.avatarLoadFailed = false     -- true if avatar decoding failed
online.lastFetchError = nil         -- most recent error string

local db = nil

-- ===== Parse Neon DSN =====

local function parseDSN(dsn)
    local user, pass, host, port, dbname, sslmode
    user = dsn:match("://([^:]+)")
    pass = dsn:match("://[^:]+:([^@]+)")
    host = dsn:match("@([^:]+)")
    port = dsn:match(":([0-9]+)/") or "5432"
    dbname = dsn:match("/([^?]+)")
    sslmode = dsn:match("sslmode=([^&]+)")
    return {
        user = user,
        password = pass,
        host = host,
        port = tonumber(port),
        database = dbname,
        ssl = sslmode == "require",
    }
end

-- ===== Database Connection =====

-- pgmoon uses luasocket. The sslhandshake call requires LuaSec
-- (require("ssl")) which is NOT bundled with stock Love2D.
-- On systems where LuaSec is available (installed via apt/brew/luarocks),
-- SSL connections to Neon will work.  Otherwise connectDB() fails gracefully
-- and the game runs offline with the blue circle fallback.
local function connectDB()
    if db then return true end

    local cfg = parseDSN(online.DB_URL)
    logger.info(string.format("Connecting to %s:%s/%s as %s (ssl=%s)",
        cfg.host, cfg.port, cfg.database, cfg.user, tostring(cfg.ssl)))

    local ok, err = pcall(function()
        db = pgmoon.new(cfg)
        assert(db:connect())
    end)

    if not ok then
        logger.warn("DB connection failed: " .. tostring(err))
        logger.warn("Neon requires LuaSec (luasec) for SSL — install it:")
        logger.warn("  Ubuntu: sudo apt install lua-sec")
        logger.warn("  macOS:  brew install luasec")
        logger.warn("  Or:     luarocks install luasec")
        logger.warn("Running in offline mode (blue circle player)")
        db = nil
        online.lastFetchError = tostring(err)
        return false
    end

    logger.info("Connected to Neon PostgreSQL")
    return true
end

local function disconnectDB()
    if db then
        pcall(function() db:disconnect() end)
        db = nil
    end
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

-- Fetch the user profile directly from the Neon database via pgmoon.
function online.fetchProfile()
    if not online.enabled then return false end
    if not online.accountId then
        online.lastFetchError = "No account ID"
        return false
    end

    if not connectDB() then
        return false
    end

    local ok, result = pcall(function()
        -- Query the User table by id
        return db:query([[
            SELECT id, username, email, avatar, "createdAt"
            FROM "User"
            WHERE id = $1
            LIMIT 1
        ]], online.accountId)
    end)

    if not ok then
        online.lastFetchError = tostring(result)
        logger.warn("Profile query failed: " .. online.lastFetchError)
        return false
    end

    if #result == 0 then
        online.lastFetchError = "User not found"
        logger.warn("No user with id: " .. online.accountId)
        return false
    end

    local row = result[1]
    online.user = {
        id = row.id,
        username = row.username,
        email = row.email,
        avatar = row.avatar,
        createdAt = row.createdAt or row.createdat,
    }
    online.lastFetchError = nil

    -- Load avatar image from base64 data URL if present
    online._loadAvatarImage()

    -- Keep connection alive for future queries
    -- db:keepalive() -- pgmoon sets keepalive per-query

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

-- Cleanup on game exit
function online.shutdown()
    disconnectDB()
    logger.info("Online module shut down")
end

return online
