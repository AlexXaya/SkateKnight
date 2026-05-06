extends Node

@export var game_scene_path: String = "res://scenes/main.tscn"
@export var start_camera_offset: Vector3 = Vector3(0, 4, -9)
@export var spin_speed_deg_per_sec: float = 140.0

var _started := false
var _preview_root: Node
var _visual_node: Node3D

var _ui_root: Control
var _main_panel: Control
var _settings_panel: Control
var _music_slider: HSlider
var _music_value: Label
var _sfx_slider: HSlider
var _sfx_value: Label
var _theme: Theme

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Ensure music is playing on the menu.
	var music := get_node_or_null("/root/Music")
	if music != null and music.has_method("play"):
		music.call("play")

	_spawn_preview()
	_build_ui()

	# Freeze preview gameplay.
	get_tree().paused = true

func _spawn_preview() -> void:
	if game_scene_path.is_empty() or not ResourceLoader.exists(game_scene_path):
		return

	var packed := load(game_scene_path) as PackedScene
	_preview_root = packed.instantiate()
	add_child(_preview_root)

	# Freeze the player logic in preview.
	var player := _preview_root.get_node_or_null("Player") as Node3D
	if player != null:
		player.set_process(false)
		player.set_physics_process(false)
		player.process_mode = Node.PROCESS_MODE_PAUSABLE

	_visual_node = _preview_root.get_node_or_null("Player/Visual") as Node3D
	if _visual_node != null:
		_visual_node.process_mode = Node.PROCESS_MODE_ALWAYS

	# Adjust camera for menu preview.
	var camera_rig := _preview_root.get_node_or_null("CameraRig") as Node3D
	if camera_rig != null:
		camera_rig.process_mode = Node.PROCESS_MODE_ALWAYS
		if camera_rig.get("offset") != null:
			camera_rig.set("offset", start_camera_offset)
		if player != null:
			camera_rig.global_position = player.global_position + start_camera_offset

	# Hide gameplay HUD/pause UI in preview.
	var hud := _preview_root.get_node_or_null("HUD")
	if hud:
		hud.visible = false
	var pause_menu := _preview_root.get_node_or_null("PauseMenu")
	if pause_menu:
		pause_menu.visible = false
		pause_menu.set_process(false)
		pause_menu.set_physics_process(false)

	# Force cursor visible (preview pause menu can capture it).
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if _started:
		return
	if _visual_node == null:
		return
	_visual_node.rotate_y(deg_to_rad(spin_speed_deg_per_sec) * maxf(0.0, delta))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	_theme = _make_theme()

	_ui_root = Control.new()
	_ui_root.anchor_right = 1.0
	_ui_root.anchor_bottom = 1.0
	_ui_root.theme = _theme
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
	var bold_font := _load_font_or_null("res://ui/fonts/Cinzel-Bold.ttf")
	if bold_font != null:
		title.add_theme_font_override("font", bold_font)
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

	var start_btn := Button.new()
	start_btn.text = "Start"
	start_btn.focus_mode = Control.FOCUS_NONE
	start_btn.pressed.connect(_start_game)
	main_v.add_child(start_btn)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.focus_mode = Control.FOCUS_NONE
	settings_btn.pressed.connect(_show_settings)
	main_v.add_child(settings_btn)

	var skins_btn := Button.new()
	skins_btn.text = "Skins (coming soon)"
	skins_btn.disabled = true
	skins_btn.focus_mode = Control.FOCUS_NONE
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
	if bold_font != null:
		set_title.add_theme_font_override("font", bold_font)
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

