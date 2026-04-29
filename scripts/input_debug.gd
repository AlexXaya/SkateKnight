extends CanvasLayer

@onready var _label := Label.new()

func _ready() -> void:
	_label.position = Vector2(18, 110)
	_label.text = "Input debug: (waiting)"
	add_child(_label)

func _process(_delta: float) -> void:
	var parts: Array[String] = []

	for action in ["move_left", "move_right", "jump", "slide", "boost", "pause"]:
		if Input.is_action_pressed(action):
			parts.append(action)

	if parts.is_empty():
		_label.text = "Input debug: (no actions pressed)"
	else:
		_label.text = "Input debug: " + ", ".join(parts)

