class_name CombatEngine
extends RefCounted
## Authoritative, deterministic, zero-yield combat state machine.
## PREVIEW -> ACTION_WAIT (both sides pick an action for every active troop) -> RESOLUTION (Speed order) -> CHECK_WIN (-> STANDBY) -> ...
## Every public call runs synchronously until input is needed and returns the ordered event log.

var state: CombatState = CombatState.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _log: Array[CombatEvent] = []
var _trigger_queue: Array[Dictionary] = []
var _next_uid: int = 1


var _archetypes: Dictionary[StringName, ArchetypeData] = ArchetypeRegistry.load_all()


func _init(seed_value: int = 0) -> void:
	rng.seed = seed_value


# =====================================================================
# Public API (intents)
# =====================================================================

func start_preview(squad_a: Array[TroopData], squad_b: Array[TroopData]) -> Array[CombatEvent]:
	if squad_a.size() != CombatTypes.DRAFT_BRING or squad_b.size() != CombatTypes.DRAFT_BRING:
		return _reject(-1, "Each side must bring exactly %d troops." % CombatTypes.DRAFT_BRING)
	state = CombatState.new()
	_next_uid = 1
	state.teams[0].squad.assign(squad_a)
	state.teams[1].squad.assign(squad_b)
	state.phase = CombatTypes.Phase.PREVIEW
	_emit(CombatTypes.EventType.PREVIEW_STARTED)
	return _flush()


## `picks`: 4 indices into the brought squad. The first two lead (Active), the last two are the bench.
func submit_draft(side: int, picks: Array[int]) -> Array[CombatEvent]:
	if state.phase != CombatTypes.Phase.PREVIEW:
		return _reject(side, "Draft is closed.")
	if side < 0 or side > 1:
		return _reject(side, "Invalid side.")
	var team: TeamState = state.team(side)
	if team.locked:
		return _reject(side, "Draft already locked.")
	var err: String = _validate_picks(picks, team.squad.size())
	if err != "":
		return _reject(side, err)
	team.picks = picks.duplicate()
	team.locked = true
	_emit(CombatTypes.EventType.DRAFT_LOCKED, -1, -1, 0.0, {"side": side})
	if state.teams[0].locked and state.teams[1].locked:
		_start_battle()
	return _flush()


## `actions`: troop uid -> CombatAction, one per non-stunned living active of `side`. Locks the side;
## once both sides are locked the round resolves in Speed order.
func submit_actions(side: int, actions: Dictionary) -> Array[CombatEvent]:
	if state.phase != CombatTypes.Phase.ACTION_WAIT:
		return _reject(side, "Not waiting for actions.")
	if side < 0 or side > 1:
		return _reject(side, "Invalid side.")
	var team: TeamState = state.team(side)
	if team.actions_locked:
		return _reject(side, "Actions already locked.")
	var err: String = validate_actions(side, actions)
	if err != "":
		return _reject(side, err)
	team.actions = actions.duplicate()
	team.actions_locked = true
	_emit(CombatTypes.EventType.ACTIONS_LOCKED, -1, -1, 0.0, {"side": side})
	if state.team(0).actions_locked and state.team(1).actions_locked:
		_resolve_round()
		_advance()
	return _flush()


## Concede: the other side wins immediately.
func forfeit(side: int) -> Array[CombatEvent]:
	if state.phase == CombatTypes.Phase.FINISHED or side < 0 or side > 1:
		return _reject(side, "Nothing to forfeit.")
	state.winner = CombatTypes.other_side(side)
	state.phase = CombatTypes.Phase.FINISHED
	_emit(CombatTypes.EventType.BATTLE_ENDED, -1, -1, float(state.winner), {"winner": state.winner, "cycle": state.cycle, "turns": state.turn_count})
	return _flush()


func submit_replacement(side: int, slot: int, bench_index: int) -> Array[CombatEvent]:
	if state.phase != CombatTypes.Phase.STANDBY:
		return _reject(side, "No replacement is pending.")
	if side < 0 or side > 1:
		return _reject(side, "Invalid side.")
	var team: TeamState = state.team(side)
	if not team.pending_slots.has(slot):
		return _reject(side, "No replacement needed for that slot.")
	if not team.is_bench_ready(bench_index):
		return _reject(side, "Invalid bench troop.")
	var fallen: TroopInstance = team.active[slot]
	var incoming: TroopInstance = team.bench[bench_index]
	team.active[slot] = incoming
	team.bench[bench_index] = fallen
	team.pending_slots.erase(slot)
	_emit(CombatTypes.EventType.REPLACED, incoming.uid, fallen.uid if fallen != null else -1, float(slot), {"side": side, "slot": slot, "bench_index": bench_index, "name": incoming.data.display_name})
	_enter_field(incoming, slot)
	_process_triggers()
	if state.teams[0].pending_slots.is_empty() and state.teams[1].pending_slots.is_empty():
		_advance()
	return _flush()


