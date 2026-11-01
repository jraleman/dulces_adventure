# Dolce's Adventure — Game Design Document

> Hand-off document for the implementation session. It fixes the concept, the
> rules, the architecture and the order of work. Numbers marked *(tune)* are
> starting points, not contracts. Read the repository's `AGENTS.md` first — the
> framework/game boundary there overrides anything here that seems to conflict.

| | |
| --- | --- |
| Game ID | `dolces_adventure` |
| Title | Dolce's Adventure |
| Folder | `godot-base/games/dolces_adventure/` (its own Git repository, consumed as a host submodule) |
| Control style | `GameManifest.CONTROL_STYLE_CUSTOM_KEYS` |
| Round rules | Game-owned (`uses_shell_round_rules = false`) |
| Menu order | `9` (after Cube Trials' `8`) |
| Feature tag | `dolces_adventure` |
| Look-and-feel reference | `games/cube_trials/` |
| Renderer | `gl_compatibility` — unchanged |

---

## 1. Concept

**Dolce** is a small, cheerful chihuahua mix who loves to run, jump and eat —
burgers above all. Every run she sets off from her front door and goes **as far
as she can**, hopping over pits, bouncing on pests and snapping up food on the
way. The run ends when she loses her last heart; the score is **distance**,
with burgers and stomps on top.

It is a side-scrolling platformer in the spirit of *Super Mario Bros.* — run,
variable-height jump, stomp from above, a power-up that buys you one extra
hit — with both endless seeded runs and five fixed, finishable stages, one per
biome (§5.5). Endless distance and stage clear time are separate headlines.
v1 is solo; hot-seat turns are a v2 candidate.

### Locked pillars

1. **Feels good in the first second.** Responsive run and jump with coyote
   time, jump buffering and variable jump height. Movement quality beats
   content volume.
2. **Always fair.** Every pit is jumpable at the speed the game expects; every
   enemy is readable before it is dangerous. Generated terrain is assembled
   from hand-authored chunks validated by tests, never from free noise.
3. **Cute, never cruel.** Enemies are pests that get *bonked* and scurry off
   or poof into a puff — no gore, no death animation for Dolce beyond a
   flustered tumble.
4. **Same studio look as Cube Trials.** A real 3D world and character in an
   isolated viewport, driven by a node-free 2D model, under the shared HUD and
   menus.
5. **Original everything.** Inspired by Mario; no Nintendo levels, sprites,
   sounds, music, names or enemy designs are used.

### Story (for the intro cards and `instructions_rules`)

Four short cards, the same shape as Cube Trials' boot intro:

1. Dolce smells something wonderful drifting over the fence.
2. The neighbourhood food festival has opened at the far end of town.
3. Between her and it: holes, puddles, pigeons and one very rude vacuum robot.
4. She is small. She is fast. She is *very* hungry. — **Go, Dolce!**

On an endless run the festival is never "reached": the farther she gets, the
closer the smell. Biomes (§5.3) are the sense of progress. A fixed stage ends
at its food truck.

---

## 2. How Cube Trials' look-and-feel maps across

Cube Trials is the reference. Copy its *structure*; do not import its files
(no game-to-game dependency — copy and adapt helpers like `mesh_builder.gd`
into this folder).

| Cube Trials | Dolce's Adventure |
| --- | --- |
| `trial_state.gd` — node-free 120 Hz chassis model | `run_state.gd` — node-free 120 Hz platformer body and run rules |
| `course.gd` — handcrafted routes, pickups, checkpoints | `chunk_library.gd` + `level_stream.gd` — authored chunks, seeded assembly, safe-ground points |
| `course_view.gd` — isolated `SubViewport`, orthographic Side camera | `world_view.gd` — same isolated `SubViewport`, orthographic side camera, optional "Chase" later |
| `world/cube_model.gd` — imported GLB car, damage stages, decorative poses | `world/dolce_model.gd` — procedural rig of rigid parts (like Chicken Pit's `chicken_rig.gd`), run/jump/land/eat poses, decorative ear and tail motion |
| `world/mesh_builder.gd` — vertex-colour batching | Same idea, copied into `world/mesh_builder.gd` |
| `world/daylight.gd` — sun/sky rig, optional day/night | Same rig; biome palettes; optional day/night toggle |
| `world/tire_particles.gd` — bounded dust | `world/paw_particles.gd` — footstep dust, landing puff, crumbs on eating |
| `drive_controls.gd` — keyboard, gamepad, multitouch | `run_controls.gd` — same three sources, fewer buttons |
| `trial_hud.gd` — compact in-view icon HUD | `run_hud.gd` — heart / distance / burger / score icons |
| `cube_audio.gd` — synthesized cues | `dolce_audio.gd` — synthesized yips, boings, munches |
| `cube_art.gd` — palette, `WORLD_SCALE`, `world_point()` | `dolce_art.gd` — same API shape |
| Spark plugs | Burgers |
| Sparks (store currency) | Treats |
| Garage reveal | Biome gate ("Welcome to the Park!") banner and food-truck set piece |

**Scale.** Keep Cube Trials' convention: simulation units in a y-down 2D plane,
`WORLD_SCALE = 0.025` (40 units = 1 m), `world_point(point, depth)` maps to 3D.
**One tile = 40 units = 1 m.** Dolce's body is about 0.6 m long, 0.45 m tall
including ears — deliberately chunky and readable at phone size.

---

## 3. Core loop

```
Title ─► Play ─► Mode select (endless start or fixed stage, outfit on the plinth)
     ─► Instructions ─► Run:
            run right ─► jump pits ─► stomp/avoid pests ─► eat burgers
            ─► take a hit? (Full → Normal, Normal → lose a heart, respawn on safe ground)
            ─► last heart lost / stage goal ─► results (distance / clear time, stats, best)
            ─► Treats payout
     ─► Store (cosmetics) / Gallery / Share card
```

An endless run is typically **1–4 minutes** and has no countdown. A stage's
elapsed model time is its headline, not a time limit.

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
| `INVULNERABLE_SECONDS` | 1.5 | After any hit; Dolce blinks via opacity, not flashing colour |

The body is an axis-aligned box (hit box slightly smaller than the visual)
colliding against a tile grid plus one-way platforms. No slopes in v1 —
slopes are a v2 item once the core feels right (they complicate the model and
the chunk validator).

**No double jump.** One jump per ground contact, exactly as Cube Trials
refuses double jumps.

### 4.2 Hearts and the "Full" power-up

Mario's big/small rule, reworded around food:

- Dolce starts each run with **3 hearts** (`STARTING_HEARTS`).
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
| **Squirrel** | Runs at Dolce when she's within 6 tiles, hops small gaps | Scurries off-screen | Park |
| **Robo-Vac** | Slow, wide; stomp flips it over, then it can be shoved and slides, bonking other pests (the "shell" equivalent) | Flips; kick to slide | Street |
| **Seagull** | Flies a sine path, swoops when above Dolce | Feathers | Pier |
| **Hot-Sauce Bottle** | Hops in place; spits a slow drop in an arc | Pops a lid | Night Market |

Enemies are model-side data (`enemy_state` dictionaries inside `run_state.gd`
or a small `pests.gd`), never nodes, so the rules are testable headless.

Details settled in Milestone 5 (all constants at the top of `pests.gd`):

- **Squirrel:** waits facing her until she is within 6 tiles and 2 rows,
  then charges at 160 u/s. It leaps gaps of up to 2 tiles and waits at the
  edge of anything wider.
- **Robo-Vac:** a stomp flips it onto its back (it rights itself after 6 s).
  Touching a flipped vac kicks it away from her at 420 u/s. A sliding vac
  bounces off walls, falls into pits and bonks every pest it touches, for
  200 points each. For 0.3 s after a kick it can't hurt her; after that a
  sliding vac is a hit unless she stomps it, which flips it again.
- **Seagull:** flies, never falls. It patrols ±3 tiles around its perch on a
  gentle bob, swoops when she passes underneath, then climbs back. A swoop
  never comes within 8 units of the ground under it, nor more than 4 tiles
  below its perch. Chunks place it in mid-air.
- **Hot-Sauce Bottle:** hops in place every 1.6 s, and every 2.5 s spits a
  drop toward her when she is within 8 tiles. Drops arc under gravity and
  splat on the ground. A drop can't be stomped: touching one is a hit
  (harmless during i-frames).

### 4.4 Collectibles

| Item | Effect | Points |
| --- | --- | --- |
| Burger | Count +1 (the "coin") | 100 |
| Fries / taco / hot dog | Flavour variants per biome, same as a burger | 100 |
| Big Burger | Becomes Full (§4.2); 1,000 points if already Full | 500 |
| Golden Bone | +1 heart, max 3 | 1,000 |
| Lunchbox block | Bonk from below with a jump. Contents are authored: `?` holds a burger (eaten at once), `!` a Big Burger (pops out on top). It becomes an empty, still-solid box | — |

Every **100 burgers** in one run = +1 heart (capped at 3; points if capped).

### 4.5 Scoring

```
score = floor(distance_m) * 10 + item points + stomp points
stomp points: 200, chained stomps without touching ground 200 → 400 → 800 → 1600 (cap)
```

**Distance is the headline on endless runs** on the HUD, results, share card
and reach achievements; stages headline clear time (§5.5). Score is secondary.
Distance counts from the run's start everywhere, including achievements.
"Best distance" is persisted (in
`user://dolces_adventure.cfg`, declared as a `save_files` entry — progress,
not an option). Layout: one `ConfigFile` section per start point
(`[backyard]`, later `[park]`, … and the fixed stages), each holding
`distance`, `score` and `burgers`. Each field only ever goes up, and a save
merges into the stored file, so a build that doesn't know a section never
deletes it. Stage sections (`[stage_backyard]`, etc.) also hold `time_ms`:
only a clear sets it, and a best time only goes down.

Daily UTC runs (§5.6) use separate `[daily_YYYY-MM-DD]` sections with the same
distance, score and burger maxima. Ordinary start/stage sections never change
because a daily run ended; historical daily sections are preserved by the merge.

### 4.6 Auto-run assist

Tunable *Auto-run*, default **off**. A constants-only options file cannot pick
a per-device default, so the touch HUD instead shows a one-time hint offering
it when `DisplayServer.is_touchscreen_available()`. **Auto-run** enables the
saved assist; **Not now** or starting to play dismisses it without losing a
held finger. Showing the offer records
`game/dolces_adventure_auto_run_hint_seen` in `settings.cfg`, including across
a restart; this is not another tunable. No offer appears if Auto-run is
already enabled.

When on, Dolce always runs right at `RUN_SPEED`; left slows her to
`WALK_SPEED` instead of turning. This makes the game playable one-thumbed.

### 4.7 The camera never goes back

Like SMB, the camera only scrolls forward. Dolce can walk back up to the left
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
		".S.........p.S..",
		"####...#########",
		"####...#########",
	],
}
```

Legend (keep it in one const): `#` ground, `=` one-way platform, `?` lunchbox
block holding a burger, `!` lunchbox block holding a Big Burger, `B` burger,
`G` big burger, `+` golden bone, `p` pigeon, `n` gnome, `s` squirrel,
`v` robo-vac, `g` seagull, `h` hot sauce, `S` safe-ground marker,
`.` air. Lunchbox contents are authored, never rolled, so a chunk plays the
same way every time. A pest or `S` glyph stands on the bottom of its cell. Every chunk enters and leaves at **ground height row 4** (the
"seam") so any two chunks can join.

