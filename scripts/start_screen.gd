extends Node

@export var game_scene_path: String = "res://scenes/main.tscn"
@export var spin_speed_deg_per_sec: float = 140.0
@export var start_camera_offset: Vector3 = Vector3(0, 4, -9)
@export var pause_action: StringName = &"pause"

var _started := false
var _preview_root: Node
var _player_node: Node3D
var _visual_node: Node3D

var _ui_root: Control
var _main_panel: Control
var _settings_panel: Control
var _start_btn: Button
var _music_slider: HSlider
var _music_value: Label
var _sfx_slider: HSlider
var _sfx_value: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_spawn_preview()
	_build_ui()

	# Freeze gameplay while still allowing this node to receive input.
	get_tree().paused = true

func _spawn_preview() -> void:
	if game_scene_path.is_empty() or not ResourceLoader.exists(game_scene_path):
		push_error("StartScreen: game scene not found: %s" % game_scene_path)
		return

	var packed := load(game_scene_path) as PackedScene
	_preview_root = packed.instantiate()
	add_child(_preview_root)

	# Spin the Skate Knight while waiting to start.
	_player_node = _preview_root.get_node_or_null("Player") as Node3D
	_visual_node = _preview_root.get_node_or_null("Player/Visual") as Node3D
	if _player_node:
		# IMPORTANT: keep gameplay frozen on the start screen.
		# Do not allow player physics/logic to run (prevents sinking through ground).
		_player_node.process_mode = Node.PROCESS_MODE_PAUSABLE
		_player_node.set_process(false)
		_player_node.set_physics_process(false)
	if _visual_node:
		_visual_node.process_mode = Node.PROCESS_MODE_ALWAYS

	# Ensure the preview camera snaps into place before we pause the tree.
	var camera_rig := _preview_root.get_node_or_null("CameraRig") as Node3D
	if camera_rig:
		# Allow camera rig to run even when paused (keeps it stable if we ever unpause briefly).
		camera_rig.process_mode = Node.PROCESS_MODE_ALWAYS

		# Pull the camera closer for the start screen only.
		if camera_rig.get("offset") != null:
			camera_rig.set("offset", start_camera_offset)

		if _player_node:
			camera_rig.global_position = _player_node.global_position + start_camera_offset

	# Hide/disable gameplay UI and pause menu on the title screen.
	var hud := _preview_root.get_node_or_null("HUD")
	if hud:
		hud.visible = false

	var input_debug := _preview_root.get_node_or_null("InputDebug")
	if input_debug:
		input_debug.visible = false

	var pause_menu := _preview_root.get_node_or_null("PauseMenu")
	if pause_menu:
		pause_menu.visible = false
		pause_menu.process_mode = Node.PROCESS_MODE_DISABLED
		pause_menu.set_process(false)
		pause_menu.set_physics_process(false)

	# The preview scene's pause/menu logic may set the mouse to CAPTURED in _ready().
	# Force it back to VISIBLE for the start screen.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if _started:
		return
	# Keep cursor visible on the start screen (preview scene can try to capture it).
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _visual_node == null:
		return

	var dt := maxf(0.0, delta)
	_visual_node.rotate_y(deg_to_rad(spin_speed_deg_per_sec) * dt)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	_ui_root = Control.new()
	_ui_root.anchor_right = 1.0
	_ui_root.anchor_bottom = 1.0
	_ui_root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(_ui_root)

	var dim := ColorRect.new()
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0.03, 0.04, 0.06, 0.45)
	_ui_root.add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_ui_root.add_child(center)

	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(520, 0)
	stack.add_theme_constant_override("separation", 14)
	center.add_child(stack)

	var title := Label.new()
	title.text = "SKATE KNIGHT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose an option to begin."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.85, 0.9, 1.0, 0.85)
	subtitle.add_theme_font_size_override("font_size", 18)
	stack.add_child(subtitle)

	_main_panel = PanelContainer.new()
	stack.add_child(_main_panel)

	var main_pad := MarginContainer.new()
	main_pad.add_theme_constant_override("margin_left", 18)
	main_pad.add_theme_constant_override("margin_right", 18)
	main_pad.add_theme_constant_override("margin_top", 16)
	main_pad.add_theme_constant_override("margin_bottom", 16)
	_main_panel.add_child(main_pad)

	var main_v := VBoxContainer.new()
	main_v.add_theme_constant_override("separation", 10)
	main_pad.add_child(main_v)

	_start_btn = Button.new()
	_start_btn.text = "Start"
	_start_btn.focus_mode = Control.FOCUS_NONE
	_start_btn.pressed.connect(_start_game)
	main_v.add_child(_start_btn)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.focus_mode = Control.FOCUS_NONE
	settings_btn.pressed.connect(_show_settings)
	main_v.add_child(settings_btn)

	var skins_btn := Button.new()
	skins_btn.text = "Skins (coming soon)"
	skins_btn.focus_mode = Control.FOCUS_NONE
	skins_btn.disabled = true
	main_v.add_child(skins_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.focus_mode = Control.FOCUS_NONE
	quit_btn.pressed.connect(func(): get_tree().quit())
	main_v.add_child(quit_btn)

	_settings_panel = PanelContainer.new()
	_settings_panel.visible = false
	stack.add_child(_settings_panel)

	var set_pad := MarginContainer.new()
	set_pad.add_theme_constant_override("margin_left", 18)
	set_pad.add_theme_constant_override("margin_right", 18)
	set_pad.add_theme_constant_override("margin_top", 16)
	set_pad.add_theme_constant_override("margin_bottom", 16)
	_settings_panel.add_child(set_pad)

	var set_v := VBoxContainer.new()
	set_v.add_theme_constant_override("separation", 12)
	set_pad.add_child(set_v)

	var set_title := Label.new()
	set_title.text = "SETTINGS"
	set_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_title.add_theme_font_size_override("font_size", 28)
	set_v.add_child(set_title)

	# Music
	var music_group := VBoxContainer.new()
	music_group.add_theme_constant_override("separation", 6)
	set_v.add_child(music_group)

	var music_title := Label.new()
	music_title.text = "Music Volume"
	music_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	music_title.modulate = Color(0.92, 0.94, 0.98, 0.9)
	music_group.add_child(music_title)

	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 10)
	music_group.add_child(music_row)

	_music_slider = HSlider.new()
	_music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_slider.min_value = 0.0
	_music_slider.max_value = 1.0
	_music_slider.step = 0.01
	_music_slider.focus_mode = Control.FOCUS_NONE
	_music_slider.value = _get_music_volume_linear()
	_music_slider.value_changed.connect(_on_music_volume_changed)
	music_row.add_child(_music_slider)

	_music_value = Label.new()
	_music_value.custom_minimum_size = Vector2(56, 0)
	_music_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	music_row.add_child(_music_value)
	_update_music_label(_music_slider.value)

	# SFX
	var sfx_group := VBoxContainer.new()
	sfx_group.add_theme_constant_override("separation", 6)
	set_v.add_child(sfx_group)

	var sfx_title := Label.new()
	sfx_title.text = "SFX Volume"
	sfx_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sfx_title.modulate = Color(0.92, 0.94, 0.98, 0.9)
	sfx_group.add_child(sfx_title)

	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 10)
	sfx_group.add_child(sfx_row)

	_sfx_slider = HSlider.new()
	_sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 1.0
	_sfx_slider.step = 0.01
	_sfx_slider.focus_mode = Control.FOCUS_NONE
	_sfx_slider.value = _get_sfx_volume_linear()
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	sfx_row.add_child(_sfx_slider)

	_sfx_value = Label.new()
	_sfx_value.custom_minimum_size = Vector2(56, 0)
	_sfx_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sfx_row.add_child(_sfx_value)
	_update_sfx_label(_sfx_slider.value)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(_hide_settings)
	set_v.add_child(back_btn)

