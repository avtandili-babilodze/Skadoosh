#!/usr/bin/env bash
# One-click launcher for Skadoosh (Linux / macOS).
# Auto-updates from GitHub, downloads Godot 4.3 on first run, then plays.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
VER="4.3-stable"
BIN_DIR="$DIR/.godot-bin"

# --- Auto-update settings ---
REPO="avtandili-babilodze/Skadoosh"
BRANCH="main"
VERFILE="$DIR/.skadoosh_version"

# Tiny HTTP helpers (curl preferred, wget fallback).
_fetch() {    # _fetch URL -> stdout
    if command -v curl >/dev/null 2>&1; then curl -fsSL "$1"; else wget -qO- "$1"; fi
}
_download() { # _download URL OUTFILE
    if command -v curl >/dev/null 2>&1; then curl -fsSL -o "$2" "$1"; else wget -qO "$2" "$1"; fi
}

# Pull the newest version from GitHub if the repo changed. Skips quietly on any
# problem (offline, no unzip, etc.) so the game always still launches.
auto_update() {
    [ -n "$SKADOOSH_NOUPDATE" ] && return 0   # already updated this run
    command -v unzip >/dev/null 2>&1 || return 0
    echo "Checking for updates..."
    local api remote local_sha
    api="$(_fetch "https://api.github.com/repos/$REPO/commits/$BRANCH" 2>/dev/null)" || true
    remote="$(printf '%s' "$api" | grep -m1 '"sha"' | sed -E 's/.*"sha"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
    if [ -z "$remote" ]; then echo "  (update check skipped - offline?)"; return 0; fi

    # First run: assume the freshly-downloaded copy is current; just record it.
    if [ ! -f "$VERFILE" ]; then printf '%s\n' "$remote" > "$VERFILE"; return 0; fi

    local_sha="$(cat "$VERFILE" 2>/dev/null || true)"
    if [ "$remote" = "$local_sha" ]; then echo "  already up to date."; return 0; fi

    echo "  new version found - updating..."
    local tmp zip src
    tmp="$(mktemp -d)"; zip="$tmp/update.zip"
    if ! _download "https://codeload.github.com/$REPO/zip/refs/heads/$BRANCH" "$zip"; then
        echo "  update download failed - launching current version."; rm -rf "$tmp"; return 0
    fi
    if ! unzip -q -o "$zip" -d "$tmp"; then
        echo "  update extract failed - launching current version."; rm -rf "$tmp"; return 0
    fi
    src="$(find "$tmp" -maxdepth 1 -type d -name 'Skadoosh-*' | head -n1)"
    if [ -z "$src" ]; then echo "  unexpected update layout - skipping."; rm -rf "$tmp"; return 0; fi
    # Copy new files over the install (leaves .godot-bin, version file, logs alone).
    if ! cp -R "$src"/. "$DIR"/; then
        echo "  update copy failed - launching current version."; rm -rf "$tmp"; return 0
    fi
    rm -rf "$tmp"
    printf '%s\n' "$remote" > "$VERFILE"
    rm -rf "$DIR/.godot"          # force a clean re-import of changed assets
    echo "  update complete - restarting launcher..."
    export SKADOOSH_NOUPDATE=1
    exec "$0" "$@"
}

auto_update "$@"

# 1) Find an existing Godot before downloading:
#    $GODOT override -> PATH -> a 'godot' shell alias -> common install spots.
find_existing_godot() {
    # Explicit override.
    if [ -n "$GODOT" ] && [ -x "$GODOT" ]; then printf '%s' "$GODOT"; return; fi
    # On PATH.
    for c in godot godot4; do
        if command -v "$c" >/dev/null 2>&1; then command -v "$c"; return; fi
    done
    # Scripts can't run aliases, but we can read them: alias godot="/path/to/Godot"
    for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_aliases" "$HOME/.profile"; do
        [ -f "$rc" ] || continue
        local line cand
        line="$(grep -E '^[[:space:]]*alias[[:space:]]+godot=' "$rc" 2>/dev/null | head -n1)" || true
        [ -n "$line" ] || continue
        cand="${line#*=}"
        cand="$(printf '%s' "$cand" | tr -d "\"'" | awk '{print $1}')"
        cand="${cand/#\~/$HOME}"
        [ -x "$cand" ] && { printf '%s' "$cand"; return; }
    done
    # Common install locations.
    for g in "$HOME"/project/tools/Godot* /opt/godot* /usr/local/bin/godot* "$HOME"/.local/bin/godot* "$HOME"/Godot*; do
        case "$g" in *.zip) continue;; esac
        [ -f "$g" ] && [ -x "$g" ] && { printf '%s' "$g"; return; }
    done
    printf ''
}
GODOT="$(find_existing_godot)"

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

# 3) First run / after an update: build the asset import cache (no .godot yet).
if [ ! -d "$DIR/.godot/imported" ]; then
    echo "Importing assets (first run / after update), please wait..."
    "$GODOT" --path "$DIR" --headless --import || true
fi

echo "Launching Skadoosh with: $GODOT"
exec "$GODOT" --path "$DIR"
