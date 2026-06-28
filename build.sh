#!/usr/bin/env bash
# Build the Windows .exe for Skadoosh (run locally).
#   ./build.sh            -> exports build/windows/Skadoosh.exe
# The exe is self-contained (game data embedded); just ship that one file.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
VER="4.3-stable"
TVER="4.3.stable"
OUT="$DIR/build/windows/Skadoosh.exe"
PRESET="Windows Desktop"

# --- 1) Locate a Godot 4.3 binary (same search as run.sh) -------------------
find_godot() {
    if [ -n "$GODOT" ] && [ -x "$GODOT" ]; then printf '%s' "$GODOT"; return; fi
    for c in godot godot4; do
        command -v "$c" >/dev/null 2>&1 && { command -v "$c"; return; }
    done
    for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_aliases" "$HOME/.profile"; do
        [ -f "$rc" ] || continue
        local line cand
        line="$(grep -E '^[[:space:]]*alias[[:space:]]+godot=' "$rc" 2>/dev/null | head -n1)" || true
        [ -n "$line" ] || continue
        cand="${line#*=}"; cand="$(printf '%s' "$cand" | tr -d "\"'" | awk '{print $1}')"
        cand="${cand/#\~/$HOME}"
        [ -x "$cand" ] && { printf '%s' "$cand"; return; }
    done
    for g in "$HOME"/project/tools/Godot* /opt/godot* /usr/local/bin/godot* "$HOME"/.local/bin/godot* "$HOME"/Godot*; do
        case "$g" in *.zip) continue;; esac
        [ -f "$g" ] && [ -x "$g" ] && { printf '%s' "$g"; return; }
    done
    printf ''
}
GODOT="$(find_godot)"
if [ -z "$GODOT" ]; then
    echo "ERROR: Godot 4.3 not found. Set GODOT=/path/to/godot and re-run." >&2
    exit 1
fi
echo "Using Godot: $GODOT"

# --- 2) Make sure the Windows export templates are installed ----------------
TPL_DIR="$HOME/.local/share/godot/export_templates/$TVER"
if [ ! -f "$TPL_DIR/windows_release_x86_64.exe" ]; then
    echo "Windows export templates missing. Downloading (~1 GB, one-time)..."
    tmp="$(mktemp -d)"
    url="https://github.com/godotengine/godot/releases/download/$VER/Godot_v${VER}_export_templates.tpz"
    if command -v curl >/dev/null 2>&1; then curl -L -o "$tmp/t.tpz" "$url"; else wget -O "$tmp/t.tpz" "$url"; fi
    unzip -q "$tmp/t.tpz" -d "$tmp"
    mkdir -p "$TPL_DIR"
    cp "$tmp/templates/"* "$TPL_DIR/"
    rm -rf "$tmp"
    echo "Templates installed to $TPL_DIR"
fi

# --- 3) Export --------------------------------------------------------------
mkdir -p "$(dirname "$OUT")"
echo "Exporting \"$PRESET\"..."
"$GODOT" --headless --path "$DIR" --export-release "$PRESET" "$OUT"

if [ -f "$OUT" ]; then
    echo ""
    echo "Done! -> $OUT"
    echo "Size:  $(du -h "$OUT" | cut -f1)"
    echo ""
    echo "To publish it: create a GitHub Release and attach this file,"
    echo "or push a tag (git tag vX.Y && git push origin vX.Y) to let the"
    echo "GitHub Action build & publish it automatically."
else
    echo "ERROR: export did not produce $OUT" >&2
    exit 1
fi
