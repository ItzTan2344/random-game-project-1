# random_project

Godot 4.7.2 project (Forward+, Jolt physics). Game: **ET**, a 2v2 turn-based battler (Epic Seven CR/skills + VGC bring-6-pick-4).
Main scene: `res://src/client/main.tscn`. Windows 11, PowerShell.

- Godot console exe: `D:\Game\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
  (`Godot_v4.7.2-stable_win64.exe` is a **folder**, not the binary.)
- Headless check: `& "<exe>" --headless --path D:\Game\random_project --quit`
  Use `--import` for an import/scan pass. Run it after adding or renaming a `class_name` script (and on a fresh clone,
  since `.godot/` is gitignored), or `-s` scripts can't resolve global classes.

## Layout & commands
- `src/core/`: shared types (`CombatTypes.gd`), math, runtime state (`TroopInstance`, `TeamState`, `CombatState`), events/actions.
- `src/data/`: `TroopData`/`SkillData`/`EffectData` resources, `TroopRegistry`, and the roster in `troops/*.tres`.
- `src/server/`: `CombatEngine` (pure, deterministic, zero-yield), `LocalServer` (intents, ack/timeout), `AIController`.
- `src/client/`: `BattleClient` (log queue and playback), `BattleUI` + `TroopCard` (built in code, no hand-written .tscn).
- Tests: `& "<exe>" --headless --path D:\Game\random_project -s res://tests/combat_simulation_test.gd` (exit 0 = pass; prints balance stats).
- Smoke-run the real UI with AI on both sides: `& "<exe>" --headless --path D:\Game\random_project -- --autoplay`.
- Roster authoring: `tools/build_roster.gd` regenerates `troops/*.tres`, which overwrites Inspector edits.

## Code-built models
- Avatars are GDScript `extends Node3D` scripts in `src/client/avatars/`, built from `BoxMesh` in `_ready()`.
  Style: voxel/blocky, indie low-poly, **not realistic**. Feet on y=0, facing +Z, roughly 1.5–3 units tall.
- Preview (needs a window, NOT `--headless`):
  `& "<exe>" --path D:\Game\random_project -s res://tools/render_model.gd -- <res://script.gd> <out.png>`
- Cost check: `-s res://tools/bench_models.gd -- <res://a.gd> <res://b.gd> ...` (build time, parts, draw calls, materials).
- Keep it lean: share one material per colour, keep part counts low (~40–60 boxes per regular troop), and merge static
  boxes into one mesh when performance matters. Moving parts (wings, tail) stay separate pivots.

## Rules
- Typed GDScript, one statement per line, no warnings.
- Stay inside the files your task names. Don't commit or push unless asked.
- Don't spawn subagents or new threads unless your task says to.
