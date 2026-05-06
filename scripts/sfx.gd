extends Node

@export var jump_sfx_path: String = "res://Jump_sfx.mp3"

var _player: AudioStreamPlayer
var _jump_stream: AudioStream
var _volume_linear: float = 0.9

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = AudioStreamPlayer.new()
	_player.name = "SfxPlayer"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.autoplay = false
	_player.max_polyphony = 8
	add_child(_player)

	_load_streams()
	set_volume_linear(_volume_linear)

func _load_streams() -> void:
	if not jump_sfx_path.is_empty() and ResourceLoader.exists(jump_sfx_path):
		_jump_stream = load(jump_sfx_path)
	else:
		_jump_stream = null
		if not jump_sfx_path.is_empty():
			push_warning("Jump SFX file not found: %s" % jump_sfx_path)

func play_jump() -> void:
	if _player == null or _jump_stream == null:
		return
	_player.stream = _jump_stream
	_player.play()

func set_volume_linear(v: float) -> void:
	_volume_linear = clampf(v, 0.0, 1.0)
	if _player:
		_player.volume_db = linear_to_db(_volume_linear)

func get_volume_linear() -> float:
	return _volume_linear

