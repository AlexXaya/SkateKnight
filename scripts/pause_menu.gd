extends CanvasLayer

@export var pause_action: StringName = &"pause"

var _root: Control
var _main_panel: Control
var _settings_panel: Control
var _resume: Button
var _restart: Button
var _settings: Button
var _quit: Button
var _dim: ColorRect

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
	settings_vbox.add_child(settings_title)

	var placeholder := Label.new()
	placeholder.text = "Volume coming soon."
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.modulate = Color(0.82, 0.86, 0.95, 0.85)
	settings_vbox.add_child(placeholder)

	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(_hide_settings)
	settings_vbox.add_child(back)

func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_root.visible = paused
	if not paused:
		_hide_settings()
	Input.mouse_mode = (Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED)
	if paused:
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

func _make_theme() -> Theme:
	var t := Theme.new()

	# Typography
	t.set_font_size("font_size", "Label", 18)
	t.set_font_size("font_size", "Button", 18)

	# Colors
	t.set_color("font_color", "Label", Color(0.92, 0.94, 0.98))
	t.set_color("font_color", "Button", Color(0.94, 0.95, 0.98))
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", Color(0.95, 0.95, 0.98))

	# Panel style
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.09, 0.11, 0.16, 0.95)
	panel.border_color = Color(0.32, 0.52, 0.9, 0.55)
	panel.border_width_left = 1
	panel.border_width_top = 1
	panel.border_width_right = 1
	panel.border_width_bottom = 1
	panel.corner_radius_top_left = 16
	panel.corner_radius_top_right = 16
	panel.corner_radius_bottom_left = 16
	panel.corner_radius_bottom_right = 16
	panel.content_margin_left = 18
	panel.content_margin_right = 18
	panel.content_margin_top = 18
	panel.content_margin_bottom = 18
	panel.shadow_color = Color(0, 0, 0, 0.55)
	panel.shadow_size = 10
	panel.shadow_offset = Vector2(0, 6)
	t.set_stylebox("panel", "PanelContainer", panel)

	# Buttons
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.12, 0.14, 0.2, 0.95)
	btn_normal.border_color = Color(0.26, 0.3, 0.42, 0.9)
	btn_normal.border_width_left = 1
	btn_normal.border_width_top = 1
	btn_normal.border_width_right = 1
	btn_normal.border_width_bottom = 1
	btn_normal.corner_radius_top_left = 12
	btn_normal.corner_radius_top_right = 12
	btn_normal.corner_radius_bottom_left = 12
	btn_normal.corner_radius_bottom_right = 12
	btn_normal.content_margin_left = 14
	btn_normal.content_margin_right = 14
	btn_normal.content_margin_top = 10
	btn_normal.content_margin_bottom = 10

	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = Color(0.14, 0.18, 0.28, 1.0)
	btn_hover.border_color = Color(0.42, 0.62, 1.0, 1.0)

	var btn_pressed := btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.08, 0.1, 0.15, 1.0)
	btn_pressed.border_color = Color(0.42, 0.62, 1.0, 1.0)

	t.set_stylebox("normal", "Button", btn_normal)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_pressed)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	return t

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

