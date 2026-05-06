extends Node

@export var jump_sfx_path: String = "res://Jump_sfx.mp3"
@export var coin_pickup_sfx_path: String = "res://picking-up-items.mp3"
@export var slide_sfx_path: String = "res://dash.mp3"
@export var hurt_sfx_path: String = "res://classic_hurt_7UuVwoL.mp3"

var _player: AudioStreamPlayer
var _jump_stream: AudioStream
var _coin_pickup_stream: AudioStream
var _slide_stream: AudioStream
var _hurt_stream: AudioStream
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

	if not coin_pickup_sfx_path.is_empty() and ResourceLoader.exists(coin_pickup_sfx_path):
		_coin_pickup_stream = load(coin_pickup_sfx_path)
	else:
		_coin_pickup_stream = null

	if not slide_sfx_path.is_empty() and ResourceLoader.exists(slide_sfx_path):
		_slide_stream = load(slide_sfx_path)
	else:
		_slide_stream = null

	if not hurt_sfx_path.is_empty() and ResourceLoader.exists(hurt_sfx_path):
		_hurt_stream = load(hurt_sfx_path)
	else:
		_hurt_stream = null

func play_jump() -> void:
	if _player == null or _jump_stream == null:
		return
	_player.stream = _jump_stream
	_player.play()

func play_coin_pickup() -> void:
	if _player == null or _coin_pickup_stream == null:
		return
	_player.stream = _coin_pickup_stream
	_player.play()

func play_slide() -> void:
	if _player == null or _slide_stream == null:
		return
	_player.stream = _slide_stream
	_player.play()

func play_hurt() -> void:
	if _player == null or _hurt_stream == null:
		return
	_player.stream = _hurt_stream
	_player.play()

func set_volume_linear(v: float) -> void:
	_volume_linear = clampf(v, 0.0, 1.0)
	if _player:
		_player.volume_db = linear_to_db(_volume_linear)

func get_volume_linear() -> float:
	return _volume_linear

