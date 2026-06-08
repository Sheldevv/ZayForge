-- ZayForge – Core Game Module
-- Top-down sandbox survival (Minecraft x Mindustry)

local logger = require("logger")
local mobile = require("mobile")
local online = require("online")
local game = {}

-- ===== World System =====
local World = {}
World.tiles = {}    -- 2D tile grid
World.width = 100   -- World width in tiles
World.height = 100  -- World height in tiles
World.tileSize = 48 -- Pixels per tile
World.cameraX = 0
World.cameraY = 0
World.seed = 0

-- Tile types
World.TILE = {
    AIR = 0,
    GRASS = 1,
    DIRT = 2,
    STONE = 3,
    ORE_COAL = 4,
    ORE_IRON = 5,
    ORE_COPPER = 6,
    ORE_TITANIUM = 7,
    WATER = 8,
    SAND = 9,
    TREE = 10,
    WORKBENCH = 11,
    FURNACE = 12,
    CHEST = 13,
    CONVEYOR = 14,
    DRILL = 15,
    WALL_WOOD = 16,
    WALL_STONE = 17,
    TURRET = 18,
    GENERATOR = 19,
}

-- Tile colors (for rendering)
World.tileColors = {
    [0]  = { 0.05, 0.05, 0.1 }, -- Air
    [1]  = { 0.2, 0.5, 0.1 },   -- Grass
    [2]  = { 0.4, 0.3, 0.15 },  -- Dirt
    [3]  = { 0.5, 0.5, 0.5 },   -- Stone
    [4]  = { 0.2, 0.2, 0.2 },   -- Coal ore
    [5]  = { 0.7, 0.5, 0.3 },   -- Iron ore
    [6]  = { 0.8, 0.5, 0.2 },   -- Copper ore
    [7]  = { 0.6, 0.7, 0.8 },   -- Titanium ore
    [8]  = { 0.1, 0.3, 0.8 },   -- Water
    [9]  = { 0.8, 0.7, 0.4 },   -- Sand
    [10] = { 0.1, 0.4, 0.05 },  -- Tree
    [11] = { 0.6, 0.4, 0.2 },   -- Workbench
    [12] = { 0.5, 0.3, 0.2 },   -- Furnace
    [13] = { 0.5, 0.35, 0.1 },  -- Chest
    [14] = { 0.3, 0.3, 0.3 },   -- Conveyor
    [15] = { 0.4, 0.4, 0.4 },   -- Drill
    [16] = { 0.5, 0.35, 0.2 },  -- Wood wall
    [17] = { 0.4, 0.4, 0.4 },   -- Stone wall
    [18] = { 0.3, 0.3, 0.4 },   -- Turret
    [19] = { 0.6, 0.5, 0.1 },   -- Generator
}

function World.generate()
    logger.info("Generating world (seed: " .. World.seed .. ")...")
    math.randomseed(World.seed)

    -- Initialize tile grid
    for x = 1, World.width do
        World.tiles[x] = {}
        for y = 1, World.height do
            local rand = math.random()
            if rand < 0.005 then
                World.tiles[x][y] = World.TILE.WATER
            elseif rand < 0.02 then
                World.tiles[x][y] = World.TILE.SAND
            elseif rand < 0.05 then
                World.tiles[x][y] = World.TILE.STONE
            elseif rand < 0.06 then
                World.tiles[x][y] = World.TILE.ORE_COAL
            elseif rand < 0.07 then
                World.tiles[x][y] = World.TILE.ORE_IRON
            elseif rand < 0.075 then
                World.tiles[x][y] = World.TILE.ORE_COPPER
            elseif rand < 0.078 then
                World.tiles[x][y] = World.TILE.ORE_TITANIUM
            elseif rand < 0.15 then
                World.tiles[x][y] = World.TILE.TREE
            else
                World.tiles[x][y] = World.TILE.GRASS
            end
        end
    end

    -- Spawn point clearing
    for dx = -2, 2 do
        for dy = -2, 2 do
            local sx, sy = 50 + dx, 50 + dy
            if World.tiles[sx] and World.tiles[sx][sy] then
                if World.tiles[sx][sy] == World.TILE.TREE or
                    World.tiles[sx][sy] == World.TILE.STONE then
                    World.tiles[sx][sy] = World.TILE.GRASS
                end
            end
        end
    end

    logger.info("World generation complete!")
end

