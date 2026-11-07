# Playtest Report: Gemini Roster Balance Analysis

## 1. Match Summary & Formats
- Matches: 400 (alternating sides, seeds 30000–30399)
- Squad Gemini: tide_caller, tide_warden, storm_courier, storm_lancer, ember_ranger, void_fox
- Opponent: RandomSquad (squad_muse.json absent after polling)
- Win Rates: Gemini 311/400 (77.8%) vs RandomSquad 89/400 (22.3%)
- Side Symmetry: Side A (First) 211 wins (52.8%) | Side B (Second) 189 wins (47.3%)
- Pacing: Avg rounds 9.03 (min 6, max 15). Frenzy (>15 rounds): 0 matches (0.0%).

## 2. Performance Breakdown
### Overperforming
- `void_fox`: Pick% 75.5%, Win% 80.8%, Avg Dmg 381.7, Avg KOs 1.37. Fastest tier (SPE 71) combined with Ambush (-15% team SPE on switch-in) and Vanishing Strike self-switch.
- `tide_warden`: Pick% 70.3%, Win% 80.1%, Avg Dmg 348.4, Avg KOs 1.33, Deaths 71. Permafrost Heart auto-cleanse on debuff + Glacial Prison AOE slow shuts down counterplay.
- `storm_courier`: Pick% 74.8%, Win% 75.6%, Avg Dmg 370.1. Generates 2 Team Energy on S1 and switch-in, breaking the intended energy economy.
- Synergies: Tide (+10% EFF) guarantees CC landing; Storm (+5% SPE) preserves first-strike momentum.

### Underperforming
- `ember_aggro`: Pick% 69.1%, Win% 20.2%, Avg Dmg 50.7, Avg KOs 0.12. Fragile 245 HP / 48 DEF gets KO'd before acting.
- `grove_keeper`: Pick% 37.0%, Win% 12.8%, Avg Dmg 149.5. S1 4% heal is negligible; S3 5-turn cooldown is too slow.
- `storm_herald`: Pick% 76.8%, Win% 11.6%, Avg Dmg 204.4. Vulnerable stat profile despite support kit.
- `forge_bastion`: Pick% 10.1% (rarely drafted by AI due to 57 SPE and 73 ATK), Win% 14.3%.

## 3. Degenerate Strategies & Stall/Snowball Cases
- **Speed-Debuff Chain Swapping**: Cycling `void_fox` and `storm_courier` repeatedly activates entry passives (-15% enemy SPE, +20% self SPE), permanently denying turns to slow foes.
- **Energy Ramp Acceleration**: Troops with +2 energy generation on S1/passives enable round 2 Overdrive nukes and cooldown resets, snowballing before slower ramp comps stabilize.

## 4. Concrete Numeric Balance Adjustments
- `tools/build_roster.gd` (`void_fox`): `stats[1]` (attack) 111 -> 98, `Ambush` `magnitude` -0.15 -> -0.10
- `tools/build_roster.gd` (`storm_courier`): `Quick Jab` `energy_gain` 2 -> 1, `Slipstream Entry` `magnitude` 2.0 -> 1.0
- `tools/build_roster.gd` (`tide_warden`): `Glacial Prison` `attack_scaling` 0.85 -> 0.70, `chance` 0.8 -> 0.65
- `tools/build_roster.gd` (`ember_aggro`): `stats[0]` (max_hp) 245 -> 280, `stats[3]` (defense) 48 -> 56, `stats[5]` (speed) 68 -> 70
- `tools/build_roster.gd` (`grove_keeper`): `Thorn Lash` `magnitude` 0.04 -> 0.08, `Sanctuary Bloom` `cooldown` 5 -> 4
- `tools/build_roster.gd` (`forge_bastion`): `stats[5]` (speed) 57 -> 62, `Shield Bash` `hp_scaling` 0.10 -> 0.14
