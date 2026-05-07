extends Area3D

@export var amount: int = 1
@export var collect_radius: float = 0.9
@export var spin_speed_rad_s: float = 6.0
var _collected := false

func _ready() -> void:
	add_to_group("coin_pickup")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	_collect(body)

func _process(_delta: float) -> void:
	if _collected:
		return

	var mesh := get_node_or_null("CoinMesh") as Node3D
	if mesh != null and spin_speed_rad_s != 0.0:
		mesh.rotate_y(spin_speed_rad_s * _delta)

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	if global_position.distance_to(player.global_position) <= collect_radius:
		_collect(player)

func _collect(body: Node) -> void:
	if _collected:
		return
	if body.has_method("add_coins"):
		body.call("add_coins", amount)
		var sfx := get_node_or_null("/root/Sfx")
		if sfx != null and sfx.has_method("play_coin_pickup"):
			sfx.call("play_coin_pickup")
		_collected = true
		queue_free()

