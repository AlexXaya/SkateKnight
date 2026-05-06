extends CanvasLayer

@export var pause_action: StringName = &"pause"
@export var ui_shift_x: float = 0.0
@export var hide_pause_ui_temp: bool = false

var _root: Control
var _main_panel: Control
var _settings_panel: Control
var _resume: Button
var _restart: Button
var _main_menu: Button
var _settings: Button
var _quit: Button
var _dim: ColorRect
var _volume_slider: HSlider
var _volume_value: Label
var _sfx_slider: HSlider
var _sfx_value: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_ui()
	_set_paused(false)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(pause_action):
		_set_paused(not get_tree().paused)

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "PauseUI"
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.theme = _make_theme()
	add_child(_root)

	_dim = ColorRect.new()
	_dim.anchor_right = 1.0
	_dim.anchor_bottom = 1.0
	_dim.color = Color(0.03, 0.04, 0.06, 0.72)
	_root.add_child(_dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_left = ui_shift_x
	center.offset_right = ui_shift_x
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	_main_panel = panel

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	var bold_font := _load_font_or_null("res://ui/fonts/Cinzel-Bold.ttf")
	if bold_font != null:
		title.add_theme_font_override("font", bold_font)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Take a breather."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.82, 0.86, 0.95, 0.85)
	subtitle.add_theme_font_size_override("font_size", 16)
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	_resume = Button.new()
	_resume.text = "Resume"
	_resume.pressed.connect(func(): _set_paused(false))
	vbox.add_child(_resume)

	_restart = Button.new()
	_restart.text = "Restart"
	_restart.pressed.connect(func():
		_set_paused(false)
		get_tree().reload_current_scene()
	)
	vbox.add_child(_restart)

	_main_menu = Button.new()
	_main_menu.text = "Main Menu"
	_main_menu.pressed.connect(func():
		_set_paused(false)
		get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
	)
	vbox.add_child(_main_menu)

	_settings = Button.new()
	_settings.text = "Settings"
	_settings.pressed.connect(_show_settings)
	vbox.add_child(_settings)

	_quit = Button.new()
	_quit.text = "Quit"
	_quit.pressed.connect(func(): get_tree().quit())
	vbox.add_child(_quit)

	_settings_panel = PanelContainer.new()
	_settings_panel.custom_minimum_size = Vector2(420, 0)
	_settings_panel.visible = false
	center.add_child(_settings_panel)

	var settings_vbox := VBoxContainer.new()
	settings_vbox.add_theme_constant_override("separation", 12)
	_settings_panel.add_child(settings_vbox)

	var settings_title := Label.new()
	settings_title.text = "SETTINGS"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title.add_theme_font_size_override("font_size", 28)
	if bold_font != null:
		settings_title.add_theme_font_override("font", bold_font)
	settings_vbox.add_child(settings_title)

	var vol_group := VBoxContainer.new()
	vol_group.add_theme_constant_override("separation", 6)
	settings_vbox.add_child(vol_group)

	var vol_title := Label.new()
	vol_title.text = "Music Volume"
	vol_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vol_title.modulate = Color(0.92, 0.94, 0.98, 0.9)
	vol_group.add_child(vol_title)

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 10)
	vol_group.add_child(vol_row)

	_volume_slider = HSlider.new()
	_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.01
	_volume_slider.value = _get_music_volume_linear()
	_volume_slider.value_changed.connect(_on_volume_changed)
	vol_row.add_child(_volume_slider)

	_volume_value = Label.new()
	_volume_value.custom_minimum_size = Vector2(56, 0)
	_volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vol_row.add_child(_volume_value)
	_update_volume_label(_volume_slider.value)

	var sfx_group := VBoxContainer.new()
	sfx_group.add_theme_constant_override("separation", 6)
	settings_vbox.add_child(sfx_group)

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
	_sfx_slider.value = _get_sfx_volume_linear()
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	sfx_row.add_child(_sfx_slider)

	_sfx_value = Label.new()
	_sfx_value.custom_minimum_size = Vector2(56, 0)
	_sfx_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sfx_row.add_child(_sfx_value)
	_update_sfx_label(_sfx_slider.value)

	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(_hide_settings)
	settings_vbox.add_child(back)

func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_root.visible = paused and not hide_pause_ui_temp
	if not paused:
		_hide_settings()
	if paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if paused:
		if not hide_pause_ui_temp:
			_animate_open()

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

func _on_volume_changed(v: float) -> void:
	_set_music_volume_linear(v)
	_update_volume_label(v)

func _on_sfx_volume_changed(v: float) -> void:
	_set_sfx_volume_linear(v)
	_update_sfx_label(v)

func _update_volume_label(v: float) -> void:
	if _volume_value == null:
		return
	_volume_value.text = "%d%%" % int(round(clampf(v, 0.0, 1.0) * 100.0))

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
	t.set_color("font_color", "Button", Color(0.94, 0.97, 1.0))
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", Color(0.9, 0.95, 1.0))

	# Panel style
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

func _animate_open() -> void:
	if _main_panel == null or _dim == null:
		return

	_main_panel.scale = Vector2(0.96, 0.96)
	_main_panel.modulate = Color(1, 1, 1, 0.0)
	_dim.modulate = Color(1, 1, 1, 0.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_dim, "modulate", Color(1, 1, 1, 1), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_main_panel, "modulate", Color(1, 1, 1, 1), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_main_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

