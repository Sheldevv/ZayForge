# ZayForge

**ZayForge** is a 2D top-down survival/RPG game inspired by Minecraft, built with LÖVE (Love2D).

Explore, survive, and craft in a pixel-art world with top-down action and RPG elements.

## Features

- Top-down survival gameplay
- RPG progression and exploration
- Pixel-art visuals and retro-style audio
- Built with the Love2D game framework

## Requirements

- [Love2D](https://love2d.org/) installed on your system
- Lua-compatible editor or IDE for development

## Run the Game

From the project root, run:

```bash
love .
```

If you use Visual Studio Code, the `pixelbyte-love2d` extension is recommended for easy running and debugging.

## Development

Recommended VS Code extensions:

- `pixelbyte-studios.pixelbyte-love2d` — run ZayForge easily (Windows & Mac ONLY)
- `pixelwar.love2dsnippets` — Lua + Love2D snippets
- `sumneko.lua` & `yinfei.luahelper` — Lua language support
- `abyo-software.love2d-dev-tools` — Love2D Support (Cross-platform)

## Build

ZayForge uses `Boon` for packaging and building or makelove.

To build for a specific platform:

```bash
boon build . --target <OS>
```

To build for all available targets (Linux, macOS, Windows, Love):

```bash
boon build .
```

> Note: A modified Boon fork is recommended: https://github.com/Sheldevv/boon

## Release

The `release/` folder contains packaged builds, including `ZayForge.love` and a macOS bundle.

## License
[MIT](LICENSE)

## Credits
ZayForge is made by [Zayfire Studios](https://zayfirestudios.com/) <br>
Coder: [Sheldevv Pierre](https://discord.com/users/1170755742521905326) <br>
Music: [Zaiden Burns](https://discord.com/users/959235165375307837) <br>
Idea: [Sheldevv](https://discord.com/users/1170755742521905326) + [Mateo](https://discord.com/users/1321676414126391346)