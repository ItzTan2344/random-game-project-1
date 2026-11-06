# random_project

Godot 4.7.2 project (Forward+, Jolt physics). Game: **ET**, a 2v2 turn-based battler (Epic Seven CR/skills + VGC bring-6-pick-4).
Main scene: `res://src/client/main.tscn`.

- Godot console exe: `D:\Game\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
  (`Godot_v4.7.2-stable_win64.exe` is a **folder**, not the binary.)
- Headless check: `& "<exe>" --headless --path D:\Game\random_project --quit`
  Use `--import` for an import/scan pass. Run it after adding or renaming a `class_name` script (and on a fresh clone,
  since `.godot/` is gitignored), or `-s` scripts can't resolve global classes.

## ET layout & commands
- `src/core/`: shared types (`CombatTypes.gd`), math, runtime state (`TroopInstance`, `TeamState`, `CombatState`), events/actions.
- `src/data/`: `TroopData`/`SkillData`/`EffectData` resources, `TroopRegistry`, and the roster in `troops/*.tres`.
- `src/server/`: `CombatEngine` (pure, deterministic, zero-yield), `LocalServer` (intents, ack/timeout), `AIController`.
- `src/client/`: `BattleClient` (log queue and playback), `BattleUI` + `TroopCard` (built in code, no hand-written .tscn).
- Tests: `& "<exe>" --headless --path D:\Game\random_project -s res://tests/combat_simulation_test.gd` (exit 0 = pass; prints balance stats).
- Smoke-run the real UI with AI on both sides: `& "<exe>" --headless --path D:\Game\random_project -- --autoplay`.
- Roster authoring: `tools/build_roster.gd` regenerates `troops/*.tres`, which overwrites Inspector edits.

## Subagent notes (probed 2026-11-06)

Delegate via T3 `delegate_task`. Both delegates read files, ran PowerShell/git, and launched Godot headless successfully.
None of them can render a viewport or view .glb/.obj models, and none can play-test visually.

### Gemini 3.8 Flash — `providerInstanceId: antigravity`, `model: gemini-3.8-flash`, `options: {thinking_level: low}`
- Tools: `run_command` (PowerShell), `view_file`, `write_to_file`, `replace_file_content`, `search_web`, `read_url_content`,
  `generate_image` (2D textures/concept art), `ask_question`, native subagents/workflows, plus the full t3-code MCP server
  (preview/browser, delegate_task, threads, PR linking).
- Can view raster/SVG images. Fast. Writes clean typed GDScript (uses `get_gravity()`, custom input actions).
- Best for: GDScript/.tscn/shader work, looking up Godot docs, 2D placeholder textures, parallel grunt work.
- Caveat: it can spawn its own subagents and threads, so tell it not to when you want a contained task.
- Other Antigravity accounts (`antigravity_antigravity_2344`, `antigravity_antigravity_adu`) offer the same models; use them as fallbacks when quota runs out.

### Muse (Muse Spark) — `providerInstanceId: acpRegistry_muse_ai`, `model: default`
- Only 5 tools: `list_dir`, `read_file`, `write_file`, `edit_file` (writes are approval-gated), `run_command` (PowerShell).
- No web, no image viewing (SVG is read as text only), no generation, no subagents. It makes one tool call per turn.
- Diligent: it found the wrong Godot path on its own. Its GDScript is OK but terse (`;`-joined lines, `ui_*` actions).
- Best for: small, contained file edits, headless validation runs, second-opinion reviews.
- The `muse` (Muse Code) provider instance is disabled in T3.
