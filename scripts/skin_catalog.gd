extends RefCounted
class_name SkinCatalog

## Ordered palette swaps for the shared toon materials on the player (body + board).

static func default_id() -> String:
	return "knight"


static func skin_ids_ordered() -> PackedStringArray:
	var ids := PackedStringArray()
	for s in _skin_table():
		ids.append(s["id"])
	return ids


static func has_id(id: String) -> bool:
	for s in _skin_table():
		if s["id"] == id:
			return true
	return false


static func get_skin(id: String) -> Dictionary:
	for s in _skin_table():
		if s["id"] == id:
			return s.duplicate(true)
	return _skin_table()[0].duplicate(true)


static func index_of(id: String) -> int:
	var ids := skin_ids_ordered()
	for i in range(ids.size()):
		if ids[i] == id:
			return i
	return 0


## Optional fields per skin (used when present, otherwise sensible defaults):
##   model_path: String           - res:// path to a .glb/.tscn knight model
##   model_offset: Vector3        - translation to apply to the loaded model
##   model_rotation_y_deg: float  - Y rotation tweak so the knight faces forward
##   model_scale: float           - uniform scale multiplier
static func _skin_table() -> Array:
	return [
		{
			"id": "knight",
			"name": "Mini Knight",
			"char_albedo": Color(0.82, 0.84, 0.9),
			"char_shadow": Color(0.35, 0.33, 0.45),
			"board_albedo": Color(0.55, 0.45, 0.25),
			"board_shadow": Color(0.22, 0.16, 0.08),
			# Kenney "Mini Arena" character-soldier (CC0).
			"model_path": "res://models/knight.glb",
			# Lift feet onto the deck (board node sits at y=0.28; deck is ~0.08 thick).
			"model_offset": Vector3(0, 0.34, 0),
			# Player root is rotated 90deg around Y; Kenney models export facing -Z,
			# so a -90 deg local rotation aligns the soldier with the run direction.
			"model_rotation_y_deg": -90.0,
			"model_scale": 1.4,
		},
		{
			"id": "default",
			"name": "Silver Knight",
			"char_albedo": Color(0.82, 0.84, 0.9),
			"char_shadow": Color(0.35, 0.33, 0.45),
			"board_albedo": Color(0.2, 0.75, 0.9),
			"board_shadow": Color(0.1, 0.25, 0.35),
		},
		{
			"id": "midnight",
			"name": "Midnight Run",
			"char_albedo": Color(0.38, 0.42, 0.62),
			"char_shadow": Color(0.18, 0.14, 0.28),
			"board_albedo": Color(0.45, 0.22, 0.72),
			"board_shadow": Color(0.12, 0.06, 0.22),
		},
		{
			"id": "sunset",
			"name": "Sunset Deck",
			"char_albedo": Color(0.92, 0.62, 0.42),
			"char_shadow": Color(0.42, 0.22, 0.18),
			"board_albedo": Color(0.98, 0.48, 0.28),
			"board_shadow": Color(0.38, 0.12, 0.08),
		},
		{
			"id": "forest",
			"name": "Forest Sprite",
			"char_albedo": Color(0.52, 0.78, 0.48),
			"char_shadow": Color(0.18, 0.35, 0.22),
			"board_albedo": Color(0.22, 0.62, 0.42),
			"board_shadow": Color(0.08, 0.22, 0.14),
		},
		{
			"id": "rose_rider",
			"name": "Rose Rider",
			"char_albedo": Color(0.92, 0.55, 0.72),
			"char_shadow": Color(0.38, 0.18, 0.32),
			"board_albedo": Color(0.85, 0.28, 0.55),
			"board_shadow": Color(0.32, 0.08, 0.22),
		},
	]
