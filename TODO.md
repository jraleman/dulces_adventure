# Dolce's Adventure — TODO

Progress tracker for implementing [`DESIGN.md`](DESIGN.md). Sections follow the
milestones in DESIGN §12, with a scaffolding phase first.
Milestones 1–8 are **v1**. Tick a box only when the item works **and** its
tests pass. Each phase ends with an exit check.

`§n` points at the matching section of `DESIGN.md`. Run commands from
`godot-base/`. Framework rules from the root `AGENTS.md` still apply.

**v1.0.0 Windows local release is prepared; gameplay is owner-accepted.**
Implementation, all 13 game and 15 framework suites, all five full input-only
stages, the 2.25 km endless run, exports and packaged/native smoke checks pass
on Godot 4.7.2. On 2026-11-01 the owner reported "It plays nicely and all is
good" and approved local finalization. Commits, tags, signing and publication
are deferred. The detailed manual/device checks below have no supplied test
matrix; do not treat general owner acceptance as evidence they were performed.

**v2 phase 1 is implemented in source:** Daily UTC (§5.6), with UTC-midnight
resets, unlimited Backyard attempts and separate daily bests. All 13 game
and 15 framework suites pass on Godot 4.7.2. V1 binaries remain frozen;
v2 has not been packaged or owner-accepted.

---

## Owner decisions (DESIGN §13)

Some of these fix names, keys or scope that can't change once the game ships.
Don't start work that depends on an unanswered one.

- [x] **Pre-release naming** - the game is **Dolce's Adventure**, its heroine
      is **Dolce**, and source, saved keys and files use the new names only.
      Older development saves are not migrated; there are no legacy aliases.
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
- [x] **How Dolce is built** — a procedural rig of rigid parts in GDScript,
      like Chicken Pit's birds, not a Blender GLB (owner decision: Blender
      isn't installed, and procedural parts keep poses testable headless).
- [x] **Dolce's real look** (§13.1) — the owner approved the current
      procedural fawn/cream look, upright ears and curled tail for v1.
      Reference photos are optional later recolour/shape work, not a blocker.
- [x] **Store currency name** (§13.5) — **Treats** (owner decision).
- [x] **Treats payout** — `score / 100` plus 3 per run, plus 20 for clearing
      a stage; no win bonus, no cap (owner decision; DESIGN §9.2).
- [x] **Setup plinth** — Dolce is the manifest's single `characters` entry,
      so the setup screen stands her on the plinth in her outfit (owner
      decision).
- [x] **Standalone title and user dir** (§13.6) — owner approved
      `"DeskCanSaw Games/Dolce's Adventure"`, with an apostrophe in
      `custom_user_dir_name`. It can never change after the first ship.
- [x] **Stage gates** — Stage 1 open, Stage N+1 opens when Stage N is
      cleared, through five permanent keys `dolces_adventure_cleared_<biome>`
      (owner decision; DESIGN §5.5, §9.1).
- [x] **Stage headline** — clear time; burgers ("X of Y") and score are
      secondary (owner decision).
- [x] **Stage failure** — losing the last heart ends the attempt with no
      clear, as on an endless run (owner decision).
- [x] **Stage length** — about 300 m (owner decision; 280–340 m, tested).
- [x] **v1 gameplay acceptance / local release** (§13.8) — owner accepted
      gameplay on 2026-11-01 and selected local v1 finalization.
      No commits, tags, signing or publication; no new v2 mechanics.
- [x] **First v2 feature** (§13.9) — Daily UTC, resetting at **UTC midnight**
      with **unlimited attempts** from the Backyard. Separate daily bests;
      existing assists/achievements stay available; a started run keeps its
      date/seed through midnight.
- [x] Fold every answer above into `DESIGN.md` (§1, §3, §4.5, §5.4, §6.3,
      §9.1, §10, §12, §13) so the design and this list agree.

## Discrepancies found while planning

- [x] Verify on the target engine: **Godot 4.7.2 on Windows** now imports the
      game and passes all 13 game suites (12 headless, 1 window) and all 15
      framework suites with `--game=all`. This supersedes the Linux 4.6.2
      baseline failures noted in earlier milestones. Jump measurements are
      unchanged: 4.71 tiles high / 6.22 long running, 3.80 high standing.
- [ ] **Don't run `--import` with Godot 4.6.2.** It drops 4.7-only options
      such as `fix_alpha_border` from metadata across the host and submodules.
      Even 4.7 can recreate missing unrelated `.uid` files: snapshot first,
      preserve other worktrees, and remove only files this import created.
