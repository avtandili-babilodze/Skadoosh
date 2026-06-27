# Skadoosh

A local 2-player platform fighter (Brawlhalla-style) made in Godot 4.3.
Knock your opponent off the stage — the more damage they've taken, the farther they fly.

## Play it (one click)

Download/clone this repo, then:

- **Windows:** double-click **`run.bat`**
- **Linux / macOS:** run **`./run.sh`** (from a terminal: `./run.sh`)

The first launch downloads Godot 4.3 automatically into a local `.godot-bin/` folder
(~70 MB, one time). After that it starts instantly. Nothing else to install.

> **macOS note:** if it's blocked as "unidentified developer", allow it once in
> *System Settings → Privacy & Security*, then run `./run.sh` again.

> **Already have Godot 4.3?** The script auto-detects it from your `PATH`, a
> `godot` shell alias (read from `~/.zshrc` / `~/.bashrc`), or common install
> folders — so it usually won't re-download. To force a specific binary:
> `GODOT=/path/to/Godot ./run.sh` (Windows: `set GODOT=C:\path\to\Godot.exe` then `run.bat`).

## Controls

| Action     | Player 1 (Kunoichi) | Player 2 (Mage) |
|------------|---------------------|-----------------|
| Move       | `A` / `D`           | `←` / `→`       |
| Jump (x2)  | `W`                 | `↑`             |
| Fast-fall  | `S`                 | `↓`             |
| Dash       | `Shift`             | `Ctrl`          |
| Attack     | `F`                 | `/`             |

Win by knocking the other fighter off the stage 3 times. Press **Enter** to rematch.

## Requirements

- A 64-bit Windows, Linux, or macOS machine with an internet connection (for the first-run download).
