extends Node

const SkinCatalog := preload("res://scripts/skin_catalog.gd")
const TOON_SHADER := preload("res://materials/toon.gdshader")

const PERSIST_SETTING := "skate_knight/persist_skin_progress"

const SETTINGS_PATH := "user://skate_knight_settings.cfg"
const SECTION := "cosmetics"
const KEY_SKIN := "selected_skin"

var _cached_selected_id: String = ""


func _persist_enabled() -> bool:
	return bool(ProjectSettings.get_setting(PERSIST_SETTING, true))


func _ready() -> void:
	if _persist_enabled():
		_cached_selected_id = _read_skin_from_disk_raw()
	else:
		_cached_selected_id = SkinCatalog.default_id()


func _read_skin_from_disk_raw() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return ""
	return str(cfg.get_value(SECTION, KEY_SKIN, ""))


func get_selected_id() -> String:
	var saved := SkinCatalog.canonical_legacy_skin_id(_cached_selected_id)
	if saved.is_empty() or not SkinCatalog.has_id(saved):
		saved = SkinCatalog.default_id()
	var rec := get_node_or_null("/root/PlayerRecords")
	if rec != null and rec.has_method("is_skin_unlocked") and not rec.is_skin_unlocked(saved):
		saved = SkinCatalog.default_id()
	_cached_selected_id = saved
	return saved


func set_selected_id(id: String) -> void:
	id = SkinCatalog.canonical_legacy_skin_id(id)
	if not SkinCatalog.has_id(id):
		id = SkinCatalog.default_id()
	var rec := get_node_or_null("/root/PlayerRecords")
	if rec != null and rec.has_method("is_skin_unlocked") and not rec.is_skin_unlocked(id):
		id = SkinCatalog.default_id()
	_cached_selected_id = id
	if not _persist_enabled():
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SECTION, KEY_SKIN, id)
	cfg.save(SETTINGS_PATH)


func apply_to_visual(visual: Node3D) -> void:
	apply_skin_to_visual(visual, get_selected_id())


func apply_skin_to_visual(visual: Node3D, skin_id: String) -> void:
	if visual == null:
		return
	var skin := SkinCatalog.get_skin(skin_id)

	var torso := visual.get_node_or_null("Torso") as MeshInstance3D
	var head := visual.get_node_or_null("Head") as MeshInstance3D
	var deck := visual.get_node_or_null("Board/Deck") as MeshInstance3D
	var holder := visual.get_node_or_null("KnightModel") as Node3D

	# Always update the board palette, regardless of model state.
	var board_mat := _shader_material_from_mesh(deck)
	if board_mat != null:
		var ba: Color = skin["board_albedo"]
		var bs: Color = skin["board_shadow"]
		board_mat.set_shader_parameter("albedo", ba)
		board_mat.set_shader_parameter("shadow_tint", Vector3(bs.r, bs.g, bs.b))

	var has_model := _try_load_model(holder, skin)

	if has_model:
		if torso: torso.visible = false
		if head: head.visible = false
	else:
		if torso: torso.visible = true
		if head: head.visible = true
		var ca: Color = skin["char_albedo"]
		var cs: Color = skin["char_shadow"]
		var torso_mat := _shader_material_from_mesh(torso)
		if torso_mat != null:
			torso_mat.set_shader_parameter("albedo", ca)
			torso_mat.set_shader_parameter("shadow_tint", Vector3(cs.r, cs.g, cs.b))


func apply_to_player(player: CharacterBody3D) -> void:
	var vis := player.get_node_or_null("Visual") as Node3D
	if vis != null:
		apply_to_visual(vis)


func _try_load_model(holder: Node3D, skin: Dictionary) -> bool:
	if holder == null:
		return false

	for c in holder.get_children():
		c.queue_free()

	var path := str(skin.get("model_path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return false

	var packed := load(path)
	var instance: Node = null
	if packed is PackedScene:
		instance = (packed as PackedScene).instantiate()
	elif packed is Resource:
		# Fallback for cases where Godot returns a non-PackedScene resource.
		return false

	if instance == null:
		return false
	if not (instance is Node3D):
		instance.queue_free()
		return false

	var node3d := instance as Node3D
	holder.add_child(node3d)

	var offset: Vector3 = skin.get("model_offset", Vector3.ZERO)
	var rot_y: float = float(skin.get("model_rotation_y_deg", 0.0))
	var scale_mul: float = float(skin.get("model_scale", 1.0))

	node3d.position = offset
	node3d.rotation_degrees = Vector3(0, rot_y, 0)
	node3d.scale = Vector3.ONE * maxf(0.0001, scale_mul)

	var ca: Color = skin["char_albedo"]
	var cs: Color = skin["char_shadow"]
	_apply_toon_to_mesh_tree(node3d, ca, cs)
	return true


func _apply_toon_to_mesh_tree(node: Node, char_albedo: Color, char_shadow: Color) -> void:
	if node is MeshInstance3D:
		_apply_toon_to_mesh_surfaces(node as MeshInstance3D, char_albedo, char_shadow)
	for c in node.get_children():
		_apply_toon_to_mesh_tree(c, char_albedo, char_shadow)


func _apply_toon_to_mesh_surfaces(mi: MeshInstance3D, char_albedo: Color, char_shadow: Color) -> void:
	var mesh: Mesh = mi.mesh
	if mesh == null:
		return
	var n := mesh.get_surface_count()
	for si in range(n):
		var mat := ShaderMaterial.new()
		mat.shader = TOON_SHADER
		mat.set_shader_parameter("albedo", char_albedo)
		mat.set_shader_parameter("shadow_tint", Vector3(char_shadow.r, char_shadow.g, char_shadow.b))
		# Match capsule knight tuning from player scene for consistent look.
		mat.set_shader_parameter("shade_threshold", 0.45)
		mat.set_shader_parameter("shade_softness", 0.07)
		mat.set_shader_parameter("rim_strength", 0.45)
		mat.set_shader_parameter("rim_power", 3.0)
		mi.set_surface_override_material(si, mat)


func _shader_material_from_mesh(mi: MeshInstance3D) -> ShaderMaterial:
	if mi == null:
		return null
	var m: Material = mi.get_surface_override_material(0)
	if m == null and mi.mesh != null:
		m = mi.mesh.surface_get_material(0)
	return m as ShaderMaterial
