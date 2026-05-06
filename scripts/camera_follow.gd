extends Node3D

@export var target_path: NodePath
@export var offset: Vector3 = Vector3(0, 4.0, -8.5)
@export var smoothness: float = 10.0
@export var enable_collision_avoidance: bool = false
@export var collision_mask: int = 1
@export var collision_padding: float = 0.35
@export var min_height_above_target: float = 2.2
@export var allow_camera_preset_switch: bool = true
@export var camera_preset_key: Key = KEY_F3

var _camera: Camera3D
var _preset_idx: int = 0

var _target: Node3D

func _ready() -> void:
	_target = get_node(target_path) as Node3D
	_camera = get_node_or_null("Camera3D") as Camera3D
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if not allow_camera_preset_switch:
		return
	if event is InputEventKey:
		var k = event as InputEventKey
		if k.pressed and not k.echo and k.keycode == camera_preset_key:
			_cycle_camera_preset()

func _cycle_camera_preset() -> void:
	# Presets are intentionally dramatic so we can diagnose visibility issues quickly.
	# 0: default-ish chase, 1: higher chase, 2: side chase, 3: top-down-ish.
	var offsets = [
		Vector3(0, 4.0, -13.0),
		Vector3(0, 7.0, -16.0),
		Vector3(8.0, 5.0, -12.0),
		Vector3(0, 14.0, -10.0),
	]
	var rots = [
		Vector3(-18, 180, 0),
		Vector3(-22, 180, 0),
		Vector3(-18, 165, 0),
		Vector3(-55, 180, 0),
	]

	_preset_idx = (_preset_idx + 1) % offsets.size()
	offset = offsets[_preset_idx]
	if _camera != null and _preset_idx < rots.size():
		_camera.rotation_degrees = rots[_preset_idx]
	print("Camera preset %d: offset=%s" % [_preset_idx, str(offset)])

func _process(delta: float) -> void:
	if _target == null:
		return
	var target_pos := _target.global_position
	var desired := target_pos + offset

	if enable_collision_avoidance:
		# Prevent camera from clipping through level geometry by raycasting
		# from the player toward the desired camera point.
		var space := get_world_3d().direct_space_state
		# Start the ray a bit above the player so we don't constantly hit the track floor
		# as chunks stream under us.
		var ray_from := target_pos + Vector3(0, 0.9, 0)
		var query := PhysicsRayQueryParameters3D.create(ray_from, desired)
		query.collision_mask = collision_mask
		query.exclude = [_target]

		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			# Ignore floor-like hits; otherwise the camera correction can make it feel like
			# the ground is being pulled up toward the camera in the infinite runner.
			var hn: Vector3 = hit.get("normal", Vector3.ZERO)
			# Use abs() so underside-of-floor hits are ignored too.
			if absf(hn.y) > 0.7:
				hit = {}

		if not hit.is_empty():
			# Hard ignore anything explicitly tagged (e.g. floor chunks).
			var c0 = hit.get("collider")
			if c0 is Node:
				var nn := c0 as Node
				while nn != null:
					if nn.is_in_group("camera_ignore"):
						hit = {}
						break
					nn = nn.get_parent()

		if not hit.is_empty():
			# Ignore obstacles; otherwise the camera will shove forward during lane changes
			# and clip/cut the player (looks like sinking/half missing).
			var c = hit.get("collider")
			if c is Node and (c as Node).is_in_group("despawn_on_hit"):
				hit = {}
			elif c is Node:
				var n := c as Node
				while n != null:
					if n.is_in_group("despawn_on_hit"):
						hit = {}
						break
					n = n.get_parent()
		
		if not hit.is_empty():
			var p: Vector3 = hit.position
			var n: Vector3 = hit.normal
			desired = p + n * collision_padding

	# Absolute safety: never allow camera to be pushed too low, which can put the
	# camera under the track and make the floor occlude half the scene.
	desired.y = maxf(desired.y, target_pos.y + min_height_above_target)

	global_position = global_position.lerp(desired, 1.0 - exp(-smoothness * delta))

