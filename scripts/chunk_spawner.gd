extends Node3D

@export var player_path: NodePath
@export var chunk_scene: PackedScene
@export var chunk_length: float = 32.0
@export var chunks_ahead: int = 8
@export var chunks_behind: int = 2
@export var min_obstacle_spawn_chance: float = 0.75
@export var obstacle_spawn_chance: float = 1.0
@export var difficulty_ramp_seconds: float = 90.0
@export var obstacle_z_jitter: float = 3.0
@export var obstacle_min_local_z_spacing: float = 1.0
@export var min_rubble_spacing_z: float = 0.0
@export var floor_clearance_y: float = 0.18
@export var rebase_threshold_z: float = 220.0
@export var rebase_shift_z: float = 160.0
@export var powerup_spawn_interval_s: float = 15.0
@export var powerup_duration_s: float = 5.0
@export var powerup_spawn_ahead_z: float = 70.0
@export var powerup_pickup_y: float = 1.4

var _player: Node3D
var _spawned: Array[Node3D] = []
var _next_z: float = 0.0
var _rng := RandomNumberGenerator.new()
var _last_rubble_spawn_z: float = -1000000.0
var _run_time_s: float = 0.0
var _powerup_timer_s: float = 0.0

const POWERUP_SCENE_SCRIPT := preload("res://scripts/powerup_pickup.gd")
const POWERUP_TYPES: Array[String] = ["magnet", "invincible", "double"]

const POWERUP_MAT_BLUE := preload("res://materials/powerup_glow_blue.tres")
const POWERUP_MAT_GREEN := preload("res://materials/powerup_glow_green.tres")
const POWERUP_MAT_ORANGE := preload("res://materials/powerup_glow_orange.tres")
const POWERUP_MAGNET_SCENE := preload("res://scenes/props/magnet_u.tscn")

func _ready() -> void:
	_player = get_node(player_path) as Node3D
	_rng.randomize()
	_spawned.clear()
	_next_z = 0.0
	_run_time_s = 0.0
	_powerup_timer_s = 0.0
	_seed_initial()

func _process(_delta: float) -> void:
	if _player == null:
		return
	_run_time_s += _delta
	_powerup_timer_s += _delta
	_ensure_ahead()
	_cull_behind()
	_spawn_timed_powerup()
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
	_spread_rubble_in_chunk(chunk, _next_z)
	_randomize_chunk_lanes(chunk)
	_build_coin_trail(chunk)
	_tag_camera_ignore(chunk)
	add_child(chunk)
	chunk.global_position = Vector3(0.0, 0.0, _next_z)
	_spawned.append(chunk)
	_next_z += chunk_length

func _spread_rubble_in_chunk(chunk: Node3D, chunk_origin_z: float) -> void:
	var obstacles := chunk.get_node_or_null("Obstacles")
	if obstacles == null:
		return
	for child in obstacles.get_children():
		var obstacle := child as Node3D
		if obstacle == null:
			continue
		if not obstacle.name.begins_with("RubbleLow"):
			continue
		var rubble_z := chunk_origin_z + obstacle.position.z
		if rubble_z - _last_rubble_spawn_z < min_rubble_spacing_z:
			obstacle.queue_free()
			continue
		_last_rubble_spawn_z = rubble_z

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
	var obstacles := chunk.get_node_or_null("Obstacles")
	if obstacles != null:
		var spawn_chance := _current_obstacle_spawn_chance()
		var floor_top_y := _get_floor_top_local_y(chunk)
		var used_z: Array[float] = []
		for child in obstacles.get_children():
			if child is Node3D:
				var obstacle := child as Node3D
				if _rng.randf() > spawn_chance:
					obstacle.queue_free()
					continue
				# Ensure obstacles always despawn on hit (runtime guarantee).
				if obstacle is Node:
					(obstacle as Node).add_to_group("despawn_on_hit")
				_set_node_lane(obstacle, lane_x[_rng.randi_range(0, lane_x.size() - 1)])
				_jitter_obstacle_z(obstacle, used_z)
				_ensure_above_floor_local(obstacle, floor_top_y)

func _jitter_obstacle_z(obstacle: Node3D, used_z: Array[float]) -> void:
	if obstacle_z_jitter <= 0.0:
		used_z.append(obstacle.position.z)
		return
	var base_z := obstacle.position.z
	var z := base_z
	for _i in range(8):
		z = base_z + _rng.randf_range(-obstacle_z_jitter, obstacle_z_jitter)
		var overlaps := false
		for other_z in used_z:
			if absf(z - other_z) < obstacle_min_local_z_spacing:
				overlaps = true
				break
		if not overlaps:
			break
	obstacle.position.z = z
	used_z.append(z)

