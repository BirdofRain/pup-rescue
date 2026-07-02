extends Resource
class_name IslandDefinition
## One themed island grouping ordered levels and a special companion.

@export var island_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var theme_id: String = ""
@export var level_ids: PackedStringArray = PackedStringArray()
@export var special_companion_id: String = ""
@export var map_icon_path: String = ""
## Full island-map background PNG (Island Map UI only; does not affect unlocks).
@export var map_banner_path: String = ""
## Normalized 0–1 positions for route level nodes on the map art (x, y within RouteHost).
@export var route_marker_slots: PackedVector2Array = PackedVector2Array()
@export var wall_palette_index: int = 0
@export var unlock_requirement: UnlockRequirement
@export var escort_badges_required: int = 0


func is_valid() -> bool:
	return island_id != "" and display_name != "" and level_ids.size() > 0


func level_count() -> int:
	return level_ids.size()


func badges_required() -> int:
	if escort_badges_required > 0:
		return escort_badges_required
	return level_ids.size()
