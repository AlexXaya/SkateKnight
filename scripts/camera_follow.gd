extends Node3D

@export var target_path: NodePath
@export var offset: Vector3 = Vector3(0, 4.0, -8.5)
@export var smoothness: float = 10.0

var _target: Node3D

func _ready() -> void:
	_target = get_node(target_path) as Node3D

func _process(delta: float) -> void:
	if _target == null:
		return
	var desired := _target.global_position + offset
	global_position = global_position.lerp(desired, 1.0 - exp(-smoothness * delta))

