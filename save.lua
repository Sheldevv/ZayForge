-- save.lua – ZayForge Save System
--
-- Saves worlds to ~/.zayforge (Linux/macOS) or %AppData%\Zayforge (Windows).
-- Metadata stored as JSON in worlds.json, world data in individual save slots.

local logger = require("logger")

local save = {}

-- ===== Configuration =====
local SAVE_ROOT = nil

-- ===== State =====
save.saves = {}  -- {slot, name, seed, playTime, lastPlayed, version}

-- ===== Directory Setup =====

local function getSaveRoot()
    if SAVE_ROOT then return SAVE_ROOT end
    local osName = love.system.getOS()
    if osName == "Windows" then
        SAVE_ROOT = os.getenv("APPDATA") .. "/ZayForge"
    else
        SAVE_ROOT = os.getenv("HOME") .. "/.zayforge"
    end
    return SAVE_ROOT
end

local function ensureDir(path)
    -- Create directory recursively using io
    local current = ""
    for part in path:gmatch("[^/]+") do
        current = current .. "/" .. part
        local f = io.open(current)
        if not f then
            os.execute("mkdir -p '" .. current .. "' 2>/dev/null")
        else
            f:close()
        end
    end
end

-- ===== Serialization Helpers =====

-- Serialize a 2D tile grid to a compact string
-- Each tile is a single byte (0-255)
local function serializeTiles(tiles, w, h)
    local data = {}
    for x = 1, w do
        local row = {}
        for y = 1, h do
            local tile = (tiles[x] and tiles[x][y]) or 0
            row[#row + 1] = string.char(tile)
        end
        data[#data + 1] = table.concat(row)
    end
    return table.concat(data)
end

-- Deserialize tiles
local function deserializeTiles(data, w, h)
    local tiles = {}
    for x = 1, w do
        tiles[x] = {}
        for y = 1, h do
            local idx = (x - 1) * h + y
            tiles[x][y] = string.byte(data, idx) or 0
        end
    end
    return tiles
end

-- Basic table serializer (for inventory, game state)
local function serializeTable(tbl)
    local function ser(v)
        local t = type(v)
        if t == "number" then return "n" .. tostring(v)
        elseif t == "string" then return "s" .. v:len() .. ":" .. v
        elseif t == "boolean" then return v and "b1" or "b0"
        elseif t == "table" then
            local parts = { "t" }
            for key, val in pairs(v) do
                parts[#parts + 1] = ser(key) .. ser(val)
            end
            parts[#parts + 1] = "e"
            return table.concat(parts)
        end
        return "n0"
    end
    return ser(tbl)
end

local function deserializeTable(str, pos)
    pos = pos or 1
    local t = str:sub(pos, pos)
    if t == "n" then
        local num = str:match("^(%-?[%d%.]+)", pos + 1)
        local len = #num
        return tonumber(num), pos + 1 + len
    elseif t == "s" then
        local len = tonumber(str:match("^(%d+):", pos + 1))
        local val = str:sub(pos + 1 + tostring(len):len() + 1, pos + tostring(len):len() + len)
        return val, pos + tostring(len):len() + len + 1
    elseif t == "b" then
        return str:sub(pos + 1, pos + 1) == "1", pos + 2
    elseif t == "t" then
        local result = {}
        pos = pos + 1
        while str:sub(pos, pos) ~= "e" do
            local key, val
            key, pos = deserializeTable(str, pos)
            val, pos = deserializeTable(str, pos)
            result[key] = val
        end
        return result, pos + 1
    end
    return nil, pos
end

-- ===== JSON helpers for metadata =====

local function jsonEncode(tbl)
    local parts = {}
    for k, v in pairs(tbl) do
        local valStr
        if type(v) == "string" then
            valStr = '"' .. v:gsub('"', '\\"') .. '"'
        elseif type(v) == "number" then
            valStr = tostring(v)
        elseif type(v) == "boolean" then
            valStr = v and "true" or "false"
        else
            valStr = "null"
        end
        parts[#parts + 1] = '"' .. k .. '": ' .. valStr
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function jsonDecode(str)
    -- Simple JSON object decoder (flat objects only, no nesting)
    local obj = {}
    if not str or str == "" then return obj end
    -- Strip outer braces
    str = str:match("^%s*%{%s*(.-)%s*%}%s*$") or str
    -- Split by ",
    local pos = 1
    while pos <= #str do
        -- Find next key
        local keyStart = str:find('"', pos)
        if not keyStart then break end
        local keyEnd = str:find('"', keyStart + 1)
        if not keyEnd then break end
        local key = str:sub(keyStart + 1, keyEnd - 1)
        -- Skip colon
        local colon = str:find(":", keyEnd + 1)
        if not colon then break end
        -- Parse value
        local valStr = str:sub(colon + 1):match("^%s*([^,}]*)")
        if valStr then
            valStr = valStr:match("^%s*(.-)%s*$")
            local val
            if valStr:sub(1, 1) == '"' then
                val = valStr:sub(2, -2)
            elseif valStr == "true" then
                val = true
            elseif valStr == "false" then
                val = false
            elseif valStr == "null" then
                val = nil
            else
                val = tonumber(valStr)
            end
            obj[key] = val
            pos = colon + #valStr + 1
            -- Skip comma
            local comma = str:find(",", pos)
            if comma then pos = comma + 1 end
        else
            break
        end
    end
    return obj
end

-- ===== Metadata Management =====

function save.loadMetadata()
    local root = getSaveRoot()
    local metaPath = root .. "/worlds.json"
    local f = io.open(metaPath, "r")
    if not f then
        save.saves = {}
        return
    end
    local content = f:read("*a")
    f:close()
    local ok, data = pcall(jsonDecode, content)
    if ok and type(data) == "table" then
        save.saves = data
    else
        save.saves = {}
    end
end

function save.saveMetadata()
    local root = getSaveRoot()
    ensureDir(root)
    local metaPath = root .. "/worlds.json"
    local json = jsonEncode(save.saves)
    local f = io.open(metaPath, "w")
    if f then
        f:write(json)
        f:close()
    end
end

function save.getSaves()
    return save.saves
end

-- ===== World Save / Load =====

-- Save current world to a slot
function save.saveWorld(slot, name, world, player, gameState, playTime)
    local root = getSaveRoot()
    local slotDir = root .. "/slot_" .. tostring(slot)
    ensureDir(slotDir)

    -- Save tiles
    local tileData = serializeTiles(world.tiles, world.width, world.height)
    local tileFile = io.open(slotDir .. "/tiles.dat", "wb")
    if tileFile then
        tileFile:write(tileData)
        tileFile:close()
    end

    -- Save player & game state as serialized table
    local stateData = serializeTable({
        playerX = player.x, playerY = player.y,
        health = player.health, hunger = player.hunger,
        techLevel = player.techLevel,
        equippedSlot = player.equippedSlot,
        inventory = player.inventory,
        seed = world.seed,
        dayTime = gameState.dayTime or 0,
    })
    local stateFile = io.open(slotDir .. "/state.dat", "wb")
    if stateFile then
        stateFile:write(stateData)
        stateFile:close()
    end

    -- Update metadata
    save.saves[slot] = {
        slot = slot,
        name = name,
        seed = world.seed,
        playTime = playTime or 0,
        lastPlayed = os.date("%Y-%m-%d %H:%M:%S"),
        version = "1.0",
    }
    save.saveMetadata()

    logger.info("World saved to slot " .. tostring(slot) .. " (" .. name .. ")")
    return true
end

-- Load a world from a slot
function save.loadWorld(slot)
    local root = getSaveRoot()
    local slotDir = root .. "/slot_" .. tostring(slot)

    -- Load tiles
    local tileFile = io.open(slotDir .. "/tiles.dat", "rb")
    if not tileFile then
        logger.warn("No save data in slot " .. tostring(slot))
        return nil
    end
    local tileData = tileFile:read("*a")
    tileFile:close()

    -- Load player & state
    local stateFile = io.open(slotDir .. "/state.dat", "rb")
    local stateStr = stateFile and stateFile:read("*a") or ""
    if stateFile then stateFile:close() end
    local stateData = stateStr ~= "" and deserializeTable(stateStr) or {}

    return {
        tileData = tileData,
        state = stateData,
    }
end

-- Deserialize tiles from raw string to 2D grid
function save.deserializeTileData(data, w, h)
    return deserializeTiles(data, w, h)
end

-- Delete a save slot
function save.deleteWorld(slot)
    local root = getSaveRoot()
    local slotDir = root .. "/slot_" .. tostring(slot)
    os.execute("rm -rf '" .. slotDir .. "' 2>/dev/null")
    save.saves[slot] = nil
    save.saveMetadata()
    logger.info("Deleted world in slot " .. tostring(slot))
end

-- Get next available slot number
function save.getNextSlot()
    local maxSlot = 0
    for _, s in pairs(save.saves) do
        if s.slot > maxSlot then maxSlot = s.slot end
    end
    return maxSlot + 1
end

-- Initialize save system
function save.init()
    getSaveRoot()
    ensureDir(SAVE_ROOT)
    save.loadMetadata()
    logger.info("Save system ready: " .. SAVE_ROOT)
end

return save
