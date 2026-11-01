# AGENTS.md - Dolce's Adventure

Guidance for AI coding agents working in this repository.

## What this repository is

A self-contained **Godot 4.7 game folder**, consumed at
`godot-base/games/dolces_adventure` by the DeskCanSaw base project. It is not
a standalone Godot project: the host owns `project.godot`, autoloads, menus,
settings, pause, results, sharing and achievements. Read the host's root
`AGENTS.md` first; its framework/game boundary overrides anything here.

Read `DESIGN.md` before changing mechanics, and `TODO.md` for what is built,
what is next and which owner decisions are still open. The game is a
side-scrolling endless run (plus one fixed stage per biome) for a small
chihuahua mix: run, variable-height jump, stomp pests, eat burgers, go as far
as you can. It copies Cube Trials' *structure*: a node-free model in a real 3D
world inside an isolated `SubViewport`, under the shared 2D `GameShell`.

## Layout

Only what exists so far. `DESIGN.md` §6 is the target layout.

| Path | Responsibility |
| --- | --- |
| `game.gd` | Manifest, copy, theme, credits and achievement declarations |
| `dolces_adventure_options.gd` | Constants-only tunables, bindings, levels, store and gallery |
| `gameplay.gd` / `.tscn` | Shared-shell integration; inherited scene of `game_shell.tscn` |
| `run_state.gd` | Node-free 120 Hz body and run rules: hearts, Full, food, stomps, score |
| `pests.gd` | Node-free pest behaviours: pigeon, gnome, squirrel, robo-vac, seagull, hot sauce |
| `tile_grid.gd` | Live tiles the body collides with, Lunchboxes included |
| `chunk_library.gd` | The legend, biomes, every biome's chunks and gate, `build()`, the validator |
| `level_stream.gd` | Seeded chunk assembly: the live window, the ramp, breathers; stage mode |
| `stages.gd` | The five fixed stages: chunk lists, lengths, food totals, `time_text()` |
| `run_records.gd` | Best runs in `user://dolces_adventure.cfg`; merges, never regresses |
| `run_controls.gd` | Keyboard, gamepad and touch buttons into model inputs; no autoloads |
| `run_hud.gd` | Hearts, burgers and the FULL badge over the sky |
| `world_view.gd` | Isolated `SubViewport`, forward-only orthographic camera, one mesh per chunk |
| `dolce_art.gd` | Palette, `WORLD_SCALE`, `world_point()`, materials |
| `world/dolce_model.gd` | Dolce's procedural rig: one pivot per part, `pose_for(state)`, reactions |
| `world/paw_particles.gd` | One 64-slot pool of dust, crumbs and feathers; off under reduced motion |
| `dolce_audio.gd` | Synthesized cues, and `cue_for(event)`: each event's sound and caption |
| `world/pest_models.gd`, `world/food_models.gd` | Pests, each biome's food flavour, Lunchboxes |
| `world/outfit_models.gd` | Store cosmetics as meshes; colours read from each item's entry |
| `world/studio.gd` | The lit `SubViewport` set every portrait uses, and bounds-based framing |
| `store_preview.gd` / `.tscn` | Dolce wearing one store item; draws once per card |
| `character_preview.gd` / `.tscn` | Dolce on the setup plinth in her equipped outfit |
| `gallery_stage.gd` / `.tscn` | The Gallery turntable: `configure`, `set_view`, `set_auto_spin` |
| `share_art.gd` / `.tscn` | Share-card portrait: victory sit, payload outfit, Big Burger |
| `intro.tscn` | The four story cards, inheriting the framework intro |
| `world/biome_props.gd` | Per-biome palettes, props, gate signs and the parallax backdrop |
| `tools/capture_art.gd` | Dev-only: renders `assets/levels/` stills and `assets/game-icon.png` (needs a window) |
| `tools/tutorial_driver.gd` | Dev-only: Stage 1 autopilot and captions for the walkthrough clip |
| `assets/video` | `tutorial.ogv` and its poster, recorded from the driver |
| `assets/icons` | Original white-stroke HUD and touch SVGs |
| `world/mesh_builder.gd`, `world/daylight.gd` | Adapted copies of Cube Trials' batching and sun rig |
| `tests` | Standalone Godot `SceneTree` regression scripts |

## Commands

From `godot-base/` (two directories above this folder):

```bash
godot --headless --path . --import
godot --path . -- --game=dolces_adventure
godot --headless --path . --script res://games/dolces_adventure/tests/dolces_adventure_manifest_test.gd -- --game=all
godot --headless --path . --script res://games/dolces_adventure/tests/dolce_physics_test.gd -- --game=all
godot --headless --path . --script res://games/dolces_adventure/tests/dolce_rules_test.gd -- --game=all
godot --headless --path . --script res://games/dolces_adventure/tests/dolce_pests_test.gd -- --game=all
godot --headless --path . --script res://games/dolces_adventure/tests/dolce_records_test.gd -- --game=all
godot --headless --path . --script res://games/dolces_adventure/tests/dolce_chunks_test.gd -- --game=all
godot --headless --path . --script res://games/dolces_adventure/tests/dolce_stream_test.gd -- --game=all
godot --headless --path . --script res://games/dolces_adventure/tests/dolce_model_test.gd -- --game=all
godot --headless --path . --script res://games/dolces_adventure/tests/dolce_audio_test.gd -- --game=all
godot --headless --path . --script res://games/dolces_adventure/tests/dolce_stages_test.gd -- --game=all
godot --headless --path . --script res://games/dolces_adventure/tests/dolce_scene_test.gd -- --game=all
godot --path . -- --game=dolces_adventure --dolce-seed=42   # replay one seed
godot --path . --script res://games/dolces_adventure/tools/capture_art.gd -- --only=levels
godot --path . --script res://games/dolces_adventure/tools/capture_art.gd -- --only=icon
```

