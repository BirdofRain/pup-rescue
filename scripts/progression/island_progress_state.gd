class_name IslandProgressState
extends RefCounted

const ProgressionRegistryScript := preload("res://scripts/progression/progression_registry.gd")


static func default_entry() -> Dictionary:
	return {
		"unlocked": false,
		"completed_level_ids": [],
		"special_pup_found": false,
		"special_pup_discovery_level_id": "",
		"escort_badge_level_ids": [],
		"companion_unlocked": false,
	}


static func normalize(raw: Dictionary) -> Dictionary:
	var entry: Dictionary = default_entry()
	entry["unlocked"] = bool(raw.get("unlocked", false))
	entry["special_pup_found"] = bool(raw.get("special_pup_found", false))
	entry["special_pup_discovery_level_id"] = str(raw.get("special_pup_discovery_level_id", ""))
	entry["companion_unlocked"] = bool(raw.get("companion_unlocked", false))
	entry["completed_level_ids"] = _string_array(raw.get("completed_level_ids", []))
	entry["escort_badge_level_ids"] = _string_array(raw.get("escort_badge_level_ids", []))
	return entry


static func migrate_legacy_entry(
	island_id: String,
	raw: Dictionary,
	registry: ProgressionRegistry
) -> Dictionary:
	if raw.has("completed_level_ids") or raw.has("escort_badge_level_ids"):
		return normalize(raw)
	var entry: Dictionary = normalize(raw)
	entry["unlocked"] = bool(raw.get("unlocked", false))
	entry["special_pup_found"] = bool(raw.get("special_pup_found", false))
	entry["companion_unlocked"] = bool(raw.get("companion_unlocked", false))
	var mask: int = int(raw.get("completed_levels", 0))
	var badges: Variant = raw.get("escort_badges", [])
	for local_idx in range(32):
		if (mask & (1 << local_idx)) == 0:
			continue
		var level_id: String = registry.level_id_for_order(island_id, local_idx)
		if level_id != "":
			entry["completed_level_ids"].append(level_id)
	if badges is Array:
		for item: Variant in badges:
			var level_id: String = registry.level_id_for_order(island_id, int(item))
			if level_id != "" and not (entry["escort_badge_level_ids"] as Array).has(level_id):
				(entry["escort_badge_level_ids"] as Array).append(level_id)
	if entry["special_pup_found"]:
		var discovery_id: String = registry.discovery_level_id(island_id)
		if discovery_id != "":
			entry["special_pup_discovery_level_id"] = discovery_id
	entry["completed_level_ids"] = _unique_sorted(entry["completed_level_ids"])
	entry["escort_badge_level_ids"] = _unique_sorted(entry["escort_badge_level_ids"])
	return entry


static func has_completed_level(progress: Dictionary, level_id: String) -> bool:
	return _string_array(progress.get("completed_level_ids", [])).has(level_id)


static func has_escort_badge(progress: Dictionary, level_id: String) -> bool:
	return _string_array(progress.get("escort_badge_level_ids", [])).has(level_id)


static func badge_count(progress: Dictionary) -> int:
	return _string_array(progress.get("escort_badge_level_ids", [])).size()


static func completed_count(progress: Dictionary) -> int:
	return _string_array(progress.get("completed_level_ids", [])).size()


static func mark_level_completed(progress: Dictionary, level_id: String) -> void:
	var ids: Array[String] = _string_array(progress.get("completed_level_ids", []))
	if not ids.has(level_id):
		ids.append(level_id)
	progress["completed_level_ids"] = _unique_sorted(ids)


static func add_escort_badge(progress: Dictionary, level_id: String) -> bool:
	if has_escort_badge(progress, level_id):
		return false
	var ids: Array[String] = _string_array(progress.get("escort_badge_level_ids", []))
	ids.append(level_id)
	progress["escort_badge_level_ids"] = _unique_sorted(ids)
	return true


static func is_level_completed_by_order(
	progress: Dictionary,
	island_id: String,
	local_level: int,
	registry: ProgressionRegistry
) -> bool:
	var level_id: String = registry.level_id_for_order(island_id, local_level)
	if level_id == "":
		return false
	return has_completed_level(progress, level_id)


static func has_escort_badge_by_order(
	progress: Dictionary,
	island_id: String,
	local_level: int,
	registry: ProgressionRegistry
) -> bool:
	var level_id: String = registry.level_id_for_order(island_id, local_level)
	if level_id == "":
		return false
	return has_escort_badge(progress, level_id)


static func _string_array(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw is Array:
		for item: Variant in raw:
			var id := str(item)
			if id != "":
				out.append(id)
	return out


static func _unique_sorted(ids: Array[String]) -> Array[String]:
	var seen: Dictionary = {}
	var out: Array[String] = []
	for id: String in ids:
		if id == "" or seen.has(id):
			continue
		seen[id] = true
		out.append(id)
	out.sort()
	return out
