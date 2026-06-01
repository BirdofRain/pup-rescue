extends Node
class_name GameSave
## Autoload singleton at /root/SaveGame — use GameSave type via get_node, not bare SaveGame identifier.

const SAVE_PATH := "user://save.json"
const _UpgradeCatalog := preload("res://scripts/upgrade_catalog.gd")
const _PupColors := preload("res://scripts/pup_colors.gd")
const _ProgressTracker := preload("res://scripts/progress_tracker.gd")
const _DifficultyConfig := preload("res://scripts/difficulty_config.gd")
const _FollowerSnap := preload("res://scripts/follower_snap.gd")

var current_level: int = 0
var total_rescued: int = 0
var coat_index: int = 0
var treat_coins: int = 0
var pup_name: String = ""
var equipped: Dictionary = {}
var owned_accessories: Array[String] = []
var owned_upgrades: Array[String] = []
var stats: Dictionary = {}
var leaderboard: Array = []
var difficulty_mode: int = _DifficultyConfig.MODE_BEGINNER
var snap_mode: int = _FollowerSnap.MODE_TRAIL

var boot_test_mode: bool = false
var boot_new_game: bool = false


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_save() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return false
	current_level = int(data.get("current_level", 0))
	total_rescued = int(data.get("total_rescued", 0))
	if data.has("coat_index"):
		coat_index = _PupColors.clamp_index(int(data.get("coat_index", 0)))
	else:
		coat_index = _PupColors.clamp_index(int(data.get("breed", 0)))
	treat_coins = int(data.get("treat_coins", 0))
	equipped = _dict_from_variant(data.get("equipped", {}))
	owned_accessories = _string_array_from(data.get("owned_accessories", []))
	owned_upgrades = _string_array_from(data.get("owned_upgrades", []))
	stats = _dict_from_variant(data.get("stats", {}))
	pup_name = str(data.get("pup_name", ""))
	leaderboard = _array_from_variant(data.get("leaderboard", []))
	difficulty_mode = _DifficultyConfig.clamp_mode(int(data.get("difficulty_mode", _DifficultyConfig.MODE_BEGINNER)))
	snap_mode = _FollowerSnap.clamp_mode(int(data.get("snap_mode", _FollowerSnap.MODE_TRAIL)))
	return true


