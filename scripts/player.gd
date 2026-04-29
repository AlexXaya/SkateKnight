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

@export var slide_duration_s: float = 0.65
@export var slide_height_scale: float = 0.55

var _lane_index := 1
var _target_x := 0.0
var _slide_t := 0.0
var _is_sliding := false
var _capsule_height_default := 0.0

@onready var _collider: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual

func _ready() -> void:
	_lane_index = clampi(_lane_index, 0, lanes - 1)
	_target_x = _lane_x(_lane_index)
	position.x = _target_x
	var shape := _collider.shape
	if shape is CapsuleShape3D:
		_capsule_height_default = (shape as CapsuleShape3D).height

func _physics_process(delta: float) -> void:
	_handle_input(delta)

	velocity.z = _current_forward_speed()
	velocity.y -= gravity * delta

	var next_x := move_toward(position.x, _target_x, lane_change_speed * delta)
	position.x = next_x

	var prev_vel_y := velocity.y
	move_and_slide()

	# Basic “bonk” crash: if we hit something head-on (body collision), end run.
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		# Ignore floor/ground contacts.
		if col.get_normal().y > 0.7:
			continue
		# If we’re grounded and had a positive Y velocity, it was a landing; don’t crash.
		if is_on_floor() and prev_vel_y > 0.0:
			continue
		crashed.emit()
		break

func _handle_input(delta: float) -> void:
	var dir := -1 if not invert_lane_controls else 1
	if Input.is_action_just_pressed("move_left"):
		_set_lane(_lane_index + dir)
	if Input.is_action_just_pressed("move_right"):
		_set_lane(_lane_index - dir)

	if Input.is_action_just_pressed("jump") and is_on_floor() and not _is_sliding:
		velocity.y = jump_velocity

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
	coin_collected.emit(amount)

