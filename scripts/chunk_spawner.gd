extends Node3D

@export var player_path: NodePath
@export var chunk_scene: PackedScene
@export var chunk_length: float = 32.0
@export var chunks_ahead: int = 8
@export var chunks_behind: int = 2

var _player: Node3D
var _spawned: Array[Node3D] = []
var _next_z: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_player = get_node(player_path) as Node3D
	_rng.randomize()
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
	_randomize_chunk_lanes(chunk)
	add_child(chunk)
	chunk.global_position = Vector3(0.0, 0.0, _next_z)
	_spawned.append(chunk)
	_next_z += chunk_length

func _randomize_chunk_lanes(chunk: Node3D) -> void:
	var lane_x := _lane_positions()
	if lane_x.is_empty():
		return

	var coins := chunk.get_node_or_null("Coins")
	if coins != null:
		for child in coins.get_children():
			if child is Node3D:
				_set_node_lane(child as Node3D, lane_x[_rng.randi_range(0, lane_x.size() - 1)])

	var obstacles := chunk.get_node_or_null("Obstacles")
	if obstacles != null:
		for child in obstacles.get_children():
			if child is Node3D:
				var obstacle := child as Node3D
				_set_node_lane(obstacle, lane_x[_rng.randi_range(0, lane_x.size() - 1)])
				_ensure_above_floor(obstacle)

func _set_node_lane(node: Node3D, lane_x: float) -> void:
	var pos := node.position
	node.position = Vector3(lane_x, pos.y, pos.z)

func _ensure_above_floor(obstacle: Node3D) -> void:
	var shape_node := obstacle.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		return
	var box := shape_node.shape as BoxShape3D
	if box == null:
		return
	var floor_top := 0.5
	var min_y := floor_top + box.size.y * 0.5 + 0.02
	if obstacle.position.y < min_y:
		obstacle.position.y = min_y

func _lane_positions() -> Array[float]:
	var lanes := int(_player.get("lanes")) if _player != null else 4
	var lane_width := float(_player.get("lane_width")) if _player != null else 2.0
	lanes = max(1, lanes)

	var result: Array[float] = []
	var center := (float(lanes) - 1.0) * 0.5
	for i in range(lanes):
		result.append((float(i) - center) * lane_width)
	return result

func _cull_behind() -> void:
	var min_keep_z := _player.global_position.z - chunk_length * float(chunks_behind)
	while _spawned.size() > 0 and _spawned[0].global_position.z + chunk_length < min_keep_z:
		var old_chunk: Node3D = _spawned[0]
		_spawned.remove_at(0)
		old_chunk.queue_free()

