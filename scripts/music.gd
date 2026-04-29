extends Node

@export var music_path: String = "res://Skateboard Knight Chase.mp3"

var _player: AudioStreamPlayer
var _volume_linear: float = 0.85

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.autoplay = false
	_player.finished.connect(_on_finished)
	add_child(_player)

	_load_stream()
	set_volume_linear(_volume_linear)
	play()

func _load_stream() -> void:
	if music_path.is_empty():
		return
	if not ResourceLoader.exists(music_path):
		push_warning("Music file not found: %s" % music_path)
		return
	var s := load(music_path)
	_player.stream = s

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

func set_volume_linear(v: float) -> void:
	_volume_linear = clampf(v, 0.0, 1.0)
	if _player:
		_player.volume_db = linear_to_db(_volume_linear)

func get_volume_linear() -> float:
	return _volume_linear

