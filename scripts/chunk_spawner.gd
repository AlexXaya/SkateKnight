extends Node3D

@export var player_path: NodePath
@export var chunk_scene: PackedScene
@export var chunk_length: float = 32.0
@export var chunks_ahead: int = 8
@export var chunks_behind: int = 2
@export var floor_clearance_y: float = 0.18
@export var rebase_threshold_z: float = 220.0
@export var rebase_shift_z: float = 160.0

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
	_maybe_rebase_world()

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
	_tag_camera_ignore(chunk)
	add_child(chunk)
	chunk.global_position = Vector3(0.0, 0.0, _next_z)
	_spawned.append(chunk)
	_next_z += chunk_length

func _tag_camera_ignore(chunk: Node3D) -> void:
	# Infinite-runner floor should never affect camera collision avoidance.
	var floor := chunk.get_node_or_null("Floor")
	if floor is Node:
		(floor as Node).add_to_group("camera_ignore")

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
		var floor_top_y := _get_floor_top_local_y(chunk)
		for child in obstacles.get_children():
			if child is Node3D:
				var obstacle := child as Node3D
				# Ensure obstacles always despawn on hit (runtime guarantee).
				if obstacle is Node:
					(obstacle as Node).add_to_group("despawn_on_hit")
				_set_node_lane(obstacle, lane_x[_rng.randi_range(0, lane_x.size() - 1)])
				_ensure_above_floor_local(obstacle, floor_top_y)

func _set_node_lane(node: Node3D, lane_x: float) -> void:
	var pos := node.position
	node.position = Vector3(lane_x, pos.y, pos.z)

func _get_floor_top_local_y(chunk: Node3D) -> float:
	# Compute floor top in the chunk's local space.
	var floor := chunk.get_node_or_null("Floor") as Node3D
	var col := chunk.get_node_or_null("Floor/FloorCollision") as CollisionShape3D
	if floor != null and col != null:
		var box := col.shape as BoxShape3D
		if box != null:
			var half_y := box.size.y * 0.5 * floor.transform.basis.get_scale().y
			return floor.position.y + half_y
	return 0.5

func _ensure_above_floor_local(obstacle: Node3D, floor_top_local_y: float) -> void:
	var shape_node := obstacle.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		return
	var box := shape_node.shape as BoxShape3D
	if box == null:
		return
	var obstacle_scale_y := obstacle.transform.basis.get_scale().y
	var min_y := floor_top_local_y + (box.size.y * 0.5 * obstacle_scale_y) + floor_clearance_y
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

func _maybe_rebase_world() -> void:
	# Floating origin: keep Z values small to avoid depth precision artifacts
	# that make the floor "cut" objects at mid distance.
	if rebase_shift_z <= 0.0:
		return
	if _player.global_position.z < rebase_threshold_z:
		return

	var shift := rebase_shift_z

	# Shift player and camera rig (if present) to avoid visual popping.
	var parent := get_parent()
	if _player:
		_player.global_position = _player.global_position - Vector3(0, 0, shift)
	var camera_rig := parent.get_node_or_null("CameraRig") as Node3D
	if camera_rig:
		camera_rig.global_position = camera_rig.global_position - Vector3(0, 0, shift)

	# Shift all spawned chunks.
	for c in _spawned:
		if c:
			c.global_position = c.global_position - Vector3(0, 0, shift)

	# Maintain internal spawn cursor.
	_next_z -= shift

	# Keep run distance continuous.
	var rm := parent.get_node_or_null("RunManager")
	if rm != null and rm.has_method("apply_world_rebase"):
		rm.call("apply_world_rebase", shift)
