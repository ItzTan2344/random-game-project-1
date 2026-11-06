class_name LocalServer
extends Node
## In-process authority. Owns the CombatEngine, accepts client intents, publishes event logs + snapshots,
## and waits for a client-ready ack (with timeout fallback) before letting the AI act.
## Intent methods mirror future @rpc endpoints: swap `events_published` for an RPC to go online.

signal events_published(events: Array[Dictionary], snapshot: Dictionary)

@export var ack_timeout: float = 10.0
@export var draft_seconds: float = CombatTypes.DRAFT_SECONDS

var engine: CombatEngine
var viewer_side: int = CombatTypes.Side.A
var _ais: Dictionary[int, AIController] = {}
var _awaiting_ack: bool = false
var _ack_timer: Timer
var _draft_timer: Timer


func _init() -> void:
	_ack_timer = Timer.new()
	_ack_timer.one_shot = true
	_ack_timer.timeout.connect(client_ready)
	add_child(_ack_timer)
	_draft_timer = Timer.new()
	_draft_timer.one_shot = true
	_draft_timer.timeout.connect(_on_draft_timeout)
	add_child(_draft_timer)


func start_match(seed_value: int, squad_a: Array[TroopData], squad_b: Array[TroopData], ai_sides: Array[int], p_viewer_side: int = CombatTypes.Side.A) -> void:
	engine = CombatEngine.new(seed_value)
	viewer_side = p_viewer_side
	_ais.clear()
	for s in ai_sides:
		_ais[s] = AIController.new(s, seed_value + 7919 * (s + 1))
	_awaiting_ack = false
	_publish(engine.start_preview(squad_a, squad_b))
	if _ais.size() < 2 and _draft_timer.is_inside_tree():
		_draft_timer.start(draft_seconds)


func draft_seconds_left() -> float:
	return _draft_timer.time_left if _draft_timer != null and not _draft_timer.is_stopped() else 0.0


# ---------------- Client intents ----------------

func request_draft(side: int, picks: Array[int]) -> void:
	_publish(engine.submit_draft(side, picks))


func use_skill(side: int, skill_index: int, target_uid: int, overdrive: bool = false, bench_index: int = -1) -> void:
	_publish(engine.submit_action(side, CombatAction.cast(skill_index, target_uid, overdrive, bench_index)))


func switch_troop(side: int, bench_index: int) -> void:
	_publish(engine.submit_action(side, CombatAction.switch_to(bench_index)))


func choose_replacement(side: int, slot: int, bench_index: int) -> void:
	_publish(engine.submit_replacement(side, slot, bench_index))


## Client finished playing the last log. Also fired by the ack timeout.
func client_ready() -> void:
	_awaiting_ack = false
	if _ack_timer != null:
		_ack_timer.stop()
	_drive_ai()


func is_finished() -> bool:
	return engine != null and engine.state.phase == CombatTypes.Phase.FINISHED


# ---------------- Internals ----------------

func _publish(events: Array[CombatEvent]) -> void:
	var dicts: Array[Dictionary] = []
	for e in events:
		dicts.append(e.to_dict())
	if engine.state.phase != CombatTypes.Phase.PREVIEW and _draft_timer != null:
		_draft_timer.stop()
	_awaiting_ack = true
	if _ack_timer != null and _ack_timer.is_inside_tree():
		_ack_timer.start(ack_timeout)
	events_published.emit(dicts, engine.get_snapshot(viewer_side))


func _drive_ai() -> void:
	if _awaiting_ack or engine == null:
		return
	var st: CombatState = engine.state
	match st.phase:
		CombatTypes.Phase.PREVIEW:
			for s: int in _ais:
				if not st.team(s).locked:
					_publish(engine.submit_draft(s, _ais[s].choose_draft(st.team(s).squad)))
					return
		CombatTypes.Phase.ACTION_WAIT:
			if st.current_actor != null and _ais.has(st.current_actor.side):
				var s: int = st.current_actor.side
				_publish(engine.submit_action(s, _ais[s].choose_action(engine)))
		CombatTypes.Phase.STANDBY:
			for s: int in _ais:
				var team: TeamState = st.team(s)
				if not team.pending_slots.is_empty():
					_publish(engine.submit_replacement(s, team.pending_slots[0], _ais[s].choose_replacement(engine)))
					return


func _on_draft_timeout() -> void:
	if engine != null and engine.state.phase == CombatTypes.Phase.PREVIEW and not engine.state.team(viewer_side).locked:
		var auto_picks: Array[int] = [0, 1, 2, 3]
		request_draft(viewer_side, auto_picks)
