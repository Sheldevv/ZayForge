-- ZayForge – Core Game Module
-- Top-down sandbox survival (Minecraft x Mindustry)

local logger = require("logger")
local game = {}

-- ===== World System =====
local World = {}
World.tiles = {}          -- 2D tile grid
World.width = 100         -- World width in tiles
World.height = 100        -- World height in tiles
World.tileSize = 48       -- Pixels per tile
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
    [0]  = {0.05, 0.05, 0.1},     -- Air
    [1]  = {0.2, 0.5, 0.1},        -- Grass
    [2]  = {0.4, 0.3, 0.15},       -- Dirt
    [3]  = {0.5, 0.5, 0.5},        -- Stone
    [4]  = {0.2, 0.2, 0.2},        -- Coal ore
    [5]  = {0.7, 0.5, 0.3},        -- Iron ore
    [6]  = {0.8, 0.5, 0.2},        -- Copper ore
    [7]  = {0.6, 0.7, 0.8},        -- Titanium ore
    [8]  = {0.1, 0.3, 0.8},        -- Water
    [9]  = {0.8, 0.7, 0.4},        -- Sand
    [10] = {0.1, 0.4, 0.05},       -- Tree
    [11] = {0.6, 0.4, 0.2},        -- Workbench
    [12] = {0.5, 0.3, 0.2},        -- Furnace
    [13] = {0.5, 0.35, 0.1},       -- Chest
    [14] = {0.3, 0.3, 0.3},        -- Conveyor
    [15] = {0.4, 0.4, 0.4},        -- Drill
    [16] = {0.5, 0.35, 0.2},       -- Wood wall
    [17] = {0.4, 0.4, 0.4},        -- Stone wall
    [18] = {0.3, 0.3, 0.4},        -- Turret
    [19] = {0.6, 0.5, 0.1},        -- Generator
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
Player.x = 50 * 48 + 24    -- Center of spawn tile
Player.y = 50 * 48 + 24
Player.speed = 250
Player.size = 16
Player.health = 100
Player.maxHealth = 100
Player.hunger = 100
Player.maxHunger = 100
Player.inventory = {}       -- {name, count}
Player.equippedSlot = 1
Player.techLevel = 0        -- Mindustry-like tech progression

-- ===== Resource System =====
local Resources = {}

Resources.items = {
    wood       = {name = "Wood",        color = {0.5, 0.35, 0.2}},
    stone      = {name = "Stone",       color = {0.5, 0.5, 0.5}},
    coal       = {name = "Coal",        color = {0.2, 0.2, 0.2}},
    iron_ore   = {name = "Iron Ore",    color = {0.7, 0.5, 0.3}},
    copper_ore = {name = "Copper Ore",  color = {0.8, 0.5, 0.2}},
    iron_ingot = {name = "Iron Ingot",  color = {0.8, 0.8, 0.8}},
    copper_ingot = {name = "Copper Ingot", color = {0.9, 0.7, 0.3}},
    titanium   = {name = "Titanium",    color = {0.6, 0.7, 0.8}},
}

-- ===== Tech Tree (Mindustry-inspired) =====
local TechTree = {}
TechTree.levels = {
    [0] = { -- Starting
        unlock = {"wood", "stone"},
        buildings = {"workbench", "wall_wood", "chest"}
    },
    [1] = { -- Basic automation
        unlock = {"coal", "iron_ore", "copper_ore"},
        buildings = {"furnace", "conveyor", "drill", "generator"}
    },
    [2] = { -- Advanced
        unlock = {"iron_ingot", "copper_ingot", "titanium"},
        buildings = {"wall_stone", "turret"}
    }
}

-- ===== Game State =====
local fonts = {}
local debugInfo = {}
local dayTime = 0
local placementMode = nil  -- What we're currently placing
local selectedTile = nil   -- Mouse-over tile coords

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
    table.insert(Player.inventory, {name = itemName, count = count or 1})
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

function game.load()
    logger.info("Loading game world...")
    
    -- Generate world
    World.seed = os.time()
    World.generate()
    
    -- Reset player
    Player.x = 50 * World.tileSize + World.tileSize / 2
    Player.y = 50 * World.tileSize + World.tileSize / 2
    Player.inventory = {}
    Player.techLevel = 0
    Player.health = Player.maxHealth
    Player.hunger = Player.maxHunger
    
    -- Starting items (Minecraft-like start)
    addToInventory("wood", 10)
    addToInventory("stone", 5)
    
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
    
    logger.info("Game world loaded!")
end

function game.update(dt)
    local ww, wh = love.graphics.getDimensions()
    
    -- Day/night cycle
    dayTime = dayTime + dt * 0.1
    
    -- Player movement (WASD)
    local dx, dy = 0, 0
    if love.keyboard.isDown("w") then dy = dy - 1 end
    if love.keyboard.isDown("s") then dy = dy + 1 end
    if love.keyboard.isDown("a") then dx = dx - 1 end
    if love.keyboard.isDown("d") then dx = dx + 1 end
    
    -- Normalize diagonal movement
    local len = math.sqrt(dx*dx + dy*dy)
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
    selectedTile = {screenToWorld(mx, my)}
    
    -- Hunger decreases over time
    Player.hunger = math.max(0, Player.hunger - dt * 0.5)
    if Player.hunger <= 0 then
        Player.health = math.max(0, Player.health - dt * 2)
    end
    
    -- Update debug info
    if GameState.debug then
        local tileX, tileY = screenToWorld(Player.x, Player.y)
        debugInfo.playerTile = {tileX, tileY}
        debugInfo.fps = love.timer.getFPS()
        debugInfo.entities = 0
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
                local color = World.tileColors[tile] or {0.5, 0.5, 0.5}
                
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
    
    -- Draw player
    local px = Player.x - World.cameraX
    local py = Player.y - World.cameraY
    love.graphics.setColor(0.2, 0.8, 1)
    love.graphics.circle("fill", px, py, Player.size)
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.circle("line", px, py, Player.size)
    
    -- Draw UI
    drawUI()
    
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
    
    -- Instructions
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("WASD: Move | Click: Mine/Place | ESC: Menu", 20, 20)
    
    -- Placement mode
    if placementMode then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Placing: " .. placementMode .. " (Right-click to cancel)", ww/2 - 100, 50)
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

-- ---- Input Handling ----

function game.keypressed(key)
    if key == "escape" then
        logger.info("Returning to menu")
        placementMode = nil
        GameState.current = "menu"
    elseif key == "1" then Player.equippedSlot = 1
    elseif key == "2" then Player.equippedSlot = 2
    elseif key == "3" then Player.equippedSlot = 3
    elseif key == "4" then Player.equippedSlot = 4
    elseif key == "5" then Player.equippedSlot = 5
    elseif key == "6" then Player.equippedSlot = 6
    elseif key == "7" then Player.equippedSlot = 7
    elseif key == "8" then Player.equippedSlot = 8
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
            local dist = math.sqrt((tileX - playerTileX)^2 + (tileY - playerTileY)^2)
            
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
    -- Handle window resize
end

return game