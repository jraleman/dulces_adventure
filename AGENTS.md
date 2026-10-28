# AGENTS.md - Dulce's Adventure

Guidance for AI coding agents working in this repository.

## What this repository is

A self-contained **Godot 4.7 game folder**, consumed at
`godot-base/games/dulces_adventure` by the DeskCanSaw base project. It is not
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
| `dulces_adventure_options.gd` | Constants-only tunables, bindings, levels, store and gallery |
| `gameplay.gd` / `.tscn` | Shared-shell integration; inherited scene of `game_shell.tscn` |
| `run_state.gd` | Node-free 120 Hz body; jump arithmetic the validator shares |
| `tile_grid.gd` | Live tiles the body collides with; the stream will feed it |
| `chunk_library.gd` | Authored terrain as string grids (Milestone 1: the grey-box course) |
| `run_controls.gd` | Keyboard and gamepad into model inputs; touches no autoload |
| `world_view.gd` | Isolated `SubViewport`, forward-only orthographic camera, terrain bake |
| `dulce_art.gd` | Palette, `WORLD_SCALE`, `world_point()`, materials |
| `world/dulce_model.gd` | Dulce in 3D (grey box until the Milestone 4 GLB) |
| `world/mesh_builder.gd`, `world/daylight.gd` | Adapted copies of Cube Trials' batching and sun rig |
| `tests` | Standalone Godot `SceneTree` regression scripts |

## Commands

From `godot-base/` (two directories above this folder):

```bash
godot --headless --path . --import
godot --path . -- --game=dulces_adventure
godot --headless --path . --script res://games/dulces_adventure/tests/dulces_adventure_manifest_test.gd -- --game=all
godot --headless --path . --script res://games/dulces_adventure/tests/dulce_physics_test.gd -- --game=all
```

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
- The manifest sets `uses_shell_round_rules = false`: the run ends when Dulce
  loses her last heart (or clears a stage), and gameplay then calls the shell's
  normal `_end_round()` path, as Cube Trials does.
- Every action and option key carries the `dulces_adventure_` prefix. Saved
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

## Accessibility

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