-- ===== Player System =====
local Player = {}
Player.x = 50 * 48 + 24 -- Center of spawn tile
Player.y = 50 * 48 + 24
Player.speed = 250
Player.size = 16
Player.health = 100
Player.maxHealth = 100
Player.hunger = 100
Player.maxHunger = 100
Player.inventory = {} -- {name, count}
Player.equippedSlot = 1
Player.techLevel = 0  -- Mindustry-like tech progression

-- ===== Resource System =====
local Resources = {}

Resources.items = {
    wood         = { name = "Wood", color = { 0.5, 0.35, 0.2 } },
    stone        = { name = "Stone", color = { 0.5, 0.5, 0.5 } },
    coal         = { name = "Coal", color = { 0.2, 0.2, 0.2 } },
    iron_ore     = { name = "Iron Ore", color = { 0.7, 0.5, 0.3 } },
    copper_ore   = { name = "Copper Ore", color = { 0.8, 0.5, 0.2 } },
    iron_ingot   = { name = "Iron Ingot", color = { 0.8, 0.8, 0.8 } },
    copper_ingot = { name = "Copper Ingot", color = { 0.9, 0.7, 0.3 } },
    titanium     = { name = "Titanium", color = { 0.6, 0.7, 0.8 } },
}

-- ===== Tech Tree (Mindustry-inspired) =====
local TechTree = {}
TechTree.levels = {
    [0] = { -- Starting
        unlock = { "wood", "stone" },
        buildings = { "workbench", "wall_wood", "chest" }
    },
    [1] = { -- Basic automation
        unlock = { "coal", "iron_ore", "copper_ore" },
        buildings = { "furnace", "conveyor", "drill", "generator" }
    },
    [2] = { -- Advanced
        unlock = { "iron_ingot", "copper_ingot", "titanium" },
        buildings = { "wall_stone", "turret" }
    }
}

-- ===== Game State =====
local fonts = {}
local debugInfo = {}
local dayTime = 0
local placementMode = nil -- What we're currently placing
local selectedTile = nil  -- Mouse-over tile coords
local saveSlot = nil       -- Current save slot (nil = unsaved new world)
local worldName = "World"  -- Display name for current world
local playTime = 0         -- Total play time in seconds
local autoSaveTimer = 0    -- Countdown to next auto-save
local saveLib = nil        -- Will be set to require("save")

-- ---- Helpers ----

local function worldToScreen(wx, wy)
    return (wx - 0.5) * World.tileSize - World.cameraX,
        (wy - 0.5) * World.tileSize - World.cameraY
end

local function screenToWorld(sx, sy)
    return math.floor((sx + World.cameraX) / World.tileSize) + 1,
        math.floor((sy + World.cameraY) / World.tileSize) + 1
end

local function addToInventory(itemName, count)
    if not Resources.items[itemName] then return false end
    for _, slot in ipairs(Player.inventory) do
        if slot.name == itemName then
            slot.count = slot.count + (count or 1)
            return true
        end
    end
    table.insert(Player.inventory, { name = itemName, count = count or 1 })
    return true
end

local function hasInInventory(itemName, count)
    for _, slot in ipairs(Player.inventory) do
        if slot.name == itemName and slot.count >= (count or 1) then
            return true
        end
    end
    return false
end

local function removeFromInventory(itemName, count)
    for i, slot in ipairs(Player.inventory) do
        if slot.name == itemName then
            slot.count = slot.count - (count or 1)
            if slot.count <= 0 then
                table.remove(Player.inventory, i)
            end
            return true
        end
    end
    return false
end

-- ---- Public Functions ----

