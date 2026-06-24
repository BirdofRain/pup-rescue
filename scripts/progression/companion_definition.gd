extends Resource
class_name CompanionDefinition
## Persistent special pup that can be unlocked and selected as a companion.

@export var companion_id: String = ""
@export var default_name: String = ""
@export var home_island_id: String = ""
@export_file("*.tscn") var visual_scene_path: String = "res://scenes/PuppySmall.tscn"
@export var coat_index: int = 0
@export var pattern_id: String = ""
@export var starter_accessory_ids: PackedStringArray = PackedStringArray()
@export var portrait_path: String = ""


func is_valid() -> bool:
	return companion_id != "" and default_name != "" and home_island_id != ""