# =====================================================================
# Queries (used by AI, UI snapshot, and validation)
# =====================================================================

## Troops of `side` that must be given an action this round (stunned ones lose theirs).
func acting_troops(side: int) -> Array[TroopInstance]:
	var out: Array[TroopInstance] = []
	for t in state.actives(side):
		if not t.is_stunned():
			out.append(t)
	return out


func validate_actions(side: int, actions: Dictionary) -> String:
	var team: TeamState = state.team(side)
	var need: Array[TroopInstance] = acting_troops(side)
	if actions.size() != need.size():
		return "Choose an action for every active troop."
	var energy: int = team.energy
	var benches: Array[int] = []
	for t in need:
		var action: CombatAction = actions.get(t.uid) as CombatAction
		if action == null:
			return "Choose an action for every active troop."
		var err: String = validate_action(t, action)
		if err != "":
			return err
		if action.kind == CombatTypes.ActionKind.SKILL and action.overdrive:
			energy -= t.data.skills[action.skill_index].overdrive_cost
			if energy < 0:
				return "Not enough Team Energy."
		var switching: bool = action.kind == CombatTypes.ActionKind.SWITCH or t.data.skills[action.skill_index].self_switch_after
		if switching and action.bench_index != -1:
			if benches.has(action.bench_index):
				return "Both troops can't switch to the same bench troop."
			benches.append(action.bench_index)
	return ""


func validate_action(actor: TroopInstance, action: CombatAction) -> String:
	var team: TeamState = state.team(actor.side)
	if action.kind == CombatTypes.ActionKind.SWITCH:
		if not can_switch(actor):
			return "Switch unavailable (slot cooldown or empty bench)."
		if not team.is_bench_ready(action.bench_index):
			return "Invalid bench troop."
		return ""
	if action.skill_index < 0 or action.skill_index >= actor.data.skills.size():
		return "Invalid skill."
	var skill: SkillData = actor.data.skills[action.skill_index]
	if skill.is_passive:
		return "Passive skills cannot be cast."
	if actor.cooldowns[action.skill_index] > 0:
		return "Skill is on cooldown."
	if skill.needs_target() and not valid_targets(actor, action.skill_index).has(action.target_uid):
		return "Invalid target."
	if action.overdrive:
		if skill.overdrive_kind == CombatTypes.OverdriveKind.NONE:
			return "Skill has no Overdrive."
		if team.energy < skill.overdrive_cost:
			return "Not enough Team Energy."
	if skill.self_switch_after and action.bench_index != -1 and not team.is_bench_ready(action.bench_index):
		return "Invalid bench troop."
	return ""


func can_switch(actor: TroopInstance) -> bool:
	var team: TeamState = state.team(actor.side)
	var slot: int = team.slot_of(actor)
	return slot >= 0 and team.slot_switch_cd[slot] == 0 and team.first_ready_bench() != -1


func legal_skills(actor: TroopInstance) -> Array[int]:
	var out: Array[int] = []
	for i in actor.data.skills.size():
		if validate_action(actor, CombatAction.cast(i, _default_target(actor, i))) == "":
			out.append(i)
	return out


func valid_targets(actor: TroopInstance, skill_index: int) -> Array[int]:
	var out: Array[int] = []
	var skill: SkillData = actor.data.skills[skill_index]
	var pool: Array[TroopInstance] = []
	if skill.target_type == CombatTypes.TargetType.SINGLE_ENEMY:
		pool = state.actives(CombatTypes.other_side(actor.side))
	elif skill.target_type == CombatTypes.TargetType.SINGLE_ALLY:
		pool = state.actives(actor.side)
	for t in pool:
		out.append(t.uid)
	return out


## Speed order of the living actives (highest first; ties go to the lower uid).
func predicted_order() -> Array[int]:
	var list: Array[TroopInstance] = state.all_actives()
	list.sort_custom(_faster)
	var out: Array[int] = []
	for t in list:
		out.append(t.uid)
	return out


