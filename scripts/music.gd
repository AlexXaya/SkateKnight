extends Node

@export var music_path: String = "res://Skateboard Knight Chase.mp3" # gameplay (legacy name)
@export var start_screen_music_path: String = "res://Ramparts On Wheels.mp3"
@export var game_over_music_path: String = "res://Ashen Crown.mp3"

var _player: AudioStreamPlayer
var _volume_linear: float = 0.85
var _current_music_path: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.autoplay = false
	_player.finished.connect(_on_finished)
	add_child(_player)

	_load_stream(music_path)
	set_volume_linear(_volume_linear)
	play()

func _load_stream(path: String) -> void:
	if path.is_empty():
		return
	if not ResourceLoader.exists(path):
		push_warning("Music file not found: %s" % path)
		return
	var s := load(path)
	_player.stream = s
	_current_music_path = path

func _switch_to(path: String) -> void:
	if _player == null:
		return
	if path.is_empty():
		return
	if path == _current_music_path and _player.stream != null:
		play()
		return

	var was_playing := _player.playing
	stop()
	_load_stream(path)
	if was_playing:
		play()

func _on_finished() -> void:
	# Loop reliably regardless of stream type/import settings.
	play()

func play() -> void:
	if _player == null or _player.stream == null:
		return
	if not _player.playing:
		_player.play()

func stop() -> void:
	if _player:
		_player.stop()

func play_gameplay() -> void:
	_switch_to(music_path)

func play_start_screen() -> void:
	_switch_to(start_screen_music_path)

func play_game_over() -> void:
	_switch_to(game_over_music_path)

func set_volume_linear(v: float) -> void:
	_volume_linear = clampf(v, 0.0, 1.0)
	if _player:
		_player.volume_db = linear_to_db(_volume_linear)

func get_volume_linear() -> float:
	return _volume_linear

