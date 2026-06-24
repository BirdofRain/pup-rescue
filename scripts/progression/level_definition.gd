extends Resource
class_name LevelDefinition
## Stable metadata for one playable level. Procedural levels reuse Game.tscn and global index.

@export var level_id: String = ""
@export var display_name: String = ""
@export var island_id: String = ""
@export var order_index: int = 0
@export_file("*.tscn") var scene_path: String = "res://scenes/Game.tscn"
@export var global_procedural_index: int = 0
@export var allows_special_pup_discovery: bool = false
@export var reward_coin_bonus: int = 0
@export var reward_metadata: Dictionary = {}


func is_valid() -> bool:
	return level_id != "" and island_id != "" and scene_path != ""
