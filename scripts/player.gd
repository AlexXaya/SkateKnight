extends CharacterBody3D

signal crashed
signal coin_collected(amount: int)
signal trick_scored(points: int)
## Emitted when the invincible (green shield) powerup destroys a despawn_on_hit obstacle.
signal obstacle_break_scored(points: int)

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
## Extra score (not coins) each time shield destroys an obstacle while invincible.
@export var invincible_break_bonus_score: int = 12

@export var slide_duration_s: float = 0.65
@export var slide_height_scale: float = 0.55

## Second press within this window counts as a double-tap (ms).
@export var trick_double_tap_window_ms: int = 380
@export var flip_trick_bonus: int = 35
@export var wall_spin_trick_bonus: int = 50
## Time to complete one full visual rotation during a trick.
@export var trick_spin_duration_s: float = 0.22
@export var trick_cooldown_s: float = 0.32
@export var ground_jump_repeat_block_ms: int = 140

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

var _last_jump_tap_ms: int = -1_000_000
## Double-tap chains for “steer toward min lane” / “steer toward max lane” (swap keys when invert_lane_controls).
var _last_toward_min_lane_ms: int = -1_000_000
var _prev_toward_min_at_left_wall: bool = false
var _last_toward_max_lane_ms: int = -1_000_000
var _prev_toward_max_at_right_wall: bool = false
var _trick_spin_deg_remaining: float = 0.0
var _trick_spin_axis: Vector3 = Vector3.RIGHT
var _trick_cooldown_t: float = 0.0
## Blocks spamming jump while still grounded from the previous impulse.
var _last_ground_jump_ms: int = -1_000_000

@onready var _collider: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual
@onready var _invincible_bubble: Node3D = $Visual/InvincibleBubble

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
	_trick_cooldown_t = maxf(0.0, _trick_cooldown_t - delta)
	_trick_tick(delta)

	velocity.x = 0.0
	velocity.z = _current_forward_speed()
	var gravity_scale := 1.0
	if not is_on_floor() and Input.is_action_pressed("slide"):
		gravity_scale = air_down_gravity_multiplier
	velocity.y -= gravity * gravity_scale * delta

	var prev_vel_y := velocity.y
	move_and_slide()

	# Lane X after physics so wall/slide collision response can't fight strafe (fixes sluggish lane changes).
	var max_lane_step := lane_change_speed * delta
	position.x = move_toward(position.x, _target_x, max_lane_step)
	if absf(position.x - _target_x) < 0.02:
		position.x = _target_x
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
			if _is_invincible_active():
				if invincible_break_bonus_coins > 0:
					add_coins(invincible_break_bonus_coins)
				if invincible_break_bonus_score > 0:
					obstacle_break_scored.emit(invincible_break_bonus_score)
			node.queue_free()
			return
		node = node.get_parent()

