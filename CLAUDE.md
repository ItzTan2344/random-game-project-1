@AGENTS.md

## Subagent notes (probed 2026-11-06)

Delegate via T3 `delegate_task`. Both delegates read files, ran PowerShell/git, and launched Godot successfully.
Neither can view .glb/.obj models or play-test visually; Gemini can view rendered PNG screenshots.

### Gemini 3.8 Flash — `providerInstanceId: antigravity`, `model: gemini-3.8-flash`, `options: {thinking_level: low}`
- Tools: `run_command` (PowerShell), `view_file`, `write_to_file`, `replace_file_content`, `search_web`, `read_url_content`,
  `generate_image` (2D textures/concept art), `ask_question`, native subagents/workflows, plus the full t3-code MCP server
  (preview/browser, delegate_task, threads, PR linking).
- Can view raster/SVG images. Writes clean typed GDScript (uses `get_gravity()`, custom input actions).
- Best for: GDScript/.tscn/shader work, looking up Godot docs, 2D placeholder textures, parallel grunt work.
- Modelling (2026-11-06 dragon contest, tied with Claude): most creative and distinct, but slow (~23 min) and heavy
  (186 boxes/draw calls vs Claude's 40). Use for hero/boss designs with a part cap; Claude does regular troops.
- Caveat: it can spawn its own subagents and threads, so tell it not to when you want a contained task.
- Other Antigravity accounts (`antigravity_antigravity_2344`, `antigravity_antigravity_adu`) offer the same models; use them as fallbacks when quota runs out.

### Muse (Muse Spark) — `providerInstanceId: acpRegistry_muse_ai`, `model: default`
- Only 5 tools: `list_dir`, `read_file`, `write_file`, `edit_file` (writes are approval-gated), `run_command` (PowerShell).
- No web, no image viewing (SVG is read as text only), no generation, no subagents. It makes one tool call per turn.
- Diligent: it found the wrong Godot path on its own. Its GDScript is OK but terse (`;`-joined lines, `ui_*` actions).
- Best for: small, contained file edits, headless validation runs, second-opinion reviews.
- **Not for modelling/art** (user's call after the 2026-11-06 dragon contest): its entry read as a copy of Claude's.
- The `muse` (Muse Code) provider instance is disabled in T3.