## Viewer-filtered state for clients. viewer = -1 sees everything (server/debug).
func get_snapshot(viewer: int = -1) -> Dictionary:
	var troops: Dictionary = {}
	var teams: Array[Dictionary] = []
	for side in 2:
		var team: TeamState = state.team(side)
		var hidden: bool = viewer != -1 and viewer != side
		var squad: Array[Dictionary] = []
		for d in team.squad:
			squad.append(d.to_summary())
		var active_ids: Array[int] = []
		for t in team.active:
			active_ids.append(t.uid if t != null else -1)
			if t != null:
				troops[t.uid] = t.to_snapshot()
		var bench_ids: Array[int] = []
		for t in team.bench:
			if t == null:
				bench_ids.append(-1)
			elif hidden and not t.revealed:
				bench_ids.append(-2)
			else:
				bench_ids.append(t.uid)
				troops[t.uid] = t.to_snapshot()
		teams.append({
			"squad": squad,
			"locked": team.locked,
			"picks": [] if hidden else team.picks.duplicate(),
			"active": active_ids,
			"bench": bench_ids,
			"energy": team.energy,
			"actions_locked": team.actions_locked,
			"slot_switch_cd": team.slot_switch_cd.duplicate(),
			"pending_slots": team.pending_slots.duplicate(),
		})
	var snap: Dictionary = {
		"phase": state.phase,
		"phase_name": CombatTypes.Phase.keys()[state.phase],
		"cycle": state.cycle,
		"frenzy_stacks": state.frenzy_stacks(),
		"turn": state.turn_count,
		"winner": state.winner,
		"teams": teams,
		"troops": troops,
		"timeline": predicted_order(),
		"legal": {},
	}
	if state.phase == CombatTypes.Phase.ACTION_WAIT:
		for side in 2:
			if viewer == -1 or viewer == side:
				for t in acting_troops(side):
					snap["legal"][t.uid] = _legal_snapshot(t)
	return snap


# =====================================================================
# State machine
# =====================================================================

func _start_battle() -> void:
	for side in 2:
		var team: TeamState = state.team(side)
		team.active.assign([null, null])
		team.bench.clear()
		for n in team.picks.size():
			var t: TroopInstance = TroopInstance.new(_next_uid, team.squad[team.picks[n]], side)
			_next_uid += 1
			state.troops[t.uid] = t
			if n < CombatTypes.ACTIVE_SLOTS:
				team.active[n] = t
			else:
				team.bench.append(t)
	_emit(CombatTypes.EventType.BATTLE_STARTED)
	for side in 2:
		for slot in CombatTypes.ACTIVE_SLOTS:
			_enter_field(state.team(side).active[slot], slot)
	_process_triggers()
	_advance()


## Starts rounds until input is needed (ACTION_WAIT / STANDBY) or the match ends.
func _advance() -> void:
	while true:
		if _check_win():
			return
		if _request_standby():
			return
		_begin_round()
		if not (state.team(0).actions_locked and state.team(1).actions_locked):
			return
		_resolve_round()


## Opens action selection. A side with nothing to choose (all stunned) is locked automatically.
func _begin_round() -> void:
	state.phase = CombatTypes.Phase.ACTION_WAIT
	var pending: Array = [[], []]
	for team in state.teams:
		team.actions.clear()
		var need: Array[TroopInstance] = acting_troops(team.side)
		team.actions_locked = need.is_empty()
		for t in state.actives(team.side):
			if t.is_stunned():
				_emit(CombatTypes.EventType.TURN_SKIPPED, t.uid, -1, 0.0, {"reason": "stun"})
		for t in need:
			pending[team.side].append(t.uid)
	_emit(CombatTypes.EventType.ACTION_REQUESTED, -1, -1, float(state.cycle), {"pending": pending})


## Higher Speed first; ties alternate between lower and higher uid each cycle so neither side owns the tie-break.
func _faster(a: TroopInstance, b: TroopInstance) -> bool:
	var sa: float = a.get_stat(CombatTypes.Stat.SPEED)
	var sb: float = b.get_stat(CombatTypes.Stat.SPEED)
	if absf(sa - sb) > CombatTypes.EPSILON:
		return sa > sb
	if state.cycle % 2 == 0:
		return a.uid < b.uid
	return a.uid > b.uid


