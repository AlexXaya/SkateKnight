extends CanvasLayer

@export var run_manager_path: NodePath

@onready var _coins_label: Label = $HUD/Margin/VBox/Coins
@onready var _score_label: Label = $HUD/Margin/VBox/Score
@onready var _dist_label: Label = $HUD/Margin/VBox/Distance
@onready var _game_over: Control = $GameOver

var _rm: Node

func _ready() -> void:
	_rm = get_node(run_manager_path)
	_game_over.visible = false
	if _rm != null:
		if _rm.has_signal("stats_changed"):
			_rm.connect("stats_changed", _on_stats_changed)
		if _rm.has_signal("run_over"):
			_rm.connect("run_over", _on_run_over)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused

func _on_stats_changed(coins: int, score: int, distance: float) -> void:
	_coins_label.text = "Coins: %d" % coins
	_score_label.text = "Score: %d" % score
	_dist_label.text = "Distance: %dm" % int(distance)

func _on_run_over() -> void:
	_game_over.visible = true

