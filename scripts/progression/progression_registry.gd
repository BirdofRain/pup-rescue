class_name ProgressionRegistry
extends RefCounted

const ISLANDS_DIR := "res://resources/progression/islands/"
const LEVELS_DIR := "res://resources/progression/levels/"
const COMPANIONS_DIR := "res://resources/progression/companions/"
const ACCESSORIES_DIR := "res://resources/progression/accessories/"

const LegacyCompanionIds := {
	"beach_sandy": "companion_sandy",
}

static var _loaded: bool = false
static var _islands: Dictionary = {}
static var _levels: Dictionary = {}
static var _companions: Dictionary = {}
static var _accessories: Dictionary = {}
static var _island_order: Array[String] = []
static var _validation_errors: PackedStringArray = []


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_islands.clear()
	_levels.clear()
	_companions.clear()
	_accessories.clear()
	_island_order.clear()
	_load_resources(LEVELS_DIR, _levels)
	_load_resources(COMPANIONS_DIR, _companions)
	_load_resources(ACCESSORIES_DIR, _accessories)
	_load_resources(ISLANDS_DIR, _islands)
	_build_island_order()
	_validation_errors = ProgressionValidator.validate_loaded_content()
	for err: String in _validation_errors:
		push_error("ProgressionRegistry: %s" % err)


static func validation_errors() -> PackedStringArray:
	ensure_loaded()
	return _validation_errors.duplicate()


static func is_valid() -> bool:
	ensure_loaded()
	return _validation_errors.is_empty()