## Runs every chosen action in Speed order (ACT_FIRST overdrives jump the queue), then ends the round.
func _resolve_round() -> void:
	state.phase = CombatTypes.Phase.RESOLUTION
	var queue: Array[TroopInstance] = []
	var first: Dictionary = {}
	for team in state.teams:
		for uid: int in team.actions:
			var t: TroopInstance = state.get_troop(uid)
			var a: CombatAction = team.actions[uid]
			queue.append(t)
			first[uid] = a.kind == CombatTypes.ActionKind.SKILL and a.overdrive \
				and t.data.skills[a.skill_index].overdrive_kind == CombatTypes.OverdriveKind.ACT_FIRST
	queue.sort_custom(func(a: TroopInstance, b: TroopInstance) -> bool:
		if first[a.uid] != first[b.uid]:
			return first[a.uid]
		return _faster(a, b))
	var order: Array[int] = []
	for t in queue:
		order.append(t.uid)
	_emit(CombatTypes.EventType.ROUND_STARTED, -1, -1, float(state.cycle), {"order": order})
	for t in queue:
		if state.team(0).is_wiped() or state.team(1).is_wiped():
			break
		if state.is_active(t):
			_act(t, state.team(t.side).actions[t.uid])
	_round_end()


func _act(actor: TroopInstance, action: CombatAction) -> void:
	state.turn_count += 1
	state.last_actor = actor
	_emit(CombatTypes.EventType.TURN_STARTED, actor.uid, -1, float(state.turn_count), {"cycle": state.cycle, "side": actor.side, "slot": state.team(actor.side).slot_of(actor)})
	if action.kind == CombatTypes.ActionKind.SWITCH:
		if state.team(actor.side).is_bench_ready(action.bench_index):
			_do_switch(actor, action.bench_index, true)
	else:
		# A target that fell earlier this round is replaced by the first legal one.
		if actor.data.skills[action.skill_index].needs_target() and not valid_targets(actor, action.skill_index).has(action.target_uid):
			action.target_uid = _default_target(actor, action.skill_index)
		_do_skill(actor, action)
	_emit(CombatTypes.EventType.TURN_ENDED, actor.uid)


## DoTs tick, cooldowns and effect durations count down, then the next round number begins.
func _round_end() -> void:
	state.phase = CombatTypes.Phase.TURN_END
	for t in state.all_actives():
		for e: ActiveEffect in t.effects.duplicate():
			if e.kind == CombatTypes.EffectKind.DOT and t.is_alive():
				var dmg: int = maxi(1, roundi(float(e.value) * CombatMath.frenzy_damage_mult(state.cycle)))
				_apply_damage(null, t, dmg, false, "dot")
		if not t.is_alive():
			continue
		t.tick_cooldowns()
		for e in t.tick_effects(state.cycle):
			_emit(CombatTypes.EventType.EFFECT_EXPIRED, t.uid, -1, 0.0, {"kind": e.kind, "stat": e.stat})
	for team in state.teams:
		for i in team.slot_switch_cd.size():
			team.slot_switch_cd[i] = maxi(0, team.slot_switch_cd[i] - 1)
		team.actions.clear()
		team.actions_locked = false
	state.cycle += 1
	_emit(CombatTypes.EventType.CYCLE_ADVANCED, -1, -1, float(state.cycle))
	if state.frenzy_stacks() > CombatMath.frenzy_stacks(state.cycle - 1):
		_emit(CombatTypes.EventType.FRENZY_CHANGED, -1, -1, float(state.frenzy_stacks()), {
			"damage_mult": CombatMath.frenzy_damage_mult(state.cycle),
			"heal_mult": CombatMath.frenzy_heal_mult(state.cycle),
		})


func _check_win() -> bool:
	state.phase = CombatTypes.Phase.CHECK_WIN
	var a_out: bool = state.team(CombatTypes.Side.A).is_wiped()
	var b_out: bool = state.team(CombatTypes.Side.B).is_wiped()
	if not a_out and not b_out:
		return false
	if a_out and b_out:
		# Simultaneous wipe: the side that acted last takes it.
		state.winner = state.last_actor.side if state.last_actor != null else CombatTypes.Side.A
	else:
		state.winner = CombatTypes.Side.B if a_out else CombatTypes.Side.A
	state.phase = CombatTypes.Phase.FINISHED
	_emit(CombatTypes.EventType.BATTLE_ENDED, -1, -1, float(state.winner), {"winner": state.winner, "cycle": state.cycle, "turns": state.turn_count})
	return true


