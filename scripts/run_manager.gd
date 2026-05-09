extends Node

@export var player_path: NodePath
@export var danger_window_s: float = 6.0

var coins: int = 0
var score: int = 0
var best_distance: float = 0.0

var _player: Node3D
var _start_z: float = 0.0
var _is_running := true
var _danger_active := false
var _danger_until_s: float = 0.0
var _danger_hits: int = 0

signal run_over
signal stats_changed(coins: int, score: int, distance: float)
signal danger_changed(active: bool)
signal coin_pickup(amount: int)

func _ready() -> void:
	_player = get_node(player_path) as Node3D
	_start_z = _player.global_position.z if _player != null else 0.0
	if _player != null:
		if _player.has_signal("coin_collected"):
			_player.connect("coin_collected", _on_coin_collected)
		if _player.has_signal("crashed"):
			_player.connect("crashed", _on_crashed)

func _process(_delta: float) -> void:
	if not _is_running or _player == null:
		return
	var distance := maxf(0.0, _player.global_position.z - _start_z)
	best_distance = maxf(best_distance, distance)
	score = int(distance) + coins * 5
	stats_changed.emit(coins, score, distance)

	# Clear danger state after the window expires.
	if _danger_active:
		var now_s := float(Time.get_ticks_msec()) / 1000.0
		if now_s >= _danger_until_s:
			_danger_active = false
			_danger_hits = 0
			danger_changed.emit(false)

func _on_coin_collected(amount: int) -> void:
	coins += amount
	coin_pickup.emit(amount)

func _on_crashed() -> void:
	if not _is_running:
		return

	var now_s := float(Time.get_ticks_msec()) / 1000.0

	# If the danger window already expired, treat this as a first hit.
	if _danger_active and now_s >= _danger_until_s:
		_danger_active = false
		_danger_hits = 0
		danger_changed.emit(false)

	if not _danger_active:
		_danger_active = true
		_danger_hits = 1
		_danger_until_s = now_s + maxf(0.1, danger_window_s)
		danger_changed.emit(true)
		return

	# Second hit within the active window => lose.
	_danger_hits += 1
	if _danger_hits >= 2 and now_s < _danger_until_s:
		_is_running = false
		_danger_active = false
		_danger_hits = 0
		danger_changed.emit(false)
		run_over.emit()

func apply_world_rebase(shift_z: float) -> void:
	# Keep distance/score continuous when the world is shifted back toward origin.
	_start_z -= shift_z

