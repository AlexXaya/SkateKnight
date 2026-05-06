extends CanvasLayer

@export var run_manager_path: NodePath

@onready var _hud_root: Control = $HUD
@onready var _coins_box: PanelContainer = $HUD/Margin/VBox/TopStatsCenter/TopStats/CoinsBox
@onready var _score_box: PanelContainer = $HUD/Margin/VBox/TopStatsCenter/TopStats/ScoreBox
@onready var _dist_box: PanelContainer = $HUD/Margin/VBox/TopStatsCenter/TopStats/DistanceBox
@onready var _coins_value: Label = $HUD/Margin/VBox/TopStatsCenter/TopStats/CoinsBox/Pad/VBox/Value
@onready var _score_value: Label = $HUD/Margin/VBox/TopStatsCenter/TopStats/ScoreBox/Pad/VBox/Value
@onready var _dist_value: Label = $HUD/Margin/VBox/TopStatsCenter/TopStats/DistanceBox/Pad/VBox/Value
@onready var _game_over: Control = $GameOver

var _rm: Node
var _coins_target: float = 0.0
var _score_target: float = 0.0
var _dist_target: float = 0.0

var _coins_display: float = 0.0
var _score_display: float = 0.0
var _dist_display: float = 0.0

@export var count_speed: float = 24.0
@export var snap_epsilon: float = 0.001

var _danger_overlay: ColorRect
var _danger_tween: Tween
var _game_over_built := false
var _game_over_panel: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hud_theme := _make_hud_theme()
	if is_instance_valid(_hud_root):
		_hud_root.theme = hud_theme
	_apply_box_style_overrides(hud_theme)
	_build_danger_overlay()
	_build_game_over_ui()
	_rm = get_node(run_manager_path)
	_game_over.visible = false
	if _rm != null:
		if _rm.has_signal("stats_changed"):
			_rm.connect("stats_changed", _on_stats_changed)
		if _rm.has_signal("run_over"):
			_rm.connect("run_over", _on_run_over)
		if _rm.has_signal("danger_changed"):
			_rm.connect("danger_changed", _on_danger_changed)

func _process(delta: float) -> void:
	var step := maxf(1.0, count_speed) * maxf(0.0, delta)
	_coins_display = _move_display_toward(_coins_display, _coins_target, step)
	_score_display = _move_display_toward(_score_display, _score_target, step)
	_dist_display = _move_display_toward(_dist_display, _dist_target, step)

	_coins_value.text = "%d" % int(round(_coins_display))
	_score_value.text = "%d" % int(round(_score_display))
	_dist_value.text = "%dm" % int(round(_dist_display))

func _on_stats_changed(coins: int, score: int, distance: float) -> void:
	_coins_target = float(coins)
	_score_target = float(score)
	_dist_target = maxf(0.0, distance)

	if _coins_display == 0.0 and _score_display == 0.0 and _dist_display == 0.0:
		_coins_display = _coins_target
		_score_display = _score_target
		_dist_display = _dist_target

func _on_run_over() -> void:
	# Stop gameplay entirely.
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Stop background music (we'll add game-over music later).
	var music := get_node_or_null("/root/Music")
	if music != null and music.has_method("stop"):
		music.call("stop")

	# Prevent pause menu from interfering while game over is shown.
	var pm := get_parent().get_node_or_null("PauseMenu")
	if pm:
		pm.visible = false
		pm.process_mode = Node.PROCESS_MODE_DISABLED
		pm.set_process(false)
		pm.set_physics_process(false)

	_game_over.visible = true
	if _game_over_panel:
		_game_over_panel.grab_focus()

func _build_danger_overlay() -> void:
	_danger_overlay = ColorRect.new()
	_danger_overlay.name = "DangerOverlay"
	_danger_overlay.anchor_right = 1.0
	_danger_overlay.anchor_bottom = 1.0
	_danger_overlay.color = Color(1.0, 0.1, 0.12, 0.0)
	_danger_overlay.visible = false
	_danger_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_danger_overlay)

