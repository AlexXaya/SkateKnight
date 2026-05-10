extends RefCounted
class_name SkinCatalog

## Ordered palette swaps for the shared toon materials on the player (body + board).

static func default_id() -> String:
	return "default"


## Old saves used `knight` for the Kenney model before all skins used it; treat as Silver Knight.
static func canonical_legacy_skin_id(id: String) -> String:
	if id == "knight":
		return "default"
	return id


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


## Unlock: meet ANY listed threshold (coins collected in one run, score that run, distance in meters).
## Keys omitted or ≤ 0 mean that requirement is unused. All unused ⇒ starter skin (always unlocked).
static func is_skin_unlocked(id: String, best_coins: int, best_score: int, best_distance_m: float) -> bool:
	var skin := get_skin(id)
	var uc := int(skin.get("unlock_coins", -1))
	var us := int(skin.get("unlock_score", -1))
	var ud := float(skin.get("unlock_distance_m", -1.0))
	var any_req := false
	if uc > 0:
		any_req = true
		if best_coins >= uc:
			return true
	if us > 0:
		any_req = true
		if best_score >= us:
			return true
	if ud > 0.0:
		any_req = true
		if best_distance_m >= ud:
			return true
	return not any_req


static func format_unlock_progress(skin_id: String, best_coins: int, best_score: int, best_distance_m: float) -> String:
	if is_skin_unlocked(skin_id, best_coins, best_score, best_distance_m):
		return ""
	var skin := get_skin(skin_id)
	var uc := int(skin.get("unlock_coins", -1))
	if uc > 0:
		return "Reach %d coins in one run · Best: %d" % [uc, best_coins]
	var us := int(skin.get("unlock_score", -1))
	if us > 0:
		return "Reach %d score in one run · Best: %d" % [us, best_score]
	var ud := float(skin.get("unlock_distance_m", -1.0))
	if ud > 0.0:
		return "Reach %dm in one run · Best: %dm" % [int(round(ud)), int(floor(best_distance_m))]
	return ""


static func _u_coins(n: int) -> Dictionary:
	return {"unlock_coins": n, "unlock_score": -1, "unlock_distance_m": -1.0}


static func _u_score(n: int) -> Dictionary:
	return {"unlock_coins": -1, "unlock_score": n, "unlock_distance_m": -1.0}


static func _u_dist(m: float) -> Dictionary:
	return {"unlock_coins": -1, "unlock_score": -1, "unlock_distance_m": m}


## Kenney "Mini Arena" character-soldier (CC0) — used for every skin; palettes swap materials via board + fallback torso tint path if needed.
static func _mini_knight_model_fields() -> Dictionary:
	return {
		"model_path": "res://models/knight.glb",
		# Lift feet onto the deck (board node sits at y=0.28; deck is ~0.08 thick).
		"model_offset": Vector3(0, 0.34, 0),
		# Player root is rotated 90deg around Y; Kenney models export facing -Z,
		# so a -90 deg local rotation aligns the soldier with the run direction.
		"model_rotation_y_deg": -90.0,
		"model_scale": 1.4,
	}


