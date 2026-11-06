class_name BattleClient
extends Node
## Client controller: forwards UI intents to the server, queues published logs,
## plays them sequentially, reconciles with the snapshot, then acks the server.

## 0 = random seed per match.
@export var match_seed: int = 0
## Set > 0 to let the AI play both sides and quit after N seconds (smoke-test / attract mode).
@export var autoplay_seconds: float = 0.0

const HUMAN_SIDE: int = CombatTypes.Side.A

var server: LocalServer
var ui: BattleUI
var _queue: Array[Dictionary] = []
var _playing: bool = false


func _ready() -> void:
	server = LocalServer.new()
	add_child(server)
	ui = BattleUI.new()
	ui.viewer_side = HUMAN_SIDE
	add_child(ui)
	server.events_published.connect(_on_events_published)
	ui.draft_submitted.connect(func(picks: Array[int]) -> void: server.request_draft(HUMAN_SIDE, picks))
	ui.actions_locked.connect(func(actions: Dictionary) -> void: server.lock_actions(HUMAN_SIDE, actions))
	ui.replacement_requested.connect(func(slot: int, bench: int) -> void: server.choose_replacement(HUMAN_SIDE, slot, bench))
	ui.restart_requested.connect(_start_match)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--autoplay"):
		autoplay_seconds = 20.0
	if autoplay_seconds > 0.0:
		ui.playback_speed = 8.0
		get_tree().create_timer(autoplay_seconds).timeout.connect(_finish_autoplay)
	_start_match()


func _start_match() -> void:
	_queue.clear()
	ui.reset()
	var seed_value: int = match_seed if match_seed != 0 else int(Time.get_unix_time_from_system())
	var ai_sides: Array[int] = [CombatTypes.Side.B]
	if autoplay_seconds > 0.0:
		ai_sides = [CombatTypes.Side.A, CombatTypes.Side.B]
	server.start_match(seed_value, TroopRegistry.default_squad(CombatTypes.Side.A), TroopRegistry.default_squad(CombatTypes.Side.B), ai_sides, HUMAN_SIDE)


func _on_events_published(events: Array[Dictionary], snapshot: Dictionary) -> void:
	_queue.append({"events": events, "snapshot": snapshot})
	if not _playing:
		_play_queue()


func _play_queue() -> void:
	_playing = true
	ui.set_input_locked(true)
	while not _queue.is_empty():
		var batch: Dictionary = _queue.pop_front()
		for e: Dictionary in batch["events"]:
			await ui.play_event(e)
		ui.apply_snapshot(batch["snapshot"])
		server.client_ready()
	_playing = false
	ui.set_input_locked(false)


func _finish_autoplay() -> void:
	var st: CombatState = server.engine.state
	print("autoplay: phase=%s cycle=%d turn=%d winner=%d" % [CombatTypes.Phase.keys()[st.phase], st.cycle, st.turn_count, st.winner])
	get_tree().quit(0)
