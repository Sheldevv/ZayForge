#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

warn() {
    echo >&2 "[warning] $*"
}

die() {
    echo >&2 "[error] $*"
    exit 1
}

has() {
    command -v "$1" >/dev/null 2>&1
}

cd "$PROJECT_DIR"

if has boon; then
    boon build .
else
    warn "Boon is not installed. Skipping build step."
fi

has love || die "LÖVE is not installed."

run_game() {
    love .
}

if has entr; then
    find . \
        -type f \
        -name "*.lua" \
        -not -path "*/.git/*" \
        -print \
    | entr -r sh -c 'love .'
else
    warn "'entr' not found. Running without auto-reload."
    run_game
fi