func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return

	# Pause key toggles the start menu/settings panels.
	if event.is_action_pressed(pause_action):
		_toggle_menu()
		return

func _start_game() -> void:
	if _started:
		return
	_started = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false
	get_tree().change_scene_to_file(game_scene_path)

func _toggle_menu() -> void:
	if _ui_root == null:
		return
	var any_open := (_main_panel != null and _main_panel.visible) or (_settings_panel != null and _settings_panel.visible)
	if any_open:
		if _settings_panel:
			_settings_panel.visible = false
		if _main_panel:
			_main_panel.visible = false
	else:
		if _main_panel:
			_main_panel.visible = true
		if _settings_panel:
			_settings_panel.visible = false

func _show_settings() -> void:
	if _main_panel:
		_main_panel.visible = false
	if _settings_panel:
		_settings_panel.visible = true

func _hide_settings() -> void:
	if _main_panel:
		_main_panel.visible = true
	if _settings_panel:
		_settings_panel.visible = false

func _on_music_volume_changed(v: float) -> void:
	_set_music_volume_linear(v)
	_update_music_label(v)

func _on_sfx_volume_changed(v: float) -> void:
	_set_sfx_volume_linear(v)
	_update_sfx_label(v)

func _update_music_label(v: float) -> void:
	if _music_value == null:
		return
	_music_value.text = "%d%%" % int(round(clampf(v, 0.0, 1.0) * 100.0))

func _update_sfx_label(v: float) -> void:
	if _sfx_value == null:
		return
	_sfx_value.text = "%d%%" % int(round(clampf(v, 0.0, 1.0) * 100.0))

func _get_music_node() -> Node:
	return get_node_or_null("/root/Music")

func _get_sfx_node() -> Node:
	return get_node_or_null("/root/Sfx")

func _get_music_volume_linear() -> float:
	var music := _get_music_node()
	if music != null and music.has_method("get_volume_linear"):
		return float(music.call("get_volume_linear"))
	return 0.85

func _set_music_volume_linear(v: float) -> void:
	var music := _get_music_node()
	if music != null and music.has_method("set_volume_linear"):
		music.call("set_volume_linear", v)

func _get_sfx_volume_linear() -> float:
	var sfx := _get_sfx_node()
	if sfx != null and sfx.has_method("get_volume_linear"):
		return float(sfx.call("get_volume_linear"))
	return 0.9

func _set_sfx_volume_linear(v: float) -> void:
	var sfx := _get_sfx_node()
	if sfx != null and sfx.has_method("set_volume_linear"):
		sfx.call("set_volume_linear", v)

