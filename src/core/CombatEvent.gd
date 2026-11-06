class_name CombatEvent
extends RefCounted
## One entry of the ordered execution log the engine hands to presentation.

var type: CombatTypes.EventType = CombatTypes.EventType.BATTLE_STARTED
var actor: int = -1
var target: int = -1
var value: float = 0.0
var data: Dictionary = {}


func _init(p_type: CombatTypes.EventType, p_actor: int = -1, p_target: int = -1, p_value: float = 0.0, p_data: Dictionary = {}) -> void:
	type = p_type
	actor = p_actor
	target = p_target
	value = p_value
	data = p_data


func type_name() -> String:
	return CombatTypes.EventType.keys()[type]


## Plain-data form, safe to send over RPC.
func to_dict() -> Dictionary:
	return {"type": int(type), "name": type_name(), "actor": actor, "target": target, "value": value, "data": data.duplicate(true)}
