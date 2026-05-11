extends Area3D

@export var powerup_type: String = "magnet"
@export var spin_speed_rad_s: float = 4.5

@export var glitter_amount: int = 44
@export var glitter_lifetime_s: float = 1.2
@export var glitter_sphere_radius: float = 0.95


func _ready() -> void:
	add_to_group("powerup_pickup")
	body_entered.connect(_on_body_entered)
	call_deferred("_add_glitter_particles")


func _process(delta: float) -> void:
	if powerup_type != "magnet" and powerup_type != "invincible" and powerup_type != "double":
		return
	var visual := get_node_or_null("Visual") as Node3D
	if visual != null and spin_speed_rad_s != 0.0:
		visual.rotate_y(spin_speed_rad_s * delta)

func _on_body_entered(body: Node) -> void:
	if body.has_method("activate_powerup"):
		body.call("activate_powerup", powerup_type)
		queue_free()


func _add_glitter_particles() -> void:
	if powerup_type != "magnet" and powerup_type != "invincible" and powerup_type != "double":
		return
	var gp := GPUParticles3D.new()
	gp.name = "Glitter"
	gp.position = Vector3.ZERO
	gp.amount = maxi(8, glitter_amount)
	gp.lifetime = maxf(0.35, glitter_lifetime_s)
	gp.explosiveness = 0.0
	gp.randomness = 0.72
	gp.fixed_fps = 0
	gp.visibility_aabb = AABB(Vector3(-2.5, -1.5, -2.5), Vector3(5.0, 4.0, 5.0))
	gp.local_coords = true
	gp.emitting = true
	gp.one_shot = false

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = glitter_sphere_radius
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 175.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 1.35
	pm.gravity = Vector3(0.0, 0.22, 0.0)
	pm.scale_min = 0.05
	pm.scale_max = 0.16
	pm.angular_velocity_min = -3.0
	pm.angular_velocity_max = 3.0
	pm.angle_min = -28.0
	pm.angle_max = 28.0
	var col := _glitter_core_color()
	pm.color = Color(col.r, col.g, col.b, 0.92)
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([
		Color(col.r * 1.2, col.g * 1.2, col.b * 1.2, 0.0),
		Color(col.r, col.g, col.b, 1.0),
		Color(1.0, 1.0, 1.0, 0.35),
		Color(col.r, col.g, col.b, 0.0),
	])
	ramp.offsets = PackedFloat32Array([0.0, 0.18, 0.55, 1.0])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	gp.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	sm.emission_enabled = true
	sm.emission = col.lightened(0.45)
	sm.emission_energy_multiplier = 2.4
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = sm
	gp.draw_pass_1 = quad

	add_child(gp)


func _glitter_core_color() -> Color:
	match powerup_type:
		"magnet":
			return Color(0.35, 0.72, 1.0)
		"invincible":
			return Color(0.35, 1.0, 0.48)
		"double":
			return Color(1.0, 0.55, 0.2)
		_:
			return Color(0.8, 0.85, 1.0)
