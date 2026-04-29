extends Area3D

@export var amount: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.has_method("add_coins"):
		body.call("add_coins", amount)
	queue_free()

