extends CanvasLayer

@export var run_manager_path: NodePath

@onready var _hud_root: Control = $HUD
@onready var _coins_box: PanelContainer = $HUD/Margin/VBox/TopStatsCenter/TopStats/CoinsBox
@onready var _score_box: PanelContainer = $HUD/Margin/VBox/TopStatsCenter/TopStats/ScoreBox
@onready var _dist_box: PanelContainer = $HUD/Margin/VBox/TopStatsCenter/TopStats/DistanceBox
@onready var _coins_value: Label = $HUD/Margin/VBox/TopStatsCenter/TopStats/CoinsBox/Pad/VBox/Value
@onready var _coins_icon: TextureRect = $HUD/Margin/VBox/TopStatsCenter/TopStats/CoinsBox/Pad/VBox/HeaderCenter/Header/Icon
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

@export var milestone_distance_step_m: int = 1000
var _next_distance_milestone: int = 1000
@export var milestone_sparkle_count: int = 42
@export var milestone_sparkle_lifetime_s: float = 0.65
@export var milestone_sparkle_speed: float = 520.0
@export var milestone_sparkle_spread_deg: float = 180.0
@export var milestone_sparkle_size_px: float = 10.0
var _sparkle_layer: Control
var _sparkles: GPUParticles2D
var _coin_pickup_sparkles: GPUParticles2D
var _coin_box_pulse_tween: Tween

@export var coin_pickup_sparkle_count: int = 22
@export var coin_pickup_sparkle_lifetime_s: float = 0.38
@export var coin_pickup_sparkle_speed: float = 220.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hud_theme := _make_hud_theme()
	if is_instance_valid(_hud_root):
		_hud_root.theme = hud_theme
	if is_instance_valid(_game_over):
		_game_over.theme = hud_theme
	_apply_box_style_overrides(hud_theme)
	_build_danger_overlay()
	_build_milestone_sparkles()
	_build_coin_pickup_sparkles()
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
		if _rm.has_signal("coin_pickup"):
			_rm.connect("coin_pickup", _on_coin_pickup)

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

	_maybe_trigger_distance_milestone(_dist_target)

	if _coins_display == 0.0 and _score_display == 0.0 and _dist_display == 0.0:
		_coins_display = _coins_target
		_score_display = _score_target
		_dist_display = _dist_target

func _on_run_over() -> void:
	# Freeze the count-up animation so stats don't keep climbing after death.
	_coins_display = _coins_target
	_score_display = _score_target
	_dist_display = _dist_target
	_coins_value.text = "%d" % int(round(_coins_display))
	_score_value.text = "%d" % int(round(_score_display))
	_dist_value.text = "%dm" % int(round(_dist_display))

	# Stop gameplay entirely.
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Switch to game-over music.
	var music := get_node_or_null("/root/Music")
	if music != null and music.has_method("play_game_over"):
		music.call("play_game_over")
	elif music != null and music.has_method("stop"):
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

func _build_milestone_sparkles() -> void:
	_sparkle_layer = Control.new()
	_sparkle_layer.name = "MilestoneSparkles"
	_sparkle_layer.anchor_left = 0.0
	_sparkle_layer.anchor_top = 0.0
	_sparkle_layer.anchor_right = 1.0
	_sparkle_layer.anchor_bottom = 1.0
	_sparkle_layer.offset_left = 0.0
	_sparkle_layer.offset_top = 0.0
	_sparkle_layer.offset_right = 0.0
	_sparkle_layer.offset_bottom = 0.0
	_sparkle_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_sparkle_layer)

	_sparkles = GPUParticles2D.new()
	_sparkles.name = "DistanceMilestoneSparkles"
	_sparkles.one_shot = true
	_sparkles.emitting = false
	_sparkles.amount = max(1, milestone_sparkle_count)
	_sparkles.lifetime = maxf(0.05, milestone_sparkle_lifetime_s)
	_sparkles.explosiveness = 1.0
	_sparkles.randomness = 0.25
	_sparkles.texture = _make_sparkle_texture()

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(0, -1, 0)
	mat.spread = clampf(milestone_sparkle_spread_deg, 0.0, 180.0)
	mat.gravity = Vector3(0, 0, 0)
	mat.initial_velocity_min = maxf(0.0, milestone_sparkle_speed * 0.55)
	mat.initial_velocity_max = maxf(mat.initial_velocity_min, milestone_sparkle_speed)
	mat.damping_min = 2.0
	mat.damping_max = 6.0
	mat.angular_velocity_min = -10.0
	mat.angular_velocity_max = 10.0

	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0),
		Color(1, 1, 1, 0.95),
		Color(0.85, 0.95, 1.0, 0.0),
	])
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 1.0])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex

	# Size pop then fade.
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	mat.scale_curve = curve_tex
	mat.scale_min = maxf(0.01, milestone_sparkle_size_px / 16.0)
	mat.scale_max = mat.scale_min * 1.35

	_sparkles.process_material = mat

	# Additive sparkles.
	var cim := CanvasItemMaterial.new()
	cim.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sparkles.material = cim

	_sparkle_layer.add_child(_sparkles)

