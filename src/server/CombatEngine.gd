class_name CombatEngine
extends RefCounted
## Authoritative, deterministic, zero-yield combat state machine.
## PREVIEW -> TURN_START -> ACTION_WAIT -> RESOLUTION -> TURN_END -> CHECK_WIN (-> STANDBY) -> ...
## Every public call runs synchronously until input is needed and returns the ordered event log.

var state: CombatState = CombatState.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _log: Array[CombatEvent] = []
var _trigger_queue: Array[Dictionary] = []
var _next_uid: int = 1
var _pending_switch_cd_slot: int = -1


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


func submit_action(side: int, action: CombatAction) -> Array[CombatEvent]:
	if state.phase != CombatTypes.Phase.ACTION_WAIT or state.current_actor == null:
		return _reject(side, "Not waiting for an action.")
	var actor: TroopInstance = state.current_actor
	if actor.side != side:
		return _reject(side, "Not your turn.")
	var err: String = validate_action(actor, action)
	if err != "":
		return _reject(side, err)
	state.phase = CombatTypes.Phase.RESOLUTION
	if action.kind == CombatTypes.ActionKind.SWITCH:
		_do_switch(actor, action.bench_index, true)
	else:
		_do_skill(actor, action)
	_turn_end(actor)
	_advance()
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
	_enter_field(incoming, slot, CombatTypes.SWITCH_ENTRY_CR)
	_process_triggers()
	if state.teams[0].pending_slots.is_empty() and state.teams[1].pending_slots.is_empty():
		_advance()
	return _flush()


# =====================================================================
# Queries (used by AI, UI snapshot, and validation)
# =====================================================================

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


## Turn order preview: living actives sorted by time-to-act.
func predicted_order() -> Array[int]:
	var list: Array[TroopInstance] = state.all_actives()
	list.sort_custom(func(a: TroopInstance, b: TroopInstance) -> bool:
		var ta: float = CombatMath.time_to_full(a.cr, a.get_stat(CombatTypes.Stat.SPEED))
		var tb: float = CombatMath.time_to_full(b.cr, b.get_stat(CombatTypes.Stat.SPEED))
		if absf(ta - tb) > CombatTypes.EPSILON:
			return ta < tb
		return _wins_tie(a, b))
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
		"current_actor": state.current_actor.uid if state.current_actor != null else -1,
		"teams": teams,
		"troops": troops,
		"timeline": predicted_order(),
		"legal": {},
	}
	var actor: TroopInstance = state.current_actor
	if state.phase == CombatTypes.Phase.ACTION_WAIT and actor != null and (viewer == -1 or viewer == actor.side):
		snap["legal"] = _legal_snapshot(actor)
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
			_enter_field(state.team(side).active[slot], slot, 0.0)
	_process_triggers()
	_advance()


## Runs turns until the engine needs input (ACTION_WAIT / STANDBY) or the match ends.
func _advance() -> void:
	while true:
		if _check_win():
			return
		if _request_standby():
			return
		var actor: TroopInstance = _next_actor()
		if actor == null:
			push_error("CombatEngine: no actor available but no winner.")
			return
		_turn_start(actor)
		if not actor.is_alive():
			_turn_end(actor)
			continue
		if actor.is_stunned():
			_emit(CombatTypes.EventType.TURN_SKIPPED, actor.uid, -1, 0.0, {"reason": "stun"})
			_turn_end(actor)
			continue
		state.phase = CombatTypes.Phase.ACTION_WAIT
		_emit(CombatTypes.EventType.ACTION_REQUESTED, actor.uid, -1, 0.0, {"side": actor.side})
		return


