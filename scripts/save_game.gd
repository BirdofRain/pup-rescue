extends Node
class_name GameSave
## Autoload singleton at /root/SaveGame — use GameSave type via get_node, not bare SaveGame identifier.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION: int = 2
const _UpgradeCatalog := preload("res://scripts/upgrade_catalog.gd")
const _PupColors := preload("res://scripts/pup_colors.gd")
const _ProgressTracker := preload("res://scripts/progress_tracker.gd")
const _DifficultyConfig := preload("res://scripts/difficulty_config.gd")
const _FollowerSnap := preload("res://scripts/follower_snap.gd")
const _TouchControlConfig := preload("res://scripts/touch_control_config.gd")
const _IslandCatalog := preload("res://scripts/island_catalog.gd")
const _IslandProgress := preload("res://scripts/island_progress.gd")
const _ProgressionRegistry := preload("res://scripts/progression/progression_registry.gd")
const _AccessoryCatalog := preload("res://scripts/accessory_catalog.gd")
const _CompanionAccessoryConfig := preload("res://scripts/companion_accessory_config.gd")

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
var touch_control_mode: int = _TouchControlConfig.default_mode()

var save_version: int = SAVE_VERSION
var current_island_id: String = ""
var current_local_level: int = 0
var islands: Dictionary = {}
var owned_companions: Array[String] = []
var selected_companion_id: String = ""
var companion_custom_names: Dictionary = {}
var companion_equipped_accessories: Dictionary = {}
var accessory_inventory: Array[String] = []
var acknowledged_companion_unlocks: Array[String] = []
var pending_special_pup_celebrations: Array[String] = []
var pending_badge_celebrations: Array[String] = []
var pending_accessory_reveals: Array[String] = []
var portrait_revealed_islands: Array[String] = []
var total_temporary_puppies_rescued: int = 0

var boot_test_mode: bool = false
var boot_new_game: bool = false
var play_island_id: String = ""
var play_local_level: int = 0
var play_replay: bool = false
var clubhouse_focus_companion_id: String = ""

signal island_progress_changed(island_id: String)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func sync_owned_companion_starter_accessories() -> bool:
	var changed: bool = false
	for companion_id: String in owned_companions:
		var companion: CompanionDefinition = _ProgressionRegistry.get_companion(companion_id)
		if companion == null:
			continue
		for accessory_id: String in companion.starter_accessory_ids:
			if unlock_accessory(accessory_id):
				changed = true
	return changed


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
	data = migrate_save(data)
	_apply_save_dict(data)
	if sync_owned_companion_starter_accessories():
		save_game()
	_sync_legacy_progression_feedback()
	return true


func _sync_legacy_progression_feedback() -> void:
	var changed: bool = false
	for island_id: String in islands.keys():
		if not is_special_pup_found(island_id):
			continue
		if portrait_revealed_islands.has(island_id):
			continue
		if pending_special_pup_celebrations.has(island_id):
			continue
		portrait_revealed_islands.append(island_id)
		changed = true
	if changed:
		save_game()


func migrate_save(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("save_version", 0))
	var migrated: Dictionary = data.duplicate(true)
	if version < 1:
		migrated = _migrate_v0_to_v1(migrated)
		version = 1
	if version < 2:
		migrated = _migrate_v1_to_v2(migrated)
	migrated["save_version"] = SAVE_VERSION
	return migrated


