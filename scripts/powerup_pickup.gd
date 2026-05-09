extends Area3D

@export var powerup_type: String = "magnet"
@export var spin_speed_rad_s: float = 4.5

func _ready() -> void:
	add_to_group("powerup_pickup")
	body_entered.connect(_on_body_entered)

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