func _next_actor() -> TroopInstance:
	if state.extra_turn_uid != -1:
		var bonus: TroopInstance = state.get_troop(state.extra_turn_uid)
		state.extra_turn_uid = -1
		if state.is_active(bonus):
			bonus.cr = CombatTypes.CR_MAX
			_emit(CombatTypes.EventType.EXTRA_TURN, bonus.uid)
			return bonus
	var candidates: Array[TroopInstance] = state.all_actives()
	if candidates.is_empty():
		return null
	var best: TroopInstance = null
	var best_time: float = INF
	for t in candidates:
		var tt: float = CombatMath.time_to_full(t.cr, t.get_stat(CombatTypes.Stat.SPEED))
		if best == null or tt < best_time - CombatTypes.EPSILON or (absf(tt - best_time) <= CombatTypes.EPSILON and _wins_tie(t, best)):
			best = t
			best_time = tt
	if best_time > 0.0:
		for t in candidates:
			t.cr = minf(CombatTypes.CR_MAX, t.cr + t.get_stat(CombatTypes.Stat.SPEED) * best_time)
		state.timeline_time += best_time
	best.cr = CombatTypes.CR_MAX
	var cr_map: Dictionary = {}
	for t in candidates:
		cr_map[t.uid] = t.cr
	_emit(CombatTypes.EventType.TIMELINE_ADVANCED, best.uid, -1, best_time, {"cr": cr_map, "time": state.timeline_time})
	_update_cycle()
	return best


func _wins_tie(a: TroopInstance, b: TroopInstance) -> bool:
	var sa: float = a.get_stat(CombatTypes.Stat.SPEED)
	var sb: float = b.get_stat(CombatTypes.Stat.SPEED)
	if absf(sa - sb) > CombatTypes.EPSILON:
		return sa > sb
	return a.uid < b.uid


func _update_cycle() -> void:
	var new_cycle: int = CombatMath.cycle_at(state.timeline_time)
	if new_cycle <= state.cycle:
		return
	var old_stacks: int = state.frenzy_stacks()
	state.cycle = new_cycle
	_emit(CombatTypes.EventType.CYCLE_ADVANCED, -1, -1, float(new_cycle))
	var stacks: int = state.frenzy_stacks()
	if stacks != old_stacks:
		_emit(CombatTypes.EventType.FRENZY_CHANGED, -1, -1, float(stacks), {
			"damage_mult": CombatMath.frenzy_damage_mult(new_cycle),
			"heal_mult": CombatMath.frenzy_heal_mult(new_cycle),
		})


func _turn_start(actor: TroopInstance) -> void:
	state.phase = CombatTypes.Phase.TURN_START
	state.turn_count += 1
	state.current_actor = actor
	state.current_slot = state.team(actor.side).slot_of(actor)
	_pending_switch_cd_slot = -1
	actor.cr = 0.0
	_emit(CombatTypes.EventType.TURN_STARTED, actor.uid, -1, float(state.turn_count), {"cycle": state.cycle, "side": actor.side, "slot": state.current_slot})
	for e: ActiveEffect in actor.effects.duplicate():
		if e.kind == CombatTypes.EffectKind.DOT and actor.is_alive():
			var dmg: int = maxi(1, roundi(float(e.value) * CombatMath.frenzy_damage_mult(state.cycle)))
			_apply_damage(null, actor, dmg, false, "dot")
	_process_triggers()


func _turn_end(actor: TroopInstance) -> void:
	state.phase = CombatTypes.Phase.TURN_END
	actor.tick_cooldowns()
	for e in actor.tick_effects(state.turn_count):
		_emit(CombatTypes.EventType.EFFECT_EXPIRED, actor.uid, -1, 0.0, {"kind": e.kind, "stat": e.stat})
	if state.current_slot >= 0:
		var team: TeamState = state.team(actor.side)
		team.slot_switch_cd[state.current_slot] = maxi(0, team.slot_switch_cd[state.current_slot] - 1)
		if _pending_switch_cd_slot == state.current_slot:
			team.slot_switch_cd[state.current_slot] = CombatTypes.SWITCH_COOLDOWN_TURNS
	_emit(CombatTypes.EventType.TURN_ENDED, actor.uid)


func _check_win() -> bool:
	state.phase = CombatTypes.Phase.CHECK_WIN
	var a_out: bool = state.team(CombatTypes.Side.A).is_wiped()
	var b_out: bool = state.team(CombatTypes.Side.B).is_wiped()
	if not a_out and not b_out:
		return false
	if a_out and b_out:
		# Simultaneous wipe: the side that acted last takes it.
		state.winner = state.current_actor.side if state.current_actor != null else CombatTypes.Side.A
	else:
		state.winner = CombatTypes.Side.B if a_out else CombatTypes.Side.A
	state.phase = CombatTypes.Phase.FINISHED
	state.current_actor = null
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
		state.current_actor = null
		_emit(CombatTypes.EventType.STANDBY_REQUESTED, -1, -1, 0.0, {"pending": pending})
	return needed


