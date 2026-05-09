extends CharacterBody3D

signal crashed
signal coin_collected(amount: int)

@export var lanes: int = 4
@export var lane_width: float = 2.0
@export var lane_change_speed: float = 18.0
@export var forward_speed: float = 14.0
@export var max_forward_speed: float = 28.0
@export var forward_accel: float = 0.15
@export var invert_lane_controls: bool = false

@export var jump_velocity: float = 9.5
@export var gravity: float = 22.0
@export var air_down_gravity_multiplier: float = 2.0
@export var powerup_duration_s: float = 5.0
@export var coin_magnet_radius: float = 9.0
@export var coin_magnet_strength: float = 55.0
@export var invincible_break_bonus_coins: int = 2

@export var slide_duration_s: float = 0.65
@export var slide_height_scale: float = 0.55

var _lane_index := 1
var _target_x := 0.0
var _slide_t := 0.0
var _is_sliding := false
var _capsule_height_default := 0.0
var _debug_invulnerable := false
var _last_crash_ms: int = -1000000
@export var crash_debounce_ms: int = 800
var _coin_magnet_t := 0.0
var _invincible_t := 0.0
var _double_coins_t := 0.0

@onready var _collider: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual

func _ready() -> void:
	add_to_group("player")
	_lane_index = clampi(_lane_index, 0, lanes - 1)
	_target_x = _lane_x(_lane_index)
	position.x = _target_x
	var shape := _collider.shape
	if shape is CapsuleShape3D:
		_capsule_height_default = (shape as CapsuleShape3D).height

	var skins := get_node_or_null("/root/PlayerSkins")
	if skins != null and skins.has_method("apply_to_player"):
		skins.call("apply_to_player", self)

func _physics_process(delta: float) -> void:
	_handle_input(delta)

	velocity.z = _current_forward_speed()
	var gravity_scale := 1.0
	if not is_on_floor() and Input.is_action_pressed("slide"):
		gravity_scale = air_down_gravity_multiplier
	velocity.y -= gravity * gravity_scale * delta

	var next_x := move_toward(position.x, _target_x, lane_change_speed * delta)
	position.x = next_x

	var prev_vel_y := velocity.y
	move_and_slide()
	_tick_powerups(delta)

	# Basic “bonk” crash: if we hit something head-on (body collision), end run.
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		# Ignore floor/ground contacts.
		if col.get_normal().y > 0.7:
			continue
		# If we’re grounded and had a positive Y velocity, it was a landing; don’t crash.
		if is_on_floor() and prev_vel_y > 0.0:
			continue

		# Some obstacles should disappear on hit to prevent "stuck" collisions.
		_try_despawn_on_hit(col)
		if _is_invincible_active():
			continue

		var now_ms := Time.get_ticks_msec()
		if now_ms - _last_crash_ms >= crash_debounce_ms:
			_last_crash_ms = now_ms
			var sfx := get_node_or_null("/root/Sfx")
			if sfx != null and sfx.has_method("play_hurt"):
				sfx.call("play_hurt")
			crashed.emit()
		break

func _try_despawn_on_hit(col) -> void:
	var obj = col.get_collider()
	var node := obj as Node
	if node == null:
		return

	# Walk up to find a tagged parent (e.g. collider could be a child).
	while node != null:
		if node.is_in_group("despawn_on_hit"):
			if _is_invincible_active() and invincible_break_bonus_coins > 0:
				add_coins(invincible_break_bonus_coins)
			node.queue_free()
			return
		node = node.get_parent()

func _handle_input(delta: float) -> void:
	if Input.is_action_just_pressed("debug_toggle_invulnerable"):
		_debug_invulnerable = not _debug_invulnerable
		print("Debug invulnerable: ", _debug_invulnerable)

	var dir := -1 if not invert_lane_controls else 1
	if Input.is_action_just_pressed("move_left"):
		_set_lane(_lane_index + dir)
	if Input.is_action_just_pressed("move_right"):
		_set_lane(_lane_index - dir)

	if Input.is_action_just_pressed("jump") and is_on_floor() and not _is_sliding:
		velocity.y = jump_velocity
		var sfx := get_node_or_null("/root/Sfx")
		if sfx != null and sfx.has_method("play_jump"):
			sfx.call("play_jump")

	if Input.is_action_just_pressed("slide") and is_on_floor() and not _is_sliding:
		_begin_slide()

	if _is_sliding:
		_slide_t -= delta
		if _slide_t <= 0.0:
			_end_slide()

func _set_lane(new_index: int) -> void:
	_lane_index = clampi(new_index, 0, lanes - 1)
	_target_x = _lane_x(_lane_index)

func _lane_x(index: int) -> float:
	# For 4 lanes and width 2: [-3, -1, 1, 3]
	var center := (lanes - 1) * 0.5
	return (float(index) - center) * lane_width

func _current_forward_speed() -> float:
	forward_speed = minf(max_forward_speed, forward_speed + forward_accel * get_physics_process_delta_time())
	return forward_speed

func _begin_slide() -> void:
	_is_sliding = true
	_slide_t = slide_duration_s
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null and sfx.has_method("play_slide"):
		sfx.call("play_slide")
	# Scale visuals and collider to fit under “high” obstacles.
	_visual.scale.y = slide_height_scale
	var shape := _collider.shape
	if shape is CapsuleShape3D:
		(shape as CapsuleShape3D).height = _capsule_height_default * slide_height_scale

func _end_slide() -> void:
	_is_sliding = false
	_visual.scale.y = 1.0
	var shape := _collider.shape
	if shape is CapsuleShape3D:
		(shape as CapsuleShape3D).height = (_capsule_height_default if _capsule_height_default > 0.0 else 1.4)

func add_coins(amount: int) -> void:
	var final_amount := amount
	if _double_coins_t > 0.0:
		final_amount *= 2
	coin_collected.emit(final_amount)

func activate_powerup(powerup_type: String) -> void:
	var duration := maxf(0.1, powerup_duration_s)
	match powerup_type:
		"magnet":
			_coin_magnet_t = duration
		"invincible":
			_invincible_t = duration
		"double":
			_double_coins_t = duration
		_:
			return
	print("Powerup: ", powerup_type, " (", duration, "s)")

func _tick_powerups(delta: float) -> void:
	_coin_magnet_t = maxf(0.0, _coin_magnet_t - delta)
	_invincible_t = maxf(0.0, _invincible_t - delta)
	_double_coins_t = maxf(0.0, _double_coins_t - delta)
	if _coin_magnet_t > 0.0:
		_attract_nearby_coins(delta)

func _attract_nearby_coins(delta: float) -> void:
	var max_dist := maxf(0.1, coin_magnet_radius)
	for n in get_tree().get_nodes_in_group("coin_pickup"):
		var coin := n as Node3D
		if coin == null:
			continue
		var to_player := global_position - coin.global_position
		var dist := to_player.length()
		if dist <= 0.001 or dist > max_dist:
			continue
		var pull := coin_magnet_strength * (1.0 - dist / max_dist)
		coin.global_position += to_player.normalized() * pull * delta

func _is_invincible_active() -> bool:
	return _debug_invulnerable or _invincible_t > 0.0
