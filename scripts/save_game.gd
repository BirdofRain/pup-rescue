extends Node
class_name GameSave
## Autoload singleton at /root/SaveGame — use GameSave type via get_node, not bare SaveGame identifier.

const SAVE_PATH := "user://save.json"

var current_level: int = 0
var total_rescued: int = 0
var breed: int = 0  # puppy_controller.Breed

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
	breed = clampi(int(data.get("breed", 0)), 0, 2)
	return true


func save_game() -> void:
	var data := {
		"current_level": current_level,
		"total_rescued": total_rescued,
		"breed": breed,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()


func prepare_new_game(selected_breed: int) -> void:
	current_level = 0
	total_rescued = 0
	breed = clampi(selected_breed, 0, 2)
	boot_test_mode = false
	boot_new_game = true
	save_game()


func prepare_continue() -> void:
	load_save()
	boot_test_mode = false
	boot_new_game = false


func prepare_test_maze(selected_breed: int) -> void:
	current_level = 0
	breed = clampi(selected_breed, 0, 2)
	boot_test_mode = true
	boot_new_game = false


func record_level_complete(rescued_this_level: int) -> void:
	total_rescued += rescued_this_level
	current_level += 1
	save_game()
