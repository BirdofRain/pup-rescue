class_name UpgradeCatalog
extends RefCounted

const DATA_PATH := "res://data/upgrades.json"

static var _entries: Array[Dictionary] = []
static var _by_id: Dictionary = {}


static func load_catalog() -> void:
	if not _entries.is_empty():
		return
	var text := FileAccess.get_file_as_string(DATA_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("UpgradeCatalog: failed to parse %s" % DATA_PATH)
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
