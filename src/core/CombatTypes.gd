class_name CombatTypes
extends RefCounted
## Shared enums and balance constants for ET. Pure data: no state, no nodes.

enum Side { A = 0, B = 1 }
enum Phase { PREVIEW, TURN_START, ACTION_WAIT, RESOLUTION, TURN_END, CHECK_WIN, STANDBY, FINISHED }
enum Archetype { AGGRO, CONTROL, BRUISER, PIVOT }
enum SkillSlot { S1, S2, S3 }
enum TargetType { SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, SELF, ALL_ALLIES }
enum EffectTarget { SKILL_TARGETS, SELF, ALLIES, PARTNER, ENEMIES }
enum EffectKind { STAT_MOD, STUN, DOT, SHIELD, HEAL, CR_CHANGE, CLEANSE, ENERGY }
enum Stat { ATTACK, DEFENSE, SPEED, CRIT_CHANCE, EFFECTIVENESS, EFFECT_RESISTANCE }
enum Trigger { NONE, ON_SWITCH_IN, ON_ALLY_HIT, ON_DEBUFF_RECEIVED }
enum OverdriveKind { NONE, IGNORE_RESISTANCE, REDUCE_COOLDOWN, EXTRA_TURN, BONUS_DAMAGE }
enum ActionKind { SKILL, SWITCH }
enum EventType {
	PREVIEW_STARTED, DRAFT_LOCKED, BATTLE_STARTED, TROOP_ENTERED, TIMELINE_ADVANCED,
	CYCLE_ADVANCED, FRENZY_CHANGED, TURN_STARTED, ACTION_REQUESTED, TURN_SKIPPED,
	SKILL_USED, OVERDRIVE_ACTIVATED, DAMAGE, HEAL, EFFECT_APPLIED, EFFECT_RESISTED,
	EFFECT_EXPIRED, CLEANSED, CR_CHANGED, ENERGY_CHANGED, DUAL_ATTACK, PASSIVE_TRIGGERED,
	SWITCHED, KO, EXTRA_TURN, TURN_ENDED, STANDBY_REQUESTED, REPLACED, BATTLE_ENDED,
	ACTION_REJECTED,
}

# --- Match format ---
const DRAFT_BRING: int = 6
const DRAFT_PICK: int = 4
const ACTIVE_SLOTS: int = 2
const DRAFT_SECONDS: float = 45.0

# --- Combat Readiness ---
const CR_MAX: float = 100.0
## Hard cap on CR gained or lost by one target from a single skill (anti speed-cleave).
const MAX_CR_PUSH: float = 30.0
## Hard cap on total Speed buff (+30%).
const MAX_SPEED_BUFF: float = 0.30
## One Turn Cycle = the time a 100-speed troop needs to fill 0 -> 100% CR.
const CYCLE_BASE_SPEED: float = 100.0
const EPSILON: float = 0.000001

# --- Switching ---
const SWITCH_ENTRY_CR: float = 50.0
const SWITCH_COOLDOWN_TURNS: int = 1
const SWITCH_ENERGY: int = 1

# --- Team Energy / Overdrive ---
const ENERGY_CAP: int = 20
const DUAL_ATTACK_CAP: float = 0.05

# --- Damage & stats ---
const DEFENSE_CONSTANT: float = 300.0
const STAT_MOD_MIN: float = -0.5
const STAT_MOD_MAX: float = 0.5

# --- Battle Frenzy (anti-stall) ---
const FRENZY_START_CYCLE: int = 15
const FRENZY_STEP: float = 0.05


static func other_side(side: int) -> int:
	return 1 - side
