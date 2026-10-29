# Dulce's Adventure — TODO

Progress tracker for implementing [`DESIGN.md`](DESIGN.md). Sections follow the
milestones in DESIGN §12, with a scaffolding phase first and a **Fixed stages**
milestone the design does not have yet (see the owner's answers below).
Milestones 1–8 are **v1**. Tick a box only when the item works **and** its
tests pass. Each phase ends with an exit check.

`§n` points at the matching section of `DESIGN.md`. Run commands from
`godot-base/`. Framework rules from the root `AGENTS.md` still apply.

---

## Owner decisions (DESIGN §13)

Some of these fix names, keys or scope that can't change once the game ships.
Don't start work that depends on an unanswered one.

- [x] **Endless vs authored** (§13.2) — **both.** Endless seeded runs, plus
      **one fixed, finishable stage per biome (5)**, built from the same
      authored chunks in a fixed order and ending at a food-truck goal.
- [x] **Choosing a run** — endless start points and fixed stages share the
      one manifest `levels` list ("Endless — Backyard", "Stage 1 — Backyard",
      …), gated by achievements. No framework change.
- [x] **Hearts** (§13.3) — 3, with the Full buffer. Max 3.
- [x] **Distance from a later start** (§5.4) — **relative everywhere.**
      Score, best distance and the reach achievements all count from the
      start point. So a later start never unlocks anything a Backyard run
      couldn't. It's practice, labelled "from the Park".
- [x] **Hot seat** (§13.4) — v2. v1 is solo (`supports_multiplayer = false`).
- [x] **How Dulce is built** — a procedural rig of rigid parts in GDScript,
      like Chicken Pit's birds, not a Blender GLB (owner decision: Blender
      isn't installed, and procedural parts keep poses testable headless).
- [ ] **Dulce's real look** (§13.1) — reference photos for coat, ears and
      markings. Milestone 4 shipped the assumed look (owner decision: fawn,
      cream chest and muzzle, big upright ears, curled tail). Photos now mean
      a recolour in `dulce_art.gd`, plus ear or tail shape tweaks in
      `world/dulce_model.gd`. Puppy Kraft's TODO lists "overlap with Dulce's
      Adventure" as a blocker for its own art direction.
- [ ] **Store currency name** (§13.5) — "Treats" is a placeholder. Blocks
      `STORE_CURRENCY` (Milestone 7).
- [ ] **Standalone title and user dir** (§13.6) —
      `"DeskCanSaw Games/Dulce's Adventure"`, with an apostrophe in
      `custom_user_dir_name`. It can never change after the first ship.
      Blocks Milestone 8.
- [x] **Stage gates** — Stage 1 open, Stage N+1 opens when Stage N is
      cleared, through five permanent keys `dulces_adventure_cleared_<biome>`
      (owner decision; DESIGN §5.5, §9.1).
- [x] **Stage headline** — clear time; burgers ("X of Y") and score are
      secondary (owner decision).
- [x] **Stage failure** — losing the last heart ends the attempt with no
      clear, as on an endless run (owner decision).
- [x] **Stage length** — about 300 m (owner decision; 280–340 m, tested).
- [ ] Fold every answer above into `DESIGN.md` (§1, §3, §4.5, §5.4, §6.3,
      §9.1, §10, §12, §13) so the design and this list agree.

## Discrepancies found while planning

- [ ] The project targets Godot **4.7**, but this machine has **4.6.2**
      (`/usr/bin/godot`). Install 4.7 before trusting any test result. On
      4.6.2, **with no Dulce code present**, `accessibility`, `game_shell`,
      `lives_mode` and `visual_effects` segfault, `saves_test` fails
      (`saves.gd` parse error, touch-target sizes) and `game_select_test`
      fails (Back button 42 px). Until 4.7 is installed, a change is checked
      by diffing against that baseline, and the four crashing suites are run
      with `--game=dulces_adventure` (only Dulce in the catalog).
- [ ] **Don't run `--import` with Godot 4.6.2.** It rewrites tracked `.import`
      files across the host and the submodules (it drops 4.7-only options
      such as `fix_alpha_border`) and adds untracked `.uid` files. That
      happened during Milestones 0–5; the stray changes were restored with
      `git checkout` once found. Dulce's own `.import` files were written by
      4.6.2 too, so expect 4.7 to add those options on its first import.
- [ ] `tests/game_select_test.gd` (host) assumed every solo-only game skips
      mode select. Dulce is the first solo-only game with `levels`, which
      `Router.start_selected_game()` sends through mode select, so Back from
      instructions correctly returns there. Milestone 5 fixed the test to
      apply the router's rule. That is a host-repository change: commit it
      there.
- [ ] `tests/instructions_video_test.gd` requires **every** game to ship a
      walkthrough clip and poster, so it fails from the moment `game.gd`
      exists until Dulce has one. Record a grey-box clip at the end of
      Milestone 2 (scripted with `tools/tutorial_driver.gd`) rather than
      faking one, and re-record it in Milestone 7.
- [ ] `character_preview_scene_path` (§6.3) is only used when the manifest
      declares `characters`. `mode_select.gd` returns early when
      `GameSession.character_options()` is empty. The outfit-on-the-plinth
      preview needs one `characters` entry (Dulce). A single-entry picker
      would then show too. Check how that looks, or drop the preview.
- [x] The chunk validator needs at least one `S` (§5.2), but the stream also
      says "a chunk with no marker gets one at its entry seam". Pick one
      rule. As written, the §5.1 `PIT_HOP` example has no `S` and fails the
      validator. *Chose explicit `S` only, standing on solid ground (DESIGN
      §5.2). `PIT_HOP` now has its `S` markers, in DESIGN §5.1 and in the library.*
- [x] The §5.1 legend has no glyph for the **Golden Bone**, and doesn't say
      how a `?` Lunchbox picks a burger or a Big Burger (seeded roll? an
      authored variant glyph?). Add both before writing chunks. *Chose `+`
      for the bone, and authored contents: `?` burger, `!` Big Burger (DESIGN
      §4.4, §5.1).*
- [ ] The §8 table lists gamepad buttons, but Cube Trials polls the gamepad
      directly in `gameplay.gd`, so those buttons aren't rebindable in
      Settings. Accept that (as Cube Trials does), or raise it as framework
      data.
- [ ] §9.2's "roughly `score / 100`" maps to `points_per_score = 0.01`.
      There's no CPU, so `win_bonus` must be 0. Decide `round_bonus` and
      `max_per_round`, and whether clearing a stage pays extra (that has to be
      a `_round_points_earned` override).
- [x] With relative distance, the reach achievements are named after biomes
      ("Off the Leash", PARK) but can be earned from any start. Run 400 m from
      the Park and you get "reached_park" somewhere on Main Street. Keep the
      keys (they're permanent) but check the titles and descriptions say
      "run 400 m", not "reach the Park". *Keys and titles kept; descriptions
      say "Run 400 m in one run" (DESIGN §9.1).*
- [x] `save_files` (§6.3) describes "best distance and score from each start
      point". Stages add clears and a best per stage. Agree on the
      `user://dulces_adventure.cfg` layout before Milestone 2 writes it.
      *One section per start point (`[backyard]`), fields `distance`, `score`,
      `burgers`, each only ever rising; saves merge (DESIGN §4.5). Stages add
      their own sections in Milestone 6.*
- [ ] Phones show the keyboard hint in the shell's bottom bar. DESIGN §8 says
      phones show icons only. Hide or replace the hint when the touch buttons
      are showing (Milestone 8 touch pass).

---

## Phase 0 — Scaffolding

As soon as `game.gd` exists, `GameCatalog` loads it and every framework suite
sweeps it. Start with a stub that passes them, and keep them green from then
on.

- [x] Commit `DESIGN.md` to the game repository.
- [ ] Commit this `TODO.md`.
- [x] A folder `AGENTS.md` with game-specific agent notes, as Chicken Pit has.
- [x] `dulces_adventure_options.gd` — constants-only (§6, §8): `GAME_ID`,
      tunable keys (auto-run, kind pits, game speed, day/night), binding keys
      prefixed `dulces_adventure_`, an empty `LEVELS`, store and gallery for
      now.
- [x] `game.gd` — minimal manifest (§6.3): id, title, tagline,
      `menu_order = 9`, `CONTROL_STYLE_CUSTOM_KEYS`,
      `uses_shell_round_rules = false`, `supports_multiplayer = false`,
      `supports_cpu_opponent = false`, tunables, bindings.
- [x] `gameplay.tscn` (inherits `game_shell.tscn`) + `gameplay.gd` (`extends
      GameShell`, `game_id()`, `super(value)` in the reduced-motion and
      intense-effects overrides).
- [x] A `tests/` folder and a smoke test that loads the manifest by path
      (`tests/dulces_adventure_manifest_test.gd`).
- [x] `godot --headless --path . --import`
- [ ] **Exit:** all 15 framework suites exit 0 with `--game=all`, and
      `godot --path . -- --game=dulces_adventure` opens the stub.
      *Blocked on Godot 4.7.* On 4.6.2 every suite exits as it did before
      Dulce existed, except `instructions_video_test` (no clip yet, see
      above). `game_shell_test` and `visual_effects_test` pass with only
      Dulce in the catalog.

## Milestone 1 — Feel prototype (§4.1, §4.7, §6.1, §7.1) ⚠ the pillar

- [x] `run_state.gd` (`RefCounted`, no autoloads, no nodes): fixed 120 Hz step
      with an accumulator, every §4.1 constant at the top. Stomp bounce and
      i-frame constants join in Milestone 2, with the rules that use them.
  - [x] Walk/run speeds, ground accel/decel, air accel
  - [x] Gravity, fall multiplier, fall cap
  - [x] Variable jump: hold for full height, release to cut
  - [x] Running-jump bonus
  - [x] Coyote time and jump buffer
  - [x] No double jump
  - [x] AABB vs tile grid, plus one-way platforms (no slopes)
  - [x] Game-speed scaling (70–100%)
  - [x] Forward-only camera bound: Dulce can't pass the left edge (§4.7)
- [x] A grey-box test course with gaps of 2–5 tiles, a ledge, a bump block and
      one-way platforms: `chunk_library.gd` `FEEL_COURSE`, the file Milestone 3
      grows into the library. Live tiles sit in `tile_grid.gd` (new; not in
      DESIGN §6), which the stream will feed.
- [x] `dulce_art.gd` — palette, `WORLD_SCALE = 0.025`, `world_point()`.
- [x] `world/mesh_builder.gd` and `world/daylight.gd` — copied from
      `cube_trials/world/` and adapted (no game-to-game dependency). Daylight
      takes a palette dictionary, ready for the Milestone 5 biomes.
- [x] `world_view.gd` — isolated `SubViewport`, orthographic side camera
      with a slight downward tilt, forward-only scroll. The *left edge* is
      what moves forward, so a resize can't leave it ahead of Dulce, and a
      respawn re-frames the view. Pits get a dark back wall.
- [x] A grey-box Dulce (`world/dulce_model.gd`, the file Milestone 4 fills
      with the GLB) and a blob shadow that shrinks with height.
- [x] `run_controls.gd` — keyboard (rebindable actions plus fixed arrow
      keys) and gamepad (stick, D-pad, A jump, X / right trigger run).
- [x] `tests/dulce_physics_test.gd` (§10), plus one-way platforms, walls,
      ceiling bumps, the camera edge, Auto-run, pits, and checks that the
      validator's `jump_height()` / `jump_reach()` match the real body.
- [ ] **Exit:** jumping is fun with a grey box, according to two playtesters.
      Record the measured max running-jump width and height here. The chunk
      validator uses them.
      Measured on the model: a full running jump rises **4.71 tiles** and
      travels **6.22 tiles** back to take-off height; a standing jump rises
      **3.80 tiles** (DESIGN §4.1's ~3.9 is the continuous figure). A tapped
      jump is a hop of under a tile. *Playtest still to do:* run
      `godot --path . -- --game=dulces_adventure`.

## Milestone 2 — Rules (§4.2–§4.5, §9.1)

- [x] Hearts (3), the Full state, i-frames (opacity blink), pit fall and
      respawn at the last safe ground, run end after the tumble.
- [x] The Kind pits assist.
- [x] Collectibles: burger, Big Burger, Golden Bone, Lunchbox bonk from below;
      every 100 burgers gives a heart (points once capped).
- [x] Scoring: distance × 10 + items + stomps, stomp chain 200 → 1600 cap.
      Distance counts from the start point.
- [x] `pests.gd` (node-free): Grumpy Pigeon and Garden Gnome; stomp vs side
      hit. Pests wake within 16 tiles, so a chunk plays as authored.
- [x] `run_hud.gd` — hearts (filled or outline), burgers and a FULL badge
      over the sky. Distance and score went into the shell's own two HUD
      cards instead (distance takes the big one, as the headline).
- [x] `run_controls.gd` — first-pass multitouch buttons: ◀ ▶ and a big Jump,
      double-tap-and-hold ▶ to run; the ground line lifts clear of them.
      Shown only on touchscreens.
- [x] `GameShell` hooks (§6.2) wired: end the run at `hearts == 0` through the
      shell's normal end-of-round path, as Cube Trials does; `_round_totals`,
      `_player_stats`, `_describe_round_outcome`, `_round_highlight_summary`.
      "Collected" is burgers eaten out of burgers passed, so the percentage
      is real on an endless run.
- [x] Achievements registered (§9.1, all seven keys); the four reach
      achievements, `combo`, `clean` and `hundred` awarded. Assists never
      block them.
- [x] Best runs in `user://dulces_adventure.cfg`, declared in `save_files`
      (`run_records.gd`, `tests/dulce_records_test.gd`).
- [x] `tests/dulce_rules_test.gd`, `tests/dulce_pests_test.gd` (pigeon,
      gnome).
- [x] Grey-box pest and food models (`world/pest_models.gd`,
      `world/food_models.gd`), told apart by silhouette.
- [ ] **Exit:** a grey-box run with pits, two pests and burgers ends in
      results with distance, score and achievements, and `saves_test.gd`
      still passes.
      *On 4.6.2:* a scripted run ends in results ("NEW BEST: 422 M!",
      "Unlocked: Off the Leash") through the real shell path, run in a
      throwaway `XDG_DATA_HOME`; `saves_test` fails exactly as it did before
      Dulce existed. Still to do: confirm on Godot 4.7, play it by hand, and
      record the grey-box walkthrough clip (see Discrepancies).

## Milestone 3 — Stream (§5.1–§5.2)

- [x] `chunk_library.gd` — the one legend const (plus the Golden Bone glyph),
      chunks as const string grids, seam at row 4. The grey-box course is
      gone; its pieces became chunks.
- [x] `chunk_library.validate(chunk)` — a reachability search that quotes
      `run_state`'s jump arithmetic with a 1-tile margin (pits ≤ 5, ledges
      ≤ 3), plus seams, legend, pests standing on something, gnomes with
      room beside them, and every `S` on solid ground, reachable and not a
      dead end. `route_problems()` runs the same search over whole runs.
- [x] **≥ 15 Backyard chunks** across difficulties, plus breather chunks:
      18 chunks over difficulties 1–4, 3 breathers, and the fixed
      `backyard_start`.
- [x] `level_stream.gd` — seeded assembly, ~3 screens ahead, frees 2 behind,
      difficulty ramp by distance, no immediate repeats, a breather every
      4th chunk, safe-ground tracking (`run_state.forget_before()` keeps the
      respawn point).
- [x] The seed in the results stats ("Course seed"), and
      `-- --dulce-seed=<n>` to replay it.
- [x] `tests/dulce_chunks_test.gd` (every chunk, and the shapes the
      validator must reject), `tests/dulce_stream_test.gd`.
- [x] The view bakes one terrain mesh per chunk, so a new chunk or an opened
      Lunchbox re-bakes one chunk, not the run.
- [ ] **Exit:** a 1,000 m Backyard run on one seed is identical twice, and
      no generated pit is impossible.
      *On 4.6.2:* `dulce_stream_test` builds 1,000 m twice per seed and
      compares chunk ids and tiles, and walks eight seeds' kilometres end to
      end with the validator; all pass. A scripted seed-42 run plays through
      to results in the real scene. Still to do: confirm on Godot 4.7, and
      play a few seeds by hand to tune the ramp (150 m per difficulty step is
      a starting point).

## Milestone 4 — Dulce (§7.2, §9.6)

- [x] ~~Blender model + generator script in `tools/blender/`; `dulce.glb` in
      `assets/models/`.~~ Replaced by a procedural rig (owner decision above).
- [x] `world/dulce_model.gd` — idle, trot, sprint, jump-up, apex, fall, land,
      stomp-bounce, hit, tumble, eat, victory sit; Full belly morph; collar
      socket; ear and tail motion. Pivots per head, ear, leg, tail and
      collar; `pose_for(state)` picks the pose; events add short reactions.
- [x] Reduced motion: no ear flop, tail wag or squash, but jump, fall and run
      stay distinguishable (`tests/dulce_model_test.gd` checks both).
- [x] `world/paw_particles.gd` — footstep dust, landing puff, crumbs and
      feather poofs; one 64-slot pool, shadow-free, no per-frame allocation.
- [x] `dulce_audio.gd` — yip, land, boing (pitch climbs with the chain),
      munch, gulp, whine, heart chime, biome fanfare, tumble, plus bump and
      pop; all synthesized at load.
- [x] Audio captions (§9.5) for hit, heart lost, heart gained, Full
      gained/lost, stomp chain and run over, from one table
      (`DulceAudio.cue_for()`, `tests/dulce_audio_test.gd`). The biome
      caption is in the table; Milestone 5 sends the event.
- [x] `world/pest_models.gd` — pigeon and gnome, readable by silhouette; the
      pigeon now waddles (parked by reduced motion).
- [ ] **Exit:** the grey box is gone. Dulce reads clearly at phone size and
      every meaningful sound has a caption.
      *On 4.6.2:* the grey box is gone. Every pose renders distinctly in a
      contact sheet, and she reads mid-leap in portrait at phone width (about
      7% of it, near Mario's NES share; her hit box sets the limit). Captions
      are tested. Still to do: hear the cues on real speakers, check her
      size by hand on a phone, and confirm on Godot 4.7.

## Milestone 5 — Biomes 2–5 (§4.3, §5.3–§5.4, §7.1)

- [x] `world/biome_props.gd` — Backyard, Park, Main Street, Boardwalk Pier,
      Night Market; batched props and a far parallax backdrop of real
      geometry. Props stand behind the playfield, placed by column so a seed
      always dresses the same. Lanterns and lit windows go in a glow mesh.
      The orthographic camera has no perspective, so the backdrop is scaled
      to 0.42 and scrolls at 35% of the playfield's speed.
- [x] Biome palettes (`biome_props.gd`, blended in `world/daylight.gd`); the
      day/night toggle still works, and the Night Market dims the sun.
- [x] Distance-based biome changes with a banner and a gate set piece; loop
      after the Night Market with difficulty still rising. Biomes follow
      world distance, while difficulty follows the run (see DESIGN §5.3).
- [x] Food flavour per biome (hot dogs, tacos, fries, gold burgers).
- [x] Remaining pests: Squirrel, Robo-Vac (flip, kick, slide, bonk chain),
      Seagull (swoop), Hot-Sauce Bottle (arc shot); their models.
- [x] Chunks for every biome, all through `validate()`: a gate, 2 breathers
      and 2 chunks at each difficulty 1–4 per biome (44 new chunks). The
      validator caught three of them with safe ground or a bottle over a pit.
- [x] `LEVELS` — endless start points ("Endless - Backyard" … "Endless -
      the Night Market"), gated by the reach achievements; distance relative.
- [x] `tools/capture_art.gd` — biome stills into `assets/levels/` for the
      level icons. Dev-only (exclude `tools/` from exports in Milestone 8).
- [x] Extend `tests/dulce_pests_test.gd` and `tests/dulce_chunks_test.gd`,
      plus the biome schedule, gate events and whole-cycle fairness from
      every start point in `tests/dulce_stream_test.gd`, and vac and sauce
      rules in `tests/dulce_rules_test.gd`.
- [ ] **Exit:** a strong player can run from the Backyard into the Night
      Market, and each endless start unlocks from a fresh profile.
      *On 4.6.2:* the stream suite walks a full 3,000 m cycle from every
      start point, and the validator finds every pit jumpable. A scripted
      run starts at the Park on a profile with it unlocked, and the setup
      screen's gates come from the shared, tested level selector. Still to
      do: run Backyard → Night Market by hand (about 2.2 km), check the
      unlocks on a fresh profile in the real menus, and confirm on Godot 4.7.
- [ ] Polish noted while building: the Market's food trucks and the Pier's
      umbrellas can feel frequent; the Street backdrop is busy. Tune
      `_roll` thresholds and backdrop density after playtests.

## Milestone 6 — Fixed stages (DESIGN §5.5)

- [x] Write the stages into `DESIGN.md` first: length (~300 m), goal,
      headline, gates, failure rule (§5.5).
- [x] One stage per biome: a fixed, ordered list of authored chunks, with
      fixed Lunchbox contents and no random rolls (`stages.gd`; the stream's
      stage mode ignores the seed).
- [x] The food-truck goal and a "cleared" end of round; results and outcome
      text for a clear and for a run out of hearts. The goal is a new `F`
      glyph in a shared goal chunk, with ground running on past it.
- [x] `LEVELS` gains "Stage 1 - Backyard" … "Stage 5 - the Night Market",
      gated by the agreed stage-clear achievements.
- [x] Stage clears and per-stage bests in `user://dulces_adventure.cfg`
      (`time_ms`, lower is better, never set by an unfinished attempt).
- [x] Stage stills from `tools/capture_art.gd`: Dulce a few tiles short of
      the finish.
- [x] `tests/dulce_stages_test.gd` — every stage's chunk list validates and
      joins at the seams, the goal is reachable, the unlock chain, the stream
      lays the stage as authored whatever the seed, a scripted clear stops
      the clock and ends the run, bests never regress.
- [x] The results card's rules line, which had shown the shell's
      placeholder ("Round scoring goes here.") since Milestone 2, now
      describes the mode.
- [ ] **Exit:** all five stages can be cleared from a fresh profile in
      order, and the endless runs still work.
      *On 4.6.2:* every stage validates end to end, and scripted clears of
      Stage 1 and 2 go through the real scene to "NEW BEST" results and
      unlock their achievements in a throwaway profile. Still to do: clear
      all five by hand from a fresh profile (and set target times from
      that), and confirm on Godot 4.7.

## Milestone 7 — Shell features (§7.3, §9.1–§9.4)

- [ ] Store (§9.2): currency (name per §13.5), slots collar, hat and bandana;
      starter catalogue with the red collar as default; worn in the run, on
      the plinth, on the share card and in the gallery; `store_preview.tscn`.
- [ ] `characters` entry for Dulce + `character_preview.tscn` (see the
      plinth discrepancy above).
- [ ] Gallery (§9.3): Dulce (idle, Full), every pest, Lunchbox, Big Burger,
      Golden Bone, a food truck; later biome props gated by reach
      achievements; `gallery_stage.tscn` with `configure`, `set_view`,
      `set_auto_spin`.
- [ ] Share card (§9.4): `share_art.tscn`, Dulce in her outfit in the victory
      sit, distance headline (or the stage headline), biome, burgers, score,
      QR.
- [ ] `GameTheme` (§7.3) + `assets/game-icon.png` captured from the model.
- [ ] `intro.tscn` — the four story cards (§1).
- [ ] Instructions copy through `manifest.text` keys.
- [ ] Credits.
- [ ] Tutorial video + poster (`tools/tutorial_driver.gd`,
      `record_tutorials.ps1`).
- [ ] `tests/dulce_scene_test.gd` (§10): loads under the shell, HUD binds,
      pause, results, payout.
- [ ] **Exit:** `store_test`, `gallery_test`, `share_card_test`,
      `saves_test` and `single_game_test` pass with `--game=all`.

## Milestone 8 — Polish and integration (§8, §9.5, §11) — v1 ships

- [ ] Touch layout pass: buttons ≥ 44 physical px, multi-finger, clear of the
      ground line; the one-time Auto-run hint on touchscreens; icons on
      phones, key hints on wide screens.
- [ ] Accessibility sweep against §9.5.
- [ ] `tests/dulce_view_test.gd` *(window)* — Dulce visible and unobstructed,
      portrait → ultrawide, touch buttons clear of the ground line.
- [ ] `project.godot`: `config/name.dulces_adventure`,
      `custom_user_dir_name.dulces_adventure` (after §13.6),
      `config/icon.dulces_adventure`,
      `dcs/build/single_game_id.dulces_adventure`,
      `[share] stats_urls/dulces_adventure` (≤ 42 bytes).
- [ ] `export_presets.cfg`: a standalone preset with the feature tag; exclude
      `games/dulces_adventure/*` from the other presets; keep `tools/` out.
- [ ] `.gitmodules` + gitlink (two commits: game repo, then `dcs_games`).
- [ ] Root `AGENTS.md`: games table, submodules, options files, test table,
      feature tags, blurb. Update `godot-base/README.md` if it lists games.
- [ ] Write the folder `README.md` properly (it's a one-line stub).
- [ ] **Exit:** all framework suites + all game suites exit 0 with
      `--game=all`; window suites run without `--headless`.

---

## After v1 (§12 v2 candidates)

- [ ] Slopes (model + validator).
- [ ] Hot-seat turns, P1/P2/P3, best distance wins (reuse Cube Trials'
      hand-off flow).
- [ ] A daily seed.
- [ ] Chase camera.
- [ ] A light music bed through `AudioManager`.
