extends Node3D

@export var player_path: NodePath
@export var chunk_scene: PackedScene
@export var chunk_length: float = 32.0
@export var chunks_ahead: int = 8
@export var chunks_behind: int = 2

var _player: Node3D
var _spawned: Array[Node3D] = []
var _next_z: float = 0.0

func _ready() -> void:
	_player = get_node(player_path) as Node3D
	_spawned.clear()
	_next_z = 0.0
	_seed_initial()

func _process(_delta: float) -> void:
	if _player == null:
		return
	_ensure_ahead()
	_cull_behind()

func _seed_initial() -> void:
	for _i in range(chunks_ahead):
		_spawn_one()

func _ensure_ahead() -> void:
	var needed_z := _player.global_position.z + chunk_length * float(chunks_ahead)
	while _next_z < needed_z:
		_spawn_one()

func _spawn_one() -> void:
	if chunk_scene == null:
		return
	var chunk := chunk_scene.instantiate() as Node3D
	add_child(chunk)
	chunk.global_position = Vector3(0.0, 0.0, _next_z)
	_spawned.append(chunk)
	_next_z += chunk_length

func _cull_behind() -> void:
	var min_keep_z := _player.global_position.z - chunk_length * float(chunks_behind)
	while _spawned.size() > 0 and _spawned[0].global_position.z + chunk_length < min_keep_z:
		var old := _spawned.pop_front()
	old.queue_free()