func _make_theme() -> Theme:
	var t := Theme.new()

	var font_regular := _load_font_or_null("res://ui/fonts/Cinzel-Regular.ttf")
	if font_regular != null:
		t.set_font("font", "Label", font_regular)
		t.set_font("font", "Button", font_regular)

	# Typography
	t.set_font_size("font_size", "Label", 18)
	t.set_font_size("font_size", "Button", 18)

	# Colors
	t.set_color("font_color", "Label", Color(0.94, 0.97, 1.0))
	t.set_color("font_outline_color", "Label", Color(0.04, 0.05, 0.08, 1.0))
	t.set_constant("outline_size", "Label", 4)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_x", "Label", 2)
	t.set_constant("shadow_offset_y", "Label", 2)

	t.set_color("font_color", "Button", Color(0.94, 0.97, 1.0))
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", Color(0.9, 0.95, 1.0))

	# Panels
	t.set_stylebox("panel", "PanelContainer", _make_panel_stylebox())

	# Buttons
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.12, 0.1, 0.08, 0.96) # dark "wood"
	btn_normal.border_color = Color(0.78, 0.62, 0.28, 1.0) # brass
	btn_normal.border_width_left = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_bottom = 2
	btn_normal.corner_radius_top_left = 14
	btn_normal.corner_radius_top_right = 14
	btn_normal.corner_radius_bottom_left = 14
	btn_normal.corner_radius_bottom_right = 14
	btn_normal.content_margin_left = 14
	btn_normal.content_margin_right = 14
	btn_normal.content_margin_top = 10
	btn_normal.content_margin_bottom = 10
	btn_normal.shadow_color = Color(0, 0, 0, 0.45)
	btn_normal.shadow_size = 8
	btn_normal.shadow_offset = Vector2(0, 4)

	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = Color(0.16, 0.13, 0.1, 1.0)
	btn_hover.border_color = Color(0.92, 0.78, 0.38, 1.0)

	var btn_pressed := btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.08, 0.07, 0.06, 1.0)
	btn_pressed.border_color = Color(0.92, 0.78, 0.38, 1.0)

	t.set_stylebox("normal", "Button", btn_normal)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_pressed)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	return t

func _load_font_or_null(path: String) -> Font:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var f := load(path) as Font
	return f

func _make_panel_stylebox() -> StyleBox:
	var tex := _make_panel_texture(128)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.draw_center = true
	sb.texture_margin_left = 18
	sb.texture_margin_top = 18
	sb.texture_margin_right = 18
	sb.texture_margin_bottom = 18
	sb.content_margin_left = 18
	sb.content_margin_top = 16
	sb.content_margin_right = 18
	sb.content_margin_bottom = 16
	return sb

func _make_panel_texture(size: int) -> Texture2D:
	size = clampi(size, 32, 256)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)

	var noise := FastNoiseLite.new()
	noise.seed = 1337
	noise.frequency = 0.055
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

	var border := int(round(size * 0.09))
	border = clampi(border, 3, 16)
	var brass := Color(0.88, 0.74, 0.38, 1.0)
	var brass_dark := Color(0.55, 0.42, 0.18, 1.0)
	var paper_a := Color(0.92, 0.86, 0.7, 0.92)
	var paper_b := Color(0.82, 0.74, 0.55, 0.92)

	for y in range(size):
		for x in range(size):
			var u := float(x) / float(size - 1)
			var v := float(y) / float(size - 1)
			var n := (noise.get_noise_2d(x, y) * 0.5 + 0.5)
			var base := paper_a.lerp(paper_b, n)

			var dx := absf(u - 0.5) * 2.0
			var dy := absf(v - 0.5) * 2.0
			var vig := clampf(1.0 - (dx * dx + dy * dy) * 0.22, 0.72, 1.0)
			base.r *= vig
			base.g *= vig
			base.b *= vig

			var is_border := (x < border or y < border or x >= size - border or y >= size - border)
			if is_border:
				var t := clampf(float(min(min(x, y), min(size - 1 - x, size - 1 - y))) / float(border), 0.0, 1.0)
				var bcol := brass_dark.lerp(brass, t)
				if x < border or y < border:
					bcol = bcol.lerp(Color(1, 0.93, 0.6, 1.0), 0.25)
				img.set_pixel(x, y, bcol)
			else:
				img.set_pixel(x, y, base)

	var tex := ImageTexture.create_from_image(img)
	return tex

func _start_game() -> void:
	if _started:
		return
	_started = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false
	get_tree().change_scene_to_file(game_scene_path)

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

