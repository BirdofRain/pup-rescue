extends Resource
class_name UnlockRequirement
## Describes what must be satisfied before an island is playable.

@export var required_island_id: String = ""
@export var required_completed_level_id: String = ""
@export var required_escort_badge_count: int = 0
