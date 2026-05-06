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
var _debug_label: Label
@export var debug_readout_enabled: bool = false
@export var debug_print_occluder: bool = true
var _last_occ_line := ""
@export var debug_wireframe_toggle_key: Key = KEY_F4
@export var debug_fog_toggle_key: Key = KEY_F5
@export var debug_nodepth_toggle_key: Key = KEY_F6
@export var debug_floor_toggle_key: Key = KEY_F7
var _wireframe_on := false
var _fog_forced_off := false
var _nodepth_on := false
var _floor_hidden := false
var _nodepth_shader: Shader
var _saved_materials: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	_nodepth_shader = load("res://materials/toon_nodepth.gdshader") as Shader
	var hud_theme := _make_hud_theme()
	if is_instance_valid(_hud_root):
		_hud_root.theme = hud_theme
	_apply_box_style_overrides(hud_theme)
	_build_danger_overlay()
	_build_debug_readout()
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

	if debug_readout_enabled and _debug_label != null:
		var parent = get_parent()
		var player = parent.get_node_or_null("Player") as Node3D
		var cam_rig = parent.get_node_or_null("CameraRig") as Node3D
		var cam: Camera3D = null
		if cam_rig != null:
			cam = cam_rig.get_node_or_null("Camera3D") as Camera3D
		var pz = 0.0
		var py = 0.0
		if player != null:
			pz = player.global_position.z
			py = player.global_position.y

		var cy = 0.0
		var cz = 0.0
		if cam_rig != null:
			cy = cam_rig.global_position.y
			cz = cam_rig.global_position.z
		var occluder = ""
		var occluder_low = ""
		var hit_y_high = ""
		var hit_y_low = ""
		if cam != null and player != null:
			var space = cam.get_world_3d().direct_space_state
			var from = cam.global_position
			
			# Ray to chest
			var to_high = player.global_position + Vector3(0, 1.0, 0)
			var qh = PhysicsRayQueryParameters3D.create(from, to_high)
			qh.exclude = [player]
			qh.collision_mask = -1
			qh.collide_with_bodies = true
			qh.collide_with_areas = true
			var hit_h = space.intersect_ray(qh)
			if not hit_h.is_empty():
				var c = hit_h.get("collider")
				var p = hit_h.get("position")
				if p is Vector3:
					hit_y_high = " y=%.2f" % (p as Vector3).y
				if c is Node:
					occluder = " OccHigh=%s%s" % [(c as Node).name, hit_y_high]
				else:
					occluder = " OccHigh=?%s" % hit_y_high
			else:
				occluder = " OccHigh=none"

			# Ray to feet (low point)
			var to_low = player.global_position + Vector3(0, 0.1, 0)
			var ql = PhysicsRayQueryParameters3D.create(from, to_low)
			ql.exclude = [player]
			ql.collision_mask = -1
			ql.collide_with_bodies = true
			ql.collide_with_areas = true
			var hit_l = space.intersect_ray(ql)
			if not hit_l.is_empty():
				var c2 = hit_l.get("collider")
				var p2 = hit_l.get("position")
				if p2 is Vector3:
					hit_y_low = " y=%.2f" % (p2 as Vector3).y
				if c2 is Node:
					occluder_low = " OccLow=%s%s" % [(c2 as Node).name, hit_y_low]
				else:
					occluder_low = " OccLow=?%s" % hit_y_low
			else:
				occluder_low = " OccLow=none"

		var line := "P(y=%.2f z=%.1f) Cam(y=%.2f z=%.1f)%s%s" % [py, pz, cy, cz, occluder, occluder_low]
		_debug_label.text = line
		if debug_print_occluder and line != _last_occ_line and (occluder_low != "" or occluder != ""):
			_last_occ_line = line
			print(line)

func _unhandled_input(event: InputEvent) -> void:
	if not debug_readout_enabled:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.keycode == debug_wireframe_toggle_key:
			_toggle_wireframe()
		elif k.keycode == debug_fog_toggle_key:
			_toggle_fog()
		elif k.keycode == debug_nodepth_toggle_key:
			_toggle_nodepth()
		elif k.keycode == debug_floor_toggle_key:
			_toggle_floor_visuals()

