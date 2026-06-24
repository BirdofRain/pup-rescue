extends SceneTree

## Run with: godot --path . --script res://tools/validate_progression.gd

const ProgressionRegistryScript := preload("res://scripts/progression/progression_registry.gd")
const ProgressionValidatorScript := preload("res://scripts/progression/progression_validator.gd")


func _init() -> void:
	ProgressionRegistryScript.ensure_loaded()
	var errors: PackedStringArray = ProgressionValidatorScript.validate_loaded_content()
	if errors.is_empty():
		print("Progression data validated successfully.")
	else:
		for err: String in errors:
			push_error(err)
		quit(1)
		return
	print(
		"Loaded %d islands, %d levels, %d companions, %d accessories."
		% [
			ProgressionRegistryScript.all_islands().size(),
			ProgressionRegistryScript.all_levels().size(),
			ProgressionRegistryScript.all_companions().size(),
			ProgressionRegistryScript.all_accessories().size(),
		]
	)
	quit()