static func _load_resources(dir_path: String, target: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("ProgressionRegistry: missing directory %s" % dir_path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := dir_path.path_join(file_name)
			var resource: Resource = load(path)
			if resource == null:
				push_error("ProgressionRegistry: failed to load %s" % path)
			else:
				_register_resource(resource, target)
		file_name = dir.get_next()


static func _register_resource(resource: Resource, target: Dictionary) -> void:
	if resource is IslandDefinition:
		var island: IslandDefinition = resource
		if island.island_id != "":
			target[island.island_id] = island
	elif resource is LevelDefinition:
		var level: LevelDefinition = resource
		if level.level_id != "":
			target[level.level_id] = level
	elif resource is CompanionDefinition:
		var companion: CompanionDefinition = resource
		if companion.companion_id != "":
			target[companion.companion_id] = companion
	elif resource is AccessoryDefinition:
		var accessory: AccessoryDefinition = resource
		if accessory.accessory_id != "":
			target[accessory.accessory_id] = accessory


static func _build_island_order() -> void:
	var ids: Array[String] = []
	for island_id: String in _islands.keys():
		ids.append(island_id)
	ids.sort()
	_island_order = ids


static func all_islands() -> Array[IslandDefinition]:
	ensure_loaded()
	var out: Array[IslandDefinition] = []
	for id: String in _island_order:
		out.append(_islands[id])
	return out


static func all_levels() -> Array[LevelDefinition]:
	ensure_loaded()
	var out: Array[LevelDefinition] = []
	for level: LevelDefinition in _levels.values():
		out.append(level)
	return out


static func all_companions() -> Array[CompanionDefinition]:
	ensure_loaded()
	var out: Array[CompanionDefinition] = []
	for companion: CompanionDefinition in _companions.values():
		out.append(companion)
	return out


static func all_accessories() -> Array[AccessoryDefinition]:
	ensure_loaded()
	var out: Array[AccessoryDefinition] = []
	for accessory: AccessoryDefinition in _accessories.values():
		out.append(accessory)
	return out


static func has_island(island_id: String) -> bool:
	ensure_loaded()
	return _islands.has(island_id)


static func has_level(level_id: String) -> bool:
	ensure_loaded()
	return _levels.has(level_id)


static func has_companion(companion_id: String) -> bool:
	ensure_loaded()
	return _companions.has(normalize_companion_id(companion_id))


static func has_accessory(accessory_id: String) -> bool:
	ensure_loaded()
	return _accessories.has(accessory_id)


static func get_island(island_id: String) -> IslandDefinition:
	ensure_loaded()
	return _islands.get(island_id, null)


static func get_level(level_id: String) -> LevelDefinition:
	ensure_loaded()
	return _levels.get(level_id, null)


static func get_companion(companion_id: String) -> CompanionDefinition:
	ensure_loaded()
	return _companions.get(normalize_companion_id(companion_id), null)


static func get_accessory(accessory_id: String) -> AccessoryDefinition:
	ensure_loaded()
	return _accessories.get(accessory_id, null)


static func first_island_id() -> String:
	ensure_loaded()
	if _island_order.is_empty():
		return "beach"
	return _island_order[0]


static func level_count(island_id: String) -> int:
	var island: IslandDefinition = get_island(island_id)
	if island == null:
		return 0
	return island.level_count()


static func level_id_for_order(island_id: String, order_index: int) -> String:
	var island: IslandDefinition = get_island(island_id)
	if island == null:
		return ""
	if order_index < 0 or order_index >= island.level_ids.size():
		return ""
	return str(island.level_ids[order_index])


static func order_index_for_level(level_id: String) -> int:
	var level: LevelDefinition = get_level(level_id)
	if level == null:
		return -1
	return level.order_index


static func order_index_for_level_on_island(island_id: String, level_id: String) -> int:
	var island: IslandDefinition = get_island(island_id)
	if island == null:
		return -1
	var idx: int = island.level_ids.find(level_id)
	return idx


static func discovery_level_id(island_id: String) -> String:
	var island: IslandDefinition = get_island(island_id)
	if island == null:
		return ""
	for level_id: String in island.level_ids:
		var level: LevelDefinition = get_level(level_id)
		if level != null and level.allows_special_pup_discovery:
			return level_id
	return ""


static func discovery_order_index(island_id: String) -> int:
	var level_id: String = discovery_level_id(island_id)
	if level_id == "":
		return 0
	return order_index_for_level(level_id)


static func badges_required(island_id: String) -> int:
	var island: IslandDefinition = get_island(island_id)
	if island == null:
		return 0
	return island.badges_required()


static func global_level_offset(island_id: String) -> int:
	ensure_loaded()
	var offset := 0
	for id: String in _island_order:
		if id == island_id:
			return offset
		var island: IslandDefinition = get_island(id)
		if island != null:
			offset += island.level_count()
	return offset


static func resolve_global_level_index(island_id: String, local_level: int) -> int:
	var level_id: String = level_id_for_order(island_id, local_level)
	if level_id == "":
		return global_level_offset(island_id) + maxi(0, local_level)
	var level: LevelDefinition = get_level(level_id)
	if level != null:
		return level.global_procedural_index
	return global_level_offset(island_id) + local_level


static func island_id_for_global_level(global_level: int) -> String:
	ensure_loaded()
	for id: String in _island_order:
		var island: IslandDefinition = get_island(id)
		if island == null:
			continue
		for level_id: String in island.level_ids:
			var level: LevelDefinition = get_level(level_id)
			if level != null and level.global_procedural_index == global_level:
				return id
	return first_island_id()


static func local_level_for_global(global_level: int) -> int:
	var island_id: String = island_id_for_global_level(global_level)
	var island: IslandDefinition = get_island(island_id)
	if island == null:
		return 0
	for i in range(island.level_ids.size()):
		var level: LevelDefinition = get_level(str(island.level_ids[i]))
		if level != null and level.global_procedural_index == global_level:
			return i
	return 0


static func normalize_companion_id(companion_id: String) -> String:
	if LegacyCompanionIds.has(companion_id):
		return str(LegacyCompanionIds[companion_id])
	return companion_id


static func get_special_companion(island_id: String) -> CompanionDefinition:
	var island: IslandDefinition = get_island(island_id)
	if island == null or island.special_companion_id == "":
		return null
	return get_companion(island.special_companion_id)


static func to_legacy_island_dict(island_id: String) -> Dictionary:
	var island: IslandDefinition = get_island(island_id)
	if island == null:
		return {}
	var companion: CompanionDefinition = get_special_companion(island_id)
	return {
		"id": island.island_id,
		"name": island.display_name,
		"theme": island.theme_id,
		"level_count": island.level_count(),
		"wall_palette_index": island.wall_palette_index,
		"unlock_after": island.unlock_requirement.required_island_id if island.unlock_requirement else "",
		"special_pup": {
			"id": companion.companion_id if companion else "",
			"name": companion.default_name if companion else "",
			"coat_index": companion.coat_index if companion else 0,
			"hidden_level_index": discovery_order_index(island_id),
			"companion_unlock_badges_required": island.badges_required(),
		},
	}
