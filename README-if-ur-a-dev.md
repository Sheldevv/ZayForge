# Contributing to ZayForge

## Step 1 - Editor
You can use any editor (with Lua support) you want but preferably VSCode.
If you already have VSCode, install the recommended extensions:
1. https://marketplace.visualstudio.com/items?itemName=pixelbyte-studios.pixelbyte-love2d - To run ZayForge easily
2. https://marketplace.visualstudio.com/items?itemName=pixelwar.love2dsnippets - Makes coding in Lua + Love2D easier =D
3. https://marketplace.visualstudio.com/items?itemName=sumneko.lua - Lua Support
3. https://marketplace.visualstudio.com/items?itemName=abyo-software.love2d-dev-tools - Love2D Support
4. https://marketplace.visualstudio.com/items?itemName=yinfei.luahelper - more Lua Support

## Step 3 - Running
if you install the [Love2D support extension](https://marketplace.visualstudio.com/items?itemName=pixelbyte-studios.pixelbyte-love2d) installed, run the default keybind `Alt+L`
> Note: LOVE2D needs to be installed on your system and if you're not using VSCode, you can run:
```bash
love . # replace `love` with love binary location (unless in PATH)
```

## Step 3.5 - Building
I recommend using my modified version of [Boon](https://github.com/camchenry/boon) https://github.com/Sheldevv/boon (Linux & Windows ONLY)
If you want to build to specific OS, run:
```bash
boon build . --target <OS>
```
but if you want to build to all available OS (Linux, Mac, Windows, Love), run:
```bash
boon build .
```