function game.load(config)
    config = config or {}
    saveLib = require("save")
    logger.info("Loading game world...")

    -- Init mobile module
    mobile.init()

    -- Determine world source: load from save or generate new
    local loadedSlot = config.slot
    local loadedName = config.name or "World"

    if loadedSlot and saveLib.getSaves()[loadedSlot] then
        -- Load existing world
        logger.info("Loading world from slot " .. tostring(loadedSlot) .. ": " .. loadedName)
        local data = saveLib.loadWorld(loadedSlot)
        if data then
            World.seed = data.state.seed or os.time()
            World.tiles = saveLib.deserializeTileData(data.tileData, World.width, World.height)
            Player.x = data.state.playerX or (50 * World.tileSize + World.tileSize / 2)
            Player.y = data.state.playerY or (50 * World.tileSize + World.tileSize / 2)
            Player.health = data.state.health or Player.maxHealth
            Player.hunger = data.state.hunger or Player.maxHunger
            Player.techLevel = data.state.techLevel or 0
            Player.equippedSlot = data.state.equippedSlot or 1
            Player.inventory = data.state.inventory or {}
            dayTime = data.state.dayTime or 0
            saveSlot = loadedSlot
            worldName = loadedName
            playTime = saveLib.getSaves()[loadedSlot].playTime or 0
        end
    else
        -- Generate new world
        if loadedSlot then saveSlot = loadedSlot; worldName = loadedName end
        World.seed = os.time()
        World.generate()
        Player.x = 50 * World.tileSize + World.tileSize / 2
        Player.y = 50 * World.tileSize + World.tileSize / 2
        Player.inventory = {}
        Player.techLevel = 0
        Player.health = Player.maxHealth
        Player.hunger = Player.maxHunger
        playTime = 0
        -- Starting items
        addToInventory("wood", 10)
        addToInventory("stone", 5)
        -- Auto-save new world immediately
        if saveSlot then
            saveLib.saveWorld(saveSlot, worldName, World, Player, {dayTime = dayTime}, playTime)
        end
    end

    -- Camera
    World.cameraX = Player.x - love.graphics.getWidth() / 2
    World.cameraY = Player.y - love.graphics.getHeight() / 2

    -- Load fonts
    local success = pcall(function()
        fonts.ui = love.graphics.newFont("assets/fonts/airstrike.ttf", 16)
        fonts.small = love.graphics.newFont("assets/fonts/airstrike.ttf", 12)
    end)
    if not success then
        fonts.ui = love.graphics.newFont(16)
        fonts.small = love.graphics.newFont(12)
    end

    -- Give fonts to mobile module for its on-screen button labels
    mobile.setFonts(fonts.ui, fonts.small)
    mobile.updateLayout(love.graphics.getWidth(), love.graphics.getHeight())

    -- Fetch online profile (username + avatar) if launched with --online=true
    if online.enabled then
        logger.info("Online mode active, fetching profile...")
        coroutine.wrap(function()
            local ok = online.fetchProfile()
            if ok then
                logger.info("Profile loaded!")
            else
                logger.warn("Profile fetch failed: " .. (online.lastFetchError or "unknown"))
            end
        end)()
    end

    autoSaveTimer = 60 -- First auto-save in 60 seconds
    logger.info("Game world loaded!")
end

function game.update(dt)
    local ww, wh = love.graphics.getDimensions()

    -- Day/night cycle
    dayTime = dayTime + dt * 0.1

    -- Player movement - combine keyboard and joystick
    local dx, dy = 0, 0

    -- Keyboard input (WASD)
    if love.keyboard.isDown("w") then dy = dy - 1 end
    if love.keyboard.isDown("s") then dy = dy + 1 end
    if love.keyboard.isDown("a") then dx = dx - 1 end
    if love.keyboard.isDown("d") then dx = dx + 1 end

    -- Mobile joystick input (overrides or adds to keyboard)
    local joyX, joyY = mobile.getDirection()
    dx = dx + joyX
    dy = dy + joyY

    -- Normalize diagonal movement
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
        dx, dy = dx / len, dy / len
    end

    Player.x = Player.x + dx * Player.speed * dt
    Player.y = Player.y + dy * Player.speed * dt

    -- Camera follow
    World.cameraX = Player.x - ww / 2
    World.cameraY = Player.y - wh / 2

    -- Update selected tile
    local mx, my = love.mouse.getPosition()
    selectedTile = { screenToWorld(mx, my) }

    -- Hunger decreases over time
    Player.hunger = math.max(0, Player.hunger - dt * 0.5)
    if Player.hunger <= 0 then
        Player.health = math.max(0, Player.health - dt * 2)
    end

    -- Update debug info
    if GameState.debug then
        local tileX, tileY = screenToWorld(Player.x, Player.y)
        debugInfo.playerTile = { tileX, tileY }
        debugInfo.fps = love.timer.getFPS()
        debugInfo.entities = 0
    end

    -- Auto-save
    if saveSlot then
        playTime = playTime + dt
        autoSaveTimer = autoSaveTimer - dt
        if autoSaveTimer <= 0 then
            game.saveWorld()
            autoSaveTimer = 60
        end
    end
