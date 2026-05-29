extends Control

@onready var title_label: Label = $Center/Panel/VBox/Title
@onready var breed_option: OptionButton = $Center/Panel/VBox/BreedRow/BreedOption
@onready var coins_label: Label = $Center/Panel/VBox/CoinsLabel
@onready var play_btn: Button = $Center/Panel/VBox/PlayBtn
@onready var continue_btn: Button = $Center/Panel/VBox/ContinueBtn
@onready var wardrobe_btn: Button = $Center/Panel/VBox/WardrobeBtn
@onready var test_btn: Button = $Center/Panel/VBox/TestBtn

var _save: GameSave


func _ready() -> void:
	_save = get_node("/root/SaveGame") as GameSave
	breed_option.clear()
	breed_option.add_item("Husky", 0)
	breed_option.add_item("Labrador", 1)
	breed_option.add_item("Pitbull", 2)
	if _save.has_save():
		_save.load_save()
		breed_option.select(_save.breed)
	continue_btn.disabled = not _save.has_save()
	_refresh_coins()


func _refresh_coins() -> void:
	if coins_label:
		coins_label.text = "Treat Coins: %d" % _save.treat_coins


func _on_play_pressed() -> void:
	_save.prepare_new_game(breed_option.selected)
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_continue_pressed() -> void:
	_save.prepare_continue()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_test_pressed() -> void:
	_save.prepare_test_maze(breed_option.selected)
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_wardrobe_pressed() -> void:
	if _save.has_save():
		_save.load_save()
	get_tree().change_scene_to_file("res://scenes/Wardrobe.tscn")
