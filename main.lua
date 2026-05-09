if os.getenv("LOVE2D_TOOLS") then pcall(require, "_love2d_tools_bridge") end
-- ZayForge – Main Router
-- A 2D top-down sandbox survival game (Minecraft x Mindustry)

local logger = require("logger")
local lang = require("lang")

-- Global state
GameState = {
    current = "menu",  -- 'menu', 'game', 'options'
    debug = false       -- Toggle debug info
}

function love.load()
    logger.info("Initializing ZayForge (" .. love.system.getOS() .. ")...")
    
    -- Initialize language system first
    lang.init()
    
    -- Load modules
    GameState.menu = require("menu")
    GameState.game = require("game")
    GameState.options = require("options")
    
    -- Initialize starting module
    GameState.menu.load()
    
    logger.info("ZayForge initialized successfully!")
end

function love.update(dt)
    if GameState.current == "menu" then
        GameState.menu.update(dt)
    elseif GameState.current == "game" then
        GameState.game.update(dt)
    elseif GameState.current == "options" then
        GameState.options.update(dt)
    end
end

function love.draw()
    if GameState.current == "menu" then
        GameState.menu.draw()
    elseif GameState.current == "game" then
        GameState.game.draw()
    elseif GameState.current == "options" then
        GameState.options.draw()
    end
end

function love.keypressed(key)
    -- Global debug toggle (don't return, pass to module too)
    if key == "f3" then
        GameState.debug = not GameState.debug
        logger.debug("Debug mode: " .. tostring(GameState.debug))
        -- Don't return - let the game module also know about F3 if needed
    end
    
    if GameState.current == "menu" then
        GameState.menu.keypressed(key)
    elseif GameState.current == "game" then
        GameState.game.keypressed(key)
    elseif GameState.current == "options" then
        GameState.options.keypressed(key)
    end
end

function love.mousemoved(x, y, dx, dy)
    if GameState.current == "menu" then
        GameState.menu.mousemoved(x, y, dx, dy)
    elseif GameState.current == "game" then
        GameState.game.mousemoved(x, y, dx, dy)
    elseif GameState.current == "options" then
        GameState.options.mousemoved(x, y, dx, dy)
    end
end

function love.mousepressed(x, y, button)
    if GameState.current == "menu" then
        GameState.menu.mousepressed(x, y, button)
    elseif GameState.current == "game" then
        GameState.game.mousepressed(x, y, button)
    elseif GameState.current == "options" then
        GameState.options.mousepressed(x, y, button)
    end
end

function love.mousereleased(x, y, button)
    if GameState.current == "game" then
        GameState.game.mousereleased(x, y, button)
    elseif GameState.current == "options" then
        GameState.options.mousereleased(x, y, button)
    end
end

function love.resize(w, h)
    if GameState.current == "menu" then
        GameState.menu.resize(w, h)
    elseif GameState.current == "game" then
        GameState.game.resize(w, h)
    elseif GameState.current == "options" then
        GameState.options.resize(w, h)
    end
end