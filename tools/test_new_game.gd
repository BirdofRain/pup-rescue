extends SceneTree

func _initialize() -> void:
	var save := get_root().get_node_or_null("SaveGame")
	if save == null:
		push_error("SaveGame autoload missing")
		quit(1)
		return
	save.prepare_new_game(0)
	var err := change_scene_to_file("res://scenes/Game.tscn")
	if err != OK:
		push_error("change_scene failed: %s" % error_string(err))
		quit(1)
		return
	call_deferred("_finish")


func _finish() -> void:
	await process_frame
	await process_frame
	await process_frame
	print("Game scene loaded OK")
	quit(0)
