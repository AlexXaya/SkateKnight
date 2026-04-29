extends Node

@export var player_path: NodePath

var coins: int = 0
var score: int = 0
var best_distance: float = 0.0

var _player: Node3D
var _start_z: float = 0.0
var _is_running := true

signal run_over
signal stats_changed(coins: int, score: int, distance: float)

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

func _on_coin_collected(amount: int) -> void:
	coins += amount

func _on_crashed() -> void:
	if not _is_running:
		return
	_is_running = false
	run_over.emit()