### 5.2 Streaming — `level_stream.gd`

- A run has a **seed** (random per run, 0–999,999; shown in the results
  stats so a great run can be replayed with `-- --dolce-seed=<n>`, and so
  tests are deterministic). Which chunk comes next depends only on the seed
  and the chunks already placed, never on how the run is played.
- The stream keeps ~3 screens of chunks ahead of the camera and frees chunks
  2 screens behind. The model keeps only the live tiles.
- **Difficulty ramps with distance**: the chunk picker draws uniformly from
  the chunks with `difficulty <= 1 + distance_m / 150` *(tune)*, never
  repeats a chunk twice in a row, and every 4th chunk is a flat "breather"
  (no pits, no pests). Breathers are only ever placed by that rule. Every
  run opens on the fixed `backyard_start` chunk.
- **Safe-ground points**: each chunk declares `S` markers; pit respawn uses
  the last one passed. Every chunk declares at least one; there is no
  automatic marker, and an `S` must stand on solid ground, never over a pit.
- **Validator** (`chunk_library.validate(chunk)`, called by tests on every
  chunk): six rows, 16–48 wide, legend glyphs only, open ground on the seam
  at both ends. Then a reachability search over every place she can stand:
  a move counts only if `run_state.gd`'s own `jump_height()` and
  `jump_reach()` clear it with a 1-tile margin across and up, over columns
  with nothing solid in the way. The exit must be reachable from the entry.
  Every `S` must stand on solid ground, be reachable, and not be a dead end.
  Pests must stand on something, and a gnome needs room to land on either
  side. In practice that allows pits of up to 5 tiles and ledges of up to 3.
  The same search (`route_problems()`) walks whole generated runs in the
  stream tests. This is pillar 2 as code.

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