## Pokémon-style Standby: empty (KO'd) slots are refilled from the bench before the next turn.
func _request_standby() -> bool:
	var needed: bool = false
	var pending: Array = [[], []]
	for team in state.teams:
		team.pending_slots.clear()
		var ready_count: int = team.ready_bench_indices().size()
		for slot in CombatTypes.ACTIVE_SLOTS:
			var occupant: TroopInstance = team.active[slot]
			if (occupant == null or not occupant.is_alive()) and team.pending_slots.size() < ready_count:
				team.pending_slots.append(slot)
		pending[team.side] = team.pending_slots.duplicate()
		needed = needed or not team.pending_slots.is_empty()
	if needed:
		state.phase = CombatTypes.Phase.STANDBY
		_emit(CombatTypes.EventType.STANDBY_REQUESTED, -1, -1, 0.0, {"pending": pending})
	return needed


# =====================================================================
# Resolution
# =====================================================================

func _do_skill(actor: TroopInstance, action: CombatAction) -> void:
	var skill: SkillData = actor.data.skills[action.skill_index]
	var team: TeamState = state.team(actor.side)
	var damage_mult: float = 1.0
	var guaranteed: bool = false
	if action.overdrive:
		team.energy -= skill.overdrive_cost
		_emit(CombatTypes.EventType.ENERGY_CHANGED, -1, -1, float(team.energy), {"side": actor.side, "delta": -skill.overdrive_cost})
		_emit(CombatTypes.EventType.OVERDRIVE_ACTIVATED, actor.uid, -1, float(skill.overdrive_cost), {"kind": skill.overdrive_kind, "skill_index": action.skill_index})
		if skill.overdrive_kind == CombatTypes.OverdriveKind.GUARANTEE_EFFECTS:
			guaranteed = true
		elif skill.overdrive_kind == CombatTypes.OverdriveKind.BONUS_DAMAGE:
			damage_mult += skill.overdrive_value
	_emit(CombatTypes.EventType.SKILL_USED, actor.uid, action.target_uid, float(action.skill_index), {
		"skill_index": action.skill_index, "skill_name": skill.skill_name, "overdrive": action.overdrive, "slot": skill.slot,
	})
	actor.cooldowns[action.skill_index] = skill.cooldown
	if action.overdrive and skill.overdrive_kind == CombatTypes.OverdriveKind.REDUCE_COOLDOWN:
		actor.cooldowns[action.skill_index] = maxi(0, skill.cooldown - int(skill.overdrive_value))
	_execute_skill(actor, skill, _resolve_targets(actor, skill.target_type, action.target_uid, null), damage_mult, guaranteed)
	_process_triggers()
	if skill.dual_attack_chance > 0.0 and actor.is_alive():
		_try_dual_attack(actor, skill, action.target_uid)
	if skill.self_switch_after and state.is_active(actor):
		var bench_index: int = action.bench_index if action.bench_index != -1 else team.first_ready_bench()
		if bench_index != -1:
			_do_switch(actor, bench_index, false)


## Shared by cast skills, dual attacks, and passives.
func _execute_skill(caster: TroopInstance, skill: SkillData, targets: Array[TroopInstance], damage_mult: float, guaranteed: bool) -> void:
	if skill.deals_damage():
		for t in targets:
			if t.is_alive() and t.side != caster.side:
				_hit(caster, t, skill, damage_mult)
	for effect in skill.effects:
		for r in _effect_recipients(caster, effect.target, targets):
			if r.is_alive():
				_apply_effect(caster, r, effect, guaranteed)
	if skill.energy_gain > 0:
		_gain_energy(caster.side, skill.energy_gain)


func _try_dual_attack(actor: TroopInstance, skill: SkillData, target_uid: int) -> void:
	var partner: TroopInstance = state.partner(actor)
	if partner == null or partner.is_stunned():
		return
	if rng.randf() >= minf(skill.dual_attack_chance, CombatTypes.DUAL_ATTACK_CAP):
		return
	var target: TroopInstance = state.get_troop(target_uid)
	if not state.is_active(target) or target.side == actor.side:
		var foes: Array[TroopInstance] = state.actives(CombatTypes.other_side(actor.side))
		if foes.is_empty():
			return
		target = foes[0]
	var s1: SkillData = partner.data.skills[0]
	_emit(CombatTypes.EventType.DUAL_ATTACK, partner.uid, target.uid, 0.0, {"skill_name": s1.skill_name})
	_execute_skill(partner, s1, _resolve_targets(partner, s1.target_type, target.uid, null), 1.0, false)
	_process_triggers()


