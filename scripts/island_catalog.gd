class_name IslandCatalog
extends RefCounted
## Legacy facade over ProgressionRegistry. Keeps existing callers working unchanged.

const _ProgressionRegistry := preload("res://scripts/progression/progression_registry.gd")


static func all() -> Array[Dictionary]:
	_ProgressionRegistry.ensure_loaded()
	var out: Array[Dictionary] = []
	for island: IslandDefinition in _ProgressionRegistry.all_islands():
		out.append(_ProgressionRegistry.to_legacy_island_dict(island.island_id))
	return out


static func get_island(id: String) -> Dictionary:
	_ProgressionRegistry.ensure_loaded()
	return _ProgressionRegistry.to_legacy_island_dict(id)


static func get_special_pup(island_id: String) -> Dictionary:
	var island: Dictionary = get_island(island_id)
	var pup: Variant = island.get("special_pup", {})
	return pup if pup is Dictionary else {}


static func level_count(island_id: String) -> int:
	return _ProgressionRegistry.level_count(island_id)


static func hidden_level_index(island_id: String) -> int:
	return _ProgressionRegistry.discovery_order_index(island_id)


static func badges_required(island_id: String) -> int:
	return _ProgressionRegistry.badges_required(island_id)


static func global_level_offset(island_id: String) -> int:
	return _ProgressionRegistry.global_level_offset(island_id)


static func resolve_global_level_index(island_id: String, local_level: int) -> int:
	return _ProgressionRegistry.resolve_global_level_index(island_id, local_level)


static func island_id_for_global_level(global_level: int) -> String:
	return _ProgressionRegistry.island_id_for_global_level(global_level)


static func local_level_for_global(global_level: int) -> int:
	return _ProgressionRegistry.local_level_for_global(global_level)


static func first_island_id() -> String:
	return _ProgressionRegistry.first_island_id()


static func get_level_id(island_id: String, local_level: int) -> String:
	return _ProgressionRegistry.level_id_for_order(island_id, local_level)


static func get_registry() -> void:
	_ProgressionRegistry.ensure_loaded()