After the Night Market (which runs to 3,000 m) the biomes loop, with the
difficulty still rising.

How it is built:

- **Biomes follow the world; difficulty follows the run.** The biome comes
  from how far the run is from the front door, so a Park start is 400 m out
  and Main Street comes 500 m later. The difficulty ramp counts from the
  run's own start, like every other distance (owner decision), so a later
  start eases in. That is why every biome has chunks at difficulties 1–4.
- **Gates.** Each biome opens with a fixed gate chunk: a flat breather with
  the biome's "Welcome to" sign behind it and safe ground at column 2. The
  stream places it where the world changes biome, and a run starting in that
  biome starts on it. Passing a gate raises a `biome` event: the HUD banner,
  the fanfare and its caption.
- **Look.** `world/biome_props.gd` holds each biome's palette (ground, soil,
  pit wall, platforms, sky), its props behind the playfield, its gate sign
  and its far backdrop. Pits show the biome's pond, manhole or sea. The sky
  blends to the next palette over 1.5 s (instantly with reduced motion), and
  the Night Market's palette dims the sun, so it is night whatever the clock.
  The orthographic camera has no perspective, so the backdrop is scaled to
  0.42 and scrolls at 35% of the playfield's speed to read as distant.
- **Pests by biome.** Each biome introduces its own pest (§4.3) and keeps
  some of the earlier ones.

