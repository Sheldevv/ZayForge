#!/usr/bin/env bash

rm -rf build 2>/dev/null
mkdir -p build

zip -9 -r build/ZayForge.love . \
    -x ".git/*" \
    -x "build/*" \
    -x ".vscode/*" \
    -x "*.sh" \
    -x "*.md" \
    -x "*.toml" \
    -x ".gitignore" \
    -x "LICENSE" \
    -x "makelove-build/*" \
    -x "release/*"

tmp=$(mktemp)
cd $tmp

if command -v wget2 2>/dev/null; then
    wget2 https://github.com/love2d/love/releases/download/11.5/love-11.5-x86_64.AppImage -O love.AppImage
elif command -v wget 2>/dev/null; then
    wget https://github.com/love2d/love/releases/download/11.5/love-11.5-x86_64.AppImage -O love.AppImage
elif command -v curl 2>/dev/null; then
    curl -L https://github.com/love2d/love/releases/download/11.5/love-11.5-x86_64.AppImage -o love.AppImage
else
    echo "Error: No suitable download tool found (wget2, wget, or curl)."
    exit 1
fi

./love.AppImage --appimage-extract
cd squashfs-root
