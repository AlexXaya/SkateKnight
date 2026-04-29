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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hud_theme := _make_hud_theme()
	if is_instance_valid(_hud_root):
		_hud_root.theme = hud_theme
	_apply_box_style_overrides(hud_theme)
	_rm = get_node(run_manager_path)
	_game_over.visible = false
	if _rm != null:
		if _rm.has_signal("stats_changed"):
			_rm.connect("stats_changed", _on_stats_changed)
		if _rm.has_signal("run_over"):
			_rm.connect("run_over", _on_run_over)

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
	_game_over.visible = true

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