end

function game.draw()
    local ww, wh = love.graphics.getDimensions()

    -- Background
    love.graphics.setColor(0.1, 0.1, 0.15)
    love.graphics.rectangle("fill", 0, 0, ww, wh)

    -- Draw world tiles
    local startX = math.max(1, math.floor(World.cameraX / World.tileSize) - 1)
    local startY = math.max(1, math.floor(World.cameraY / World.tileSize) - 1)
    local endX = math.min(World.width, math.ceil((World.cameraX + ww) / World.tileSize) + 1)
    local endY = math.min(World.height, math.ceil((World.cameraY + wh) / World.tileSize) + 1)

    for x = startX, endX do
        for y = startY, endY do
            local tile = World.tiles[x] and World.tiles[x][y]
            if tile then
                local sx, sy = worldToScreen(x, y)
                local color = World.tileColors[tile] or { 0.5, 0.5, 0.5 }

                -- Day/night tint
                local brightness = 0.5 + 0.5 * math.sin(dayTime)
                love.graphics.setColor(color[1] * brightness, color[2] * brightness, color[3] * brightness)
                love.graphics.rectangle("fill", sx, sy, World.tileSize, World.tileSize)

                -- Grid lines
                love.graphics.setColor(0, 0, 0, 0.1)
                love.graphics.rectangle("line", sx, sy, World.tileSize, World.tileSize)
            end
        end
    end

    -- Draw selection highlight
    if selectedTile then
        local sx, sy = worldToScreen(selectedTile[1], selectedTile[2])
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.rectangle("fill", sx, sy, World.tileSize, World.tileSize)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle("line", sx, sy, World.tileSize, World.tileSize)
    end

    -- Draw player (avatar if online with PFP, else classic circle)
    local px = Player.x - World.cameraX
    local py = Player.y - World.cameraY

    -- Draw username above player (if online)
    online.drawPlayerName(px, py, Player.size)

    -- Draw the actual player (avatar or circle)
    online.drawPlayerAvatar(px, py, Player.size)

    -- Draw UI
    drawUI()

    -- Draw mobile controls overlay (joystick + buttons)
    if mobile.isTouchDevice then
        mobile.draw()
    end

    -- Debug overlay
    if GameState.debug then
        drawDebug()
    end
end

function drawUI()
    local ww, wh = love.graphics.getDimensions()

    -- Hotbar (Minecraft-style)
    local hotbarW = 400
    local hotbarH = 60
    local hotbarX = ww / 2 - hotbarW / 2
    local hotbarY = wh - hotbarH - 10

    love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
    love.graphics.rectangle("fill", hotbarX, hotbarY, hotbarW, hotbarH, 8, 8)
    love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
    love.graphics.rectangle("line", hotbarX, hotbarY, hotbarW, hotbarH, 8, 8)

    -- Inventory slots
    for i = 1, 8 do
        local slotX = hotbarX + 10 + (i - 1) * 48
        local slotY = hotbarY + 6

        love.graphics.setColor(0.15, 0.15, 0.15, 0.8)
        love.graphics.rectangle("fill", slotX, slotY, 44, 48, 4, 4)

        if i == Player.equippedSlot then
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.rectangle("line", slotX - 2, slotY - 2, 48, 52, 6, 6)
        end

        if Player.inventory[i] then
            local item = Resources.items[Player.inventory[i].name]
            if item then
                love.graphics.setColor(item.color)
                love.graphics.rectangle("fill", slotX + 8, slotY + 8, 28, 28, 4, 4)
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(fonts.small)
                love.graphics.print(tostring(Player.inventory[i].count), slotX + 4, slotY + 4)
            end
        end
    end

    -- Health bar
    local barW = 150
    local barH = 16
    local barX = 20
    local barY = wh - 30

    love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 4, 4)
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.rectangle("fill", barX, barY, barW * (Player.health / Player.maxHealth), barH, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.small)
    love.graphics.print("HP: " .. math.floor(Player.health), barX + 4, barY + 1)

    -- Hunger bar
    barY = barY - barH - 4
    love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 4, 4)
    love.graphics.setColor(1, 0.6, 0.1)
    love.graphics.rectangle("fill", barX, barY, barW * (Player.hunger / Player.maxHunger), barH, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Hunger: " .. math.floor(Player.hunger), barX + 4, barY + 1)

    -- Tech level
    love.graphics.setColor(0.8, 0.6, 0.2)
    love.graphics.print("Tech Level: " .. Player.techLevel, ww - 150, 20)

    -- World name & save status
    love.graphics.setFont(fonts.small)
    if saveSlot then
        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.print(worldName .. " | " .. math.floor(playTime / 60) .. "m", 20, 55)
    else
        love.graphics.setColor(0.8, 0.6, 0.2)
        love.graphics.print(worldName .. " (unsaved)", 20, 55)
    end

    -- Online status / username
    if online.isOnline() then
        love.graphics.setFont(fonts.small)
        local username = online.getUsername() or "Player"
        love.graphics.setColor(0.3, 0.8, 0.3)
        love.graphics.print("Online: " .. username, ww - 150, 38)
    elseif online.enabled then
        -- Online enabled but profile not yet loaded
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.8, 0.6, 0.2)
        love.graphics.print("Connecting...", ww - 150, 38)
    end

    -- Instructions
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("WASD: Move | Click: Mine/Place | ESC: Menu", 20, 20)

    -- Placement mode
    if placementMode then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Placing: " .. placementMode .. " (Right-click to cancel)", ww / 2 - 100, 50)
    end