### 5.4 Levels as start points (shared level selector)

Use the manifest's `levels` with achievement gates, exactly like Cube Trials'
unlocks — but here a "level" is **where a run starts**:

- **Endless - Backyard** — always open.
- **Endless - the Park** — unlocked by running 400 m
  (`dolces_adventure_reached_park`).
- **Endless - Main Street** — unlocked by running 900 m.
- **Endless - the Boardwalk Pier** / **Endless - the Night Market** — likewise.

Each start point's id is its biome's id (`backyard`, `park`, `street`,
`pier`, `market`), which is also its section in the best-runs file.

Starting later gives a smaller distance score: distance counts from the
start point **everywhere** (owner decision), so the score, the best distance
and the reach achievements all measure the run itself. Show it as "from the
Park". A later start never unlocks anything a Backyard run couldn't; it is
practice. Level icons (`assets/levels/<id>.png`, 384×240) are captured from
the real gate chunks by `tools/capture_art.gd`, as in Cube Trials.

### 5.5 Fixed stages

Owner decisions, recorded in `TODO.md`:

- **One stage per biome, about 300 m each** (280–340 m, tested): a fixed,
  ordered list of that biome's own authored chunks (`stages.gd`), climbing in
  difficulty, opening on the biome's gate and ending on the shared goal
  chunk. No seed, no random rolls, and Lunchbox contents are authored, so a
  stage plays the same every time.
- **The goal** is the `F` glyph: a food truck with a chequered flag, on solid
  ground, with ground running on past it. Passing it clears the stage. The
  clock (model time, so the game-speed assist never changes a time) stops,
  Dolce sits for 1.4 s, then the results open.
- **The headline is the clear time** ("NEW BEST: 1:04.3!"), with burgers
  shown as "X of Y" and score below. The best time per stage lives in the
  best-runs file as `time_ms` in the stage's section; it only goes down, and
  an unfinished attempt never sets one.
- **Losing the last heart ends the attempt**, as on an endless run: the
  results say how far from the goal she got. Play Again restarts the stage.
- **Unlocks:** Stage 1 is open. Clearing Stage N unlocks
  `dolces_adventure_cleared_<biome>` (permanent keys), which opens Stage N+1
  in the shared level selector.

### 5.6 Daily UTC runs (first v2 feature)

Owner-approved scope: **UTC midnight and unlimited attempts**.

- **Daily UTC - Backyard** is an always-open entry in the existing level
  selector (`daily`); it uses the existing Backyard still and starts at the
  normal front-door spawn. No separate menu or new achievement gate.
- When a round is created, capture the system Unix timestamp once. The UTC
  date and its seed stay with that run through pause, midnight and results.
  Play Again creates a fresh round: the same date repeats the same course,
  and a new UTC date gets its own course and bests.
- The seed is the positive modulo of whole UTC days since the Unix epoch,
  `floor(unix_seconds / 86400) mod 1000000`. This numeric rule is stable
  across machines and avoids platform/version-dependent string hashing.
  Daily runs ignore `--dolce-seed` with an explicit warning; normal endless
  replay overrides and fixed stage layouts retain their v1 behavior.
- The live `level_stream.gd` builds the ordinary seeded endless course from
  the Backyard. Physics, chunks, the fairness validator, difficulty ramp,
  food, pests, three hearts and the Full buffer are unchanged.
- Distance remains the headline. The HUD shows the captured UTC date;
  results/stats also show the course seed and daily best, and the existing
  share payload carries the date/seed. Save maxima under `daily_YYYY-MM-DD`
  in the existing best-runs file.
  Historical dates, ordinary endless bests and stage clear times are kept.
- Auto-run, Kind pits, Game speed and all achievements/Treats remain
  available; there is no retry cap, assist restriction, online leaderboard
  or clock-validation service. The date comes from the device's UTC clock.
- The accepted **v1.0.0 ZIP/EXE/PCK are frozen**. Do not re-export v2 source
  into that v1 package or regenerate unchanged v1 stills/tutorial media.

---

## 6. Architecture