func _hit(caster: TroopInstance, target: TroopInstance, skill: SkillData, damage_mult: float) -> void:
	var crit: bool = rng.randf() < caster.get_stat(CombatTypes.Stat.CRIT_CHANCE)
	var atk_stat: CombatTypes.Stat = CombatTypes.Stat.SPECIAL_ATTACK if skill.special else CombatTypes.Stat.ATTACK
	var def_stat: CombatTypes.Stat = CombatTypes.Stat.SPECIAL_DEFENSE if skill.special else CombatTypes.Stat.DEFENSE
	var raw: float = CombatMath.raw_damage(caster.get_stat(atk_stat), caster.max_hp(), skill, 1.0 - caster.hp_ratio())
	var mult: float = damage_mult * CombatMath.frenzy_damage_mult(state.cycle)
	if skill.bonus_vs_debuffed > 0.0 and target.has_debuff():
		mult *= 1.0 + skill.bonus_vs_debuffed
	var dmg: int = CombatMath.final_damage(raw, target.get_stat(def_stat), crit, caster.data.crit_damage, mult)
	_apply_damage(caster, target, dmg, crit, "skill")
	var target_partner: TroopInstance = state.partner(target)
	if target_partner != null:
		_queue_trigger(CombatTypes.Trigger.ON_ALLY_HIT, target_partner, target)


func _apply_damage(source: TroopInstance, target: TroopInstance, amount: int, crit: bool, tag: String) -> void:
	var absorbed: int = target.absorb_shield(amount)
	var dealt: int = amount - absorbed
	target.hp = maxi(0, target.hp - dealt)
	_emit(CombatTypes.EventType.DAMAGE, source.uid if source != null else -1, target.uid, float(dealt), {
		"raw": amount, "absorbed": absorbed, "crit": crit, "hp_after": target.hp, "shield_after": target.shield(), "tag": tag,
	})
	if target.hp == 0:
		target.effects.clear()
		_emit(CombatTypes.EventType.KO, target.uid, -1, 0.0, {"side": target.side, "slot": state.team(target.side).slot_of(target)})
		_refresh_synergy()


func _apply_effect(caster: TroopInstance, target: TroopInstance, effect: EffectData, guaranteed: bool) -> void:
	var hostile: bool = effect.is_debuff() and target.side != caster.side
	var chance: float = 1.0 if guaranteed else CombatMath.effect_chance(effect.chance, caster.get_stat(CombatTypes.Stat.EFFECTIVENESS))
	if chance < 1.0 and rng.randf() >= chance:
		if hostile:
			_emit(CombatTypes.EventType.EFFECT_RESISTED, caster.uid, target.uid, 0.0, {"kind": effect.kind, "stat": effect.stat})
		return
	var heal_mult: float = CombatMath.frenzy_heal_mult(state.cycle)
	match effect.kind:
		CombatTypes.EffectKind.STAT_MOD, CombatTypes.EffectKind.STUN:
			var existing: ActiveEffect = target.find_effect(effect.kind, effect.stat, effect.is_debuff())
			if existing != null:
				existing.remaining = maxi(existing.remaining, effect.duration)
				if absf(effect.magnitude) > absf(existing.magnitude):
					existing.magnitude = effect.magnitude
				existing.applied_turn = state.cycle
			else:
				target.effects.append(ActiveEffect.new(effect.kind, effect.stat, effect.magnitude, effect.duration, 0, caster.uid, state.cycle))
			_emit_applied(caster, target, effect, 0)
		CombatTypes.EffectKind.DOT:
			var tick: int = maxi(1, roundi(caster.get_stat(CombatTypes.Stat.ATTACK) * effect.magnitude))
			target.effects.append(ActiveEffect.new(effect.kind, effect.stat, effect.magnitude, effect.duration, tick, caster.uid, state.cycle))
			_emit_applied(caster, target, effect, tick)
		CombatTypes.EffectKind.SHIELD:
			var amount: int = roundi(float(caster.max_hp()) * effect.magnitude * heal_mult)
			if amount <= 0:
				return
			var shield: ActiveEffect = target.find_effect(effect.kind, effect.stat, false)
			if shield != null:
				shield.value = maxi(shield.value, amount)
				shield.remaining = maxi(shield.remaining, effect.duration)
				shield.applied_turn = state.cycle
			else:
				target.effects.append(ActiveEffect.new(effect.kind, effect.stat, effect.magnitude, effect.duration, amount, caster.uid, state.cycle))
			_emit_applied(caster, target, effect, amount)
		CombatTypes.EffectKind.HEAL:
			var heal: int = mini(target.max_hp() - target.hp, roundi(float(caster.max_hp()) * effect.magnitude * heal_mult))
			target.hp += maxi(0, heal)
			_emit(CombatTypes.EventType.HEAL, caster.uid, target.uid, float(maxi(0, heal)), {"hp_after": target.hp})
		CombatTypes.EffectKind.CLEANSE:
			var removed: int = target.cleanse(false)
			if removed > 0:
				_emit(CombatTypes.EventType.CLEANSED, caster.uid, target.uid, float(removed))
		CombatTypes.EffectKind.ENERGY:
			_gain_energy(target.side, roundi(effect.magnitude))
	if hostile:
		_queue_trigger(CombatTypes.Trigger.ON_DEBUFF_RECEIVED, target, target)