# =====================================================================
# Resolution
# =====================================================================

func _do_skill(actor: TroopInstance, action: CombatAction) -> void:
	var skill: SkillData = actor.data.skills[action.skill_index]
	var team: TeamState = state.team(actor.side)
	var damage_mult: float = 1.0
	var ignore_er: bool = false
	if action.overdrive:
		team.energy -= skill.overdrive_cost
		_emit(CombatTypes.EventType.ENERGY_CHANGED, -1, -1, float(team.energy), {"side": actor.side, "delta": -skill.overdrive_cost})
		_emit(CombatTypes.EventType.OVERDRIVE_ACTIVATED, actor.uid, -1, float(skill.overdrive_cost), {"kind": skill.overdrive_kind, "skill_index": action.skill_index})
		if skill.overdrive_kind == CombatTypes.OverdriveKind.IGNORE_RESISTANCE:
			ignore_er = true
		elif skill.overdrive_kind == CombatTypes.OverdriveKind.BONUS_DAMAGE:
			damage_mult += skill.overdrive_value
	_emit(CombatTypes.EventType.SKILL_USED, actor.uid, action.target_uid, float(action.skill_index), {
		"skill_index": action.skill_index, "skill_name": skill.skill_name, "overdrive": action.overdrive, "slot": skill.slot,
	})
	actor.cooldowns[action.skill_index] = skill.cooldown
	if action.overdrive and skill.overdrive_kind == CombatTypes.OverdriveKind.REDUCE_COOLDOWN:
		actor.cooldowns[action.skill_index] = maxi(0, skill.cooldown - int(skill.overdrive_value))
	_execute_skill(actor, skill, _resolve_targets(actor, skill.target_type, action.target_uid, null), damage_mult, ignore_er)
	_process_triggers()
	if skill.dual_attack_chance > 0.0 and actor.is_alive():
		_try_dual_attack(actor, skill, action.target_uid)
	if action.overdrive and skill.overdrive_kind == CombatTypes.OverdriveKind.EXTRA_TURN and actor.is_alive():
		state.extra_turn_uid = actor.uid
	if skill.self_switch_after and state.is_active(actor):
		var bench_index: int = action.bench_index if action.bench_index != -1 else team.first_ready_bench()
		if bench_index != -1:
			_do_switch(actor, bench_index, false)


## Shared by cast skills, dual attacks, and passives.
func _execute_skill(caster: TroopInstance, skill: SkillData, targets: Array[TroopInstance], damage_mult: float, ignore_er: bool) -> void:
	if skill.deals_damage():
		for t in targets:
			if t.is_alive() and t.side != caster.side:
				_hit(caster, t, skill, damage_mult)
	var pushes: Dictionary = {}
	for effect in skill.effects:
		for r in _effect_recipients(caster, effect.target, targets):
			if r.is_alive():
				_apply_effect(caster, r, effect, ignore_er, pushes)
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
	var raw: float = CombatMath.raw_damage(caster.get_stat(CombatTypes.Stat.ATTACK), caster.max_hp(), skill, 1.0 - caster.hp_ratio())
	var mult: float = damage_mult * CombatMath.frenzy_damage_mult(state.cycle)
	if skill.bonus_vs_debuffed > 0.0 and target.has_debuff():
		mult *= 1.0 + skill.bonus_vs_debuffed
	var dmg: int = CombatMath.final_damage(raw, target.get_stat(CombatTypes.Stat.DEFENSE), crit, caster.data.crit_damage, mult)
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
		target.cr = 0.0
		_emit(CombatTypes.EventType.KO, target.uid, -1, 0.0, {"side": target.side, "slot": state.team(target.side).slot_of(target)})


