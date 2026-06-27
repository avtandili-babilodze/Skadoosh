#!/usr/bin/env bash
# One-click launcher for Skadoosh (Linux / macOS).
# Downloads Godot 4.3 automatically on first run, then plays the game.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
VER="4.3-stable"
BIN_DIR="$DIR/.godot-bin"

# 1) Use an existing Godot if one is already installed/downloaded.
GODOT=""
if command -v godot >/dev/null 2>&1; then
    GODOT="$(command -v godot)"
elif command -v godot4 >/dev/null 2>&1; then
    GODOT="$(command -v godot4)"
fi

# 2) Otherwise download a local copy (no system install needed).
if [ -z "$GODOT" ]; then
    OS="$(uname -s)"
    case "$OS" in
        Linux)
            URL="https://github.com/godotengine/godot/releases/download/$VER/Godot_v${VER}_linux.x86_64.zip"
            EXE="$BIN_DIR/Godot_v${VER}_linux.x86_64" ;;
        Darwin)
            URL="https://github.com/godotengine/godot/releases/download/$VER/Godot_v${VER}_macos.universal.zip"
            EXE="$BIN_DIR/Godot.app/Contents/MacOS/Godot" ;;
        *)
            echo "Unsupported OS: $OS — please install Godot 4.3 manually." ; exit 1 ;;
    esac

    if [ ! -x "$EXE" ]; then
        echo "Godot not found. Downloading Godot $VER (one-time, ~70 MB)..."
        mkdir -p "$BIN_DIR"
        ZIP="$BIN_DIR/godot.zip"
        if command -v curl >/dev/null 2>&1; then
            curl -L -o "$ZIP" "$URL"
        else
            wget -O "$ZIP" "$URL"
        fi
        unzip -o "$ZIP" -d "$BIN_DIR"
        rm -f "$ZIP"
        chmod +x "$EXE" 2>/dev/null || true
    fi
    GODOT="$EXE"
fi

echo "Launching Skadoosh with: $GODOT"
exec "$GODOT" --path "$DIR"