func _emit_applied(caster: TroopInstance, target: TroopInstance, effect: EffectData, amount: int) -> void:
	_emit(CombatTypes.EventType.EFFECT_APPLIED, caster.uid, target.uid, float(amount), {
		"kind": effect.kind, "stat": effect.stat, "magnitude": effect.magnitude, "duration": effect.duration, "debuff": effect.is_debuff(),
	})


func _do_switch(actor: TroopInstance, bench_index: int, tactical: bool) -> void:
	var team: TeamState = state.team(actor.side)
	var slot: int = team.slot_of(actor)
	var incoming: TroopInstance = team.bench[bench_index]
	team.bench[bench_index] = actor
	team.active[slot] = incoming
	_emit(CombatTypes.EventType.SWITCHED, actor.uid, incoming.uid, float(slot), {"side": actor.side, "slot": slot, "bench_index": bench_index, "tactical": tactical, "incoming_name": incoming.data.display_name})
	_gain_energy(actor.side, CombatTypes.SWITCH_ENERGY)
	if tactical:
		team.slot_switch_cd[slot] = CombatTypes.SWITCH_COOLDOWN_TURNS + 1 # round end ticks it once
	_enter_field(incoming, slot)
	_process_triggers()


## Places a troop on the field: stat-debuff cleanse, ON_SWITCH_IN passives.
func _enter_field(troop: TroopInstance, slot: int) -> void:
	troop.revealed = true
	_refresh_synergy()
	var cleansed: int = troop.cleanse(true)
	_emit(CombatTypes.EventType.TROOP_ENTERED, troop.uid, -1, 0.0, {
		"side": troop.side, "slot": slot, "name": troop.data.display_name, "troop_id": String(troop.data.troop_id),
		"archetype": String(troop.data.archetype), "synergy": not troop.synergy.is_empty(), "role": troop.data.role, "hp": troop.hp, "max_hp": troop.max_hp(), "shield": troop.shield(),
	})
	if cleansed > 0:
		_emit(CombatTypes.EventType.CLEANSED, troop.uid, troop.uid, float(cleansed))
	_queue_trigger(CombatTypes.Trigger.ON_SWITCH_IN, troop, troop)


## Archetype synergy: both living actives of a side share an archetype -> each gets that archetype's bonus.
func _refresh_synergy() -> void:
	for side in 2:
		var pair: Array[TroopInstance] = state.actives(side)
		var fx: Array[EffectData] = []
		if pair.size() == CombatTypes.ACTIVE_SLOTS and pair[0].data.archetype == pair[1].data.archetype and _archetypes.has(pair[0].data.archetype):
			fx = _archetypes[pair[0].data.archetype].synergy
		for t: TroopInstance in state.troops.values():
			if t.side == side:
				t.synergy.assign(fx if state.is_active(t) else [])


func _gain_energy(side: int, amount: int) -> void:
	var team: TeamState = state.team(side)
	var before: int = team.energy
	team.energy = clampi(team.energy + amount, 0, CombatTypes.ENERGY_CAP)
	if team.energy != before:
		_emit(CombatTypes.EventType.ENERGY_CHANGED, -1, -1, float(team.energy), {"side": side, "delta": team.energy - before})


# =====================================================================
# Passives
# =====================================================================

func _queue_trigger(trigger: CombatTypes.Trigger, owner: TroopInstance, context: TroopInstance) -> void:
	if owner != null:
		_trigger_queue.append({"trigger": trigger, "owner": owner, "context": context})