func _migrate_v0_to_v1(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	_ProgressionRegistry.ensure_loaded()
	var legacy_level: int = int(migrated.get("current_level", 0))
	var first_island: String = _IslandCatalog.first_island_id()
	var level_count: int = _IslandCatalog.level_count(first_island)
	var local_level: int = mini(legacy_level, maxi(0, level_count - 1))
	var completed_mask := 0
	for i in range(mini(legacy_level, level_count)):
		completed_mask |= 1 << i
	migrated["current_island_id"] = first_island
	migrated["current_local_level"] = local_level
	migrated["islands"] = {
		first_island: {
			"unlocked": true,
			"special_pup_found": false,
			"escort_badges": [],
			"completed_levels": completed_mask,
			"companion_unlocked": false,
		},
	}
	migrated["owned_companions"] = migrated.get("owned_companions", [])
	migrated["selected_companion_id"] = str(migrated.get("selected_companion_id", ""))
	return migrated


func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	_ProgressionRegistry.ensure_loaded()
	var raw_islands: Variant = migrated.get("islands", {})
	var normalized: Dictionary = {}
	if raw_islands is Dictionary:
		for island_id: Variant in (raw_islands as Dictionary).keys():
			var id: String = str(island_id)
			var entry: Variant = (raw_islands as Dictionary)[island_id]
			if entry is Dictionary:
				normalized[id] = _IslandProgress.normalize(entry as Dictionary, id)
	migrated["islands"] = normalized
	migrated["companion_custom_names"] = _dict_from_variant(migrated.get("companion_custom_names", {}))
	migrated["companion_equipped_accessories"] = _dict_from_variant(
		migrated.get("companion_equipped_accessories", {})
	)
	migrated["accessory_inventory"] = _string_array_from(
		migrated.get("accessory_inventory", migrated.get("owned_accessories", []))
	)
	migrated["owned_accessories"] = (migrated["accessory_inventory"] as Array).duplicate()
	migrated["total_temporary_puppies_rescued"] = int(
		migrated.get("total_temporary_puppies_rescued", migrated.get("total_rescued", 0))
	)
	migrated["total_rescued"] = migrated["total_temporary_puppies_rescued"]
	var companions: Array[String] = _string_array_from(migrated.get("owned_companions", []))
	var normalized_companions: Array[String] = []
	for companion_id: String in companions:
		var normalized_id: String = _ProgressionRegistry.normalize_companion_id(companion_id)
		if normalized_id != "" and not normalized_companions.has(normalized_id):
			normalized_companions.append(normalized_id)
	migrated["owned_companions"] = normalized_companions
	var selected: String = _ProgressionRegistry.normalize_companion_id(
		str(migrated.get("selected_companion_id", ""))
	)
	migrated["selected_companion_id"] = selected
	return migrated


func _apply_save_dict(data: Dictionary) -> void:
	save_version = int(data.get("save_version", SAVE_VERSION))
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
	touch_control_mode = _TouchControlConfig.clamp_mode(
		int(data.get("touch_control_mode", _TouchControlConfig.default_mode()))
	)
	current_island_id = str(data.get("current_island_id", _IslandCatalog.first_island_id()))
	current_local_level = int(data.get("current_local_level", 0))
	islands = _dict_from_variant(data.get("islands", {}))
	owned_companions = _normalize_companion_ids(_string_array_from(data.get("owned_companions", [])))
	selected_companion_id = _ProgressionRegistry.normalize_companion_id(
		str(data.get("selected_companion_id", ""))
	)
	companion_custom_names = _dict_from_variant(data.get("companion_custom_names", {}))
	companion_equipped_accessories = _dict_from_variant(data.get("companion_equipped_accessories", {}))
	accessory_inventory = _string_array_from(
		data.get("accessory_inventory", data.get("owned_accessories", []))
	)
	acknowledged_companion_unlocks = _normalize_companion_ids(
		_string_array_from(data.get("acknowledged_companion_unlocks", []))
	)
	pending_special_pup_celebrations = _string_array_from(
		data.get("pending_special_pup_celebrations", [])
	)
	pending_badge_celebrations = _string_array_from(data.get("pending_badge_celebrations", []))
	pending_accessory_reveals = _string_array_from(data.get("pending_accessory_reveals", []))
	portrait_revealed_islands = _string_array_from(data.get("portrait_revealed_islands", []))
	owned_accessories = accessory_inventory.duplicate()
	total_temporary_puppies_rescued = int(
		data.get("total_temporary_puppies_rescued", data.get("total_rescued", 0))
	)
	total_rescued = total_temporary_puppies_rescued
	_ensure_island_defaults()
	sync_current_level_from_islands()


func _ensure_island_defaults() -> void:
	_ProgressionRegistry.ensure_loaded()
	var first: String = _IslandCatalog.first_island_id()
	if current_island_id == "":
		current_island_id = first
	for island: IslandDefinition in _ProgressionRegistry.all_islands():
		var id: String = island.island_id
		if not islands.has(id):
			islands[id] = _IslandProgress.default_entry()
		islands[id] = _IslandProgress.normalize(islands[id], id)
		if id == first:
			islands[id]["unlocked"] = true


func _sync_progress_totals() -> void:
	total_temporary_puppies_rescued = total_rescued


func _sync_inventory_fields() -> void:
	owned_accessories = accessory_inventory.duplicate()


func _normalize_companion_ids(raw: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for companion_id: String in raw:
		var normalized: String = _ProgressionRegistry.normalize_companion_id(companion_id)
		if normalized != "" and not out.has(normalized):
			out.append(normalized)
	return out


func save_game() -> void:
	sync_current_level_from_islands()
	_sync_progress_totals()
	_sync_inventory_fields()
	var data := {
		"save_version": SAVE_VERSION,
		"current_level": current_level,
		"current_island_id": current_island_id,
		"current_local_level": current_local_level,
		"islands": islands.duplicate(true),
		"owned_companions": owned_companions.duplicate(),
		"selected_companion_id": selected_companion_id,
		"companion_custom_names": companion_custom_names.duplicate(),
		"companion_equipped_accessories": companion_equipped_accessories.duplicate(true),
		"accessory_inventory": accessory_inventory.duplicate(),
		"acknowledged_companion_unlocks": acknowledged_companion_unlocks.duplicate(),
		"pending_special_pup_celebrations": pending_special_pup_celebrations.duplicate(),
		"pending_badge_celebrations": pending_badge_celebrations.duplicate(),
		"pending_accessory_reveals": pending_accessory_reveals.duplicate(),
		"portrait_revealed_islands": portrait_revealed_islands.duplicate(),
		"total_temporary_puppies_rescued": total_temporary_puppies_rescued,
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
		"touch_control_mode": touch_control_mode,
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
	islands = {}
	owned_companions = []
	selected_companion_id = ""
	companion_custom_names = {}
	companion_equipped_accessories = {}
	accessory_inventory = []
	acknowledged_companion_unlocks = []
	pending_special_pup_celebrations = []
	pending_badge_celebrations = []
	pending_accessory_reveals = []
	portrait_revealed_islands = []
	total_temporary_puppies_rescued = 0
	current_island_id = _IslandCatalog.first_island_id()
	current_local_level = 0
	_ensure_island_defaults()
	sync_current_level_from_islands()
	boot_test_mode = false
	boot_new_game = true
	play_island_id = ""
	play_local_level = 0
	play_replay = false
	save_game()


func prepare_continue() -> void:
	load_save()
	boot_test_mode = false
	boot_new_game = false
	play_island_id = ""
	play_local_level = 0
	play_replay = false


func prepare_test_maze(selected_coat: int) -> void:
	current_level = 0
	coat_index = _PupColors.clamp_index(selected_coat)
	boot_test_mode = true
	boot_new_game = false
	play_island_id = ""
	play_local_level = 0
	play_replay = false


func set_play_target(island_id: String, local_level: int, replay: bool = false) -> void:
	play_island_id = island_id
	play_local_level = maxi(0, local_level)
	play_replay = replay
	current_island_id = island_id
	current_local_level = play_local_level
	sync_current_level_from_islands()


func clear_play_target() -> void:
	play_island_id = ""
	play_local_level = 0
	play_replay = false


func get_play_island_id() -> String:
	if play_island_id != "":
		return play_island_id
	if current_island_id != "":
		return current_island_id
	return _IslandCatalog.first_island_id()


func get_play_local_level() -> int:
	if play_island_id != "":
		return play_local_level
	return current_local_level


func resolve_global_level_index(island_id: String = "", local_level: int = -1) -> int:
	var island: String = island_id if island_id != "" else get_play_island_id()
	var local: int = local_level if local_level >= 0 else get_play_local_level()
	return _IslandCatalog.resolve_global_level_index(island, local)


func sync_current_level_from_islands() -> void:
	if current_island_id == "":
		current_island_id = _IslandCatalog.first_island_id()
	current_level = resolve_global_level_index(current_island_id, current_local_level)


func get_island_progress(island_id: String) -> Dictionary:
	_ensure_island_defaults()
	if islands.has(island_id):
		return islands[island_id]
	return _IslandProgress.default_entry()


func is_island_unlocked(island_id: String) -> bool:
	return bool(get_island_progress(island_id).get("unlocked", false))


func is_level_completed(island_id: String, local_level: int) -> bool:
	return _IslandProgress.is_level_completed(get_island_progress(island_id), local_level, island_id)


func is_level_completed_by_id(island_id: String, level_id: String) -> bool:
	return _IslandProgress.is_level_completed_by_id(get_island_progress(island_id), level_id)


func has_escort_badge(island_id: String, local_level: int) -> bool:
	return _IslandProgress.has_badge(get_island_progress(island_id), local_level, island_id)


func has_escort_badge_for_level(island_id: String, level_id: String) -> bool:
	return _IslandProgress.has_badge_for_level(get_island_progress(island_id), level_id)


func escort_badge_count(island_id: String) -> int:
	return _IslandProgress.badge_count(get_island_progress(island_id))


func is_special_pup_found(island_id: String) -> bool:
	return bool(get_island_progress(island_id).get("special_pup_found", false))


func owns_companion(companion_id: String) -> bool:
	return owned_companions.has(_ProgressionRegistry.normalize_companion_id(companion_id))


func get_companion_display_name(companion_id: String) -> String:
	var normalized: String = _ProgressionRegistry.normalize_companion_id(companion_id)
	if companion_custom_names.has(normalized):
		return str(companion_custom_names[normalized])
	var companion: CompanionDefinition = _ProgressionRegistry.get_companion(normalized)
	if companion != null:
		return companion.default_name
	return normalized


func set_companion_custom_name(companion_id: String, raw_name: String) -> bool:
	var normalized: String = _ProgressionRegistry.normalize_companion_id(companion_id)
	if not owns_companion(normalized):
		return false
	var sanitized: String = _ProgressTracker.sanitize_name(raw_name)
	if sanitized == "":
		return false
	companion_custom_names[normalized] = sanitized
	return true


func restore_companion_default_name(companion_id: String) -> void:
	var normalized: String = _ProgressionRegistry.normalize_companion_id(companion_id)
	if not owns_companion(normalized):
		return
	companion_custom_names.erase(normalized)
	save_game()


func get_companion_equipped(companion_id: String, socket: String) -> String:
	var normalized: String = _ProgressionRegistry.normalize_companion_id(companion_id)
	var equipped_for: Variant = companion_equipped_accessories.get(normalized, {})
	if equipped_for is Dictionary:
		return str((equipped_for as Dictionary).get(socket.strip_edges().to_lower(), ""))
	return ""


func get_companion_loadout(companion_id: String) -> Dictionary:
	var loadout: Dictionary = {}
	for socket: String in _CompanionAccessoryConfig.ALL_SOCKETS:
		var equipped_id: String = get_companion_equipped(companion_id, socket)
		if equipped_id != "":
			loadout[socket] = equipped_id
	return loadout


func find_companion_wearing_accessory(accessory_id: String) -> String:
	if accessory_id == "":
		return ""
	for companion_id: String in owned_companions:
		var raw: Variant = companion_equipped_accessories.get(companion_id, {})
		if raw is Dictionary:
			for equipped_id: Variant in (raw as Dictionary).values():
				if str(equipped_id) == accessory_id:
					return companion_id
	return ""


func unequip_companion_socket(companion_id: String, socket: String) -> void:
	var normalized: String = _ProgressionRegistry.normalize_companion_id(companion_id)
	if not owns_companion(normalized):
		return
	var normalized_socket: String = socket.strip_edges().to_lower()
	var equipped_for: Dictionary = {}
	var raw: Variant = companion_equipped_accessories.get(normalized, {})
	if raw is Dictionary:
		equipped_for = (raw as Dictionary).duplicate()
	equipped_for.erase(normalized_socket)
	companion_equipped_accessories[normalized] = equipped_for
	save_game()


func unequip_companion_category(companion_id: String, category: String) -> void:
	var socket: String = _CompanionAccessoryConfig.socket_for_category(category)
	if socket == "":
		return
	unequip_companion_socket(companion_id, socket)


func equip_companion_accessory(companion_id: String, accessory_id: String) -> bool:
	var normalized: String = _ProgressionRegistry.normalize_companion_id(companion_id)
	if not owns_companion(normalized) or accessory_id == "" or not owns_accessory(accessory_id):
		return false
	var socket: String = _AccessoryCatalog.get_socket_for_accessory(accessory_id)
	if socket == "":
		return false
	if not _AccessoryCatalog.allows_duplicate_equip(accessory_id):
		var previous_wearer: String = find_companion_wearing_accessory(accessory_id)
		if previous_wearer != "" and previous_wearer != normalized:
			_remove_accessory_from_companion(previous_wearer, accessory_id)
	var equipped_for: Dictionary = {}
	var raw: Variant = companion_equipped_accessories.get(normalized, {})
	if raw is Dictionary:
		equipped_for = (raw as Dictionary).duplicate()
	equipped_for[socket] = accessory_id
	companion_equipped_accessories[normalized] = equipped_for
	save_game()
	return true


func set_companion_equipped(companion_id: String, socket: String, accessory_id: String) -> void:
	if accessory_id == "":
		unequip_companion_socket(companion_id, socket)
	else:
		equip_companion_accessory(companion_id, accessory_id)


func _remove_accessory_from_companion(companion_id: String, accessory_id: String) -> void:
	var normalized: String = _ProgressionRegistry.normalize_companion_id(companion_id)
	var raw: Variant = companion_equipped_accessories.get(normalized, {})
	if not raw is Dictionary:
		return
	var equipped_for: Dictionary = (raw as Dictionary).duplicate()
	for socket_key: Variant in equipped_for.keys():
		if str(equipped_for[socket_key]) == accessory_id:
			equipped_for.erase(socket_key)
	companion_equipped_accessories[normalized] = equipped_for


func set_selected_companion(companion_id: String) -> void:
	var normalized: String = _ProgressionRegistry.normalize_companion_id(companion_id)
	if normalized == "" or owns_companion(normalized):
		selected_companion_id = normalized


func set_clubhouse_focus(companion_id: String) -> void:
	clubhouse_focus_companion_id = _ProgressionRegistry.normalize_companion_id(companion_id)


func consume_clubhouse_focus() -> String:
	var focused: String = clubhouse_focus_companion_id
	clubhouse_focus_companion_id = ""
	return focused


func mark_special_pup_found(island_id: String, discovery_level_id: String = "") -> bool:
	_ensure_island_defaults()
	if not islands.has(island_id):
		islands[island_id] = _IslandProgress.default_entry()
	var progress: Dictionary = islands[island_id]
	if bool(progress.get("special_pup_found", false)):
		return false
	progress["special_pup_found"] = true
	var resolved_level_id: String = discovery_level_id
	if resolved_level_id == "":
		resolved_level_id = _ProgressionRegistry.discovery_level_id(island_id)
	if resolved_level_id != "":
		progress["special_pup_discovery_level_id"] = resolved_level_id
	islands[island_id] = progress
	queue_special_pup_celebration(island_id)
	return true


func queue_special_pup_celebration(island_id: String) -> void:
	if island_id == "" or pending_special_pup_celebrations.has(island_id):
		return
	pending_special_pup_celebrations.append(island_id)


func acknowledge_special_pup_celebration(island_id: String) -> void:
	if island_id == "":
		return
	pending_special_pup_celebrations.erase(island_id)
	save_game()


func first_pending_special_pup_celebration() -> String:
	if pending_special_pup_celebrations.is_empty():
		return ""
	return pending_special_pup_celebrations[0]


func _badge_celebration_key(island_id: String, local_level: int) -> String:
	return "%s:%d" % [island_id, local_level]


func queue_badge_celebration(island_id: String, local_level: int) -> void:
	var key: String = _badge_celebration_key(island_id, local_level)
	if key == "" or pending_badge_celebrations.has(key):
		return
	pending_badge_celebrations.append(key)


func acknowledge_badge_celebration(island_id: String, local_level: int) -> void:
	var key: String = _badge_celebration_key(island_id, local_level)
	pending_badge_celebrations.erase(key)
	save_game()


func first_pending_badge_for_island(island_id: String) -> Dictionary:
	for key: String in pending_badge_celebrations:
		var parts: PackedStringArray = key.split(":")
		if parts.size() < 2:
			continue
		if parts[0] == island_id:
			return {"island_id": island_id, "local_level": int(parts[1])}
	return {"island_id": "", "local_level": -1}


func queue_accessory_reveal(accessory_id: String) -> void:
	if accessory_id == "" or pending_accessory_reveals.has(accessory_id):
		return
	pending_accessory_reveals.append(accessory_id)


func acknowledge_accessory_reveal(accessory_id: String) -> void:
	if accessory_id == "":
		return
	pending_accessory_reveals.erase(accessory_id)
	save_game()


func first_pending_accessory_reveal() -> String:
	if pending_accessory_reveals.is_empty():
		return ""
	return pending_accessory_reveals[0]


func needs_portrait_reveal(island_id: String) -> bool:
	return is_special_pup_found(island_id) and not portrait_revealed_islands.has(island_id)


func mark_portrait_revealed(island_id: String) -> void:
	if island_id == "" or portrait_revealed_islands.has(island_id):
		return
	portrait_revealed_islands.append(island_id)
	save_game()


func get_island_map_marker(island_id: String) -> String:
	if not is_island_unlocked(island_id):
		return "🔒"
	if is_island_companion_unlocked(island_id):
		return "⭐"
	if not is_special_pup_found(island_id):
		return "❓"
	var badges: int = escort_badge_count(island_id)
	var required: int = _IslandCatalog.badges_required(island_id)
	if badges < required:
		return "🐾"
	return "✓"


func award_escort_badge(island_id: String, local_level: int) -> bool:
	_ensure_island_defaults()
	if not islands.has(island_id):
		islands[island_id] = _IslandProgress.default_entry()
	var progress: Dictionary = islands[island_id]
	var added: bool = _IslandProgress.add_badge(progress, local_level, island_id)
	if added:
		islands[island_id] = progress
		queue_badge_celebration(island_id, local_level)
	return added


func is_island_companion_unlocked(island_id: String) -> bool:
	return bool(get_island_progress(island_id).get("companion_unlocked", false))


func should_show_companion_celebration(companion_id: String) -> bool:
	var normalized: String = _ProgressionRegistry.normalize_companion_id(companion_id)
	if normalized == "" or not owns_companion(normalized):
		return false
	return not acknowledged_companion_unlocks.has(normalized)


func acknowledge_companion_unlock(companion_id: String) -> void:
	var normalized: String = _ProgressionRegistry.normalize_companion_id(companion_id)
	if normalized == "" or acknowledged_companion_unlocks.has(normalized):
		return
	acknowledged_companion_unlocks.append(normalized)
	var companion: CompanionDefinition = _ProgressionRegistry.get_companion(normalized)
	if companion != null:
		for accessory_id: String in companion.starter_accessory_ids:
			pending_accessory_reveals.erase(accessory_id)
	save_game()


func first_unacknowledged_companion_unlock() -> String:
	for companion_id: String in owned_companions:
		if should_show_companion_celebration(companion_id):
			return companion_id
	return ""


func try_unlock_companion(island_id: String) -> Dictionary:
	var result := {
		"newly_unlocked": false,
		"companion_id": "",
	}
	var companion: CompanionDefinition = _ProgressionRegistry.get_special_companion(island_id)
	if companion == null:
		return result
	var companion_id: String = companion.companion_id
	result["companion_id"] = companion_id
	if not is_special_pup_found(island_id):
		return result
	var progress: Dictionary = get_island_progress(island_id)
	if bool(progress.get("companion_unlocked", false)):
		return result
	var level_count: int = _IslandCatalog.level_count(island_id)
	if _IslandProgress.badge_count(progress) < level_count:
		return result
	progress["companion_unlocked"] = true
	islands[island_id] = progress
	if not owned_companions.has(companion_id):
		owned_companions.append(companion_id)
	for accessory_id: String in companion.starter_accessory_ids:
		if unlock_accessory(accessory_id):
			queue_accessory_reveal(accessory_id)
	if selected_companion_id == "":
		selected_companion_id = companion_id
	result["newly_unlocked"] = true
	save_game()
	return result


func record_island_level_complete(
	island_id: String,
	local_level: int,
	rescued_this_level: int,
	squad_size: int,
	had_escort_at_exit: bool,
	replay: bool,
	commit_special_pup_discovery: bool = false
) -> Dictionary:
	var result := {
		"badge_awarded": false,
		"pup_found": false,
		"companion_unlocked": false,
		"companion_newly_unlocked": false,
		"unlocked_companion_id": "",
		"advanced": false,
	}
	if not replay:
		total_rescued += rescued_this_level
		total_temporary_puppies_rescued = total_rescued
	_ensure_island_defaults()
	if not islands.has(island_id):
		islands[island_id] = _IslandProgress.default_entry()
	var progress: Dictionary = islands[island_id]
	_IslandProgress.mark_level_completed(progress, local_level, island_id)
	islands[island_id] = progress

	var global_completed: int = resolve_global_level_index(island_id, local_level) + 1
	if not replay:
		_update_bests(global_completed, total_rescued, squad_size)

	if commit_special_pup_discovery:
		var discovery_id: String = _IslandCatalog.get_level_id(island_id, local_level)
		result["pup_found"] = mark_special_pup_found(island_id, discovery_id)

	if had_escort_at_exit and is_special_pup_found(island_id):
		if not has_escort_badge(island_id, local_level):
			result["badge_awarded"] = award_escort_badge(island_id, local_level)

	if is_special_pup_found(island_id):
		var unlock_result: Dictionary = try_unlock_companion(island_id)
		result["companion_newly_unlocked"] = bool(unlock_result.get("newly_unlocked", false))
		result["unlocked_companion_id"] = str(unlock_result.get("companion_id", ""))
		result["companion_unlocked"] = result["companion_newly_unlocked"] or is_island_companion_unlocked(island_id)

	if not replay:
		var count: int = _IslandCatalog.level_count(island_id)
		if local_level + 1 < count:
			current_local_level = local_level + 1
			result["advanced"] = true
		else:
			current_local_level = local_level
		current_island_id = island_id
		play_island_id = island_id
		play_local_level = current_local_level
		play_replay = false
		sync_current_level_from_islands()

	if progress_features_unlocked() and not replay:
		_append_leaderboard_entry(global_completed, total_rescued, squad_size)
	save_game()
	island_progress_changed.emit(island_id)
	return result


func record_level_complete(rescued_this_level: int, squad_size: int = 0) -> void:
	var island_id: String = get_play_island_id()
	var local_level: int = get_play_local_level()
	record_island_level_complete(
		island_id,
		local_level,
		rescued_this_level,
		squad_size,
		false,
		play_replay
	)


func record_level_complete_with_escort(
	rescued_this_level: int,
	squad_size: int,
	had_escort_at_exit: bool,
	commit_special_pup_discovery: bool = false
) -> Dictionary:
	return record_island_level_complete(
		get_play_island_id(),
		get_play_local_level(),
		rescued_this_level,
		squad_size,
		had_escort_at_exit,
		play_replay,
		commit_special_pup_discovery
	)


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


func get_touch_control_mode() -> int:
	return _TouchControlConfig.clamp_mode(touch_control_mode)


func set_touch_control_mode(mode: int) -> void:
	touch_control_mode = _TouchControlConfig.clamp_mode(mode)


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
	var display_level: int = resolve_global_level_index() + 1
	var display_rescued: int = total_rescued + maxi(0, rescued_pending)
	_update_bests(display_level, display_rescued, squad_size)
	if progress_features_unlocked():
		_append_leaderboard_entry(display_level, display_rescued, squad_size)


func save_run_progress(level_index: int, squad_size: int, rescued_pending: int = 0) -> void:
	current_level = level_index
	current_local_level = _IslandCatalog.local_level_for_global(level_index)
	current_island_id = _IslandCatalog.island_id_for_global_level(level_index)
	record_progress_snapshot(squad_size, rescued_pending)
	save_game()


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	treat_coins += amount


func add_temporary_rescues(amount: int) -> void:
	if amount <= 0:
		return
	total_rescued += amount
	total_temporary_puppies_rescued = total_rescued


func can_afford(cost: int) -> bool:
	return treat_coins >= cost


func spend_coins(cost: int) -> bool:
	if cost < 0 or treat_coins < cost:
		return false
	treat_coins -= cost
	return true


func owns_accessory(id: String) -> bool:
	return accessory_inventory.has(id) or owned_accessories.has(id)


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
	if id == "" or owns_accessory(id):
		return false
	owned_accessories.append(id)
	accessory_inventory.append(id)
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
		return v.duplicate(true)
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
