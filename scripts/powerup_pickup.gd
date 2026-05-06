extends Area3D

@export var powerup_type: String = "magnet"

func _ready() -> void:
	add_to_group("powerup_pickup")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.has_method("activate_powerup"):
		body.call("activate_powerup", powerup_type)
		queue_free()