Re-run `capture_art.gd` after changing a gate chunk, a biome's palette or its
props, so the level selector's stills match the game, and with `--only=icon`
after changing Dolce's head or the burger. Re-record the walkthrough clip
after changing Stage 1, the HUD or the tutorial captions.

`dolce_scene_test.gd` plays real runs, so it snapshots `store.cfg`,
`achievements.cfg`, `settings.cfg` and `dolces_adventure.cfg` and puts them
back. A new test that ends a run must do the same.

A new or edited chunk must pass `dolce_chunks_test.gd`. If the validator
rejects it, widen or lower the chunk, never the validator: the validator is
the "always fair" pillar.

A test or a scripted run that can finish a run writes the player's real
`dolces_adventure.cfg` and `achievements.cfg`. Point `run_records.gd` at a
scratch path, or on Linux run Godot with `XDG_DATA_HOME` set to a scratch
directory, which gives it a throwaway `user://`.

The physics suite prints the measured jump limits. If a `run_state.gd`
constant changes, those numbers change, and so does what the chunk validator
accepts.

Run tests one at a time: framework tests share `user://`. Run the host's 15
framework suites with `--game=all` before calling a milestone done. They sweep
every game in the catalog, so this one is covered as soon as `game.gd` exists.

## Framework boundary

- Extend `GameShell`; do not build parallel menus, pause, results or scorecards.
- No game-to-game dependency. Copy and adapt Cube Trials helpers
  (`mesh_builder.gd`, `daylight.gd`) into this folder; never preload a path
  under `res://games/cube_trials/`.
- Load game scripts by path with `preload` constants. Avoid `class_name`, so
  nothing here needs an `--import` to resolve and no global name collides.
- The manifest sets `uses_shell_round_rules = false`: the run ends when Dolce
  loses her last heart (or clears a stage), and gameplay then calls the shell's
  normal `_end_round()` path, as Cube Trials does.
- Every action and option key carries the `dolces_adventure_` prefix. Saved
  keys, achievement keys and `custom_user_dir_name` are permanent once shipped.
- Override `_set_reduced_motion_enabled` and `_set_intense_effects_enabled`
  with exact signatures and **call `super(value)`**; the framework sweeps check.

## Mechanics invariants (DESIGN §4–§6)

- `run_state.gd`, `pests.gd`, `chunk_library.gd` and `level_stream.gd` are
  `RefCounted` and touch **no autoload and no node**. Pass options in. They are
  what the headless tests exercise.
- The model steps at a fixed 120 Hz with an accumulator. Every tuning constant
  sits at the top of `run_state.gd`, so tests and the chunk validator quote
  the same numbers.
- The view may add decorative motion (ear flop, tail wag, squash) but never
  feeds back into the model.
- Terrain comes only from hand-authored chunks that pass
  `chunk_library.validate()`, never from free noise. The validator is pillar 2
  ("always fair") as code; widen a chunk, not the validator.
- The camera only scrolls forward. One jump per ground contact; no double jump.
- Distance counts from the run's start point everywhere: score, best distance
  and reach achievements (owner decision, recorded in `TODO.md`).
- Assists (Auto-run, Kind pits, Game speed) never block achievements.
- A stage's clock is model time, so the game-speed assist never changes a
  clear time. A stage's chunk list is part of its records: editing one
  changes what every saved best time means.

## Accessibility

A new run event that makes a sound decides its caption in
`DolceAudio.cue_for()`, and `dolce_audio_test.gd` lists the events that must
have one. Dolce's look lives in `dolce_art.gd` (coat colours) and
`world/dolce_model.gd` (shapes); photos of the real dog may still change it.

Reduced motion removes ear flop, tail wag, squash, camera easing and parallax
drift, but jump, fall and run must stay distinguishable. Intense effects off
means no screen shake and no white flashes; the i-frame blink is an opacity
pulse in either mode. Pests differ by silhouette, never by colour alone, and
the Full state changes both the model's shape and a HUD icon. Every meaningful
sound-only event gets an audio caption (DESIGN §9.5).

## Conventions

Tabs, static typing, `snake_case` and `_private_members`, `##` doc comments
that explain why, matching the host. Keep changes inside this folder unless a
generic framework capability is genuinely necessary, and then add data to
`GameManifest` rather than a game-name branch. Update `README.md`, `DESIGN.md`
and `TODO.md` in the same change as the behaviour they describe. When you
cannot run Godot 4.7 to verify a change, say so.