end

function drawDebug()
    local dbgY = 80
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0, 1, 0)

    love.graphics.print("DEBUG MODE", 20, dbgY)
    dbgY = dbgY + 20
    love.graphics.print("FPS: " .. math.floor((debugInfo.fps or 0)), 20, dbgY)
    dbgY = dbgY + 16
    love.graphics.print("Player Pos: " .. math.floor(Player.x) .. ", " .. math.floor(Player.y), 20, dbgY)
    dbgY = dbgY + 16
    if debugInfo.playerTile then
        love.graphics.print("Tile: " .. debugInfo.playerTile[1] .. ", " .. debugInfo.playerTile[2], 20, dbgY)
        dbgY = dbgY + 16
    end
    love.graphics.print("World Seed: " .. World.seed, 20, dbgY)
    dbgY = dbgY + 16
    love.graphics.print("Camera: " .. math.floor(World.cameraX) .. ", " .. math.floor(World.cameraY), 20, dbgY)
    dbgY = dbgY + 20
    love.graphics.print("Inventory:", 20, dbgY)
    dbgY = dbgY + 16
    for i, slot in ipairs(Player.inventory) do
        love.graphics.print("  " .. i .. ". " .. (Resources.items[slot.name] or {}).name .. " x" .. slot.count, 20, dbgY)
        dbgY = dbgY + 16
    end
end

-- ---- World Save / Load ----

function game.saveWorld()
    if not saveLib then saveLib = require("save") end
    if not saveSlot then
        -- Find a free slot
        saveSlot = saveLib.getNextSlot()
        worldName = "World " .. tostring(saveSlot)
    end
    saveLib.saveWorld(saveSlot, worldName, World, Player, {dayTime = dayTime}, math.floor(playTime))
    logger.debug("World auto-saved to slot " .. tostring(saveSlot))
end

function game.loadWorld(slot)
    if not saveLib then saveLib = require("save") end
    game.load({slot = slot, name = saveLib.getSaves()[slot] and saveLib.getSaves()[slot].name or "World"})
end

function game.getSaveSlot()
    return saveSlot
end

function game.getWorldName()
    return worldName
end

-- ---- Input Handling ----

function game.keypressed(key)
    if key == "escape" then
        logger.info("Returning to menu")
        placementMode = nil
        if saveSlot then
            game.saveWorld()
        end
        GameState.current = "menu"
        GameState.menu.load()
    elseif key == "1" then
        Player.equippedSlot = 1
    elseif key == "2" then
        Player.equippedSlot = 2
    elseif key == "3" then
        Player.equippedSlot = 3
    elseif key == "4" then
        Player.equippedSlot = 4
    elseif key == "5" then
        Player.equippedSlot = 5
    elseif key == "6" then
        Player.equippedSlot = 6
    elseif key == "7" then
        Player.equippedSlot = 7
    elseif key == "8" then
        Player.equippedSlot = 8
    end
end

function game.mousemoved(x, y, dx, dy)
    -- Updated in update loop
end