- [x] `tests/game_select_test.gd` (host) assumed every solo-only game skips
      mode select. Dolce is the first solo-only game with `levels`, which
      `Router.start_selected_game()` sends through mode select, so Back from
      instructions correctly returns there. Milestone 5 fixed the test to
      apply the router's rule; the host suite now passes on 4.7.2.
- [x] `tests/instructions_video_test.gd` requires **every** game to ship a
      walkthrough clip and poster, so it fails from the moment `game.gd`
      exists until Dolce has one. *Milestone 7 recorded the real clip: an
      autopilot (`tools/tutorial_driver.gd`) runs Stage 1.*
- [x] `character_preview_scene_path` (§6.3) is only used when the manifest
      declares `characters`. `mode_select.gd` returns early when
      `GameSession.character_options()` is empty. *Dolce is the one
      `characters` entry (owner decision), so the plinth shows her. The
      single-entry Dog row hasn't been checked by eye yet: Milestone 8's
      layout pass.*
- [x] The host recorder accepts `-Games dolces_adventure`. Re-recorded on
      Windows 4.7.2 after the touch/HUD pass through `tutorial_capture.tscn`
      and the real Stage 1 driver: Movie Maker at 1280×720 / 30 fps, Theora
      at 960×540 / q 6, 27 s, poster at the script's default 6.0 s.
- [x] One old Movie Maker take logged `!isfinite(p_size)` once. It did not
      recur in the 4.7.2 take or rendered suite.
- [ ] Host `lives_mode_test` and `single_game_test` exit 0 but log ObjectDB /
      resource-in-use warnings at shutdown. Verbose output identifies the
      shared UI's click/focus/back WAVs and Chicken Pit's intro narration.
      Investigate separately; Dolce's scene/rendered suites have none.
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
- [x] **Gamepad controls** (§8) — the owner approved the current fixed
      gamepad controls for v1. Keyboard actions remain rebindable; no new
      framework binding capability is needed.
- [x] §9.2's "roughly `score / 100`" maps to `points_per_score = 0.01`.
      There's no CPU, so `win_bonus` must be 0. Decide `round_bonus` and
      `max_per_round`, and whether clearing a stage pays extra (that has to be
      a `_round_points_earned` override). *`round_bonus` 3, no cap, and
      `TREATS_PER_CLEAR` 20 through the override (DESIGN §9.2).*