func _build_coin_pickup_sparkles() -> void:
	if _sparkle_layer == null:
		return
	_coin_pickup_sparkles = GPUParticles2D.new()
	_coin_pickup_sparkles.name = "CoinPickupSparkles"
	_coin_pickup_sparkles.one_shot = true
	_coin_pickup_sparkles.emitting = false
	_coin_pickup_sparkles.amount = maxi(1, coin_pickup_sparkle_count)
	_coin_pickup_sparkles.lifetime = maxf(0.05, coin_pickup_sparkle_lifetime_s)
	_coin_pickup_sparkles.explosiveness = 1.0
	_coin_pickup_sparkles.randomness = 0.35
	_coin_pickup_sparkles.texture = _make_sparkle_texture()

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 140.0
	mat.gravity = Vector3(0, 0, 0)
	mat.initial_velocity_min = maxf(8.0, coin_pickup_sparkle_speed * 0.35)
	mat.initial_velocity_max = maxf(mat.initial_velocity_min, coin_pickup_sparkle_speed)
	mat.damping_min = 3.0
	mat.damping_max = 8.0

	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([
		Color(1.0, 0.92, 0.35, 0.0),
		Color(1.0, 0.96, 0.55, 0.95),
		Color(1.0, 0.65, 0.15, 0.0),
	])
	ramp.offsets = PackedFloat32Array([0.0, 0.14, 1.0])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.12, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	mat.scale_curve = curve_tex
	var sz := maxf(0.04, milestone_sparkle_size_px * 0.55 / 16.0)
	mat.scale_min = sz
	mat.scale_max = sz * 1.4

	_coin_pickup_sparkles.process_material = mat

	var cim := CanvasItemMaterial.new()
	cim.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_coin_pickup_sparkles.material = cim

	_sparkle_layer.add_child(_coin_pickup_sparkles)

func _make_sparkle_texture() -> Texture2D:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var c := Vector2((size - 1) * 0.5, (size - 1) * 0.5)
	var max_r := float(size) * 0.5

	for y in range(size):
		for x in range(size):
			var p := Vector2(float(x), float(y))
			var d := p.distance_to(c)
			var a_rad := clampf(1.0 - (d / max_r), 0.0, 1.0)
			a_rad = pow(a_rad, 2.2)

			# Cross sparkle "spikes".
			var dx := absf(p.x - c.x)
			var dy := absf(p.y - c.y)
			var a_cross := 0.0
			if dx < 1.25:
				a_cross = maxf(a_cross, clampf(1.0 - (dx / 1.25), 0.0, 1.0))
			if dy < 1.25:
				a_cross = maxf(a_cross, clampf(1.0 - (dy / 1.25), 0.0, 1.0))
			a_cross *= clampf(1.0 - (d / max_r), 0.0, 1.0)

			var a := clampf(a_rad * 0.85 + a_cross * 0.95, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))

	var tex := ImageTexture.create_from_image(img)
	return tex

func _maybe_trigger_distance_milestone(dist_m: float) -> void:
	if milestone_distance_step_m <= 0:
		return

	var d := int(floor(dist_m))
	if d < _next_distance_milestone:
		return

	# Catch up if we skipped multiple milestones in one update.
	while d >= _next_distance_milestone:
		_next_distance_milestone += milestone_distance_step_m

	_play_sparkles()

func _play_sparkles() -> void:
	if _sparkles == null or _dist_box == null:
		return

	# Position at the center of the Distance box (in canvas coordinates).
	var center := _dist_box.get_global_rect().get_center()
	_sparkles.global_position = center

	_sparkles.amount = max(1, milestone_sparkle_count)
	_sparkles.lifetime = maxf(0.05, milestone_sparkle_lifetime_s)

	var pm := _sparkles.process_material as ParticleProcessMaterial
	if pm:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		pm.spread = clampf(milestone_sparkle_spread_deg, 0.0, 180.0)
		pm.initial_velocity_min = maxf(0.0, milestone_sparkle_speed * 0.55)
		pm.initial_velocity_max = maxf(pm.initial_velocity_min, milestone_sparkle_speed)
		pm.scale_min = maxf(0.01, milestone_sparkle_size_px / 16.0)
		pm.scale_max = pm.scale_min * 1.35

	_sparkles.emitting = false
	_sparkles.restart()
	_sparkles.emitting = true

func _on_coin_pickup(amount: int) -> void:
	if amount <= 0:
		return
	_coin_pickup_pulse()
	_coin_pickup_popup(amount)
	_play_coin_pickup_sparkles()

func _coin_pickup_pulse() -> void:
	if not is_instance_valid(_coins_box):
		return
	if _coin_box_pulse_tween:
		_coin_box_pulse_tween.kill()
		_coin_box_pulse_tween = null
	_coins_box.pivot_offset = _coins_box.size * 0.5
	_coin_box_pulse_tween = create_tween()
	_coin_box_pulse_tween.set_parallel(true)
	_coin_box_pulse_tween.tween_property(_coins_box, "scale", Vector2(1.07, 1.07), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_coins_value):
		_coin_box_pulse_tween.tween_property(_coins_value, "modulate", Color(1.0, 0.95, 0.58), 0.06)
	_coin_box_pulse_tween.chain()
	_coin_box_pulse_tween.set_parallel(true)
	_coin_box_pulse_tween.tween_property(_coins_box, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_coins_value):
		_coin_box_pulse_tween.tween_property(_coins_value, "modulate", Color.WHITE, 0.2)

