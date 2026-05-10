extends Node

## Persists best single-run stats used for skin unlock checks.

const SkinCatalog := preload("res://scripts/skin_catalog.gd")

const SETTINGS_PATH := "user://player_records.cfg"
const SECTION := "records"

var best_run_coins: int = 0
var best_run_score: int = 0
var best_run_distance_m: float = 0.0

## Queued skin IDs to announce on the main menu (persisted so runs that end in gameplay still notify later).
var _pending_skin_unlock_toasts: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_load()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	best_run_coins = int(cfg.get_value(SECTION, "best_run_coins", 0))
	best_run_score = int(cfg.get_value(SECTION, "best_run_score", 0))
	best_run_distance_m = float(cfg.get_value(SECTION, "best_run_distance_m", 0.0))

	var pending_raw = cfg.get_value(SECTION, "pending_skin_unlocks", PackedStringArray())
	if pending_raw is PackedStringArray:
		_pending_skin_unlock_toasts = pending_raw
	elif pending_raw is Array:
		for x in pending_raw:
			_pending_skin_unlock_toasts.append(str(x))


func _persist() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SECTION, "best_run_coins", best_run_coins)
	cfg.set_value(SECTION, "best_run_score", best_run_score)
	cfg.set_value(SECTION, "best_run_distance_m", best_run_distance_m)
	cfg.set_value(SECTION, "pending_skin_unlocks", _pending_skin_unlock_toasts)
	cfg.save(SETTINGS_PATH)


func submit_run_end(coins: int, score: int, distance_m: float) -> void:
	var oc := best_run_coins
	var os := best_run_score
	var od := best_run_distance_m
	var nc := maxi(oc, coins)
	var ns := maxi(os, score)
	var nd := maxf(od, distance_m)

	var unlock_added := false
	if nc != oc or ns != os or nd != od:
		for id in SkinCatalog.skin_ids_ordered():
			if SkinCatalog.is_skin_unlocked(id, oc, os, od):
				continue
			if SkinCatalog.is_skin_unlocked(id, nc, ns, nd):
				if not _pending_contains(id):
					_pending_skin_unlock_toasts.append(id)
					unlock_added = true

	best_run_coins = nc
	best_run_score = ns
	best_run_distance_m = nd

	var bests_changed := (nc != oc or ns != os or nd != od)
	if bests_changed or unlock_added:
		_persist()


func peek_pending_skin_unlocks() -> PackedStringArray:
	return _pending_skin_unlock_toasts.duplicate()


func clear_pending_skin_unlocks() -> void:
	if _pending_skin_unlock_toasts.is_empty():
		return
	_pending_skin_unlock_toasts.clear()
	_persist()


func is_skin_unlocked(skin_id: String) -> bool:
	return SkinCatalog.is_skin_unlocked(skin_id, best_run_coins, best_run_score, best_run_distance_m)


func _pending_contains(id: String) -> bool:
	for x in _pending_skin_unlock_toasts:
		if x == id:
			return true
	return false
