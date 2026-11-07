# Versus Playtest Report: Gemini 1 vs Gemini 2

## 1. Head-to-Head Results (500 Matches, Seeds 50000–50249)
- **Squad WR**: Gemini 2: **61.2%** (306/500) | Gemini 1: **38.8%** (194/500).
- **Side WR**: Side A: **66.8%** (334/500) | Side B: **33.2%** (166/500).
- **Pacing**: Avg rounds **9.71** (Min 7, Max 13). Battle Frenzy (>15): **0** (0.0%).
- **Key Pick & WR**:
  - G2: `storm_courier` (87.4% pick, 64.3% WR), `void_fox` (85.6%, 61.0% WR), `forge_sentinel` (77.8%, 58.6% WR), `forge_bastion` (2.0%, 40.0% WR).
  - G1: `storm_courier` (80.8% pick, 39.1% WR), `void_fox` (73.0%, 41.6% WR), `ember_ranger` (57.8%, 30.1% WR, 289 deaths / 289 picks).

## 2. Verdict on Side A Bias: Real Engine Bias
The Side A advantage is a **real structural bias in the engine**, NOT an artifact of test setup:
- Both tests alternated sides symmetrically across paired seeds.
- When swapped, both squads gain an identical **+33.6% win rate** on Side A:
  - G1: 55.6% on Side A vs 22.0% on Side B.
  - G2: 78.0% on Side A vs 44.4% on Side B.
- **Root Cause**: `CombatEngine._faster` breaks speed ties with `return a.uid < b.uid`. Side A troops always receive UIDs 1–4; Side B receives 5–8. In mirror/fast metas where both draft SPE 71 leads (`storm_courier`, `void_fox`), 1,408 speed ties occurred across 500 matches, and Side A acted first on 100% of them. In `playtest_sim.gd`, random squads lacked speed parity, masking the issue at 52.8%.

## 3. Balance Recommendations Comparison
The recommendations from `report_gemini.md` and `report_gemini2.md` **do not contradict each other**; they are fully complementary:
- Both agree on curbing speed snowballing (`storm_courier` S1 energy 2->1, `void_fox` Ambush -15%->-10%).
- Both identify Tanker neglect (`forge_bastion` ~2% pick rate) and glass-cannon fragility (`ember_ranger`/`aggro` 100% death rate). Gemini 1 suggested base stat/skill buffs; Gemini 2 targeted AI draft scoring.

## 4. Prioritized Balance Action Plan
1. **P0 (Fairness)** `src/server/CombatEngine.gd` (`_faster`): `return a.uid < b.uid` -> `return rng.randf() < 0.5` to eliminate the ~34% Side A speed-tie bias.
2. **P1 (Meta Diversity)** `src/server/AIController.gd` (`choose_draft`): `d.speed * 2.0` -> `d.speed * 1.2` to prevent AI from ignoring Tankers (<60 SPE).
3. **P2 (Overdrive Loop)** `tools/build_roster.gd` (`storm_courier` S1 `energy_gain`): `2` -> `1`.
4. **P2 (Speed Control)** `tools/build_roster.gd` (`void_fox` `Ambush` `magnitude`): `-0.15` -> `-0.10`.
5. **P3 (DPS Survivability)** `tools/build_roster.gd` (`ember_ranger`): `max_hp` `260` -> `280`, `defense` `51` -> `58`, `Piercing Shot` `overdrive_cost` `15` -> `11`.
6. **P3 (Tanker Viability)** `tools/build_roster.gd` (`forge_bastion`): `speed` `57` -> `62`, `Shield Bash` `hp_scaling` `0.10` -> `0.14`.
