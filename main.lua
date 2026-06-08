if os.getenv("LOVE2D_TOOLS") then pcall(require, "_love2d_tools_bridge") end
-- ZayForge – Main Router
-- A 2D top-down sandbox survival game (Minecraft x Mindustry)

local logger = require("logger")
local lang = require("lang")
local online = require("online")
local save = require("save")
-- local lovefs = require("lovefs.lovefs")

-- Global state
GameState = {
    current = "menu", -- 'menu', 'game', 'options'
    debug = false     -- Toggle debug info
}

local function applyMobileSettings()
    local osName = love.system.getOS()
    if osName == "Android" or osName == "iOS" then
        -- Set fullscreen with orientation-aware dimensions
        love.window.setFullscreen(true, "exclusive")

        logger.info("Mobile mode enabled for: " .. osName)
    end
end

function love.load(args)
    logger.info("Initializing ZayForge (" .. love.system.getOS() .. ")...")

    -- Add local luarocks paths to C loader so pgmoon can find luasec (ssl.so)
    local home = os.getenv("HOME") or os.getenv("USERPROFILE")
    if home then
        local lr_clib = home .. "/.luarocks/lib/lua/5.1/?.so"
        local lr_lib  = home .. "/.luarocks/share/lua/5.1/?.lua;" ..
                       home .. "/.luarocks/share/lua/5.1/?/init.lua"
        package.cpath = lr_clib .. ";" .. (package.cpath or "")
        package.path  = lr_lib  .. ";" .. (package.path or "")
    end

    -- Parse online args from launcher: --online=true/false --account-id=<uuid>
    online.parseArgs(args)

    -- Initialize save system
    save.init()

    -- Initialize language system first
    lang.init()

    -- Load modules
    GameState.menu = require("menu")
    GameState.game = require("game")
    GameState.options = require("options")

    -- Initialize starting module
    GameState.menu.load(args)

    -- Apply mobile settings after modules are loaded so they can react
    applyMobileSettings()

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
    if key == "back" then
        if GameState.current == "game" then
            -- Save and return to menu
            GameState.game.saveWorld()
            GameState.current = "menu"
            GameState.menu.load()
        elseif GameState.current == "menu" then
            love.event.quit()
        elseif GameState.current == "options" then
            GameState.current = "menu"
            GameState.menu.load()
        end
        return
    end
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

function love.quit()
    logger.info("ZayForge shutting down...")
    online.shutdown()
    logger.close()
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

function love.touchpressed(id, x, y, dx, dy, pressure)
    if GameState.current == "menu" then
        GameState.menu.touchpressed(id, x, y, dx, dy, pressure)
    elseif GameState.current == "game" then
        GameState.game.touchpressed(id, x, y, dx, dy, pressure)
    elseif GameState.current == "options" then
        GameState.options.touchpressed(id, x, y, dx, dy, pressure)
    end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    if GameState.current == "menu" then
        GameState.menu.touchreleased(id, x, y, dx, dy, pressure)
    elseif GameState.current == "game" then
        GameState.game.touchreleased(id, x, y, dx, dy, pressure)
    elseif GameState.current == "options" then
        GameState.options.touchreleased(id, x, y, dx, dy, pressure)
    end
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    if GameState.current == "menu" then
        GameState.menu.touchmoved(id, x, y, dx, dy, pressure)
    elseif GameState.current == "game" then
        GameState.game.touchmoved(id, x, y, dx, dy, pressure)
    elseif GameState.current == "options" then
        GameState.options.touchmoved(id, x, y, dx, dy, pressure)
    end
end