## Deferred so passives resolve after the skill that caused them. Internal cooldowns stop loops.
func _process_triggers() -> void:
	var guard: int = 0
	while not _trigger_queue.is_empty() and guard < 64:
		guard += 1
		var entry: Dictionary = _trigger_queue.pop_front()
		var owner: TroopInstance = entry["owner"]
		var context: TroopInstance = entry["context"]
		if not state.is_active(owner) or owner.passive_icd > 0:
			continue
		for skill in owner.data.skills:
			if skill.is_passive and skill.trigger == entry["trigger"]:
				owner.passive_icd = skill.cooldown
				_emit(CombatTypes.EventType.PASSIVE_TRIGGERED, owner.uid, context.uid if context != null else -1, 0.0, {"skill_name": skill.skill_name})
				_execute_skill(owner, skill, _resolve_targets(owner, skill.target_type, -1, context), 1.0, false)
				break
	_trigger_queue.clear()


# =====================================================================
# Helpers
# =====================================================================

func _resolve_targets(caster: TroopInstance, target_type: CombatTypes.TargetType, target_uid: int, context: TroopInstance) -> Array[TroopInstance]:
	var out: Array[TroopInstance] = []
	match target_type:
		CombatTypes.TargetType.SINGLE_ENEMY, CombatTypes.TargetType.SINGLE_ALLY:
			var t: TroopInstance = context if context != null else state.get_troop(target_uid)
			if state.is_active(t):
				out.append(t)
		CombatTypes.TargetType.ALL_ENEMIES:
			out = state.actives(CombatTypes.other_side(caster.side))
		CombatTypes.TargetType.SELF:
			out.append(caster)
		CombatTypes.TargetType.ALL_ALLIES:
			out = state.actives(caster.side)
	return out


func _effect_recipients(caster: TroopInstance, target: CombatTypes.EffectTarget, skill_targets: Array[TroopInstance]) -> Array[TroopInstance]:
	var out: Array[TroopInstance] = []
	match target:
		CombatTypes.EffectTarget.SKILL_TARGETS:
			out = skill_targets
		CombatTypes.EffectTarget.SELF:
			out.append(caster)
		CombatTypes.EffectTarget.ALLIES:
			out = state.actives(caster.side)
		CombatTypes.EffectTarget.PARTNER:
			var p: TroopInstance = state.partner(caster)
			if p != null:
				out.append(p)
		CombatTypes.EffectTarget.ENEMIES:
			out = state.actives(CombatTypes.other_side(caster.side))
	return out


func _default_target(actor: TroopInstance, skill_index: int) -> int:
	var targets: Array[int] = valid_targets(actor, skill_index)
	return targets[0] if not targets.is_empty() else -1


func _legal_snapshot(actor: TroopInstance) -> Dictionary:
	var team: TeamState = state.team(actor.side)
	var skills: Array[Dictionary] = []
	for i in actor.data.skills.size():
		var s: SkillData = actor.data.skills[i]
		var info: Dictionary = s.to_summary()
		info["index"] = i
		info["ready"] = not s.is_passive and actor.cooldowns[i] == 0
		info["cooldown_left"] = actor.cooldowns[i]
		info["targets"] = valid_targets(actor, i) if s.needs_target() else []
		info["can_overdrive"] = s.overdrive_kind != CombatTypes.OverdriveKind.NONE and team.energy >= s.overdrive_cost
		info["self_switch"] = s.self_switch_after
		skills.append(info)
	return {
		"actor": actor.uid,
		"skills": skills,
		"can_switch": can_switch(actor),
		"bench": team.ready_bench_indices() if can_switch(actor) else [],
	}


func _validate_picks(picks: Array[int], squad_size: int) -> String:
	if picks.size() != CombatTypes.DRAFT_PICK:
		return "Pick exactly %d troops." % CombatTypes.DRAFT_PICK
	var seen: Dictionary = {}
	for p in picks:
		if p < 0 or p >= squad_size:
			return "Pick index out of range."
		if seen.has(p):
			return "Duplicate pick."
		seen[p] = true
	return ""


func _emit(type: CombatTypes.EventType, actor: int = -1, target: int = -1, value: float = 0.0, data: Dictionary = {}) -> void:
	_log.append(CombatEvent.new(type, actor, target, value, data))


func _reject(side: int, reason: String) -> Array[CombatEvent]:
	_emit(CombatTypes.EventType.ACTION_REJECTED, -1, -1, 0.0, {"side": side, "reason": reason})
	return _flush()


func _flush() -> Array[CombatEvent]:
	var out: Array[CombatEvent] = _log
	_log = []
	return out
