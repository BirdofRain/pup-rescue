extends Resource
class_name AccessoryDefinition
## Progression-facing accessory metadata. Shop runtime still uses data/accessories.json.

@export var accessory_id: String = ""
@export var display_name: String = ""
@export var category: String = ""
@export var visual_reference: String = ""
@export var compatible_socket: String = ""
@export var allows_duplicate_equip: bool = false
@export var source_companion_id: String = ""
@export var source_island_id: String = ""


func is_valid() -> bool:
	return accessory_id != "" and normalized_category() != ""


func normalized_category() -> String:
	return CompanionAccessoryConfig.normalize_category(category if category != "" else compatible_socket)


func resolved_socket() -> String:
	if compatible_socket != "":
		return compatible_socket.strip_edges().to_lower()
	return CompanionAccessoryConfig.socket_for_category(normalized_category())
