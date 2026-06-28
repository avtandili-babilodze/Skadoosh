# Skadoosh

A local 2-player platform fighter (Brawlhalla-style) made in Godot 4.3.
Knock your opponent off the stage — the more damage they've taken (the **%** in the
top corners), the farther they fly, until they ring out.

## Download & play (Windows)

The easiest way — no install, no setup:

1. Go to the **[Releases page](https://github.com/avtandili-babilodze/Skadoosh/releases/latest)**.
2. Under **Assets**, click **`Skadoosh.exe`** to download it (~85 MB).
3. **Double-click `Skadoosh.exe`** to play.

> If Windows shows a blue **"Windows protected your PC"** box, click
> **More info → Run anyway**. This happens because the game isn't code-signed;
> it's safe to run.

**Direct download:** [Skadoosh.exe](https://github.com/avtandili-babilodze/Skadoosh/releases/latest/download/Skadoosh.exe)

## Run from source (Linux / macOS, or to develop)

Download/clone this repo, then:

- **Windows:** double-click **`run.bat`**
- **Linux / macOS:** run **`./run.sh`** (from a terminal: `./run.sh`)

The first launch downloads Godot 4.3 automatically into a local `.godot-bin/` folder
(~70 MB, one time). After that it starts instantly. Nothing else to install.

> **Auto-update:** each launch checks GitHub for a newer version and updates itself
> before starting (it just plays the current version if you're offline).

> **macOS note:** if it's blocked as "unidentified developer", allow it once in
> *System Settings → Privacy & Security*, then run `./run.sh` again.

> **Already have Godot 4.3?** The script auto-detects it from your `PATH`, a
> `godot` shell alias (read from `~/.zshrc` / `~/.bashrc`), or common install
> folders — so it usually won't re-download. To force a specific binary:
> `GODOT=/path/to/Godot ./run.sh` (Windows: `set GODOT=C:\path\to\Godot.exe` then `run.bat`).

## Controls

| Action        | Player 1 (Kunoichi) | Player 2 (Linea) |
|---------------|---------------------|------------------|
| Move          | `A` / `D`           | `←` / `→`        |
| Jump (double) | `W`                 | `↑`              |
| Fast-fall     | `S`                 | `↓`              |
| Dash          | `Shift`             | `Ctrl`           |
| Heavy attack  | `F`                 | `/`              |
| Light attack  | `G`                 | `'`              |

Win by knocking the other fighter off the stage 3 times. Press **Enter** to rematch.

## The fighters

Each hero is data-driven (`data/heroes/<name>/hero.tres`) with its own speed,
defense, walk animation, and two skills — a quick **light** attack and a stronger
**heavy** attack, each with its own damage and knockback.

- **Kunoichi** — a fast, tanky bruiser. Hits hard up close with melee light/heavy strikes.
- **Linea** — a fragile glass cannon. Zones from range: a big **Fireball** (heavy) and
  a quick close-range **Fire Jab** (light). She also has an animated walk cycle.

> Want to tweak balance or add a hero? Edit the numbers in
> `data/heroes/<name>/hero.tres` — no code needed. New heroes are just a new folder.

## Requirements

- A 64-bit Windows, Linux, or macOS machine with an internet connection
  (for the first-run download and auto-update).
