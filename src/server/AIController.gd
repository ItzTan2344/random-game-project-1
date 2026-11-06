class_name AIController
extends RefCounted
## Heuristic opponent. Reads engine state, returns intents; never mutates state directly.

const LOW_HP_SWITCH: float = 0.3
const HEALTHY_BENCH: float = 0.6
const SUPPORT_SKIP_HP: float = 0.8

var side: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(p_side: int, seed_value: int) -> void:
	side = p_side
	rng.seed = seed_value


## Top 4 by a jittered stat score; the two fastest lead.
func choose_draft(squad: Array[TroopData]) -> Array[int]:
	var scores: Array[float] = []
	var order: Array[int] = []
	for i in squad.size():
		var d: TroopData = squad[i]
		scores.append(d.max_hp * 0.1 + d.attack + d.defense * 0.5 + d.speed * 2.0 + rng.randf() * 60.0)
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b])
	var picks: Array[int] = []
	for i in CombatTypes.DRAFT_PICK:
		picks.append(order[i])
	picks.sort_custom(func(a: int, b: int) -> bool: return squad[a].speed > squad[b].speed)
	return picks


func choose_action(engine: CombatEngine) -> CombatAction:
	var actor: TroopInstance = engine.state.current_actor
	var team: TeamState = engine.state.team(side)
	if actor.hp_ratio() < LOW_HP_SWITCH and engine.can_switch(actor):
		var bench: int = _healthiest_bench(team)
		if bench != -1 and team.bench[bench].hp_ratio() > HEALTHY_BENCH and rng.randf() < 0.6:
			return CombatAction.switch_to(bench)
	var legal: Array[int] = engine.legal_skills(actor)
	var choice: int = legal[0]
	for i in range(legal.size() - 1, -1, -1):
		if _is_useful(engine, actor, actor.data.skills[legal[i]]):
			choice = legal[i]
			break
	var skill: SkillData = actor.data.skills[choice]
	var overdrive: bool = skill.overdrive_kind != CombatTypes.OverdriveKind.NONE \
		and team.energy >= skill.overdrive_cost \
		and (skill.slot == CombatTypes.SkillSlot.S3 or team.energy >= CombatTypes.ENERGY_CAP - 2)
	return CombatAction.cast(choice, _pick_target(engine, actor, choice), overdrive)


func choose_replacement(engine: CombatEngine) -> int:
	return _healthiest_bench(engine.state.team(side))


func _is_useful(engine: CombatEngine, actor: TroopInstance, skill: SkillData) -> bool:
	if skill.deals_damage():
		return true
	var support_only: bool = true
	for e in skill.effects:
		if e.kind != CombatTypes.EffectKind.HEAL and e.kind != CombatTypes.EffectKind.SHIELD and e.kind != CombatTypes.EffectKind.CLEANSE:
			support_only = false
	if not support_only:
		return true
	for ally in engine.state.actives(actor.side):
		if ally.hp_ratio() < SUPPORT_SKIP_HP:
			return true
	return false


func _pick_target(engine: CombatEngine, actor: TroopInstance, skill_index: int) -> int:
	var best: int = -1
	var best_score: float = INF
	for uid in engine.valid_targets(actor, skill_index):
		var t: TroopInstance = engine.state.get_troop(uid)
		var score: float = float(t.hp) if t.side != actor.side else t.hp_ratio()
		if score < best_score:
			best_score = score
			best = uid
	return best


func _healthiest_bench(team: TeamState) -> int:
	var best: int = -1
	for i in team.ready_bench_indices():
		if best == -1 or team.bench[i].hp_ratio() > team.bench[best].hp_ratio():
			best = i
	return best