```
game.gd                     # GameManifest — copy, theme, achievements, credits
dolces_adventure_options.gd # constants-only: tunables, bindings, store, gallery
gameplay.gd / .tscn         # extends GameShell; inherited scene of game_shell.tscn
tile_grid.gd                # live tiles the body collides with; the stream feeds it
run_records.gd              # best runs in user://dolces_adventure.cfg
intro.tscn                  # four story cards, inheriting the framework intro
run_state.gd                # node-free 120 Hz body, hits, hearts, scoring
pests.gd                    # node-free enemy behaviours
chunk_library.gd            # authored chunk grids, legend, validator
level_stream.gd             # seeded assembly, ramp, safe-ground, live tile window; stage mode
stages.gd                   # the five fixed stages: chunk lists, lengths, time format
daily_run.gd                # node-free UTC date, deterministic seed and daily record key
world_view.gd               # isolated SubViewport, orthographic camera, one baked mesh per chunk
run_controls.gd             # keyboard, gamepad, multitouch
run_hud.gd                  # hearts, distance, burgers, score, pause
dolce_audio.gd              # synthesized cues
dolce_art.gd                # palette, WORLD_SCALE, world_point(), materials
share_art.gd / .tscn        # Dolce's victory sit beside a Big Burger for the share card
store_preview.gd / .tscn    # Dolce wearing one item, drawn once
gallery_stage.gd / .tscn    # turntable for the Gallery
character_preview.gd / .tscn # Dolce in her equipped outfit on the setup plinth
world/dolce_model.gd        # procedural rig: poses, ears/tail, Full state, outfit sockets
world/outfit_models.gd      # collar, hat and bandana/cape meshes from the store items
world/studio.gd             # the lit SubViewport set every portrait above stands in
world/biome_props.gd        # per-biome palettes, props, gate signs and backdrops (batched)
world/pest_models.gd        # enemy meshes and their poses
world/food_models.gd        # burgers, Big Burger, Golden Bone, Lunchbox blocks
world/mesh_builder.gd       # copied from cube_trials, adapted
world/daylight.gd           # copied rig, biome palettes
world/paw_particles.gd      # bounded, shadow-free particle batches
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
game.id = Options.GAME_ID                       # "dolces_adventure"
game.title = "Dolce's Adventure"
game.tagline = "Small dog. Big appetite. Long way to lunch."
game.menu_order = 9
game.gameplay_scene_path = "res://games/dolces_adventure/gameplay.tscn"
game.intro_scene_path = "res://games/dolces_adventure/intro.tscn"
game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
game.uses_shell_round_rules = false
game.supports_multiplayer = false               # v1; see §11
game.supports_cpu_opponent = false
game.levels = Options.LEVELS                    # start biomes, achievement-gated
game.save_files = [{"path": "user://dolces_adventure.cfg", "title": "Best runs",
		"description": "Best distance, score and burgers from each start point, and stage times."}]
game.characters = Options.CHARACTERS            # Dolce alone, so the plinth shows her
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
- **Original** low-poly models, vertex-coloured, built from rounded
  primitives in GDScript through `mesh_builder.gd` (owner decision: no
  Blender on the build machine, and procedural parts keep poses testable
  headless, as Chicken Pit's birds are). Dolce is a rig of rigid parts, one
  pivot per head, ear, leg, tail and collar. A Blender GLB could replace any
  part later behind the same calls. Scenery is batched the same way.
- Warm daylight rig with Compatibility shadows; Dolce casts a blob or real
  shadow so her height over a pit is always readable.
- Depth layers: playfield at depth 0; props at ±1–3 m; a far parallax backdrop
  (hills, rooftops, skyline) — real geometry, not a flat image, but cheap.
- Bounded, shadow-free particle batches; nothing per-frame-allocated.

### 7.2 Dolce

Chihuahua mix — big upright ears, short muzzle, round eyes, compact body,
slightly longer legs than a pure chihuahua (the "mix"), curled tail. Coat:
**fawn/tan with a cream chest and muzzle**, approved by the owner for v1
(§13.1). Later reference photos can inform a recolour in `dolce_art.gd`
or ear/tail adjustments, but are not a release blocker. Collar socket
for store items; the default collar is red.

Poses (angles on the rig's pivots; `dolce_model.pose_for(state)` picks one):
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
const FAWN := Color("d6a26b")      # Dolce
```

`GameTheme`: accent `MUSTARD`, light `CREAM`, plaque `Color("5a3d2e")`,
background top/bottom a warm brown-to-plum gradient, `style_share_card = true`,
logo `assets/game-icon.png` (Dolce's head holding a burger, captured from the
real model by `tools/capture_art.gd`).

---

## 8. Controls

Keyboard bindings in `dolces_adventure_options.gd` are rebindable (prefix
every action and key with `dolces_adventure_`). Arrows and gamepad controls are
fixed extras, polled by `run_controls.gd`; they are not Settings bindings.
The owner approved these fixed gamepad controls for v1.

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Left | A / ← | D-pad / left stick | ◀ button |
| Right | D / → | D-pad / left stick | ▶ button |
| Jump | Space / ↑ | A | Big jump button (right thumb) |
| Run | Shift | X / right trigger | Tap ▶, then tap again and hold; or Auto-run |
| Pause | Escape (shell) | Start | Pause icon |

Touch: icon buttons, ≥ 44 physical px, below the ground line, multi-finger
like Cube Trials (hold right + tap jump at the same time). An action remains
held until its last finger or mouse hold releases. A canceled or dragged
contact is not a sprint tap; pause, focus loss and hiding the controls clear
held inputs and the old double-tap window.