static func _merge_skin(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in extra:
		out[k] = extra[k]
	return out


## Optional fields per skin (used when present, otherwise sensible defaults):
##   unlock_coins: int           - require this many coins collected in a single run (-1 = unused)
##   unlock_score: int          - require this run score (-1 = unused)
##   unlock_distance_m: float   - require this run distance in meters (-1 = unused)
##   Meet ANY listed requirement to unlock.
##   model_path: String           - res:// path to a .glb/.tscn knight model
##   model_offset: Vector3        - translation to apply to the loaded model
##   model_rotation_y_deg: float  - Y rotation tweak so the knight faces forward
##   model_scale: float           - uniform scale multiplier
static func _skin_table() -> Array:
	var mk := _mini_knight_model_fields()
	return [
		_merge_skin({
			"id": "default",
			"name": "Silver Knight",
			"char_albedo": Color(0.82, 0.84, 0.9),
			"char_shadow": Color(0.35, 0.33, 0.45),
			"board_albedo": Color(0.2, 0.75, 0.9),
			"board_shadow": Color(0.1, 0.25, 0.35),
		}, mk),
		_merge_skin({
			"id": "midnight",
			"name": "Midnight Run",
			"char_albedo": Color(0.38, 0.42, 0.62),
			"char_shadow": Color(0.18, 0.14, 0.28),
			"board_albedo": Color(0.45, 0.22, 0.72),
			"board_shadow": Color(0.12, 0.06, 0.22),
		}.merged(_u_coins(40)), mk),
		_merge_skin({
			"id": "sunset",
			"name": "Sunset Deck",
			"char_albedo": Color(0.92, 0.62, 0.42),
			"char_shadow": Color(0.42, 0.22, 0.18),
			"board_albedo": Color(0.98, 0.48, 0.28),
			"board_shadow": Color(0.38, 0.12, 0.08),
		}.merged(_u_dist(200.0)), mk),
		_merge_skin({
			"id": "forest",
			"name": "Forest Sprite",
			"char_albedo": Color(0.52, 0.78, 0.48),
			"char_shadow": Color(0.18, 0.35, 0.22),
			"board_albedo": Color(0.22, 0.62, 0.42),
			"board_shadow": Color(0.08, 0.22, 0.14),
		}.merged(_u_score(1200)), mk),
		_merge_skin({
			"id": "rose_rider",
			"name": "Rose Rider",
			"char_albedo": Color(0.92, 0.55, 0.72),
			"char_shadow": Color(0.38, 0.18, 0.32),
			"board_albedo": Color(0.85, 0.28, 0.55),
			"board_shadow": Color(0.32, 0.08, 0.22),
		}.merged(_u_coins(100)), mk),
		_merge_skin({
			"id": "golden",
			"name": "Golden Hour",
			"char_albedo": Color(0.95, 0.78, 0.42),
			"char_shadow": Color(0.42, 0.28, 0.1),
			"board_albedo": Color(0.98, 0.72, 0.28),
			"board_shadow": Color(0.38, 0.22, 0.06),
		}.merged(_u_dist(450.0)), mk),
		_merge_skin({
			"id": "ocean",
			"name": "Ocean Deep",
			"char_albedo": Color(0.35, 0.72, 0.82),
			"char_shadow": Color(0.12, 0.28, 0.38),
			"board_albedo": Color(0.15, 0.55, 0.72),
			"board_shadow": Color(0.06, 0.22, 0.35),
		}.merged(_u_score(4500)), mk),
		_merge_skin({
			"id": "ember",
			"name": "Ember Ash",
			"char_albedo": Color(0.42, 0.38, 0.38),
			"char_shadow": Color(0.18, 0.12, 0.12),
			"board_albedo": Color(0.92, 0.35, 0.18),
			"board_shadow": Color(0.35, 0.1, 0.05),
		}.merged(_u_coins(220)), mk),
		_merge_skin({
			"id": "royal",
			"name": "Royal Court",
			"char_albedo": Color(0.62, 0.48, 0.85),
			"char_shadow": Color(0.22, 0.14, 0.38),
			"board_albedo": Color(0.85, 0.72, 0.35),
			"board_shadow": Color(0.35, 0.28, 0.1),
		}.merged(_u_dist(850.0)), mk),
		_merge_skin({
			"id": "arctic",
			"name": "Arctic Rush",
			"char_albedo": Color(0.88, 0.94, 0.98),
			"char_shadow": Color(0.42, 0.52, 0.62),
			"board_albedo": Color(0.55, 0.82, 0.95),
			"board_shadow": Color(0.18, 0.35, 0.48),
		}.merged(_u_score(8500)), mk),
		_merge_skin({
			"id": "stealth",
			"name": "Night Blade",
			"char_albedo": Color(0.22, 0.22, 0.28),
			"char_shadow": Color(0.06, 0.06, 0.1),
			"board_albedo": Color(0.65, 0.68, 0.72),
			"board_shadow": Color(0.22, 0.24, 0.28),
		}.merged(_u_coins(380)), mk),
	]
