class_name IslandProgress
extends RefCounted

const _IslandProgressState := preload("res://scripts/progression/island_progress_state.gd")
const _ProgressionRegistry := preload("res://scripts/progression/progression_registry.gd")


static func default_entry() -> Dictionary:
	return _IslandProgressState.default_entry()


static func normalize(raw: Dictionary, island_id: String = "") -> Dictionary:
	if island_id != "":
		return _IslandProgressState.migrate_legacy_entry(island_id, raw, _ProgressionRegistry)
	return _IslandProgressState.normalize(raw)


static func has_badge(progress: Dictionary, local_level: int, island_id: String = "") -> bool:
	if island_id != "":
		return _IslandProgressState.has_escort_badge_by_order(progress, island_id, local_level, _ProgressionRegistry)
	var badges: Variant = progress.get("escort_badge_level_ids", progress.get("escort_badges", []))
	if badges is Array:
		return (badges as Array).has(local_level)
	return false


static func has_badge_for_level(progress: Dictionary, level_id: String) -> bool:
	return _IslandProgressState.has_escort_badge(progress, level_id)


static func badge_count(progress: Dictionary) -> int:
	return _IslandProgressState.badge_count(progress)


static func is_level_completed(progress: Dictionary, local_level: int, island_id: String = "") -> bool:
	if island_id != "":
		return _IslandProgressState.is_level_completed_by_order(
			progress, island_id, local_level, _ProgressionRegistry
		)
	var mask: int = int(progress.get("completed_levels", 0))
	return (mask & (1 << local_level)) != 0


static func is_level_completed_by_id(progress: Dictionary, level_id: String) -> bool:
	return _IslandProgressState.has_completed_level(progress, level_id)


static func mark_level_completed(progress: Dictionary, local_level: int, island_id: String = "") -> void:
	if island_id != "":
		var level_id: String = _ProgressionRegistry.level_id_for_order(island_id, local_level)
		if level_id != "":
			_IslandProgressState.mark_level_completed(progress, level_id)
			return
	var mask: int = int(progress.get("completed_levels", 0))
	progress["completed_levels"] = mask | (1 << local_level)


static func mark_level_completed_by_id(progress: Dictionary, level_id: String) -> void:
	_IslandProgressState.mark_level_completed(progress, level_id)


static func completed_count(progress: Dictionary, level_count: int = -1) -> int:
	if progress.has("completed_level_ids"):
		return _IslandProgressState.completed_count(progress)
	var count := 0
	var total: int = level_count if level_count > 0 else 32
	for i in range(total):
		if is_level_completed(progress, i):
			count += 1
	return count


static func add_badge(progress: Dictionary, local_level: int, island_id: String = "") -> bool:
	if island_id != "":
		var level_id: String = _ProgressionRegistry.level_id_for_order(island_id, local_level)
		if level_id != "":
			return _IslandProgressState.add_escort_badge(progress, level_id)
		return false
	if has_badge(progress, local_level):
		return false
	var badges: Array = []
	var raw: Variant = progress.get("escort_badges", [])
	if raw is Array:
		for item: Variant in raw:
			badges.append(int(item))
	badges.append(local_level)
	badges.sort()
	progress["escort_badges"] = badges
	return true


static func add_badge_for_level(progress: Dictionary, level_id: String) -> bool:
	return _IslandProgressState.add_escort_badge(progress, level_id)
