extends Control

const ProgressTrackerScript := preload("res://scripts/progress_tracker.gd")

@onready var bests_label: Label = $Center/Panel/VBox/BestsLabel
@onready var entries_box: VBoxContainer = $Center/Panel/VBox/Scroll/EntriesBox
@onready var empty_label: Label = $Center/Panel/VBox/EmptyLabel

var _save: GameSave


func _ready() -> void:
	_save = get_node("/root/SaveGame") as GameSave
	if _save.has_save():
		_save.load_save()
	_refresh()


func _refresh() -> void:
	if bests_label:
		bests_label.text = "Your bests — Level %d  |  %d rescued  |  Squad of %d" % [
			_save.get_best_level(),
			_save.get_best_rescued(),
			_save.get_best_squad(),
		]
	for c in entries_box.get_children():
		c.queue_free()
	var board: Array = _save.leaderboard
	if board.is_empty():
		if empty_label:
			empty_label.visible = true
		return
	if empty_label:
		empty_label.visible = false
	var rank := 1
	for entry: Variant in board:
		if not entry is Dictionary:
			continue
		var d: Dictionary = entry
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.text = "%d. %s — Lv %d, %d rescued, squad %d" % [
			rank,
			str(d.get("name", "Pup")),
			int(d.get("level", 0)),
			int(d.get("rescued", 0)),
			int(d.get("squad", 0)),
		]
		entries_box.add_child(row)
		rank += 1


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")