func _on_danger_changed(active: bool) -> void:
	if _danger_overlay == null:
		return

	if _danger_tween:
		_danger_tween.kill()
		_danger_tween = null

	if not active:
		# Fade out instead of popping off instantly.
		_danger_overlay.visible = true
		_danger_tween = create_tween()
		_danger_tween.tween_property(_danger_overlay, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_danger_tween.tween_callback(func():
			if _danger_overlay:
				_danger_overlay.visible = false
		)
		return

	_danger_overlay.visible = true
	_danger_overlay.color.a = 0.0

	# Blink faint red.
	_danger_tween = create_tween()
	_danger_tween.set_loops()
	_danger_tween.tween_property(_danger_overlay, "color:a", 0.18, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_danger_tween.tween_property(_danger_overlay, "color:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _build_game_over_ui() -> void:
	if _game_over_built:
		return
	_game_over_built = true

	if _game_over == null:
		return

	# Ensure the overlay covers the full viewport regardless of window size.
	_game_over.anchor_left = 0.0
	_game_over.anchor_top = 0.0
	_game_over.anchor_right = 1.0
	_game_over.anchor_bottom = 1.0
	_game_over.offset_left = 0.0
	_game_over.offset_top = 0.0
	_game_over.offset_right = 0.0
	_game_over.offset_bottom = 0.0

	# Clear placeholder children from the scene.
	for c in _game_over.get_children():
		c.queue_free()

	_game_over.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.offset_left = 0.0
	dim.offset_top = 0.0
	dim.offset_right = 0.0
	dim.offset_bottom = 0.0
	dim.color = Color(0.02, 0.02, 0.03, 0.75)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_game_over.add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_left = 0.0
	center.offset_top = 0.0
	center.offset_right = 0.0
	center.offset_bottom = 0.0
	_game_over.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	_game_over_panel = panel

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 20)
	pad.add_theme_constant_override("margin_top", 18)
	pad.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(pad)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pad.add_child(v)

	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	v.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Your run has ended."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.85, 0.9, 1.0, 0.85)
	subtitle.add_theme_font_size_override("font_size", 18)
	v.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	v.add_child(spacer)

	var restart := Button.new()
	restart.text = "Restart"
	restart.focus_mode = Control.FOCUS_ALL
	restart.pressed.connect(func():
		var music := get_node_or_null("/root/Music")
		if music != null and music.has_method("stop"):
			music.call("stop")
		if music != null and music.has_method("play"):
			music.call("play")
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().reload_current_scene()
	)
	v.add_child(restart)

	var main_menu := Button.new()
	main_menu.text = "Main Menu"
	main_menu.focus_mode = Control.FOCUS_ALL
	main_menu.pressed.connect(func():
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
	)
	v.add_child(main_menu)

	# Default focus.
	restart.grab_focus()

func _make_hud_theme() -> Theme:
	var t := Theme.new()

	# Base sizes (titles/values can override per-node in scene).
	t.set_font_size("font_size", "Label", 18)
	t.set_font_size("font_size", "Button", 18)

	# "Cartoon-ish" readability: thick outline + subtle shadow.
	t.set_color("font_color", "Label", Color(1, 1, 1))
	t.set_color("font_outline_color", "Label", Color(0.05, 0.06, 0.09, 1.0))
	t.set_constant("outline_size", "Label", 4)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_x", "Label", 2)
	t.set_constant("shadow_offset_y", "Label", 2)

	# Stat boxes.
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.12, 0.18, 0.85)
	panel.border_color = Color(0.35, 0.55, 1.0, 0.9)
	panel.border_width_left = 2
	panel.border_width_top = 2
	panel.border_width_right = 2
	panel.border_width_bottom = 2
	panel.corner_radius_top_left = 16
	panel.corner_radius_top_right = 16
	panel.corner_radius_bottom_left = 16
	panel.corner_radius_bottom_right = 16
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 8
	panel.shadow_offset = Vector2(0, 5)
	t.set_stylebox("panel", "PanelContainer", panel)

	return t

func _apply_box_style_overrides(t: Theme) -> void:
	var sb := t.get_stylebox("panel", "PanelContainer")
	if sb == null:
		return
	if is_instance_valid(_coins_box):
		_coins_box.add_theme_stylebox_override("panel", sb)
	if is_instance_valid(_score_box):
		_score_box.add_theme_stylebox_override("panel", sb)
	if is_instance_valid(_dist_box):
		_dist_box.add_theme_stylebox_override("panel", sb)

func _move_display_toward(current: float, target: float, step: float) -> float:
	var next := move_toward(current, target, step)
	if absf(target - next) <= snap_epsilon:
		return target
	return next