Keyboard hints show only without touch controls. The shared pause button is
an icon with an accessible name. Short touch landscapes use two-line headline
cards; long scores fit their card without pushing Pause off screen. The tip
docks above the buttons in portrait or at the upper right on short, wide
screens. HUD, tip and captions leave the playfield clear; zero-step layout
redraws reframe immediately, even with motion enabled. A camera zoom floor
keeps short-screen silhouettes readable where the horizontal pit preview
permits.

### Tunables (Settings → Game)

| Key | Type | Default |
| --- | --- | --- |
| `game/dolces_adventure_auto_run` | toggle | false |
| `game/dolces_adventure_kind_pits` | toggle | false |
| `game/dolces_adventure_game_speed` | slider 70–100% | 100% |
| `game/dolces_adventure_day_night` | toggle | true |

Assists never block achievements (Cube Trials' rule).

---

## 9. Shell features

### 9.1 Achievements (keys are stable forever)

| Key | Title | Badge | Condition |
| --- | --- | --- | --- |
| `dolces_adventure_reached_park` | Off the Leash | PARK | Run 400 m in one run |
| `dolces_adventure_reached_street` | Street Smart | STREET | Run 900 m in one run |
| `dolces_adventure_reached_pier` | Sea Legs | PIER | Run 1,500 m in one run |
| `dolces_adventure_reached_market` | Follow Your Nose | MARKET | Run 2,200 m in one run |
| `dolces_adventure_hundred` | Hungry Hungry | 100 | 100 burgers in one run |
| `dolces_adventure_combo` | Boing Boing Boing | COMBO | 4-stomp chain |
| `dolces_adventure_clean` | Not a Scratch | CLEAN | 500 m without a hit or a fall |
| `dolces_adventure_cleared_backyard` | Out the Gate | STAGE 1 | Clear Stage 1; opens Stage 2 |
| `dolces_adventure_cleared_park` | Walk in the Park | STAGE 2 | Clear Stage 2; opens Stage 3 |
| `dolces_adventure_cleared_street` | Street Food | STAGE 3 | Clear Stage 3; opens Stage 4 |
| `dolces_adventure_cleared_pier` | Pier Pressure | STAGE 4 | Clear Stage 4; opens Stage 5 |
| `dolces_adventure_cleared_market` | Last Stop, Lunch | STAGE 5 | Clear Stage 5 |

The first four also gate the start-biome levels (§5.4).

### 9.2 Store — currency "Treats"

A run pays `score / 100` Treats (`points_per_score = 0.01`) plus 3 for
playing (`round_bonus`). There is no CPU to beat, so `win_bonus` is 0. Clearing
a stage pays `TREATS_PER_CLEAR` (20) on top, through gameplay's
`_round_points_earned` override. Slots: **collar**, **hat**, **bandana**; the
hat and bandana slots can be empty. Items are purely cosmetic and visible in
the run, the setup plinth, the share card and the gallery; a colour comes from
the item's own entry, so the store's swatch and the worn mesh always agree.

| Slot | Item | Price | Gate |
| --- | --- | --- | --- |
| Collar | Red collar | default | — |
| Collar | Sky collar | 60 | — |
| Collar | Spiked collar | 150 | — |
| Collar | Gold collar | 300 | Clear Stage 5 |
| Hat | Party hat | 80 | — |
| Hat | Flower crown | 120 | — |
| Hat | Tiny chef's hat | 160 | — |
| Hat | Sombrero | 220 | Run 900 m |
| Bandana | Ketchup bandana | 70 | — |
| Bandana | Mustard bandana | 70 | — |
| Bandana | Superhero cape | 250 | Run 1,500 m |

`store_preview.tscn` draws Dolce wearing one item, once per card (no live
render loop on a shelf of cards). The setup screen's plinth shows Dolce, the
manifest's single `characters` entry, in her equipped outfit.

### 9.3 Gallery

`GALLERY_EXHIBITS`: Dolce (idle, Full; both in her equipped outfit), pigeon,
gnome, Lunchbox block, Big Burger and Golden Bone are open from the start.
Each later pest waits for the reach achievement of the biome it first appears
in (squirrel: Park, robo-vac: Main Street, seagull: Pier, hot sauce: Night
Market), and the food truck with its chequered flag waits for clearing
Stage 1. `gallery_stage.tscn` implements `configure`, `set_view` and
`set_auto_spin`, framing each exhibit from its measured bounds.

### 9.4 Share card

`share_art.tscn`: Dolce in the outfit she ran in (the payload's `outfit`),
in the victory sit on a little lawn beside a Big Burger, under the Backyard
sky. The shell's card around it carries the headline: distance on an endless
run, clear time on a stage, with burgers, score and the QR to `stats_url`.

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
- Touch targets retain physical size as the window and UI scale change.
  Audio captions fill the available touch width with readable text and never
  cover Dolce or a button. Icon controls have tooltips or accessible names.

### 9.6 Audio — `dolce_audio.gd`

Synthesized like `cube_audio.gd`: jump yip (pitch rises with jump strength),
land pat, stomp boing (pitch climbs with the chain), munch, Full "gulp",
hit whine, heart chime, biome fanfare, run-over tumble. No continuous loop
required in v1; an optional light music bed later goes through `AudioManager`.

---

## 10. Tests — `tests/`

Headless unless noted; each a standalone `SceneTree` script that exits 0.

| Suite | Covers |
| --- | --- |
| `dolces_adventure_manifest_test.gd` | Manifest, prefixed keys, shell rules, declared assets and content |
| `dolce_physics_test.gd` | Accel/decel, max speeds, jump apex for tap vs hold, coyote, buffer, no double jump, fall cap, game-speed scaling |
| `dolce_rules_test.gd` | Stomp vs side hit, Full ↔ Normal, hearts, i-frames, pit respawn at last `S`, 100-burger heart, stomp chain points, run end |
| `dolce_chunks_test.gd` | `validate()` on **every** chunk: seams, max gap/height vs `run_state` constants, spawns, safe ground |
| `dolce_stream_test.gd` | Same seed ⇒ same world; difficulty ramp; breather spacing; no immediate repeats; window frees old chunks |
| `dolce_pests_test.gd` | Each enemy's behaviour, robo-vac kick chain, seagull swoop bounds |
| `dolce_records_test.gd` | Merged records, monotonic bests, damaged files left untouched |
| `dolce_stages_test.gd` | Fixed courses, fair seams, goals, seed independence, clocks and clear records |
| `dolce_model_test.gd` | Procedural rig, poses, reactions, Full and reduced motion |
| `dolce_audio_test.gd` | Synthesized cues and captions for meaningful events |
| `dolce_controls_test.gd` | Routed touch events, genuine sprint taps, handoffs, cancellation, dragging, pause and emulated mouse twins |
| `dolce_scene_test.gd` | Full input-only stages and Backyard-to-Market run; fresh unlocks, saved results/payouts, HUD/outfit, pause, Auto-run tip and lookahead isolation |
| `dolce_view_test.gd` *(window)* | Rendered pixels and whole-body bounds; portrait/landscape phones, tablet, ultrawide, long scores, large UI, Full, captions, tip docking and airborne poses |

The framework suites (`game_shell_test`, `game_options_test`,
`accessibility_test`, `visual_effects_test`, `single_game_test`,
`store_test`, `gallery_test`, `saves_test`, …) pick the game up automatically
— run them all with `--game=all` before calling a milestone done.

Run suites serially. Isolate `user://` with a scratch `APPDATA` on Windows or
`XDG_DATA_HOME` on Linux. The scene and view suites also snapshot disk saves
and Settings' cache, stopping its pending save timer before restoring.
Load shell gameplay scenes at runtime after autoloads exist, not by directly
preloading `gameplay.gd` in a `SceneTree` test.

The scene suite's test-only player searches collision trajectories on deep
copies of the live `run_state`, grid and pests, then presses normal actions.
It clears all five complete stage courses and drives seed 42 through every
biome gate to 2,250 m without damage. Untimed hops then lose the last heart
through real collisions, exercising the endless result and unlocks.
The runtime-loaded `tests/playthrough_gameplay.gd` only fixes the normal
constructor's seed. No run is positioned near a goal, no enemies are removed
and no hearts are injected. Both helpers stay under the excluded `tests/`
folder; they are not a shipped assist. Predictions must leave live food,
Lunchboxes, pests, body state and events untouched.

---

## 11. Integration checklist (outside this folder)

These are the only edits outside `games/dolces_adventure/`:

- [x] `project.godot`: `config/name.dolces_adventure`,
      `config/custom_user_dir_name.dolces_adventure="DeskCanSaw Games/Dolce's Adventure"`
      (stable forever once shipped), `config/icon.dolces_adventure`,
      `dcs/build/single_game_id.dolces_adventure`, and
      `[share] stats_urls/dolces_adventure`. The feature-specific version
      is `1.0.0`; other games' versions and the default catalog pin stay unchanged.
- [x] `export_presets.cfg`: **Windows - Dolce's Adventure (standalone)**,
      x86_64 release with the feature tag, external PCK, and other games,
      tests and development tools excluded. Existing non-collection presets
      exclude Dolce; the collection includes it.
- [ ] Commit registration and the updated gitlink (one game commit, then one
      in `dcs_games`). Deferred for local release finalization; no Git writes
      were requested.
- [x] Root `AGENTS.md`: games table, submodule list, options-file list, test
      table, feature-tag list, and the per-game blurb.
- [x] `godot-base/README.md`: launch, game, export and test documentation.
- [ ] `godot --headless --path . --import` after adding `class_name`s (prefer
      preload-by-path like Cube Trials to avoid needing them).

No framework code changes are expected. If one seems needed, add data to
`GameManifest` instead of a game-name branch.
The v1 export check exposed one generic integration fix: `StudioInfo.version()`
now resolves feature overrides, so a standalone's title footer matches its
release version without changing the collection's version. The host
`main_menu_test.gd` covers this; no game-name branch was added.

**v1.0.0 automated release gate:** all 13 game and 15 framework suites pass
on Godot 4.7.2. Windows standalone and collection exports, headless and
rendered checks against their exact PCKs, and native EXE boots pass.
Standalone has only Dolce and the approved save directory; the collection
keeps all ten games and its existing profile/version. The unsigned EXE/PCK
pair is packaged in `build/dolces_adventure/DolcesAdventure-v1.0.0-windows-x86_64.zip`.
All five stages now clear input-only with three hearts and no damage, and
a 2.25 km Backyard-to-Market input run checks fresh endless unlocks, records
and payouts. Human feel, physical-device/speaker checks, human full-course
playthroughs and publication remain separate from this gate. The production
game and assets have not changed in this QA pass, so the verified release
binaries and tutorial do not need regeneration.

**v1.0.0 local release acceptance (2026-11-01):** the owner reported
"It plays nicely and all is good" and selected local v1 finalization, not v2.
The unchanged standalone ZIP has companion `RELEASE-NOTES.txt` and
`SHA256SUMS.txt` under ignored `build/dolces_adventure/` output. Its entries
match the verified EXE/PCK; native title/version, a responsive Windows boot,
and the exact-PCK catalog, footer, save path, media and gameplay checks pass.
The release remains unsigned, untagged and unpublished. Commits are left
alone. General owner acceptance does not supply a detailed manual full-course,
physical-device or speaker test matrix; do not mark those tests as performed.

---

## 12. Milestones

1. **Feel prototype.** `run_state.gd` + flat test chunk + capsule placeholder
   in the 3D view + keyboard input. Physics test green. *Goal: jumping is fun
   with a grey box.*
2. **Rules.** Pits, hearts, Full, burgers, two enemies (pigeon, gnome), HUD,
   results, achievements for distance. Rules + pests tests.
3. **Stream.** Chunk library (≥ 15 Backyard chunks), validator, seeded
   stream, difficulty ramp. Chunks + stream tests.
4. **Dolce.** Procedural rigid-part rig, poses, Full morph, particles, audio.
5. **Biomes 2–5.** Props, palettes, remaining enemies, level gates, captured
   level stills.
6. **Fixed stages.** Five authored courses, food-truck goals, clear times,
   sequential stage unlocks and per-stage best records.
7. **Shell features.** Store, gallery, share art, character preview, intro,
   tutorial video, credits, theme, icon.
8. **Polish & integration.** Touch layouts, accessibility sweep, framework
   suites with `--game=all`, export preset, `AGENTS.md`/README updates.

**v2 phase 1:** Daily UTC runs (§5.6), with unlimited retries and UTC-midnight
resets. This is source development, not a replacement for the frozen v1
release package.

**Remaining v2 candidates:** slopes, hot-seat turns (P1/P2/P3, best distance
wins — reuse Cube Trials' hand-off flow), chase camera, music bed.

---

## 13. Owner decisions and open questions

1. **Dolce's real look** — answered: the current procedural fawn/cream look
   is approved for v1. Reference photos are optional later art work.
2. **Endless vs authored levels** — answered: both, including one fixed
   stage per biome (§5.5).
3. **Hearts count** — answered: three, maximum three, plus the Full buffer.
4. **Hot seat in v1?** — answered: v2; v1 is solo.
5. **Store currency** — answered: Treats; payout is score / 100 plus three
   per run and twenty per clear, with no win bonus or cap (§9.2).
6. **Standalone title / user dir name** — answered: **Dolce's Adventure**
   and the permanent `"DeskCanSaw Games/Dolce's Adventure"` directory,
   including the apostrophe.
7. **Gamepad rebinding** — answered: keep the current fixed gamepad controls
   for v1; keyboard action bindings remain rebindable.
8. **v1 gameplay / release acceptance** — answered: the owner accepted
   gameplay on 2026-11-01 and approved local v1 release finalization.
   Leave commits, tags, signing and publication untouched. Record the
   general playtest acceptance, not unreported device-specific measurements.
9. **First v2 feature** — answered: Daily UTC runs (§5.6), resetting at
   **UTC midnight** with **unlimited attempts** from the Backyard and
   separate daily bests. Existing assists/achievements remain available;
   each round keeps its captured date/seed through midnight.

Other locked answers, also tracked in `TODO.md`: the heroine is Dolce, with
new source/save names only and no legacy aliases; her rig uses procedural
rigid parts; the setup plinth shows the single character in her outfit;
distance is relative everywhere; stages are roughly 300 m with sequential
clear gates, a clear-time headline and last-heart failure (§5.5).