function game.mousepressed(x, y, button)
    if button == 2 then
        -- Right click - cancel placement
        placementMode = nil
        logger.debug("Placement cancelled")
    elseif button == 1 and selectedTile then
        local tileX, tileY = selectedTile[1], selectedTile[2]

        -- Check tile exists
        if not World.tiles[tileX] or not World.tiles[tileX][tileY] then return end

        local tile = World.tiles[tileX][tileY]

        -- If in placement mode, try to place building
        if placementMode then
            if tile == World.TILE.GRASS or tile == World.TILE.DIRT then
                if placementMode == "workbench" then
                    World.tiles[tileX][tileY] = World.TILE.WORKBENCH
                elseif placementMode == "furnace" then
                    World.tiles[tileX][tileY] = World.TILE.FURNACE
                elseif placementMode == "chest" then
                    World.tiles[tileX][tileY] = World.TILE.CHEST
                elseif placementMode == "drill" then
                    World.tiles[tileX][tileY] = World.TILE.DRILL
                elseif placementMode == "conveyor" then
                    World.tiles[tileX][tileY] = World.TILE.CONVEYOR
                elseif placementMode == "wall_wood" then
                    World.tiles[tileX][tileY] = World.TILE.WALL_WOOD
                elseif placementMode == "wall_stone" then
                    World.tiles[tileX][tileY] = World.TILE.WALL_STONE
                elseif placementMode == "turret" then
                    World.tiles[tileX][tileY] = World.TILE.TURRET
                end
                logger.info("Placed " .. placementMode .. " at " .. tileX .. "," .. tileY)
            end
            placementMode = nil
        else
            -- Mining/building mode
            local playerTileX, playerTileY = screenToWorld(Player.x, Player.y)
            local dist = math.sqrt((tileX - playerTileX) ^ 2 + (tileY - playerTileY) ^ 2)

            if dist <= 4 then -- Interaction range
                if tile == World.TILE.TREE then
                    World.tiles[tileX][tileY] = World.TILE.GRASS
                    addToInventory("wood", 3)
                    logger.debug("Mined tree, got wood x3")
                elseif tile == World.TILE.STONE then
                    World.tiles[tileX][tileY] = World.TILE.GRASS
                    addToInventory("stone", 2)
                    logger.debug("Mined stone, got stone x2")
                elseif tile == World.TILE.ORE_COAL then
                    World.tiles[tileX][tileY] = World.TILE.GRASS
                    addToInventory("coal", 1)
                    logger.debug("Mined coal ore")
                elseif tile == World.TILE.ORE_IRON then
                    World.tiles[tileX][tileY] = World.TILE.GRASS
                    addToInventory("iron_ore", 1)
                    logger.debug("Mined iron ore")
                elseif tile == World.TILE.ORE_COPPER then
                    World.tiles[tileX][tileY] = World.TILE.GRASS
                    addToInventory("copper_ore", 1)
                    logger.debug("Mined copper ore")
                elseif tile == World.TILE.WORKBENCH then
                    -- Open crafting/build menu
                    logger.debug("Workbench - opening build menu")
                    -- For now, just unlock tech level 1
                    if Player.techLevel < 1 then
                        Player.techLevel = 1
                        logger.info("Advanced to tech level 1!")
                    end
                elseif tile == World.TILE.FURNACE then
                    -- Smelt ores
                    if hasInInventory("iron_ore") then
                        removeFromInventory("iron_ore")
                        addToInventory("iron_ingot")
                        logger.debug("Smelted iron ore into iron ingot")
                    elseif hasInInventory("copper_ore") then
                        removeFromInventory("copper_ore")
                        addToInventory("copper_ingot")
                        logger.debug("Smelted copper ore into copper ingot")
                    end
                end
            end
        end
    end
end

function game.mousereleased(x, y, button)
    -- Future use
end

function game.resize(w, h)
    mobile.updateLayout(w, h)
end

