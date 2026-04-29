extends Node

func _ready() -> void:
	_ensure_action_keys("move_left", [KEY_A, KEY_LEFT])
	_ensure_action_keys("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action_keys("jump", [KEY_W, KEY_SPACE, KEY_UP])
	_ensure_action_keys("slide", [KEY_S, KEY_DOWN])
	_ensure_action_keys("boost", [KEY_SHIFT, KEY_KP_0]) # second key is just a fallback
	_ensure_action_keys("pause", [KEY_ESCAPE])

func _ensure_action_keys(action: StringName, keycodes: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	# If the project already has bindings, keep them.
	if not InputMap.action_get_events(action).is_empty():
		return

	for code in keycodes:
		var ev := InputEventKey.new()
		ev.keycode = code
		InputMap.action_add_event(action, ev)