func save_game() -> void:
	var data := {
		"current_level": current_level,
		"total_rescued": total_rescued,
		"coat_index": coat_index,
		"treat_coins": treat_coins,
		"pup_name": pup_name,
		"equipped": equipped.duplicate(),
		"owned_accessories": owned_accessories.duplicate(),
		"owned_upgrades": owned_upgrades.duplicate(),
		"stats": stats.duplicate(),
		"leaderboard": leaderboard.duplicate(),
		"difficulty_mode": difficulty_mode,
		"snap_mode": snap_mode,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()


func prepare_new_game(selected_coat: int) -> void:
	var kept_stats := stats.duplicate()
	var kept_board: Array = leaderboard.duplicate()
	var kept_name := pup_name
	current_level = 0
	total_rescued = 0
	treat_coins = 0
	coat_index = _PupColors.clamp_index(selected_coat)
	equipped = {}
	owned_accessories = []
	owned_upgrades = []
	stats = kept_stats
	leaderboard = kept_board
	pup_name = kept_name
	boot_test_mode = false
	boot_new_game = true
	save_game()


func prepare_continue() -> void:
	load_save()
	boot_test_mode = false
	boot_new_game = false


func prepare_test_maze(selected_coat: int) -> void:
	current_level = 0
	coat_index = _PupColors.clamp_index(selected_coat)
	boot_test_mode = true
	boot_new_game = false


func record_level_complete(rescued_this_level: int, squad_size: int = 0) -> void:
	total_rescued += rescued_this_level
	var completed_level: int = current_level + 1
	current_level += 1
	_update_bests(completed_level, total_rescued, squad_size)
	if progress_features_unlocked():
		_append_leaderboard_entry(completed_level, total_rescued, squad_size)
	save_game()


func set_pup_name(raw: String) -> void:
	pup_name = _ProgressTracker.sanitize_name(raw)


func get_pup_name() -> String:
	return _ProgressTracker.display_name(pup_name)


func get_difficulty_mode() -> int:
	return _DifficultyConfig.clamp_mode(difficulty_mode)


func set_difficulty_mode(mode: int) -> void:
	difficulty_mode = _DifficultyConfig.clamp_mode(mode)


func get_snap_mode() -> int:
	return _FollowerSnap.clamp_mode(snap_mode)


func set_snap_mode(mode: int) -> void:
	snap_mode = _FollowerSnap.clamp_mode(mode)


func progress_features_unlocked() -> bool:
	if current_level >= _ProgressTracker.UNLOCK_AT_LEVEL_INDEX:
		return true
	return int(stats.get("best_level", 0)) >= _ProgressTracker.UNLOCK_AT_LEVEL_INDEX + 1


func get_best_level() -> int:
	return int(stats.get("best_level", 0))


func get_best_rescued() -> int:
	return int(stats.get("best_rescued", 0))


func get_best_squad() -> int:
	return int(stats.get("best_squad", 0))


func _update_bests(level_display: int, rescued: int, squad_size: int) -> void:
	stats["best_level"] = maxi(get_best_level(), level_display)
	stats["best_rescued"] = maxi(get_best_rescued(), rescued)
	stats["best_squad"] = maxi(get_best_squad(), squad_size)


func _append_leaderboard_entry(level_display: int, rescued: int, squad_size: int) -> void:
	var entry := {
		"name": get_pup_name(),
		"level": level_display,
		"rescued": rescued,
		"squad": squad_size,
		"coins": treat_coins,
		"ts": Time.get_unix_time_from_system(),
	}
	leaderboard.append(entry)
	leaderboard.sort_custom(_ProgressTracker.sort_leaderboard)
	while leaderboard.size() > _ProgressTracker.LEADERBOARD_MAX:
		leaderboard.pop_back()


func record_progress_snapshot(squad_size: int, rescued_pending: int = 0) -> void:
	var display_level: int = current_level + 1
	var display_rescued: int = total_rescued + maxi(0, rescued_pending)
	_update_bests(display_level, display_rescued, squad_size)
	if progress_features_unlocked():
		_append_leaderboard_entry(display_level, display_rescued, squad_size)


func save_run_progress(level_index: int, squad_size: int, rescued_pending: int = 0) -> void:
	current_level = level_index
	record_progress_snapshot(squad_size, rescued_pending)
	save_game()


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	treat_coins += amount


func can_afford(cost: int) -> bool:
	return treat_coins >= cost


func spend_coins(cost: int) -> bool:
	if cost < 0 or treat_coins < cost:
		return false
	treat_coins -= cost
	return true


func owns_accessory(id: String) -> bool:
	return owned_accessories.has(id)


func owns_upgrade(id: String) -> bool:
	return upgrade_maxed(id)


func upgrade_stack_count(id: String) -> int:
	var n := 0
	for uid: String in owned_upgrades:
		if uid == id:
			n += 1
	return n


func upgrade_maxed(id: String) -> bool:
	var entry: Dictionary = _UpgradeCatalog.get_entry(id)
	if entry.is_empty():
		return true
	if entry.get("stackable", false):
		return upgrade_stack_count(id) >= int(entry.get("max_stacks", 1))
	return owned_upgrades.has(id)


func unlock_accessory(id: String) -> bool:
	if id == "" or owned_accessories.has(id):
		return false
	owned_accessories.append(id)
	return true


func unlock_upgrade(id: String) -> bool:
	if id == "" or upgrade_maxed(id):
		return false
	owned_upgrades.append(id)
	return true


func equip_accessory(slot: String, id: String) -> void:
	if id == "":
		equipped.erase(slot)
	else:
		equipped[slot] = id


func get_equipped(slot: String) -> String:
	return str(equipped.get(slot, ""))


func has_rainbow_trail() -> bool:
	return owns_upgrade("rainbow_trail")


func has_exit_roundup() -> bool:
	return owns_upgrade("pup_roundup")


func get_upgrade_flag(effect: String) -> bool:
	for uid: String in owned_upgrades:
		var entry: Dictionary = _UpgradeCatalog.get_entry(uid)
		if entry.get("effect", "") == effect:
			return true
	return false


func get_upgrade_value(effect: String, default: float = 0.0) -> float:
	var total: float = default
	for uid: String in owned_upgrades:
		var entry: Dictionary = _UpgradeCatalog.get_entry(uid)
		if entry.get("effect", "") == effect:
			total += float(entry.get("value", 0.0))
	return total


func get_upgrade_mult(effect: String, default: float = 1.0) -> float:
	var mult: float = default
	for uid: String in owned_upgrades:
		var entry: Dictionary = _UpgradeCatalog.get_entry(uid)
		if entry.get("effect", "") == effect:
			mult *= float(entry.get("value", 1.0))
	return mult


func _dict_from_variant(v: Variant) -> Dictionary:
	if v is Dictionary:
		return v.duplicate()
	return {}


func _string_array_from(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for item: Variant in v:
			out.append(str(item))
	return out


func _array_from_variant(v: Variant) -> Array:
	if v is Array:
		return v.duplicate()
	return []