func _coin_pickup_popup(amount: int) -> void:
	var layer: Control = _sparkle_layer if _sparkle_layer != null else _hud_root
	if layer == null:
		return
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = "+%d" % amount
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bold_font := _load_font_or_null("res://ui/fonts/Cinzel-Bold.ttf")
	if bold_font != null:
		lbl.add_theme_font_override("font", bold_font)
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.38))
	lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.02))
	lbl.add_theme_constant_override("outline_size", 3)
	layer.add_child(lbl)

	var center := _coins_box.get_global_rect().get_center()
	if is_instance_valid(_coins_icon):
		center = _coins_icon.get_global_rect().get_center()

	await get_tree().process_frame
	if not is_instance_valid(lbl):
		return
	lbl.global_position = Vector2(center.x - lbl.size.x * 0.5, center.y - lbl.size.y - 6.0)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 38.0, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.08)
	tw.finished.connect(func():
		if is_instance_valid(lbl):
			lbl.queue_free()
	)

func _play_coin_pickup_sparkles() -> void:
	if _coin_pickup_sparkles == null or not is_instance_valid(_coins_box):
		return
	var center := _coins_box.get_global_rect().get_center()
	if is_instance_valid(_coins_icon):
		center = _coins_icon.get_global_rect().get_center()
	_coin_pickup_sparkles.global_position = center
	_coin_pickup_sparkles.amount = maxi(1, coin_pickup_sparkle_count)
	_coin_pickup_sparkles.lifetime = maxf(0.05, coin_pickup_sparkle_lifetime_s)
	var pm := _coin_pickup_sparkles.process_material as ParticleProcessMaterial
	if pm:
		pm.initial_velocity_min = maxf(8.0, coin_pickup_sparkle_speed * 0.35)
		pm.initial_velocity_max = maxf(pm.initial_velocity_min, coin_pickup_sparkle_speed)
	_coin_pickup_sparkles.emitting = false
	_coin_pickup_sparkles.restart()
	_coin_pickup_sparkles.emitting = true

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
	var bold_font := _load_font_or_null("res://ui/fonts/Cinzel-Bold.ttf")
	if bold_font != null:
		title.add_theme_font_override("font", bold_font)
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
		if music != null and music.has_method("play_gameplay"):
			music.call("play_gameplay")
		elif music != null and music.has_method("play"):
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
		var music := get_node_or_null("/root/Music")
		if music != null and music.has_method("play_start_screen"):
			music.call("play_start_screen")
		get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
	)
	v.add_child(main_menu)

	# Default focus.
	restart.grab_focus()

func _make_hud_theme() -> Theme:
	var t := Theme.new()

	var font_regular := _load_font_or_null("res://ui/fonts/Cinzel-Regular.ttf")
	if font_regular != null:
		t.set_font("font", "Label", font_regular)
		t.set_font("font", "Button", font_regular)

	# Base sizes (titles/values can override per-node in scene).
	t.set_font_size("font_size", "Label", 18)
	t.set_font_size("font_size", "Button", 18)

	# "Cartoon-ish" readability: thick outline + subtle shadow.
	t.set_color("font_color", "Label", Color(0.94, 0.97, 1.0))
	t.set_color("font_outline_color", "Label", Color(0.04, 0.05, 0.08, 1.0))
	t.set_constant("outline_size", "Label", 4)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_x", "Label", 2)
	t.set_constant("shadow_offset_y", "Label", 2)

	# Stat boxes.
	t.set_stylebox("panel", "PanelContainer", _make_panel_stylebox())

	# Buttons (Game Over menu uses them).
	t.set_color("font_color", "Button", Color(0.94, 0.97, 1.0))
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", Color(0.9, 0.95, 1.0))

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
	# "Parchment over stone" vibe: warm textured center, brass border baked into texture.
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

			# Subtle vignette to feel like material.
			var dx := absf(u - 0.5) * 2.0
			var dy := absf(v - 0.5) * 2.0
			var vig := clampf(1.0 - (dx * dx + dy * dy) * 0.22, 0.72, 1.0)
			base.r *= vig
			base.g *= vig
			base.b *= vig

			# Brass border baked in.
			var is_border := (x < border or y < border or x >= size - border or y >= size - border)
			if is_border:
				var t := clampf(float(min(min(x, y), min(size - 1 - x, size - 1 - y))) / float(border), 0.0, 1.0)
				var bcol := brass_dark.lerp(brass, t)
				# Fake bevel highlight.
				if x < border or y < border:
					bcol = bcol.lerp(Color(1, 0.93, 0.6, 1.0), 0.25)
				img.set_pixel(x, y, bcol)
			else:
				img.set_pixel(x, y, base)

	var tex := ImageTexture.create_from_image(img)
	return tex

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
