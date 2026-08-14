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

> **Auto-update:** downloaded source releases check GitHub for a newer version before
> starting. Git clones never auto-update, so local development work cannot be overwritten.

> **macOS note:** if it's blocked as "unidentified developer", allow it once in
> *System Settings → Privacy & Security*, then run `./run.sh` again.

> **Already have Godot 4.3?** The script auto-detects it from your `PATH`, a
> `godot` shell alias (read from `~/.zshrc` / `~/.bashrc`), or common install
> folders — so it usually won't re-download. To force a specific binary:
> `GODOT=/path/to/Godot ./run.sh` (Windows: `set GODOT=C:\path\to\Godot.exe` then `run.bat`).

## Controls

| Action        | Player 1   | Player 2   |
|---------------|------------|------------|
| Move          | `A` / `D`  | `←` / `→`  |
| Jump (double) | `W`        | `↑`        |
| Fast-fall     | `S`        | `↓`        |
| Dash          | `Shift`    | `Ctrl`     |
| Heavy attack  | `F`        | `/`        |
| Light attack  | `G`        | `'`        |

Win by knocking the other fighter off the stage 3 times. Press **Enter** to rematch.

## Character selection

The selection screen builds itself from `Roster.heroes`. Fighter cards include
their names and automatically wrap into a responsive multi-row grid. Large rosters
can be scrolled vertically, and the grid automatically scrolls to keep the most
recently moved player cursor visible.

- Player 1 uses `A` / `D` to choose, `W` to lock in, and `S` to unlock.
- Player 2 uses `←` / `→` to choose, `↑` to lock in, and `↓` to unlock.
- Both players may select the same fighter.

Adding another resource path to `HERO_PATHS` in `autoload/roster.gd` automatically
adds its card to this grid; the menu does not require per-character layout changes.

## The fighters

Each hero is data-driven (`data/heroes/<name>/hero.tres`) with its own movement,
defense, animation, and two skills. Attacks have independently tunable startup,
active, recovery, post-skill lock, damage, knockback, cooldown, and hitbox/projectile
values. Light attacks lock control for 0.3 seconds after finishing; heavy attacks
lock control for 0.5 seconds.

- **Kunoichi** — a fast, tanky bruiser with a four-pose walk cycle and distinct
  light/heavy sword animations.
- **Linea** — a fragile glass cannon. Zones from range: a big **Fireball** (heavy) and
  a quick close-range **Fire Jab** (light), each with its own casting animation.
- **Primordial Demon** — a heavy dark-matter fighter with a close claw slash and a
  delayed spike eruption about four game meters in front of her.
- **Waterbender** — a flowing ranged fighter with a three-meter water spit and a
  four-meter wave that grows in size and scales from 1× to 2× damage as it travels.

> Want to tweak balance or add a hero? Edit the numbers in
> `data/heroes/<name>/hero.tres` — no player-code changes are needed. Add a new
> hero's resource path to `autoload/roster.gd` to make it selectable.

### Adding character artwork

Create a folder such as `data/heroes/my_hero/` and put the character PNG files
there. A complete fighter can provide:

- `idle.png` and `icon.png`
- a walk sprite sheet
- jump and fall/dive poses or sprite sheets
- separate light- and heavy-attack sprite sheets
- optional projectile or ground-spike effect art for special attacks

Sprite sheets should have a transparent background, equal-sized cells, consistent
character scale/baseline, and no artwork crossing between cells. Copy an existing
`hero.tres`, replace its texture paths and animation grid values, then add that
resource to `HERO_PATHS` in `autoload/roster.gd`.

## Tests

With Godot 4.3 available, run the dependency-free headless suite with:

```sh
godot --headless --path . tests/test_runner.tscn
```

The release workflow runs the same suite before exporting the Windows build.

## Requirements

- A 64-bit Windows, Linux, or macOS machine with an internet connection
  (for the first-run download and auto-update).
