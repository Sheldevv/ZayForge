-- ZayForge – Configuration File
-- Top-down sandbox survival game (Minecraft x Mindustry)

function love.conf(t)
    -- ===== Identity =====
    t.identity = "zayforge"              -- Save directory name (string)
    t.appendidentity = false             -- Search source directory before save directory (boolean)
    t.version = "11.5"                   -- LÖVE version this game was made for (string)
    t.console = false                    -- Attach console (boolean, Windows only)
    t.accelerometerjoystick = true       -- Enable accelerometer on iOS/Android as Joystick (boolean)
    t.externalstorage = false            -- Save files in external storage on Android (boolean)
    t.gammacorrect = false               -- Enable gamma-correct rendering (boolean)

    -- ===== Audio =====
    t.audio.mic = false                  -- Request microphone on Android (boolean)
    t.audio.mixwithsystem = true         -- Keep background music when opening LOVE (boolean, iOS/Android)

    -- ===== Window Settings =====
    t.window.title = "ZayForge"          -- Window title (string)
    t.window.icon = "assets/images/icon.png"  -- Window icon (string)
    t.window.width = 1024                -- Window width (number)
    t.window.height = 768                -- Window height (number)
    t.window.borderless = false          -- Remove window borders (boolean)
    t.window.resizable = true            -- Allow window resizing (boolean)
    t.window.minwidth = 800              -- Minimum window width (number)
    t.window.minheight = 600             -- Minimum window height (number)
    t.window.fullscreen = false          -- Enable fullscreen (boolean)
    t.window.fullscreentype = "desktop"  -- Fullscreen type: "desktop" or "exclusive" (string)
    t.window.vsync = 1                   -- Vertical sync mode: 0=disabled, 1=enabled, 2=adaptive (number)
    t.window.msaa = 4                    -- Multisample antialiasing samples (number)
    t.window.depth = 24                  -- Depth buffer bits per sample (number)
    t.window.stencil = 8                 -- Stencil buffer bits per sample (number)
    t.window.display = 1                 -- Monitor index to display on (number)
    t.window.highdpi = true              -- Enable high-dpi on Retina displays (boolean)
    t.window.usedpiscale = true          -- Enable automatic DPI scaling (boolean)
    t.window.x = nil                     -- Window x-coordinate (number, nil for centered)
    t.window.y = nil                     -- Window y-coordinate (number, nil for centered)

    -- ===== Module Settings =====
    t.modules.audio = true               -- Enable audio module (boolean)
    t.modules.data = true                -- Enable data module (boolean)
    t.modules.event = true               -- Enable event module (boolean)
    t.modules.font = true                -- Enable font module (boolean)
    t.modules.graphics = true            -- Enable graphics module (boolean)
    t.modules.image = true               -- Enable image module (boolean)
    t.modules.joystick = true            -- Enable joystick module (boolean)
    t.modules.keyboard = true            -- Enable keyboard module (boolean)
    t.modules.math = true                -- Enable math module (boolean)
    t.modules.mouse = true               -- Enable mouse module (boolean)
    t.modules.physics = false            -- Enable physics module (boolean) - Disabled: using custom collision
    t.modules.sound = true               -- Enable sound module (boolean)
    t.modules.system = true              -- Enable system module (boolean)
    t.modules.thread = true              -- Enable thread module (boolean) - For future async operations
    t.modules.timer = true               -- Enable timer module (boolean)
    t.modules.touch = true               -- Enable touch module (boolean)
    t.modules.video = false              -- Enable video module (boolean) - Disabled: not needed
    t.modules.window = true              -- Enable window module (boolean)
end