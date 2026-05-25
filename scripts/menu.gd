extends Control

@onready var title_label: Label = $Center/Panel/VBox/Title
@onready var breed_option: OptionButton = $Center/Panel/VBox/BreedRow/BreedOption
@onready var play_btn: Button = $Center/Panel/VBox/PlayBtn
@onready var continue_btn: Button = $Center/Panel/VBox/ContinueBtn
@onready var test_btn: Button = $Center/Panel/VBox/TestBtn


func _ready() -> void:
	breed_option.clear()
	breed_option.add_item("Husky", 0)
	breed_option.add_item("Labrador", 1)
	breed_option.add_item("Pitbull", 2)
	if SaveGame.has_save():
		SaveGame.load_save()
		breed_option.select(SaveGame.breed)
	continue_btn.disabled = not SaveGame.has_save()


func _on_play_pressed() -> void:
	SaveGame.prepare_new_game(breed_option.selected)
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_continue_pressed() -> void:
	SaveGame.prepare_continue()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_test_pressed() -> void:
	SaveGame.prepare_test_maze(breed_option.selected)
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