local function performMining()
    if not selectedTile then return end
    local tileX, tileY = selectedTile[1], selectedTile[2]
    if not World.tiles[tileX] or not World.tiles[tileX][tileY] then return end

    local playerTileX, playerTileY = screenToWorld(Player.x, Player.y)
    local dist = math.sqrt((tileX - playerTileX) ^ 2 + (tileY - playerTileY) ^ 2)
    if dist > 4 then return end

    local tile = World.tiles[tileX][tileY]
    if tile == World.TILE.TREE then
        World.tiles[tileX][tileY] = World.TILE.GRASS
        addToInventory("wood", 3)
        logger.debug("Mined tree, got wood x3")
    elseif tile == World.TILE.STONE then
        World.tiles[tileX][tileY] = World.TILE.GRASS
        addToInventory("stone", 2)
        logger.debug("Mined stone, got stone x2")
    elseif tile == World.TILE.ORE_COAL then
        World.tiles[tileX][tileY] = World.TILE.GRASS
        addToInventory("coal", 1)
        logger.debug("Mined coal ore")
    elseif tile == World.TILE.ORE_IRON then
        World.tiles[tileX][tileY] = World.TILE.GRASS
        addToInventory("iron_ore", 1)
        logger.debug("Mined iron ore")
    elseif tile == World.TILE.ORE_COPPER then
        World.tiles[tileX][tileY] = World.TILE.GRASS
        addToInventory("copper_ore", 1)
        logger.debug("Mined copper ore")
    end
end

local function performInteraction()
    if not selectedTile then return end
    local tileX, tileY = selectedTile[1], selectedTile[2]
    if not World.tiles[tileX] or not World.tiles[tileX][tileY] then return end

    local playerTileX, playerTileY = screenToWorld(Player.x, Player.y)
    local dist = math.sqrt((tileX - playerTileX) ^ 2 + (tileY - playerTileY) ^ 2)
    if dist > 4 then return end

    local tile = World.tiles[tileX][tileY]
    if tile == World.TILE.WORKBENCH then
        if Player.techLevel < 1 then
            Player.techLevel = 1
            logger.info("Advanced to tech level 1!")
        end
    elseif tile == World.TILE.FURNACE then
        if hasInInventory("iron_ore") then
            removeFromInventory("iron_ore")
            addToInventory("iron_ingot")
            logger.debug("Smelted iron ore into iron ingot")
        elseif hasInInventory("copper_ore") then
            removeFromInventory("copper_ore")
            addToInventory("copper_ingot")
            logger.debug("Smelted copper ore into copper ingot")
        end
    end
end

local function performPlacing()
    if not placementMode or not selectedTile then return end
    local tileX, tileY = selectedTile[1], selectedTile[2]
    if not World.tiles[tileX] or not World.tiles[tileX][tileY] then return end
    local tile = World.tiles[tileX][tileY]

    if tile == World.TILE.GRASS or tile == World.TILE.DIRT then
        local tileMap = {
            workbench  = World.TILE.WORKBENCH,
            furnace    = World.TILE.FURNACE,
            chest      = World.TILE.CHEST,
            drill      = World.TILE.DRILL,
            conveyor   = World.TILE.CONVEYOR,
            wall_wood  = World.TILE.WALL_WOOD,
            wall_stone = World.TILE.WALL_STONE,
            turret     = World.TILE.TURRET,
        }
        local newTile = tileMap[placementMode]
        if newTile then
            World.tiles[tileX][tileY] = newTile
            logger.info("Placed " .. placementMode .. " at " .. tileX .. "," .. tileY)
        end
    end
    placementMode = nil
end

function game.touchpressed(id, x, y, dx, dy, pressure)
    local action = mobile.touchpressed(id, x, y)
    if action == "mine" then
        performMining()
    elseif action == "place" then
        if placementMode then
            performPlacing()
        else
            placementMode = nil
        end
    elseif action == "inventory" then
        -- toggle inventory UI (future)
        logger.debug("Inventory button pressed")
    elseif action == "joystick" then
        -- handled by movement update
    else
        -- Tap on world: first tap = select tile, second tap = mine/interact
        local tileX, tileY = screenToWorld(x, y)
        if selectedTile and selectedTile[1] == tileX and selectedTile[2] == tileY then
            -- Same tile tapped again => perform action
            if placementMode then
                performPlacing()
            else
                performMining()
                performInteraction()
            end
        else
            selectedTile = { tileX, tileY }
        end
    end
end

function game.touchmoved(id, x, y, dx, dy, pressure)
    local handled = mobile.touchmoved(id, x, y)
    -- Update selected tile when dragging (not on joystick)
    if not handled then
        local tileX, tileY = screenToWorld(x, y)
        selectedTile = { tileX, tileY }
    end
end

function game.touchreleased(id, x, y, dx, dy, pressure)
    local released = mobile.touchreleased(id, x, y)
    if released == "place" then
        -- Place button released: toggle placement mode or cancel
        if placementMode then
            placementMode = nil
        end
    end
end

return game
