class_name AccessoryCatalog
extends RefCounted

const CompanionAccessoryConfigScript := preload("res://scripts/companion_accessory_config.gd")
const ProgressionRegistryScript := preload("res://scripts/progression/progression_registry.gd")
const DATA_PATH := "res://data/accessories.json"

static var _entries: Array[Dictionary] = []
static var _by_id: Dictionary = {}


static func load_catalog() -> void:
	if not _entries.is_empty():
		return
	var text := FileAccess.get_file_as_string(DATA_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("AccessoryCatalog: failed to parse %s" % DATA_PATH)
		return
	_entries.clear()
	_by_id.clear()
	for item: Variant in parsed:
		if item is Dictionary:
			var d: Dictionary = item
			_entries.append(d)
			_by_id[d.get("id", "")] = d


static func all() -> Array[Dictionary]:
	load_catalog()
	return _entries


static func get_entry(id: String) -> Dictionary:
	load_catalog()
	return _by_id.get(id, {}) if _by_id.has(id) else {}


static func get_for_slot(slot: String) -> Array[Dictionary]:
	load_catalog()
	var out: Array[Dictionary] = []
	var normalized_slot := slot.strip_edges().to_lower()
	for e: Dictionary in _entries:
		if str(e.get("slot", "")).strip_edges().to_lower() == normalized_slot:
			out.append(e)
	return out


static func get_for_category(category: String) -> Array[Dictionary]:
	var socket: String = CompanionAccessoryConfigScript.socket_for_category(category)
	if socket == "":
		return []
	return get_for_slot(socket)


static func get_socket_for_accessory(accessory_id: String) -> String:
	var entry: Dictionary = get_entry(accessory_id)
	if not entry.is_empty():
		return str(entry.get("slot", "")).strip_edges().to_lower()
	var def: AccessoryDefinition = ProgressionRegistryScript.get_accessory(accessory_id)
	if def != null:
		return def.resolved_socket()
	return ""


static func get_category_for_accessory(accessory_id: String) -> String:
	var socket: String = get_socket_for_accessory(accessory_id)
	return CompanionAccessoryConfigScript.category_for_socket(socket)


static func allows_duplicate_equip(accessory_id: String) -> bool:
	var def: AccessoryDefinition = ProgressionRegistryScript.get_accessory(accessory_id)
	if def != null:
		return def.allows_duplicate_equip
	var entry: Dictionary = get_entry(accessory_id)
	return bool(entry.get("allows_duplicate", false))


static func display_name_for(accessory_id: String) -> String:
	var def: AccessoryDefinition = ProgressionRegistryScript.get_accessory(accessory_id)
	if def != null and def.display_name != "":
		return def.display_name
	var entry: Dictionary = get_entry(accessory_id)
	if not entry.is_empty():
		return str(entry.get("name", accessory_id))
	return accessory_id


static func random_shop_id(owned: Array[String]) -> String:
	load_catalog()
	var pool: Array[String] = []
	for e: Dictionary in _entries:
		var id: String = e.get("id", "")
		if id != "" and not owned.has(id):
			pool.append(id)
	if pool.is_empty():
		for e: Dictionary in _entries:
			pool.append(e.get("id", ""))
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]