func _current_obstacle_spawn_chance() -> float:
	if difficulty_ramp_seconds <= 0.0:
		return clampf(obstacle_spawn_chance, 0.0, 1.0)
	var t := clampf(_run_time_s / difficulty_ramp_seconds, 0.0, 1.0)
	return lerpf(clampf(min_obstacle_spawn_chance, 0.0, 1.0), clampf(obstacle_spawn_chance, 0.0, 1.0), t)

func _build_coin_trail(chunk: Node3D) -> void:
	var coins := chunk.get_node_or_null("Coins") as Node3D
	if coins == null:
		return
	var lane_x := _lane_positions()
	if lane_x.is_empty():
		return
	var template := coins.get_child(0) as Node3D
	if template == null:
		return

	for c in coins.get_children():
		c.queue_free()

	var coin_count := 20
	var lane_idx := _rng.randi_range(0, lane_x.size() - 1)
	var z_start := -15.0
	var z_step := 1.7
	for i in range(coin_count):
		# Keep coins in a continuous line; only occasionally drift lanes.
		if i > 0 and i % 5 == 0:
			lane_idx = clampi(lane_idx + _rng.randi_range(-1, 1), 0, lane_x.size() - 1)
		var z := z_start + z_step * float(i)
		var x := lane_x[lane_idx]
		var y := _coin_height_for_context(chunk, x, z)
		var coin := template.duplicate() as Node3D
		coins.add_child(coin)
		coin.position = Vector3(x, y, z)

func _coin_height_for_context(chunk: Node3D, lane_x: float, z: float) -> float:
	var base_y := 1.2
	var obstacles := chunk.get_node_or_null("Obstacles")
	if obstacles == null:
		return base_y
	for child in obstacles.get_children():
		var obstacle := child as Node3D
		if obstacle == null:
			continue
		if absf(obstacle.position.x - lane_x) > 0.7:
			continue
		if absf(obstacle.position.z - z) > 1.9:
			continue
		if obstacle.name.begins_with("BeamHigh"):
			return 0.7
		if obstacle.name.begins_with("RubbleLow"):
			return 2.45
	return base_y

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
	for n in get_tree().get_nodes_in_group("powerup_pickup"):
		var p := n as Node3D
		if p != null and p.global_position.z < min_keep_z - chunk_length:
			p.queue_free()

func _spawn_timed_powerup() -> void:
	if _player == null:
		return
	if powerup_spawn_interval_s <= 0.0:
		return
	if _powerup_timer_s < powerup_spawn_interval_s:
		return
	_powerup_timer_s = 0.0
	_spawn_powerup()

func _spawn_powerup() -> void:
	var lane_x := _lane_positions()
	if lane_x.is_empty():
		return
	var powerup_type: String = POWERUP_TYPES[_rng.randi_range(0, POWERUP_TYPES.size() - 1)]
	var area := Area3D.new()
	area.script = POWERUP_SCENE_SCRIPT
	area.set("powerup_type", powerup_type)
	add_child(area)

	var lane := lane_x[_rng.randi_range(0, lane_x.size() - 1)]
	var spawn_z := _player.global_position.z + maxf(chunk_length, powerup_spawn_ahead_z) + _rng.randf_range(-4.0, 6.0)
	area.global_position = Vector3(lane, powerup_pickup_y, spawn_z)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	collision.shape = shape
	area.add_child(collision)

	var visual := Node3D.new()
	visual.name = "Visual"
	area.add_child(visual)

	if powerup_type == "magnet" and POWERUP_MAGNET_SCENE != null:
		var magnet := POWERUP_MAGNET_SCENE.instantiate() as Node3D
		visual.add_child(magnet)
	else:
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh"
		var sphere := SphereMesh.new()
		sphere.radius = 0.45
		sphere.height = 0.9
		mesh.mesh = sphere
		mesh.material_override = _powerup_material(powerup_type)
		visual.add_child(mesh)

func _powerup_material(powerup_type: String) -> Material:
	match powerup_type:
		"magnet":
			return POWERUP_MAT_BLUE
		"invincible":
			return POWERUP_MAT_GREEN
		"double":
			return POWERUP_MAT_ORANGE
		_:
			return POWERUP_MAT_BLUE

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
	for n in get_tree().get_nodes_in_group("powerup_pickup"):
		var p := n as Node3D
		if p != null:
			p.global_position = p.global_position - Vector3(0, 0, shift)

	# Maintain internal spawn cursor.
	_next_z -= shift
	_last_rubble_spawn_z -= shift

	# Keep run distance continuous.
	var rm := parent.get_node_or_null("RunManager")
	if rm != null and rm.has_method("apply_world_rebase"):
		rm.call("apply_world_rebase", shift)