- [x] With relative distance, the reach achievements are named after biomes
      ("Off the Leash", PARK) but can be earned from any start. Run 400 m from
      the Park and you get "reached_park" somewhere on Main Street. Keep the
      keys (they're permanent) but check the titles and descriptions say
      "run 400 m", not "reach the Park". *Keys and titles kept; descriptions
      say "Run 400 m in one run" (DESIGN §9.1).*
- [x] `save_files` (§6.3) describes "best distance and score from each start
      point". Stages add clears and a best per stage. Agree on the
      `user://dolces_adventure.cfg` layout before Milestone 2 writes it.
      *One section per start point (`[backyard]`), fields `distance`, `score`,
      `burgers`, each only ever rising; saves merge (DESIGN §4.5). Stages add
      their own sections in Milestone 6.*
- [x] Hide the shell's keyboard hint when touch icons are visible; reclaim
      that footer space while keeping active audio captions clear.

---

## Phase 0 — Scaffolding

As soon as `game.gd` exists, `GameCatalog` loads it and every framework suite
sweeps it. Start with a stub that passes them, and keep them green from then
on.

- [x] Commit `DESIGN.md` to the game repository.
- [ ] Commit this `TODO.md`.
- [x] A folder `AGENTS.md` with game-specific agent notes, as Chicken Pit has.
- [x] `dolces_adventure_options.gd` — constants-only (§6, §8): `GAME_ID`,
      tunable keys (auto-run, kind pits, game speed, day/night), binding keys
      prefixed `dolces_adventure_`, an empty `LEVELS`, store and gallery for
      now.
- [x] `game.gd` — minimal manifest (§6.3): id, title, tagline,
      `menu_order = 9`, `CONTROL_STYLE_CUSTOM_KEYS`,
      `uses_shell_round_rules = false`, `supports_multiplayer = false`,
      `supports_cpu_opponent = false`, tunables, bindings.
- [x] `gameplay.tscn` (inherits `game_shell.tscn`) + `gameplay.gd` (`extends
      GameShell`, `game_id()`, `super(value)` in the reduced-motion and
      intense-effects overrides).
- [x] A `tests/` folder and a smoke test that loads the manifest by path
      (`tests/dolces_adventure_manifest_test.gd`).
- [x] `godot --headless --path . --import`
- [x] **Exit:** all 15 framework suites exit 0 with `--game=all`, and the
      window suite starts the current gameplay scene under the real shell
      on Godot 4.7.2. The old stub and 4.6.2 blockers are superseded.

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
  - [x] Forward-only camera bound: Dolce can't pass the left edge (§4.7)
- [x] A grey-box test course with gaps of 2–5 tiles, a ledge, a bump block and
      one-way platforms: `chunk_library.gd` `FEEL_COURSE`, the file Milestone 3
      grows into the library. Live tiles sit in `tile_grid.gd` (new; not in
      DESIGN §6), which the stream will feed.
- [x] `dolce_art.gd` — palette, `WORLD_SCALE = 0.025`, `world_point()`.
- [x] `world/mesh_builder.gd` and `world/daylight.gd` — copied from
      `cube_trials/world/` and adapted (no game-to-game dependency). Daylight
      takes a palette dictionary, ready for the Milestone 5 biomes.
- [x] `world_view.gd` — isolated `SubViewport`, orthographic side camera
      with a slight downward tilt, forward-only scroll. The *left edge* is
      what moves forward, so a resize can't leave it ahead of Dolce, and a
      respawn re-frames the view. Pits get a dark back wall.
- [x] A grey-box Dolce (`world/dolce_model.gd`, the file Milestone 4 fills
      with the procedural rig) and a blob shadow that shrinks with height.
- [x] `run_controls.gd` — keyboard (rebindable actions plus fixed arrow
      keys) and gamepad (stick, D-pad, A jump, X / right trigger run).
- [x] `tests/dolce_physics_test.gd` (§10), plus one-way platforms, walls,
      ceiling bumps, the camera edge, Auto-run, pits, and checks that the
      validator's `jump_height()` / `jump_reach()` match the real body.
- [ ] **Exit:** jumping is fun with a grey box, according to two playtesters.
      Record the measured max running-jump width and height here. The chunk
      validator uses them.
      Measured on the model: a full running jump rises **4.71 tiles** and
      travels **6.22 tiles** back to take-off height; a standing jump rises
      **3.80 tiles** (DESIGN §4.1's ~3.9 is the continuous figure). A tapped
      jump is a hop of under a tile. *Playtest still to do:* run
      `godot --path . -- --game=dolces_adventure`.

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
- [x] Best runs in `user://dolces_adventure.cfg`, declared in `save_files`
      (`run_records.gd`, `tests/dolce_records_test.gd`).
- [x] `tests/dolce_rules_test.gd`, `tests/dolce_pests_test.gd` (pigeon,
      gnome).
- [x] Grey-box pest and food models (`world/pest_models.gd`,
      `world/food_models.gd`), told apart by silhouette.
- [ ] **Exit:** a grey-box run with pits, two pests and burgers ends in
      results with distance, score and achievements, and `saves_test.gd`
      still passes.
      *On 4.6.2:* a scripted run ends in results ("NEW BEST: 422 M!",
      "Unlocked: Off the Leash") through the real shell path, run in a
      throwaway `XDG_DATA_HOME`; `saves_test` fails exactly as it did before
      Dolce existed. *Now on 4.7.2:* the real-scene results and saves suites
      pass; the procedural-art walkthrough is recorded. Playing by hand is
      still required.

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
      `-- --dolce-seed=<n>` to replay it.
- [x] `tests/dolce_chunks_test.gd` (every chunk, and the shapes the
      validator must reject), `tests/dolce_stream_test.gd`.
- [x] The view bakes one terrain mesh per chunk, so a new chunk or an opened
      Lunchbox re-bakes one chunk, not the run.
- [ ] **Exit:** a 1,000 m Backyard run on one seed is identical twice, and
      no generated pit is impossible.
      *On 4.6.2:* `dolce_stream_test` builds 1,000 m twice per seed and
      compares chunk ids and tiles, and walks eight seeds' kilometres end to
      end with the validator; all pass. A scripted seed-42 run plays through
      to results in the real scene. The stream and real-scene suites also
      pass on 4.7.2. Still to do: play a few seeds by hand to tune the ramp
      (150 m per difficulty step is a starting point).

## Milestone 4 — Dolce (§7.2, §9.6)

- [x] ~~Blender model + generator script in `tools/blender/`; `dolce.glb` in
      `assets/models/`.~~ Replaced by a procedural rig (owner decision above).
- [x] `world/dolce_model.gd` — idle, trot, sprint, jump-up, apex, fall, land,
      stomp-bounce, hit, tumble, eat, victory sit; Full belly morph; collar
      socket; ear and tail motion. Pivots per head, ear, leg, tail and
      collar; `pose_for(state)` picks the pose; events add short reactions.
- [x] Reduced motion: no ear flop, tail wag or squash, but jump, fall and run
      stay distinguishable (`tests/dolce_model_test.gd` checks both).
- [x] `world/paw_particles.gd` — footstep dust, landing puff, crumbs and
      feather poofs; one 64-slot pool, shadow-free, no per-frame allocation.
- [x] `dolce_audio.gd` — yip, land, boing (pitch climbs with the chain),
      munch, gulp, whine, heart chime, biome fanfare, tumble, plus bump and
      pop; all synthesized at load.
- [x] Audio captions (§9.5) for hit, heart lost, heart gained, Full
      gained/lost, stomp chain and run over, from one table
      (`DolceAudio.cue_for()`, `tests/dolce_audio_test.gd`). The biome
      caption is in the table; Milestone 5 sends the event.
- [x] `world/pest_models.gd` — pigeon and gnome, readable by silhouette; the
      pigeon now waddles (parked by reduced motion).
- [ ] **Exit:** the grey box is gone. Dolce reads clearly at phone size and
      every meaningful sound has a caption.
      *On 4.6.2:* the grey box is gone. Every pose renders distinctly in a
      contact sheet, and she reads mid-leap in portrait at phone width (about
      7% of it, near Mario's NES share; her hit box sets the limit). Captions
      are tested. *Now on 4.7.2:* the rig/audio suites and real phone-sized
      window renders pass. Still to do: hear the cues on real speakers and
      check her size by hand on a physical phone.

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
- [x] Extend `tests/dolce_pests_test.gd` and `tests/dolce_chunks_test.gd`,
      plus the biome schedule, gate events and whole-cycle fairness from
      every start point in `tests/dolce_stream_test.gd`, and vac and sauce
      rules in `tests/dolce_rules_test.gd`.
- [ ] **Exit:** a strong player can run from the Backyard into the Night
      Market, and each endless start unlocks from a fresh profile.
      *On 4.6.2:* the stream suite walks a full 3,000 m cycle from every
      start point, and the validator finds every pit jumpable. A scripted
      run starts at the Park on a profile with it unlocked, and the setup
      screen's gates come from the shared, tested level selector. The stream
      and framework gates suites now pass on 4.7.2. Still to do: run
      Backyard → Night Market by hand (about 2.2 km) and check the unlocks
      on a fresh profile in the real menus.
      *v1 automated check on 4.7.2:* seed 42 drives 2,250 m through normal
      controls, passing every biome gate with three hearts and no damage
      (148 burgers, 27 stomps). Actual input collisions then end the run
      at 2,256 m; results earn all four reach achievements, unlock every
      endless start from fresh progression, and save the real record.
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
- [x] Stage clears and per-stage bests in `user://dolces_adventure.cfg`
      (`time_ms`, lower is better, never set by an unfinished attempt).
- [x] Stage stills from `tools/capture_art.gd`: Dolce a few tiles short of
      the finish.
- [x] `tests/dolce_stages_test.gd` — every stage's chunk list validates and
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
      unlock their achievements in a throwaway profile. These suites also
      pass on 4.7.2. Still to do: clear all five by hand from a fresh profile
      and set target times from that.
      *v1 automated check on 4.7.2:* every full course clears through real
      input actions from fresh progression: 298, 296, 294, 292 and 300 m,
      with three hearts, no hits and no pit recoveries. Results, Treats,
      actual saved clear times and sequential unlocks pass. The test-only
      player predicts on deep copies; no teleporting, removed enemies,
      injected hearts, course edits or validator changes. Full human clears
      and human target times remain unverified.

## Milestone 7 — Shell features (§7.3, §9.1–§9.4)

- [x] Store (§9.2): Treats; collar, hat and neck slots (hat and neck can be
      empty); eleven items, the red collar the free default, three gated by
      achievements; worn in the run, on the plinth, on the share card and in
      the gallery (`world/outfit_models.gd`); `store_preview.tscn` draws once
      per card.
- [x] Payout: `score / 100` + 3 per run through `STORE_CURRENCY`, + 20 for a
      stage clear through `_round_points_earned`.
- [x] `characters` entry for Dolce + `character_preview.tscn`: the plinth
      shows her in her equipped outfit.
- [x] Gallery (§9.3): Dolce (idle, Full), every pest, Lunchbox, Big Burger,
      Golden Bone, the food truck; later pests gated by their biome's reach
      achievement, the truck by clearing Stage 1; `gallery_stage.tscn` with
      `configure`, `set_view`, `set_auto_spin`.
- [x] Share card (§9.4): `share_art.tscn`, Dolce in the payload's outfit in
      the victory sit beside a Big Burger; the shell's card carries the
      distance or clear-time headline, burgers, score and QR.
- [x] One portrait set, `world/studio.gd`, for the store, plinth, gallery and
      share card: daylight rig, camera framed from measured bounds.
- [x] `GameTheme` (§7.3) + `assets/game-icon.png` captured from the model
      (`capture_art.gd --only=icon`).
- [x] `intro.tscn` — the four story cards (§1).
- [x] Instructions copy through `manifest.text` keys, including the store and
      gallery intros.
- [x] Credits.
- [x] Tutorial video + poster: `tools/tutorial_driver.gd` drives Stage 1 with
      an autopilot (runs, clears pits, stomps pigeons, hops gnomes) and
      captions; a take must cover ≥ 90 m, ≥ 5 burgers and a stomp. 27 s clip,
      poster now from 6.0 s. (See the recorder note under discrepancies.)
- [x] `tests/dolce_scene_test.gd` (§10): loads under the shell, HUD and
      outfit bind, pause, full input-only stages and Backyard-to-Market,
      saved results/payouts and fresh endless/stage unlocks. Test-only
      lookahead cannot mutate the live food, Lunchboxes, pests or body.
      Snapshots and restores every save it touches, including cached unlocks.
- [x] Host `tests/store_test.gd` demanded a free default for every item kind,
      though `GameManifest.store_slots` documents `empty_title` as the
      alternative. Milestone 7 changed the test so only a kind some slot must
      always wear needs a default; it passes on 4.7.2.
- [x] **Exit:** `store_test`, `gallery_test`, `share_card_test`,
      `saves_test` and `single_game_test` pass with `--game=all`.
      Confirmed on 4.7.2 with all games in the catalog. Manual inspection of
      the store, plinth and gallery remains separate from this test gate.

## Milestone 8 — Polish and integration (§8, §9.5, §11) — v1 ships

- [x] Touch layout pass: buttons ≥ 44 physical px, multi-finger, clear of the
      ground line; the one-time Auto-run hint on touchscreens; icons on
      phones, key hints without touch controls. Finger/mouse handoffs,
      cancellation and drag cannot invent sprint taps or duplicate Jump.
      The saved tip can be accepted or dismissed across a restart.
- [x] Automated accessibility sweep against §9.5: model poses and effects,
      caption coverage, accessible touch names/targets and responsive HUD.
- [ ] Detailed manual accessibility/playtesting evidence on physical
      devices and speakers. Not inferred from the owner's general approval.
- [x] `tests/dolce_controls_test.gd` — real routed touch events, double taps,
      handoffs, cancellation, drag, hidden/paused inputs and mouse emulation.
- [x] `tests/dolce_view_test.gd` *(window)* — actual rendered pixels and
      whole-body bounds on 320×568, 390×844, 568×320, 844×390, 768×1024,
      1280×720 and 3440×1440; touch targets clear of the ground, counters,
      tips and captions. Also long scores, UI scale 1.4, Full, 10,000 burgers,
      and jump/fall framing with motion enabled.
- [x] `project.godot`: `config/name.dolces_adventure`,
      `custom_user_dir_name.dolces_adventure` (after §13.6),
      `config/icon.dolces_adventure`,
      `dcs/build/single_game_id.dolces_adventure`,
      `[share] stats_urls/dolces_adventure` (≤ 42 bytes), plus the standalone
      `1.0.0` version override. Default/collection pins remain unchanged.
- [x] `export_presets.cfg`: Windows x86_64 standalone with the feature tag,
      external PCK, and all other games/tests/tools excluded. All existing
      non-collection presets exclude Dolce; collection still includes it.
- [x] Host `.gitmodules` and submodule registration use `dolces_adventure`.
- [ ] Commit game changes, then the host changes and updated gitlink.
      The owner committed the original v1 game snapshot as `2840893`.
      New playthrough QA and host release-integration changes remain
      unstaged/uncommitted; pre-existing staged registration is preserved.
      Deferred at the owner's request for local release finalization.
- [x] Root `AGENTS.md`: games table, submodules, options files, test table,
      feature tags, blurb. Update `godot-base/README.md` if it lists games.
- [x] Write the folder `README.md`: play, controls/assists, host launch,
      isolated tests, art generation, records and open release decisions.
- [x] Feature-specific release version appears in the actual title footer:
      generic `StudioInfo.version()` override resolution, covered by the
      host `main_menu_test.gd`. The collection stays at its existing version.
- [x] Export **Windows - Dolce's Adventure (standalone)** and the collection
      with official 4.7.2 Windows x86_64 templates. The matching archive's
      official SHA-256 was verified; templates are in the isolated test profile.
- [x] Both exact release PCKs pass headless and real-window smoke checks:
      feature tags, catalog, actual user directories, title/footer, icon,
      tutorial/poster, previews/gallery/share resources and real gameplay.
      Standalone has only Dolce and no tests/tools; collection keeps ten games.
- [x] Both native release EXEs open responsive Windows graphics windows and
      exit 0 without runtime diagnostics. Dolce's PE product/version metadata
      matches the approved title and `1.0.0.0`.
- [x] Package the verified EXE/PCK pair:
      `build/dolces_adventure/DolcesAdventure-v1.0.0-windows-x86_64.zip`
      (~46 MB). Unsigned; signing/publication are separate release work.
- [x] Finalize the local handoff: companion `RELEASE-NOTES.txt` and
      `SHA256SUMS.txt` in the ignored release directory. The ZIP is unchanged;
      both entries match the native files, v1 PE metadata is correct, and
      final standalone native/exact-PCK smokes pass with isolated saves.
- [x] Owner gameplay acceptance for v1. Local-only finalization is approved;
      publication, signing, tags and commits are not part of this phase.
- [x] **Test gate:** all framework suites + all game suites exit 0 with
      `--game=all`; window suites run without `--headless`.
      Godot 4.7.2: 13 game + 15 framework suites pass. This is not the
      detailed manual QA matrix: device/speaker measurements and human
      full-course evidence are unreported. General owner gameplay acceptance
      is recorded above. Full automated input courses and export checks pass.
      Local finalization changes no production code or assets, so the verified
      binaries/video stay valid.

---

## V2 phase 1 — Daily UTC (§5.6)

- [x] `daily_run.gd`: capture UTC date, stable epoch-day seed and
      `daily_YYYY-MM-DD` record section once at round creation.
- [x] Always-open **Daily UTC - Backyard** in the shared level picker,
      reusing Backyard art and the unchanged endless stream/ramp.
- [x] Preserve all v1 physics, authored chunks, the fairness validator,
      fixed stage lists, assists, achievement keys and payout rules.
- [x] Same-day Play Again repeats the course without an attempt cap.
      Midnight leaves an active run/results/share on its starting date;
      the next attempt uses the new date and separate bests.
- [x] HUD/date, daily-distance results, best/seed stats and share payload.
      The full UTC date stays visible at 14 physical pixels on small phones.
      A replay seed override is explicitly ignored in Daily UTC.
- [x] Focused stream/record tests cover UTC boundaries, deterministic
      courses, daily maxima, older dates and unchanged v1 records.
- [x] Real-scene daily retries and 2,257 m Backyard-to-Market run on
      2026-11-01 / seed 020758; actual death, Treats, reach achievements with
      Kind pits, preserved v1 bests and midnight result routing.
- [x] **Test gate:** 13 game + 15 framework suites pass on Godot 4.7.2,
      plus the real-window full scene with `--dolce-seed=999999` proving
      daily replay protection. Date-readability and affected framework UI
      tests pass. Lint's three existing diagnostics are unchanged.
- [x] Document source versus the frozen v1 EXE/PCK/ZIP; do not overwrite
      v1 artifacts, commit, tag, sign or publish.
- [ ] Owner playtest/acceptance and a separately versioned v2 release.
      Automated rendered phones are not physical-device measurements.

## Remaining v2 candidates (§12; not in this phase)

- [ ] Slopes (model + validator).
- [ ] Hot-seat turns, P1/P2/P3, best distance wins (reuse Cube Trials'
      hand-off flow).
- [ ] Chase camera.
- [ ] A light music bed through `AudioManager`.
