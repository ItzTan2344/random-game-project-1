# Balance Playtest Report: Gemini 2 vs Gemini 1

## Tournament Overview
- **Matchup**: Gemini 2 (`tide_caller`, `tide_warden`, `forge_sentinel`, `forge_bastion`, `storm_courier`, `void_fox`) vs Gemini 1 (`tide_caller`, `tide_warden`, `storm_courier`, `storm_lancer`, `ember_ranger`, `void_fox`).
- **Format**: 240 headless matches (120 seed pairs, alternate sides A/B per seed to eliminate side bias).
- **Match Win Rate**: Gemini 2: **55.0%** (132/240) | Gemini 1: **45.0%** (108/240).
- **Side Advantage (Speed-Tie Edge)**: Side A: **67.5%** (162/240) | Side B: **32.5%** (78/240).
- **Pacing**: Avg rounds **9.62** (Min 6, Max 13). Battle Frenzy (round 15+) reached: **0** (0.0%).

## Troop Performance & Synergies
- **Gemini 2 MVPs**:
  - `storm_courier`: 86.3% pick, 59.9% WR. High speed (71), S1 energy generation (+2), and entry passive speed buff dominate tempo.
  - `tide_caller`: 69.2% pick, 56.0% WR. Entry shield (10% max HP) and S3 AoE speed debuff provide massive team survivability.
  - `void_fox`: 88.3% pick, 55.2% WR. Entry -15% AoE enemy speed debuff consistently decides round 1 turn order.
  - `tide_warden`: 78.8% pick, 53.4% WR. S3 `Glacial Prison` (80% chance -25% SPE) locks down enemy rotations.
  - `forge_sentinel`: 74.6% pick, 50.3% WR. S2 `Overclock` (+20% SPE team) and S3 `Time Lock` (80% stun) act as key disruption.
- **Underperformers**:
  - `forge_bastion`: Picked only 2.9% (7/240). Speed (57) is too low for `AIController.choose_draft` speed-weighting (`d.speed * 2.0`).
  - `ember_ranger` (Gemini 1): 63.8% pick, only 37.3% WR. Fragile (260 HP, 51 DEF), easily focused down before using S3/overdrive.

## Degenerate Strategies & Balance Observations
1. **Speed-Tie Lower UID Bias**: `CombatEngine._faster` breaks speed ties using `a.uid < b.uid`. Side A troops receive lower UIDs (1-4 vs 5-8), granting an overwhelming 67.5% win rate when speed ties occur (which is very frequent at 71 base SPE).
2. **Pivot & Energy Snowballing**: Fast pivots with entry passives (`storm_courier`, `void_fox`, `tide_caller`) cycle repeatedly, stacking team buffs/enemy debuffs and filling Team Energy rapidly (374 `REDUCE_COOLDOWN` overdrives used vs only 8 `BONUS_DAMAGE` and 6 `ACT_FIRST`).
3. **Slow Tanker Exclusion**: Tankers with <60 SPE are systematically ignored by AI draft scoring, making speed control the only viable meta.

## Concrete Balance Recommendations
1. `src/server/CombatEngine.gd` - `_faster`: Replace deterministic `return a.uid < b.uid` with seeded tiebreaker (`rng.randf() < 0.5` or alternating team priority) to eliminate the 67.5% Side A bias.
2. `src/data/troops/storm_courier.tres` (or `tools/build_roster.gd:195`) - `S1.energy_gain`: `2` -> `1` (prevents early Overdrive spam).
3. `src/data/troops/void_fox.tres` (or `tools/build_roster.gd:262`) - `Passive.magnitude`: `-0.15` -> `-0.10` (softens entry speed swing).
4. `src/data/troops/ember_ranger.tres` (or `tools/build_roster.gd:209`) - `max_hp`: `260` -> `280`, `defense`: `51` -> `58` (prevents round-1 blowouts).
5. `src/server/AIController.gd:19` - `choose_draft` score formula: `d.speed * 2.0` -> `d.speed * 1.2` (allows Tankers like Bastion/Colossus to be drafted).
6. `tools/build_roster.gd:214` - `Piercing Shot` `overdrive_cost`: `15` -> `11` (allows ACT_FIRST to actually be cast).