func _apply_effect(caster: TroopInstance, target: TroopInstance, effect: EffectData, ignore_er: bool, pushes: Dictionary) -> void:
	if effect.chance < 1.0 and rng.randf() >= effect.chance:
		return
	var hostile: bool = effect.is_debuff() and target.side != caster.side
	if hostile:
		var er: float = 0.0 if ignore_er else target.get_stat(CombatTypes.Stat.EFFECT_RESISTANCE)
		var chance: float = CombatMath.hit_chance(caster.get_stat(CombatTypes.Stat.EFFECTIVENESS), er)
		if chance < 1.0 and rng.randf() >= chance:
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
				existing.applied_turn = state.turn_count
			else:
				target.effects.append(ActiveEffect.new(effect.kind, effect.stat, effect.magnitude, effect.duration, 0, caster.uid, state.turn_count))
			_emit_applied(caster, target, effect, 0)
		CombatTypes.EffectKind.DOT:
			var tick: int = maxi(1, roundi(caster.get_stat(CombatTypes.Stat.ATTACK) * effect.magnitude))
			target.effects.append(ActiveEffect.new(effect.kind, effect.stat, effect.magnitude, effect.duration, tick, caster.uid, state.turn_count))
			_emit_applied(caster, target, effect, tick)
		CombatTypes.EffectKind.SHIELD:
			var amount: int = roundi(float(caster.max_hp()) * effect.magnitude * heal_mult)
			if amount <= 0:
				return
			var shield: ActiveEffect = target.find_effect(effect.kind, effect.stat, false)
			if shield != null:
				shield.value = maxi(shield.value, amount)
				shield.remaining = maxi(shield.remaining, effect.duration)
				shield.applied_turn = state.turn_count
			else:
				target.effects.append(ActiveEffect.new(effect.kind, effect.stat, effect.magnitude, effect.duration, amount, caster.uid, state.turn_count))
			_emit_applied(caster, target, effect, amount)
		CombatTypes.EffectKind.HEAL:
			var heal: int = mini(target.max_hp() - target.hp, roundi(float(caster.max_hp()) * effect.magnitude * heal_mult))
			target.hp += maxi(0, heal)
			_emit(CombatTypes.EventType.HEAL, caster.uid, target.uid, float(maxi(0, heal)), {"hp_after": target.hp})
		CombatTypes.EffectKind.CR_CHANGE:
			var before_total: float = float(pushes.get(target.uid, 0.0))
			var allowed: float = CombatMath.clamp_cr_push(before_total + effect.magnitude) - before_total
			pushes[target.uid] = before_total + allowed
			var old_cr: float = target.cr
			target.cr = clampf(target.cr + allowed, 0.0, CombatTypes.CR_MAX)
			_emit(CombatTypes.EventType.CR_CHANGED, caster.uid, target.uid, target.cr - old_cr, {"cr_after": target.cr})
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
	actor.cr = 0.0
	_emit(CombatTypes.EventType.SWITCHED, actor.uid, incoming.uid, float(slot), {"side": actor.side, "slot": slot, "bench_index": bench_index, "tactical": tactical, "incoming_name": incoming.data.display_name})
	_gain_energy(actor.side, CombatTypes.SWITCH_ENERGY)
	if tactical:
		_pending_switch_cd_slot = slot
	_enter_field(incoming, slot, CombatTypes.SWITCH_ENTRY_CR)
	_process_triggers()


## Places a troop on the field: entry CR, stat-debuff cleanse, ON_SWITCH_IN passives.
func _enter_field(troop: TroopInstance, slot: int, entry_cr: float) -> void:
	troop.cr = entry_cr
	troop.revealed = true
	var cleansed: int = troop.cleanse(true)
	_emit(CombatTypes.EventType.TROOP_ENTERED, troop.uid, -1, entry_cr, {
		"side": troop.side, "slot": slot, "name": troop.data.display_name, "troop_id": String(troop.data.troop_id),
		"archetype": troop.data.archetype, "hp": troop.hp, "max_hp": troop.max_hp(), "shield": troop.shield(), "cr": troop.cr,
	})
	if cleansed > 0:
		_emit(CombatTypes.EventType.CLEANSED, troop.uid, troop.uid, float(cleansed))
	_queue_trigger(CombatTypes.Trigger.ON_SWITCH_IN, troop, troop)


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