func _handle_input(delta: float) -> void:
	if Input.is_action_just_pressed("debug_toggle_invulnerable"):
		_debug_invulnerable = not _debug_invulnerable
		print("Debug invulnerable: ", _debug_invulnerable)

	var dir := -1 if not invert_lane_controls else 1
	if Input.is_action_just_pressed("move_left"):
		var now_ms := Time.get_ticks_msec()
		var wall_spin := false
		if not invert_lane_controls:
			# move_left → lower lane index → toward left wall.
			var at_left := _lane_index == 0
			if _is_double_tap_ms(_last_toward_min_lane_ms, now_ms) and at_left and _prev_toward_min_at_left_wall and _can_start_trick():
				_start_wall_spin_trick()
				wall_spin = true
			_prev_toward_min_at_left_wall = at_left
			_last_toward_min_lane_ms = now_ms
		else:
			# Inverted: move_left → higher lane index → toward right wall.
			var at_right := _lane_index == lanes - 1
			if _is_double_tap_ms(_last_toward_max_lane_ms, now_ms) and at_right and _prev_toward_max_at_right_wall and _can_start_trick():
				_start_wall_spin_trick()
				wall_spin = true
			_prev_toward_max_at_right_wall = at_right
			_last_toward_max_lane_ms = now_ms
		if not wall_spin:
			_set_lane(_lane_index + dir)

	if Input.is_action_just_pressed("move_right"):
		var now_ms_r := Time.get_ticks_msec()
		var wall_spin_r := false
		if not invert_lane_controls:
			var at_right := _lane_index == lanes - 1
			if _is_double_tap_ms(_last_toward_max_lane_ms, now_ms_r) and at_right and _prev_toward_max_at_right_wall and _can_start_trick():
				_start_wall_spin_trick()
				wall_spin_r = true
			_prev_toward_max_at_right_wall = at_right
			_last_toward_max_lane_ms = now_ms_r
		else:
			var at_left := _lane_index == 0
			if _is_double_tap_ms(_last_toward_min_lane_ms, now_ms_r) and at_left and _prev_toward_min_at_left_wall and _can_start_trick():
				_start_wall_spin_trick()
				wall_spin_r = true
			_prev_toward_min_at_left_wall = at_left
			_last_toward_min_lane_ms = now_ms_r
		if not wall_spin_r:
			_set_lane(_lane_index - dir)

	if Input.is_action_just_pressed("jump"):
		var now_j := Time.get_ticks_msec()
		if _is_double_tap_ms(_last_jump_tap_ms, now_j) and not is_on_floor() and _can_start_trick():
			_start_flip_trick()
		else:
			if is_on_floor() and not _is_sliding:
				if now_j - _last_ground_jump_ms >= ground_jump_repeat_block_ms:
					velocity.y = jump_velocity
					_last_ground_jump_ms = now_j
					var sfx := get_node_or_null("/root/Sfx")
					if sfx != null and sfx.has_method("play_jump"):
						sfx.call("play_jump")
		_last_jump_tap_ms = now_j

	if Input.is_action_just_pressed("slide") and is_on_floor() and not _is_sliding and _trick_spin_deg_remaining <= 0.0:
		_begin_slide()

	if _is_sliding:
		_slide_t -= delta
		if _slide_t <= 0.0:
			_end_slide()


func _is_double_tap_ms(last_ms: int, now_ms: int) -> bool:
	return now_ms - last_ms <= trick_double_tap_window_ms


func _can_start_trick() -> bool:
	return _trick_spin_deg_remaining <= 0.0 and _trick_cooldown_t <= 0.0 and not _is_sliding


func _start_flip_trick() -> void:
	_trick_spin_axis = Vector3.RIGHT
	_trick_spin_deg_remaining = 360.0
	_trick_cooldown_t = trick_cooldown_s
	trick_scored.emit(flip_trick_bonus)


func _start_wall_spin_trick() -> void:
	_trick_spin_axis = Vector3.UP
	_trick_spin_deg_remaining = 360.0
	_trick_cooldown_t = trick_cooldown_s
	trick_scored.emit(wall_spin_trick_bonus)


func _trick_tick(delta: float) -> void:
	if _trick_spin_deg_remaining <= 0.0:
		return
	var dur := maxf(0.05, trick_spin_duration_s)
	var rate_deg := 360.0 / dur
	var step_deg := minf(_trick_spin_deg_remaining, rate_deg * delta)
	_visual.rotate_object_local(_trick_spin_axis.normalized(), deg_to_rad(step_deg))
	_trick_spin_deg_remaining -= step_deg
	if _trick_spin_deg_remaining <= 0.01:
		_trick_spin_deg_remaining = 0.0
		_visual.rotation = Vector3.ZERO


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
	if _invincible_bubble != null:
		# Only show the bubble for the actual invincible powerup timer (not debug invulnerable).
		_invincible_bubble.visible = _invincible_t > 0.0
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

func get_magnet_remaining_s() -> float:
	return _coin_magnet_t

func get_invincible_remaining_s() -> float:
	return _invincible_t

func get_double_coins_remaining_s() -> float:
	return _double_coins_t