func _toggle_wireframe() -> void:
	_wireframe_on = not _wireframe_on
	var vp := get_viewport()
	if vp != null:
		vp.debug_draw = (Viewport.DEBUG_DRAW_WIREFRAME if _wireframe_on else Viewport.DEBUG_DRAW_DISABLED)
	print("Wireframe: %s" % ("ON" if _wireframe_on else "OFF"))

func _toggle_fog() -> void:
	_fog_forced_off = not _fog_forced_off
	var we := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		we.environment.fog_enabled = not _fog_forced_off
	print("Fog: %s" % ("OFF" if _fog_forced_off else "ON"))

func _toggle_nodepth() -> void:
	_nodepth_on = not _nodepth_on
	var root := get_parent()
	if root == null or _nodepth_shader == null:
		return

	var targets: Array[Node] = []
	var player := root.get_node_or_null("Player")
	if player != null:
		targets.append(player)
	var spawner := root.get_node_or_null("ChunkSpawner") as Node
	if spawner != null:
		targets.append(spawner)

	# Collect MeshInstance3D nodes under player + spawned chunks.
	var meshes: Array[MeshInstance3D] = []
	for t in targets:
		if t == null:
			continue
		for child in t.get_children():
			_collect_meshes_recursive(child, meshes)

	if _nodepth_on:
		for m in meshes:
			if m == null:
				continue
			if not _saved_materials.has(m.get_instance_id()):
				_saved_materials[m.get_instance_id()] = m.material_override
			var mat := ShaderMaterial.new()
			mat.shader = _nodepth_shader
			# Try to preserve color if the mesh already uses a shader material override.
			var cur := m.material_override
			if cur is ShaderMaterial:
				var sm := cur as ShaderMaterial
				if sm.get_shader_parameter("albedo") != null:
					mat.set_shader_parameter("albedo", sm.get_shader_parameter("albedo"))
				if sm.get_shader_parameter("shadow_tint") != null:
					mat.set_shader_parameter("shadow_tint", sm.get_shader_parameter("shadow_tint"))
			m.material_override = mat
	else:
		for m in meshes:
			if m == null:
				continue
			var id := m.get_instance_id()
			if _saved_materials.has(id):
				m.material_override = _saved_materials[id]
		_saved_materials.clear()

	print("No-depth test: %s" % ("ON" if _nodepth_on else "OFF"))

func _collect_meshes_recursive(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		_collect_meshes_recursive(c, out)

func _toggle_floor_visuals() -> void:
	_floor_hidden = not _floor_hidden
	var root := get_parent()
	if root == null:
		return
	var spawner := root.get_node_or_null("ChunkSpawner") as Node
	if spawner == null:
		return

	var meshes: Array[MeshInstance3D] = []
	for c in spawner.get_children():
		_collect_meshes_recursive(c, meshes)

	for m in meshes:
		if m == null:
			continue
		# Only toggle track visuals (FloorMesh + lane lines). We identify them by name.
		if m.name == "FloorMesh" or m.name.begins_with("Line"):
			m.visible = not _floor_hidden

	print("Floor visuals: %s" % ("HIDDEN" if _floor_hidden else "VISIBLE"))

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

func _build_debug_readout() -> void:
	if not debug_readout_enabled:
		return
	_debug_label = Label.new()
	_debug_label.name = "DebugReadout"
	_debug_label.anchor_left = 0.0
	_debug_label.anchor_top = 1.0
	_debug_label.anchor_right = 0.0
	_debug_label.anchor_bottom = 1.0
	_debug_label.offset_left = 12
	_debug_label.offset_right = 1200
	_debug_label.offset_top = -72
	_debug_label.offset_bottom = -12
	_debug_label.modulate = Color(1, 1, 1, 1.0)
	_debug_label.add_theme_font_size_override("font_size", 20)
	_debug_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_debug_label.add_theme_constant_override("shadow_offset_x", 2)
	_debug_label.add_theme_constant_override("shadow_offset_y", 2)

	var bg := ColorRect.new()
	bg.name = "DebugReadoutBG"
	bg.anchor_left = 0.0
	bg.anchor_top = 1.0
	bg.anchor_right = 0.0
	bg.anchor_bottom = 1.0
	bg.offset_left = 8
	bg.offset_right = 1220
	bg.offset_top = -78
	bg.offset_bottom = -8
	bg.color = Color(0, 0, 0, 0.35)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	add_child(_debug_label)

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
