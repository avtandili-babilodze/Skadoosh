# Skadoosh

A platform fighter (Brawlhalla-style) made in Godot 4.3, for one player against
the CPU or two players on one machine. Knock your opponent off the stage — the
more damage they've taken (the **%** on their plate), the farther they fly, until
they ring out.

## Download & play (Windows)

The easiest way — no install, no setup:

1. Go to the **[Releases page](https://github.com/avtandili-babilodze/Skadoosh/releases/latest)**.
2. Under **Assets**, click **`Skadoosh.exe`** to download it (~85 MB).
3. **Double-click `Skadoosh.exe`** to play.

The game opens fullscreen (`F11` switches to a window and back). The first time
it runs it also puts a **Skadoosh** shortcut on your desktop, so keep
`Skadoosh.exe` somewhere it can stay. Delete the shortcut and it will not come
back; move the game and the shortcut follows it the next time you run the game.

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

> **Desktop shortcut (Windows):** a source run only makes one when asked:
> `godot --path . -- --desktop-shortcut`.

> **Auto-update:** downloaded source releases check GitHub for a newer version before
> starting. Git clones never auto-update, so local development work cannot be overwritten.

> **macOS note:** if it's blocked as "unidentified developer", allow it once in
> *System Settings → Privacy & Security*, then run `./run.sh` again.

> **Already have Godot 4.3?** The script auto-detects it from your `PATH`, a
> `godot` shell alias (read from `~/.zshrc` / `~/.bashrc`), or common install
> folders — so it usually won't re-download. To force a specific binary:
> `GODOT=/path/to/Godot ./run.sh` (Windows: `set GODOT=C:\path\to\Godot.exe` then `run.bat`).

## Controls

| Action                            | Player 1   | Player 2   | Gamepad            |
|-----------------------------------|------------|------------|--------------------|
| Move                              | `A` / `D`  | `←` / `→`  | stick / d-pad      |
| Jump (again in the air to double) | `W`        | `↑`        | `A`                |
| Fast-fall, drop through platforms | `S`        | `↓`        | down               |
| Dash (with a direction) / dodge   | `Shift`    | `Ctrl`     | bumpers            |
| Heavy attack (rises in the air)   | `F`        | `/`        | `B` / `Y`          |
| Light attack                      | `G`        | `'`        | `X`                |

`Esc` (or Start) pauses a match, `F11` toggles fullscreen and `7` toggles the
music. The first gamepad plays Player 1 and the second plays Player 2. Presses
are buffered for a moment, so a jump tapped just before landing or an attack
tapped at the end of another still comes out.

Win by knocking the other fighter off the stage until they run out of stocks
(three by default; change it under **Settings**).

### How a fight flows

- **A hit gives you the advantage.** Once an attack lands you can cut the rest
  of it short with a jump, a dash or your other attack, while your rival is
  still stunned. A light that lands leads into the heavy; a heavy that lands
  lets you jump or dash after the fighter you just launched.
- **A miss leaves you open.** Only an attack that hits nobody pays its end lag
  (about 0.12 s for a light, 0.24 s for a heavy), and it cannot be cut short.
- **Attacks are aimed.** Each attack button gives a different attack for where
  you aim it: hold a side for the side attack, hold down for the low one, stand
  still for the one aimed upward, and press it in the air for the air attack.
  Kunoichi has all eight (Quick Slash, Rising Cut, Low Sweep, Air Slash;
  Piercing Lunge, Crescent Launcher, Ground Splitter, Moonrise). A fighter
  without an attack of her own for an aim uses her side attack there.
- **The dive.** In the air, hold down and the heavy button: the fighter plunges
  for as long as the button is held, and strikes where it reaches the floor or
  another fighter. Let go and the dive ends with no strike. Every fighter can
  dive; Kunoichi's is her own (Falling Fang).
- **Attacks move.** A grounded swing steps forward as it comes out and carries a
  run-up with it, but never slides off a ledge. In the air an attack keeps its
  momentum and can still be steered.
- **The heavy key in the air is a rising heavy:** the heavy attack carried
  upward by an extra jump, once per airtime. It is both a finisher and the last
  part of a recovery. A skill that needs the floor (Waterbender's wave) only
  gives the jump.
- A swing also hits a rival standing right on top of you.

## Playing a match

The title screen offers **1 Player** (you against the CPU, at the level chosen
under **Settings**) and **2 Players**. Leave the title alone for half a minute
and it plays a demo match by itself; any key returns to the title.

1. **Choose your fighter.** Move with your movement keys, lock in with your
   heavy-attack key (`F` / `/`) and unlock with your light-attack key
   (`G` / `'`). Each side shows the fighter under that cursor, animated, with
   stats and both skills. In a one-player match you pick your own fighter and
   then the CPU's. Both players may pick the same fighter.
2. **Choose your stage.** Either player moves; the screen previews the stage's
   real layout with your fighters standing on it. The last card picks at random.
3. **Fight.** The camera follows both fighters. Leaving the blast zone on any
   side costs a stock; a marker at the screen edge tracks anyone out of view.
4. **Results** show knock-outs, falls and damage dealt, with a rematch one
   button away.

### Stages

| Stage              | Layout                                                        |
|--------------------|---------------------------------------------------------------|
| **Neon Foundry**   | One platform over the middle of the deck.                     |
| **Sakura Shrine**  | Twin platforms, one over each half.                           |
| **Ember Caldera**  | Three platforms stacked into a tower.                         |
| **Frostfall Peak** | A small floor and one platform that glides side to side.      |

Platforms are pass-through: jump up through them, land on top, and tap down to
drop back through. The main floor is solid, with ledges on both sides; a
recovery that reaches the ledge wall just below the top is pulled up onto the
stage, so a jump that falls a little short still makes it.

Stages are data (`data/maps/<id>.tres`, a `MapData` resource: art, platform
layout, spawn points, blast zone, ambient particles). They are written by
`tools/make_maps.py`; add an entry there and its path to `MAP_PATHS` in
`autoload/roster.gd`, and the map select picks it up.

## Character selection

The selection screen builds itself from `Roster.heroes`. Fighter cards include
their names and automatically wrap into a responsive multi-row grid. Large rosters
can be scrolled vertically, and the grid automatically scrolls to keep the most
recently moved player cursor visible.

Adding another resource path to `HERO_PATHS` in `autoload/roster.gd` automatically
adds its card to this grid; the menu does not require per-character layout changes.

## The fighters

Each hero is data-driven (`data/heroes/<name>/hero.tres`) with its own movement,
defense, animation, and two skills. Attacks have independently tunable startup,
active, recovery, end lag, damage, knockback, cooldown, and hitbox/projectile
values, plus a release frame that pins the art's key pose (a sword landing, a
fireball leaving the hand) to the exact moment the hit happens. End lag is paid
only by an attack that misses, and a skill's cooldown never outlasts it by more
than the input buffer, so a skill is ready whenever the fighter is (the test
suite checks both).

- **Kunoichi** — a masked ninja with a silver ponytail and a crimson scarf: a
  **Quick Slash** (light) and an overhead **Heavy Strike** (heavy) with her
  ninjato. The fastest fighter, and tanky for her speed.
- **Linea** — an elf fire sorceress and a fragile glass cannon. Zones from range: a
  big **Fireball** (heavy) and a quick close-range **Fire Jab** (light).
- **Primordial Demon** — a tall dark-matter fighter with a spiked tail: a close
  **Dark Matter Slash** (light) with her claws and a delayed **Primordial
  Eruption** (heavy) about four game meters in front of her.
- **Waterbender** — a flowing ranged fighter with a three-meter **Water Spit**
  (light) and a four-meter **Rising Tide** (heavy), a wave that grows in size and
  scales from 1× to 2× damage as it travels.
- **Lilith** — a winged demoness with a whip: a quick **Whip Lash** (light) and a
  wide overhead **Infernal Whip** (heavy). Slightly floaty in the air.
- **Knight** — the king's champion, and he knows it: a towering man in battered
  plate with a greatsword resting on his shoulder and a fist on his hip. Slow,
  very hard to launch, and he fights as if you were beneath him: a pommel
  punch (**Rebuke**), a salute that becomes a thrust (**Salute**), a boot
  (**Heel**), a jousting charge (**Tilt**), an uppercut (**Crownbreaker**), a
  planted sword that throws everyone near him (**Kneel**), a hammer blow with
  the crossguard that knocks you downward (**Murder-Stroke**), and a dive that
  is simply him stepping on you (**Beneath Me**).
- **Kitsune** — a nine-tailed fox who throws a **Foxfire Orb** (light) and drives
  both palms forward to burst foxfire at close range, the **Foxfire Eruption**
  (heavy).
- **Antiope** — an Amazon warrior in bronze: a quick **Shield Bash** (light) and a
  sweeping **Amazon Cleave** (heavy). Tanky, with a shield-bearer's defense.
- **Musashi** — a wandering ronin under a wide straw hat: a fast **Iai Slash**
  (light) and a two-handed rising **Crescent Moon Cut** (heavy) that knocks foes
  up and away. A balanced swordsman with mid defense.
- **Akane** — a haughty fire witch: a dismissive **Ember Flick** (light) that sprays
  flame at close range, and a finger-snap **Pyre Pillar** (heavy) that erupts a
  column of fire about four game meters ahead, launching whoever stands in it.
  Light on her feet and floaty in the air, but fragile.

> Want to tweak balance? Edit the numbers in `data/heroes/<name>/hero.tres` — no
> player-code changes are needed. (Fighters built with the rig kit keep the same
> numbers in their spec, so change them there too or the next art rebuild will
> write the old values back.)

### How the fighters are drawn and animated

Every fighter is drawn **once**, in a clean inked cartoon style, standing in a
neutral pose. The drawing is cut into parts (head, torso, upper arm, forearm,
hair segments, cloth, weapon, …) on a 2D skeleton, and the game moves those
parts **live**: each animation stores the bones' rotations and the game blends
between them at whatever rate the screen draws, so motion is as smooth as the
display. Hair, scarves, tails, capes and sleeves are simulated as they move, so
they react to what the fighter is really doing: a run streams them back, a
launch whips them, a landing settles them. On the ground they rest on the
floor instead of sinking into it. Switching animations blends from the pose
that was showing instead of snapping.

- Running, jumping, landing, being hit and falling come from **motion capture**
  of real people.
- Attacks are **hand-keyed** the way fighting-game animators pose them: a clear
  wind-up, a very fast strike, a held contact pose, follow-through and an eased
  return to guard. Heavy attacks wind up longer and hold longer than light ones.
  The game fits the animation to the skill's timing: the wind-up fills the
  startup, the held contact fills the active window, and the follow-through
  fills recovery and the end lag.
- Blades leave a swing trail drawn from the real blade; Lilith's whip is a
  live rope that pays out, cracks straight at the target and recoils
  (`entities/fx/whip.gd`); fireballs, foxfire, water, flame bursts and
  eruptions are drawn by a cel-shaded effect shader
  (`entities/fx/toon_fx.gdshader`) in the same inked style.

A rigged fighter's art lives in `data/heroes/<name>/rig/`: `rig.json` (bones,
parts, simulated chains and the nine animations) and `parts/*.png`. Its
`hero.tres` points at `rig.json` through the `rig` field; `tools/wire_rig.py`
adds that link. The tools that cut drawings and author animations are a small
Python kit kept beside the art sources, not in this repository.

