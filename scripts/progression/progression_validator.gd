class_name ProgressionValidator
extends RefCounted


static func validate_loaded_content() -> PackedStringArray:
	ProgressionRegistry.ensure_loaded()
	var errors: PackedStringArray = []
	for island: IslandDefinition in ProgressionRegistry.all_islands():
		errors.append_array(validate_island(island))
	for level: LevelDefinition in ProgressionRegistry.all_levels():
		errors.append_array(validate_level(level))
	for companion: CompanionDefinition in ProgressionRegistry.all_companions():
		errors.append_array(validate_companion(companion))
	for accessory: AccessoryDefinition in ProgressionRegistry.all_accessories():
		errors.append_array(validate_accessory(accessory))
	return errors


static func validate_island(island: IslandDefinition) -> PackedStringArray:
	var errors: PackedStringArray = []
	if island == null:
		errors.append("Encountered null island definition.")
		return errors
	if not island.is_valid():
		errors.append("Island '%s' is missing required fields." % island.island_id)
	if island.special_companion_id != "" and not ProgressionRegistry.has_companion(island.special_companion_id):
		errors.append(
			"Island '%s' references missing companion '%s'."
			% [island.island_id, island.special_companion_id]
		)
	if island.unlock_requirement != null:
		var req: UnlockRequirement = island.unlock_requirement
		if req.required_island_id != "" and not ProgressionRegistry.has_island(req.required_island_id):
			errors.append(
				"Island '%s' unlock requirement references missing island '%s'."
				% [island.island_id, req.required_island_id]
			)
		if req.required_completed_level_id != "" and not ProgressionRegistry.has_level(req.required_completed_level_id):
			errors.append(
				"Island '%s' unlock requirement references missing level '%s'."
				% [island.island_id, req.required_completed_level_id]
			)
	var seen_orders: Dictionary = {}
	for level_id: String in island.level_ids:
		if not ProgressionRegistry.has_level(level_id):
			errors.append("Island '%s' references missing level '%s'." % [island.island_id, level_id])
			continue
		var level: LevelDefinition = ProgressionRegistry.get_level(level_id)
		if level.island_id != island.island_id:
			errors.append(
				"Island '%s' lists level '%s' owned by island '%s'."
				% [island.island_id, level_id, level.island_id]
			)
		if seen_orders.has(level.order_index):
			errors.append(
				"Island '%s' has duplicate order_index %d."
				% [island.island_id, level.order_index]
			)
		seen_orders[level.order_index] = true
	return errors


static func validate_level(level: LevelDefinition) -> PackedStringArray:
	var errors: PackedStringArray = []
	if level == null:
		errors.append("Encountered null level definition.")
		return errors
	if not level.is_valid():
		errors.append("Level '%s' is missing required fields." % level.level_id)
	if not ProgressionRegistry.has_island(level.island_id):
		errors.append("Level '%s' references missing island '%s'." % [level.level_id, level.island_id])
	if level.scene_path != "" and not ResourceLoader.exists(level.scene_path):
		errors.append("Level '%s' scene '%s' does not exist." % [level.level_id, level.scene_path])
	return errors


static func validate_companion(companion: CompanionDefinition) -> PackedStringArray:
	var errors: PackedStringArray = []
	if companion == null:
		errors.append("Encountered null companion definition.")
		return errors
	if not companion.is_valid():
		errors.append("Companion '%s' is missing required fields." % companion.companion_id)
	if not ProgressionRegistry.has_island(companion.home_island_id):
		errors.append(
			"Companion '%s' references missing home island '%s'."
			% [companion.companion_id, companion.home_island_id]
		)
	if companion.visual_scene_path != "" and not ResourceLoader.exists(companion.visual_scene_path):
		errors.append(
			"Companion '%s' visual scene '%s' does not exist."
			% [companion.companion_id, companion.visual_scene_path]
		)
	for accessory_id: String in companion.starter_accessory_ids:
		if accessory_id != "" and not ProgressionRegistry.has_accessory(accessory_id):
			errors.append(
				"Companion '%s' references missing starter accessory '%s'."
				% [companion.companion_id, accessory_id]
			)
	return errors


static func validate_accessory(accessory: AccessoryDefinition) -> PackedStringArray:
	var errors: PackedStringArray = []
	if accessory == null:
		errors.append("Encountered null accessory definition.")
		return errors
	if not accessory.is_valid():
		errors.append("Accessory '%s' is missing required fields." % accessory.accessory_id)
	if accessory.source_companion_id != "" and not ProgressionRegistry.has_companion(accessory.source_companion_id):
		errors.append(
			"Accessory '%s' references missing companion '%s'."
			% [accessory.accessory_id, accessory.source_companion_id]
		)
	if accessory.source_island_id != "" and not ProgressionRegistry.has_island(accessory.source_island_id):
		errors.append(
			"Accessory '%s' references missing island '%s'."
			% [accessory.accessory_id, accessory.source_island_id]
		)
	return errors
