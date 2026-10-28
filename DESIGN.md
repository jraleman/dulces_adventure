# Dulce's Adventure — Game Design Document

> Hand-off document for the implementation session. It fixes the concept, the
> rules, the architecture and the order of work. Numbers marked *(tune)* are
> starting points, not contracts. Read the repository's `AGENTS.md` first — the
> framework/game boundary there overrides anything here that seems to conflict.

| | |
| --- | --- |
| Game ID | `dulces_adventure` |
| Title | Dulce's Adventure |
| Folder | `godot-base/games/dulces_adventure/` (its own Git repository, intended to become the eighth submodule) |
| Control style | `GameManifest.CONTROL_STYLE_CUSTOM_KEYS` |
| Round rules | Game-owned (`uses_shell_round_rules = false`) |
| Menu order | `9` (after Cube Trials' `8`) |
| Feature tag | `dulces_adventure` |
| Look-and-feel reference | `games/cube_trials/` |
| Renderer | `gl_compatibility` — unchanged |

---

## 1. Concept

**Dulce** is a small, cheerful chihuahua mix who loves to run, jump and eat —
burgers above all. Every run she sets off from her front door and goes **as far
as she can**, hopping over pits, bouncing on pests and snapping up food on the
way. The run ends when she loses her last heart; the score is **distance**,
with burgers and stomps on top.

It is a side-scrolling platformer in the spirit of *Super Mario Bros.* — run,
variable-height jump, stomp from above, a power-up that buys you one extra
hit — shaped as a "how far can you get" run rather than a fixed level with a
flagpole.

### Locked pillars

1. **Feels good in the first second.** Responsive run and jump with coyote
   time, jump buffering and variable jump height. Movement quality beats
   content volume.
2. **Always fair.** Every pit is jumpable at the speed the game expects; every
   enemy is readable before it is dangerous. Generated terrain is assembled
   from hand-authored chunks validated by tests, never from free noise.
3. **Cute, never cruel.** Enemies are pests that get *bonked* and scurry off
   or poof into a puff — no gore, no death animation for Dulce beyond a
   flustered tumble.
4. **Same studio look as Cube Trials.** A real 3D world and character in an
   isolated viewport, driven by a node-free 2D model, under the shared HUD and
   menus.
5. **Original everything.** Inspired by Mario; no Nintendo levels, sprites,
   sounds, music, names or enemy designs are used.

### Story (for the intro cards and `instructions_rules`)

Four short cards, the same shape as Cube Trials' boot intro:

1. Dulce smells something wonderful drifting over the fence.
2. The neighbourhood food festival has opened at the far end of town.
3. Between her and it: holes, puddles, pigeons and one very rude vacuum robot.
4. She is small. She is fast. She is *very* hungry. — **Go, Dulce!**

The festival is never "reached": the farther she gets, the closer the smell.
Biomes (§5.3) are the sense of progress.

---

## 2. How Cube Trials' look-and-feel maps across

Cube Trials is the reference. Copy its *structure*; do not import its files
(no game-to-game dependency — copy and adapt helpers like `mesh_builder.gd`
into this folder).

| Cube Trials | Dulce's Adventure |
| --- | --- |
| `trial_state.gd` — node-free 120 Hz chassis model | `run_state.gd` — node-free 120 Hz platformer body and run rules |
| `course.gd` — handcrafted routes, pickups, checkpoints | `chunk_library.gd` + `level_stream.gd` — authored chunks, seeded assembly, safe-ground points |
| `course_view.gd` — isolated `SubViewport`, orthographic Side camera | `world_view.gd` — same isolated `SubViewport`, orthographic side camera, optional "Chase" later |
| `world/cube_model.gd` — imported GLB car, damage stages, decorative poses | `world/dulce_model.gd` — imported GLB dog, run/jump/land/eat poses, decorative ear and tail motion |
| `world/mesh_builder.gd` — vertex-colour batching | Same idea, copied into `world/mesh_builder.gd` |
| `world/daylight.gd` — sun/sky rig, optional day/night | Same rig; biome palettes; optional day/night toggle |
| `world/tire_particles.gd` — bounded dust | `world/paw_particles.gd` — footstep dust, landing puff, crumbs on eating |
| `drive_controls.gd` — keyboard, gamepad, multitouch | `run_controls.gd` — same three sources, fewer buttons |
| `trial_hud.gd` — compact in-view icon HUD | `run_hud.gd` — heart / distance / burger / score icons |
| `cube_audio.gd` — synthesized cues | `dulce_audio.gd` — synthesized yips, boings, munches |
| `cube_art.gd` — palette, `WORLD_SCALE`, `world_point()` | `dulce_art.gd` — same API shape |
| Spark plugs | Burgers |
| Sparks (store currency) | Treats |
| Garage reveal | Biome gate ("Welcome to the Park!") banner and food-truck set piece |

**Scale.** Keep Cube Trials' convention: simulation units in a y-down 2D plane,
`WORLD_SCALE = 0.025` (40 units = 1 m), `world_point(point, depth)` maps to 3D.
**One tile = 40 units = 1 m.** Dulce's body is about 0.6 m long, 0.45 m tall
including ears — deliberately chunky and readable at phone size.

---

## 3. Core loop

```
Title ─► Play ─► Mode select (start biome, outfit preview on the plinth)
     ─► Instructions ─► Run:
            run right ─► jump pits ─► stomp/avoid pests ─► eat burgers
            ─► take a hit? (Full → Normal, Normal → lose a heart, respawn on safe ground)
            ─► last heart lost ─► results (distance, burgers, stomps, best) ─► Treats payout
     ─► Store (cosmetics) / Gallery / Share card
```

A run is typically **1–4 minutes**. There is no timer; the clock is shown only
as a stat.

---

## 4. Rules

### 4.1 Movement — `run_state.gd`

Fixed step `STEP := 1.0 / 120.0`, accumulated like Cube Trials. All constants
live at the top of the file so tests and the tuning tunables can quote them.

| Constant | Start value *(tune)* | Notes |
| --- | --- | --- |
| `WALK_SPEED` | 220 u/s | Holding right without run |
| `RUN_SPEED` | 360 u/s | Holding Run (or auto-run, §4.6) |
| `GROUND_ACCEL` / `GROUND_DECEL` | 1400 / 1800 u/s² | Snappy, slightly floaty turn-around |
| `AIR_ACCEL` | 900 u/s² | Some air steering, Mario-like |
| `GRAVITY` | 2600 u/s² | |
| `FALL_GRAVITY_MULT` | 1.6 | Heavier on the way down |
| `JUMP_SPEED` | 900 u/s | ~3.9 tiles apex with full hold |
| `JUMP_CUT_MULT` | 0.45 | Releasing early cuts upward velocity — short hops |
| `RUN_JUMP_BONUS` | +8% per 100 u/s over walk | Running jumps go higher *and* farther |
| `MAX_FALL_SPEED` | 1500 u/s | |
| `COYOTE_SECONDS` | 0.09 | Jump just after leaving a ledge |
| `JUMP_BUFFER_SECONDS` | 0.12 | Jump pressed just before landing |
| `STOMP_BOUNCE_SPEED` | 620 u/s (980 if Jump held) | Hold to bounce high off a pest |
| `INVULNERABLE_SECONDS` | 1.5 | After any hit; Dulce blinks via opacity, not flashing colour |

The body is an axis-aligned box (hit box slightly smaller than the visual)
colliding against a tile grid plus one-way platforms. No slopes in v1 —
slopes are a v2 item once the core feels right (they complicate the model and
the chunk validator).

**No double jump.** One jump per ground contact, exactly as Cube Trials
refuses double jumps.

### 4.2 Hearts and the "Full" power-up

Mario's big/small rule, reworded around food:

- Dulce starts each run with **3 hearts** (`STARTING_HEARTS`).
- A **Big Burger** (rare, from a `?`-style *Lunchbox* block) makes her **Full**:
  slightly rounder model, a little bounce in her trot.
- Hit while Full → she becomes Normal, keeps the heart, gets i-frames.
- Hit while Normal → lose a heart, i-frames.
- Falling into a pit → lose a heart regardless of Full, respawn on the last
  **safe ground point** (§5.2) behind the pit, Full state lost.
- Last heart lost → the run ends after a short tumble.
- A **Golden Bone** (very rare) restores one heart, up to 3.

Optional assist tunable "Kind pits" (default off): a pit only removes the Full
state rather than a heart if she was Full.

### 4.3 Enemies (all original, all bonkable)

Contact from above with downward velocity = stomp (enemy defeated, bounce).
Any other contact = hit. Each enemy must be readable at phone size from its
silhouette, not its colour.

| Enemy | Behaviour | Stomp result | First biome |
| --- | --- | --- | --- |
| **Grumpy Pigeon** | Waddles back and forth on a platform, turns at edges | Poof of feathers | Backyard |
| **Garden Gnome** | Stands still, blocks a path; can't be stomped (pointy hat) — jump over it | — (hit if touched) | Backyard |
| **Squirrel** | Runs at Dulce when she's within 6 tiles, hops small gaps | Scurries off-screen | Park |
| **Robo-Vac** | Slow, wide; stomp flips it over, then it can be shoved and slides, bonking other pests (the "shell" equivalent) | Flips; kick to slide | Street |
| **Seagull** | Flies a sine path, swoops when above Dulce | Feathers | Pier |
| **Hot-Sauce Bottle** | Hops in place; spits a slow drop in an arc | Pops a lid | Night Market |

Enemies are model-side data (`enemy_state` dictionaries inside `run_state.gd`
or a small `pests.gd`), never nodes, so the rules are testable headless.

### 4.4 Collectibles

| Item | Effect | Points |
| --- | --- | --- |
| Burger | Count +1 (the "coin") | 100 |
| Fries / taco / hot dog | Flavour variants per biome, same as a burger | 100 |
| Big Burger | Becomes Full (§4.2); 1,000 points if already Full | 500 |
| Golden Bone | +1 heart, max 3 | 1,000 |
| Lunchbox block | Bonk from below with a jump → pops a burger or (rarely) a Big Burger | — |

Every **100 burgers** in one run = +1 heart (capped at 3; points if capped).

### 4.5 Scoring

```
score = floor(distance_m) * 10 + item points + stomp points
stomp points: 200, chained stomps without touching ground 200 → 400 → 800 → 1600 (cap)
```

**Distance is the headline** on the HUD, results, share card and achievements;
score is the secondary line. "Best distance" is persisted (in
`user://dulces_adventure.cfg`, declared as a `save_files` entry — progress,
not an option).

### 4.6 Auto-run assist

Tunable *Auto-run*, default **off**. A constants-only options file cannot pick
a per-device default, so the touch HUD instead shows a one-time hint offering
it when `DisplayServer.is_touchscreen_available()`. When on, Dulce always runs right at
`RUN_SPEED`; left slows her to `WALK_SPEED` instead of turning. This is what
makes the game playable one-thumbed on a phone.

### 4.7 The camera never goes back

Like SMB, the camera only scrolls forward. Dulce can walk back up to the left
edge of the view but not beyond. This bounds the stream (§5.2) and stops
enemy/collectible farming.

---

## 5. World

### 5.1 Chunks — `chunk_library.gd`

The world is a chain of **hand-authored chunks**, each 16–48 tiles wide,
written as const string grids so they are diffable and testable:

```gdscript
const PIT_HOP := {
	"id": "pit_hop", "biome": Biome.BACKYARD, "difficulty": 1,
	"rows": [
		"................",
		"........B.......",
		"......=====.....",
		"...........p....",
		"####...#########",
		"####...#########",
	],
}
```

Legend (keep it in one const): `#` ground, `=` one-way platform, `?` lunchbox
block, `B` burger, `G` big burger, `p` pigeon, `n` gnome, `s` squirrel,
`v` robo-vac, `g` seagull, `h` hot sauce, `S` safe-ground marker,
`.` air. Every chunk enters and leaves at **ground height row 4** (the
"seam") so any two chunks can join.

### 5.2 Streaming — `level_stream.gd`

- A run has a **seed** (random per run; shown on the results panel so a
  great run can be replayed via a debug flag, and so tests are deterministic).
- The stream keeps ~3 screens of chunks ahead of the camera and frees chunks
  2 screens behind. The model keeps only the live tiles.
- **Difficulty ramps with distance**: the chunk picker weights by
  `difficulty <= 1 + distance_m / 150` *(tune)*, never repeats a chunk
  twice in a row, and inserts a flat "breather" chunk at least every 4.
- **Safe-ground points**: each chunk declares `S` markers; pit respawn uses
  the last one passed. A chunk with no marker gets one at its entry seam.
- **Validator** (`chunk_library.validate(chunk)`, called by tests on every
  chunk): seam heights match, every gap ≤ the max running-jump width with a
  1-tile margin, every required ledge ≤ the max jump height with a margin,
  no enemy spawns inside solid tiles, at least one `S`. This is pillar 2 as
  code.

### 5.3 Biomes

Each biome is a palette + prop set + enemy mix + food flavour. Biome changes
are distance-based with a short banner and a gate set piece.

| # | Biome | Starts at | Palette / props | Food |
| --- | --- | --- | --- | --- |
| 1 | **Backyard** | 0 m | Green lawn, picket fence, flower pots, dog house | Burgers |
| 2 | **Park** | 400 m | Trees (adapt Cube Trials' pine *approach*, new mesh), benches, pond pits | Hot dogs |
| 3 | **Main Street** | 900 m | Kerbs, awnings, parked toy-like cars, open manholes | Tacos |
| 4 | **Boardwalk Pier** | 1,500 m | Planks with gaps, water, beach umbrellas, sunset light | Fries |
| 5 | **Night Market** | 2,200 m | Lanterns, food trucks, string lights, night palette | Burgers (gold wrapper) |

After the Night Market the biomes loop with the difficulty still rising.

### 5.4 Levels as start points (shared level selector)

Use the manifest's `levels` with achievement gates, exactly like Cube Trials'
unlocks — but here a "level" is **where a run starts**:

- **Backyard** — always open.
- **Park** — unlocked by reaching 400 m (`dulces_adventure_reached_park`).
- **Main Street** — unlocked by reaching 900 m.
- **Pier** / **Night Market** — likewise.

Starting later gives a smaller distance score (distance counts from the
biome's start offset, so leaderboard-style "best" is still meaningful; show
it as "from the Park"). Level icons are captured from real chunks by a
`tools/capture_art.gd`, as in Cube Trials.

---

## 6. Architecture

```
game.gd                     # GameManifest — copy, theme, achievements, credits
dulces_adventure_options.gd # constants-only: tunables, bindings, store, gallery
gameplay.gd / .tscn         # extends GameShell; inherited scene of game_shell.tscn
intro.tscn                  # four story cards (shared intro shape)
run_state.gd                # node-free 120 Hz body, hits, hearts, scoring
pests.gd                    # node-free enemy behaviours
chunk_library.gd            # authored chunk grids, legend, validator
level_stream.gd             # seeded assembly, ramp, safe-ground, live tile window
world_view.gd               # isolated SubViewport, orthographic camera, culling
run_controls.gd             # keyboard, gamepad, multitouch
run_hud.gd                  # hearts, distance, burgers, score, pause
dulce_audio.gd              # synthesized cues
dulce_art.gd                # palette, WORLD_SCALE, world_point(), materials
share_art.gd / .tscn        # portrait of Dulce for the share card
store_preview.gd / .tscn    # Dulce wearing one item
gallery_stage.gd / .tscn    # turntable for the Gallery
character_preview.gd / .tscn # Dulce in her equipped outfit on the setup plinth
world/dulce_model.gd        # GLB adapter: poses, ears/tail, Full state, outfits
world/biome_props.gd        # per-biome scenery factories (batched)
world/pest_models.gd        # enemy meshes and their poses
world/mesh_builder.gd       # copied from cube_trials, adapted
world/daylight.gd           # copied rig, biome palettes
world/paw_particles.gd      # bounded, shadow-free particle batches
assets/models/              # dulce.glb, enemies, props (Blender sources in tools/blender/)
assets/icons/               # HUD/touch SVGs: heart, burger, distance, run, jump, pause
assets/levels/              # captured biome stills for the level selector
assets/video/               # tutorial.ogv + poster
tests/                      # see §10
tools/                      # capture_art.gd, tutorial_driver.gd, blender/ (export-excluded)
README.md · DESIGN.md · AGENTS.md
```

### 6.1 Model / view split

`run_state.gd`, `pests.gd`, `chunk_library.gd` and `level_stream.gd` are
`RefCounted`, touch **no autoload and no node**, and are what the headless
tests exercise. `gameplay.gd` steps the model at 120 Hz, feeds input in, and
hands state to `world_view.gd` for drawing. The view may add decorative
motion (ear flop, tail wag, squash on landing) but must never feed back into
the model — the Cube Trials rule.

### 6.2 `GameShell` hooks used

`game_id`, `_prepare_session`, `_build_playfield`, `_load_round_settings`
(`super()`), `_reset_round_state`, `_activate_round`, `_update_round`,
`_handle_gameplay_input`, `_finish_round`, `_round_totals`, `_player_stats`,
`_describe_round_outcome`, `_round_highlight_summary`,
`_award_round_achievements`, `_round_points_earned`, `_configure_mode_ui`
(`super()`), `_on_game_setting_changed`, `_set_reduced_motion_enabled`
(**`super(value)`**), `_set_intense_effects_enabled` (**`super(value)`**).
Copy the signatures exactly from `AGENTS.md`.

Because the game owns its rules (`uses_shell_round_rules = false`), the shell's
countdown/lives pool is not used; the run ends when `run_state.hearts == 0`
and gameplay calls the shell's normal end-of-round path, as Cube Trials does.

### 6.3 Manifest sketch

```gdscript
game.id = Options.GAME_ID                       # "dulces_adventure"
game.title = "Dulce's Adventure"
game.tagline = "Small dog. Big appetite. Long way to lunch."
game.menu_order = 9
game.gameplay_scene_path = "res://games/dulces_adventure/gameplay.tscn"
game.intro_scene_path = "res://games/dulces_adventure/intro.tscn"
game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
game.uses_shell_round_rules = false
game.supports_multiplayer = false               # v1; see §11
game.supports_cpu_opponent = false
game.levels = Options.LEVELS                    # start biomes, achievement-gated
game.save_files = [{"path": "user://dulces_adventure.cfg", "title": "Best runs",
		"description": "Best distance and score from each start point."}]
game.character_preview_scene_path = ".../character_preview.tscn"
game.tunables / control_bindings / store_* / gallery_* = Options.*
game.tutorial_video_path / tutorial_poster_path
game.share_art_scene_path = ".../share_art.tscn"
game.stats_url = "https://deskcansaw.com"       # ≤ 42 bytes
game.theme = theme                              # §7.3
```

---

## 7. Art direction

### 7.1 Same pipeline as Cube Trials

- Real 3D in an isolated `SubViewport` (Compatibility renderer), orthographic
  side camera with a slight downward tilt so ground tops read.
- **Original** low-poly models, vertex-coloured, authored in Blender and
  exported as GLB (keep the `.blend` and generator scripts in `tools/blender/`,
  as Cube Trials does). Scenery batched through `mesh_builder.gd`.
- Warm daylight rig with Compatibility shadows; Dulce casts a blob or real
  shadow so her height over a pit is always readable.
- Depth layers: playfield at depth 0; props at ±1–3 m; a far parallax backdrop
  (hills, rooftops, skyline) — real geometry, not a flat image, but cheap.
- Bounded, shadow-free particle batches; nothing per-frame-allocated.

### 7.2 Dulce

Chihuahua mix — big upright ears, short muzzle, round eyes, compact body,
slightly longer legs than a pure chihuahua (the "mix"), curled tail. Coat:
**fawn/tan with a cream chest and muzzle** *(confirm against reference photos
— see §12)*. Collar slot for store items.

Poses (all model-side blend shapes or bone poses in one GLB):
idle (tail wag), trot, sprint (ears back), jump-up, apex, fall, land
(squash), stomp-bounce, hit (flustered), tumble (run over), eat (chomp,
crumbs), Full (rounder belly morph), victory sit for the results and share card.

Reduced motion removes ear flop, tail wag and squash/stretch, but keeps the
gameplay-essential poses (jump vs fall vs run must still be distinguishable).

### 7.3 Palette and theme

```gdscript
const INK := Color("2e2a33")
const CREAM := Color("fff1d6")
const MUSTARD := Color("f2b33d")   # accent — burger cheese
const KETCHUP := Color("d9533b")
const LETTUCE := Color("6fae4f")
const FAWN := Color("d6a26b")      # Dulce
```

`GameTheme`: accent `MUSTARD`, light `CREAM`, plaque `Color("5a3d2e")`,
background top/bottom a warm brown-to-plum gradient, `style_share_card = true`,
logo `assets/game-icon.png` (Dulce's head holding a burger, captured from the
real model by `tools/capture_art.gd`).

---

## 8. Controls

Rebindable actions in `dulces_adventure_options.gd` (prefix every action and
key with `dulces_adventure_`):

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Left | A / ← | D-pad / left stick | ◀ button |
| Right | D / → | D-pad / left stick | ▶ button |
| Jump | Space / W / ↑ | A | Big jump button (right thumb) |
| Run | Shift | X / right trigger | Hold ▶ twice-tap, or Auto-run |
| Pause | Escape (shell) | Start | Pause icon |

Touch: icon buttons, ≥ 44 physical px, below/at the edges of the playfield,
multi-finger like Cube Trials (hold right + tap jump at the same time). Wider
screens show key hints; phones show icons only; tooltips and screen-reader
descriptions keep the names.

### Tunables (Settings → Game)

| Key | Type | Default |
| --- | --- | --- |
| `game/dulces_adventure_auto_run` | toggle | false |
| `game/dulces_adventure_kind_pits` | toggle | false |
| `game/dulces_adventure_game_speed` | slider 70–100% | 100% |
| `game/dulces_adventure_day_night` | toggle | true |

Assists never block achievements (Cube Trials' rule).

---

## 9. Shell features

### 9.1 Achievements (keys are stable forever)

| Key | Title | Badge | Condition |
| --- | --- | --- | --- |
| `dulces_adventure_reached_park` | Off the Leash | PARK | Reach 400 m |
| `dulces_adventure_reached_street` | Street Smart | STREET | Reach 900 m |
| `dulces_adventure_reached_pier` | Sea Legs | PIER | Reach 1,500 m |
| `dulces_adventure_reached_market` | Follow Your Nose | MARKET | Reach 2,200 m |
| `dulces_adventure_hundred` | Hungry Hungry | 100 | 100 burgers in one run |
| `dulces_adventure_combo` | Boing Boing Boing | COMBO | 4-stomp chain |
| `dulces_adventure_clean` | Not a Scratch | CLEAN | 500 m without a hit |

The first four also gate the start-biome levels (§5.4).

### 9.2 Store — currency "Treats"

`store_currency` pays roughly `score / 100` per run *(tune)*. Slots:
**collar**, **hat**, **bandana**. Items are purely cosmetic and visible in the
run, the setup plinth, the share card and the gallery. Starter ideas: red
collar (default), spiked collar, flower crown, tiny chef's hat, sombrero,
party hat, ketchup-red bandana, mustard bandana, superhero cape (bandana slot).

### 9.3 Gallery

`GALLERY_EXHIBITS`: Dulce (idle, Full), each pest, Lunchbox block, Big
Burger, Golden Bone, a food truck from the Night Market. Later biome props
gated by their reach achievement. Stage implements `configure`, `set_view`,
`set_auto_spin`.

### 9.4 Share card

Dulce in her equipped outfit in the victory sit, the distance as the headline,
biome reached, burgers and score; QR to `stats_url`.

### 9.5 Accessibility (non-negotiable)

- Reduced motion: no ear/tail/squash, no camera easing, no parallax drift
  beyond what scrolling requires; opacity-only fades.
- Intense effects off: no screen shake on hits, no white flashes; i-frame
  blink is an opacity pulse, gentle in either mode.
- Never colour-only: enemies differ by silhouette; Full state also changes
  the model's shape and a HUD icon.
- Audio captions for: hit, heart lost, heart gained, Full gained/lost,
  stomp chain, biome reached, run over.
- Game speed slider (§8) for players who need more reaction time.

### 9.6 Audio — `dulce_audio.gd`

Synthesized like `cube_audio.gd`: jump yip (pitch rises with jump strength),
land pat, stomp boing (pitch climbs with the chain), munch, Full "gulp",
hit whine, heart chime, biome fanfare, run-over tumble. No continuous loop
required in v1; an optional light music bed later goes through `AudioManager`.

---

## 10. Tests — `tests/`

Headless unless noted; each a standalone `SceneTree` script that exits 0.

| Suite | Covers |
| --- | --- |
| `dulce_physics_test.gd` | Accel/decel, max speeds, jump apex for tap vs hold, coyote, buffer, no double jump, fall cap, game-speed scaling |
| `dulce_rules_test.gd` | Stomp vs side hit, Full ↔ Normal, hearts, i-frames, pit respawn at last `S`, 100-burger heart, stomp chain points, run end |
| `dulce_chunks_test.gd` | `validate()` on **every** chunk: seams, max gap/height vs `run_state` constants, spawns, safe ground |
| `dulce_stream_test.gd` | Same seed ⇒ same world; difficulty ramp; breather spacing; no immediate repeats; window frees old chunks |
| `dulce_pests_test.gd` | Each enemy's behaviour, robo-vac kick chain, seagull swoop bounds |
| `dulce_scene_test.gd` | Gameplay scene loads under the shell, HUD binds, pause, results, payout |
| `dulce_view_test.gd` *(window)* | Real render: Dulce visible and unobstructed, layouts portrait → ultrawide, touch buttons don't cover the ground line |

The framework suites (`game_shell_test`, `game_options_test`,
`accessibility_test`, `visual_effects_test`, `single_game_test`,
`store_test`, `gallery_test`, `saves_test`, …) pick the game up automatically
— run them all with `--game=all` before calling a milestone done.

---

## 11. Integration checklist (outside this folder)

These are the only edits outside `games/dulces_adventure/`:

- [ ] `project.godot`: `config/name.dulces_adventure`,
      `config/custom_user_dir_name.dulces_adventure="DeskCanSaw Games/Dulce's Adventure"`
      (stable forever once shipped), `config/icon.dulces_adventure`,
      `dcs/build/single_game_id.dulces_adventure`, and
      `[share] stats_urls/dulces_adventure`.
- [ ] `export_presets.cfg`: a standalone preset with the feature tag; add
      `games/dulces_adventure/*` to the other presets' `exclude_filter`.
- [ ] `.gitmodules` + gitlink once the folder has a remote (two commits: one
      in the game repo, one in `dcs_games`).
- [ ] Root `AGENTS.md`: games table, submodule list, options-file list, test
      table, feature-tag list, and the per-game blurb.
- [ ] `godot-base/README.md` if it lists games.
- [ ] `godot --headless --path . --import` after adding `class_name`s (prefer
      preload-by-path like Cube Trials to avoid needing them).

No framework code changes are expected. If one seems needed, add data to
`GameManifest` instead of a game-name branch.

---

## 12. Milestones

1. **Feel prototype.** `run_state.gd` + flat test chunk + capsule placeholder
   in the 3D view + keyboard input. Physics test green. *Goal: jumping is fun
   with a grey box.*
2. **Rules.** Pits, hearts, Full, burgers, two enemies (pigeon, gnome), HUD,
   results, achievements for distance. Rules + pests tests.
3. **Stream.** Chunk library (≥ 15 Backyard chunks), validator, seeded
   stream, difficulty ramp. Chunks + stream tests.
4. **Dulce.** Blender model, GLB, poses, Full morph, particles, audio.
5. **Biomes 2–5.** Props, palettes, remaining enemies, level gates, captured
   level stills.
6. **Shell features.** Store, gallery, share art, character preview, intro,
   tutorial video, credits, theme, icon.
7. **Polish & integration.** Touch layouts, accessibility sweep, framework
   suites with `--game=all`, export preset, `AGENTS.md`/README updates.

**v2 candidates:** slopes, hot-seat turns (P1/P2/P3, best distance wins —
reuse Cube Trials' hand-off flow), a daily seed, chase camera, music bed.

---

## 13. Open questions for the owner

1. **Dulce's real look** — is she based on a real dog? Reference photos would
   pin coat colours, ear shape and markings (§7.2 assumes fawn with cream).
2. **Endless vs authored levels** — this doc picks endless (seeded chunks) to
   match "go as far as possible". Confirm, or should there also be a few
   fixed, finishable stages?
3. **Hearts count** — 3 with a Full buffer (Mario-like), or Cube Trials' 5?
4. **Hot seat in v1?** Defaulted to v2 to keep v1 small.
5. **Name of the store currency** — "Treats" is a placeholder.
6. **Standalone title / user dir name** — "Dulce's Adventure" with an
   apostrophe in `custom_user_dir_name`; confirm before first ship, since it
   can never change afterwards.