All ten fighters are rigged. The game still supports the older sprite-sheet
drawing (the `*_sheet.png` files and the sheet fields in `hero.tres`) for a
fighter without a `rig`.

## Tests

With Godot 4.3 available, run the dependency-free headless suite with:

```sh
godot --headless --path . tests/test_runner.tscn
```

Checks are grouped into suites in `tests/suites/` (hero data, animation, combat,
scenes, CPU), with shared pixel helpers in `tests/support/`. Besides gameplay,
they check every fighter's sheets (equal grids, transparent corners, one shared
ground line, legs that keep pace with movement at a natural speed), every stage
(solid floor under both spawn points, platforms where the layout says, ring-outs
and respawns, pass-through and moving platforms) and the CPU opponent (it lands
hits with every fighter, climbs back from below a ledge and does not walk off
one). The release workflow runs the same suite before exporting the Windows build.

## How it is put together

- `autoload/` — services available everywhere: `GameInput` (key and gamepad
  bindings), `Roster` (fighters, stages, the current picks), `Settings`
  (saved preferences and the audio buses), `Sfx`, `Music`, `Fx` (hit-stop,
  shake, sparks, dust, knock-out blasts) and `Transition` (scene wipes).
- `scenes/` — `title`, `character_select`, `map_select` and `arena`, with the
  arena's camera, HUD, pause menu and results screen under `scenes/arena/`.
- `entities/` — the fighter (rules in `player.gd`, looks in
  `fighter_visuals.gd`, the CPU in `fighter_brain.gd`), projectiles, ground
  spikes and effect visuals.
- `ui/` — the shared menu kit: palette, fonts, buttons, the animated fighter
  preview, the stage miniature.
- `tools/` — generators that are not part of the game: `build_sfx.py` builds
  the sound effects (with synthesized layers from `make_sfx.py`), `make_maps.py`
  writes the stage resources, `wire_rig.py` links a fighter to its live rig.

Fonts are [Bangers](https://github.com/googlefonts/bangers) and
[Chakra Petch](https://github.com/m4rc1e/Chakra-Petch), both under the SIL Open
Font License (texts in `assets/fonts/`).

Sound effects are built by `tools/build_sfx.py` from recorded CC0 (public
domain) packs on OpenGameArt: 100 CC0 SFX, Kenney's RPG and Interface sounds,
the Swishes pack, 20 sword sound effects, Magic spell SFX and a synthesized fire
effect, layered with synthesized low-end. Each sound has several variants that
the game picks between at random.

## Requirements

- A 64-bit Windows, Linux, or macOS machine with an internet connection
  (for the first-run download and auto-update).
