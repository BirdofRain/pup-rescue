extends Node
class_name GameSave
## Autoload singleton at /root/SaveGame — use GameSave type via get_node, not bare SaveGame identifier.

const SAVE_PATH := "user://save.json"
const _UpgradeCatalog := preload("res://scripts/upgrade_catalog.gd")
const _PupColors := preload("res://scripts/pup_colors.gd")

var current_level: int = 0
var total_rescued: int = 0
var coat_index: int = 0
var treat_coins: int = 0
var equipped: Dictionary = {}
var owned_accessories: Array[String] = []
var owned_upgrades: Array[String] = []
var stats: Dictionary = {}

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
	return true


func save_game() -> void:
	var data := {
		"current_level": current_level,
		"total_rescued": total_rescued,
		"coat_index": coat_index,
		"treat_coins": treat_coins,
		"equipped": equipped.duplicate(),
		"owned_accessories": owned_accessories.duplicate(),
		"owned_upgrades": owned_upgrades.duplicate(),
		"stats": stats.duplicate(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()


func prepare_new_game(selected_coat: int) -> void:
	current_level = 0
	total_rescued = 0
	treat_coins = 0
	coat_index = _PupColors.clamp_index(selected_coat)
	equipped = {}
	owned_accessories = []
	owned_upgrades = []
	stats = {}
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


func record_level_complete(rescued_this_level: int) -> void:
	total_rescued += rescued_this_level
	current_level += 1
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
