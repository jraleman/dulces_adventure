# Dolce's Adventure

**v1.0.0 Windows release candidate:** implementation and automated release
checks pass on Godot 4.7.2. Human/device QA remains open.

An original solo side-scrolling platformer for a small dog with a big appetite.
Run, jump, bonk pests and eat burgers through the Backyard, Park, Main Street,
Boardwalk Pier and Night Market.

This is a **Godot 4.7 game folder**, not a standalone Godot project. It lives at
`godot-base\games\dolces_adventure`; the DeskCanSaw host supplies the project,
menus, settings, pause, results, store, gallery, achievements and share cards.

## Playing

**Endless runs** assemble seeded, hand-authored chunks. Distance counts from
your chosen start point; later starts unlock through distance achievements.
The course seed appears in results so a run can be replayed.

**Five fixed stages**, one per biome, are roughly 300 m long. Reach the
food-truck goal to clear a stage and unlock the next. Clear time is the
headline; the clock uses model time, so the game-speed assist does not improve
a saved time.

Dolce starts with three hearts. Stomp pests from above, but jump over pointed
gnome hats and hot-sauce drops. Burgers score points; every hundredth restores
a heart. A Big Burger makes her Full, absorbing one pest hit. A Golden Bone
restores a heart. Pits cost a heart unless Kind pits protects a Full Dolce.
Losing the last heart ends the attempt.

Runs pay Treats for cosmetic collars, hats and bandanas: score / 100 plus
three for playing, plus twenty for clearing a stage. Outfits appear in the
run, setup preview, gallery and share portrait.

## Controls and assists

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Move | A / D, left / right arrows | Left stick / D-pad | Left / right icons |
| Jump | Space, up arrow | A | Hold Jump for height; tap for a hop |
| Sprint | Shift | X / right trigger | Tap Right, then tap again and hold |
| Pause | Escape | Start | Pause icon |

A, D, Space and Shift are rebindable in Settings. Arrows and gamepad controls
are fixed extras, approved for v1. Independent fingers can hold Right and Jump; lifting one
finger, canceling a gesture or opening pause cannot leave another action stuck.

On a touchscreen, a one-time **Auto-run** tip offers one-thumb play. Accepting
it enables the saved assist; **Not now** or starting to play dismisses it.
Auto-run stays off unless enabled, and Left then brakes to a walk.

Settings also offers **Kind pits**, **Game speed** (70-100%, next run) and
**Day / night cycle**. Assists never block achievements. Reduced motion,
intense-effects controls and audio captions use the host's accessibility
settings. Touch targets stay at least 44 physical pixels, with room kept
clear for the counters and active captions.

## Running in the host

From this game folder, in PowerShell:

```powershell
Set-Location ..\..
$godot = 'C:\path\to\Godot_v4.7-stable_win64.exe'
Start-Process -FilePath $godot -ArgumentList @(
    '--path', '.', '--', '--game=dolces_adventure'
) -Wait
```

Replace `$godot` with your executable. To replay an endless course, add
`'--dolce-seed=42'` after the game argument.

## Tests

Run suites **one at a time** from `godot-base`. A real run can write progress;
use an isolated profile even though the scene and view suites restore their
save snapshots. On Windows, set `APPDATA` before starting Godot; on Linux,
set `XDG_DATA_HOME`.

```powershell
$env:APPDATA = Join-Path $env:TEMP ('dolce-tests-' + [guid]::NewGuid())
$env:LOCALAPPDATA = $env:APPDATA
New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
$tests = Get-ChildItem .\games\dolces_adventure\tests -Filter '*_test.gd' -File |
    Where-Object Name -ne 'dolce_view_test.gd' | Sort-Object Name
foreach ($test in $tests) {
    $process = Start-Process -FilePath $godot -ArgumentList @(
        '--headless', '--path', '.', '--script',
        "res://games/dolces_adventure/tests/$($test.Name)", '--', '--game=all'
    ) -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "$($test.Name) failed." }
}
```

The thirteenth suite, `dolce_view_test.gd`, needs a real window: omit
`--headless`. It checks rendered visibility, portrait/landscape phones,
tablet, ultrawide, large UI, long scores, Full, captions and airborne poses.
It can save screenshots with `--dolce-view-captures=<absolute directory>`.
Run the host's fifteen framework suites with `--game=all` before closing a
milestone. Exact suite commands are in [AGENTS.md](AGENTS.md).

The current regression pass used **Godot 4.7.2**: all thirteen game suites and
fifteen framework suites exited 0. Two host suites (`lives_mode_test` and
`single_game_test`) reported unrelated shared-UI and Chicken Pit audio
resources in use at shutdown.
The scene suite drives all of Stage 1 through input actions and checks all
five goal/results/payout paths and sequential unlocks from fresh progression.
Later stages' complete geometry is validated, but their scene clear checks
start near the goal; they are not full-course playthroughs.

## Release configuration

The host's **Windows - Dolce's Adventure (standalone)** preset builds v1.0.0
with the `dolces_adventure` feature tag and the approved permanent save
directory **`DeskCanSaw Games/Dolce's Adventure`**. It packages only this
game, excluding tests and development tools. Keep `DolcesAdventure.exe`
and `DolcesAdventure.pck` together in `build\dolces_adventure`.
The collection preset includes Dolce without changing its own save directory.
Source `--game=dolces_adventure` launches still use the host's development
profile; a command-line catalog selection is not a save-directory override.

The verified distribution is
`build\dolces_adventure\DolcesAdventure-v1.0.0-windows-x86_64.zip`
(about 46 MB). Extract both files together. Both native release EXEs booted
in real Windows graphics windows without errors; both exact release PCKs
passed headless and rendered checks for catalog contents, actual save paths,
branding/version, required media and gameplay. Standalone includes only Dolce,
with tests/tools excluded; collection retains all ten playable games.
The EXE is **unsigned**; signing, publication and game/host commits are not
performed by these build checks.

From `godot-base`, with matching 4.7.2 Windows export templates installed:

```powershell
$process = Start-Process -FilePath $godot -ArgumentList (
    '--headless --path . --export-release "Windows - Dolce''s Adventure (standalone)"'
) -NoNewWindow -Wait -PassThru
if ($process.ExitCode -ne 0) { throw 'Dolce export failed.' }
```

## Art, saves and remaining QA

Models, scenery and synthesized cues are original and procedural. The model
is node-free at 120 Hz; the 3D view cannot change physics. New chunks must pass
the fairness validator, not loosen it.

Best distance, score and burger totals live in `user://dolces_adventure.cfg`,
with the best `time_ms` per stage. Records merge and never regress. The host
stores outfits, achievements and settings separately; the touch-tip flag is
in `settings.cfg`, not an extra Settings option.

After changing biome art or gates, rerun `tools\capture_art.gd`. After changing
Stage 1, the HUD or tutorial captions, run the host's recorder:

```powershell
.\tools\record_tutorials.ps1 -Godot $godot -Games dolces_adventure -Variants solo -Quality 6
```

The walkthrough is a real 27-second Stage 1 run, with a poster at six seconds.
See [DESIGN.md](DESIGN.md) for the rules and [TODO.md](TODO.md) for progress.
The owner approved the current procedural art for v1; reference photos are
optional later work. Human jump-feel, physical-device and speaker playtests
remain separate from the automated regression/export checks. Full clears of
Stages 2-5 and an endless Backyard-to-Market run still need human verification.