extends Control

const AccessoryCatalogScript := preload("res://scripts/accessory_catalog.gd")

@onready var coins_label: Label = $Center/Panel/VBox/CoinsLabel
@onready var slot_tabs: TabContainer = $Center/Panel/VBox/SlotTabs

var _save: GameSave


func _ready() -> void:
	_save = get_node("/root/SaveGame") as GameSave
	if _save.has_save():
		_save.load_save()
	_refresh()


func _refresh() -> void:
	if coins_label:
		coins_label.text = "Treat Coins: %d" % _save.treat_coins
	for i in range(slot_tabs.get_tab_count()):
		var slot: String = ["hat", "collar", "pack"][i]
		var box: VBoxContainer = slot_tabs.get_tab_control(i) as VBoxContainer
		if box == null:
			continue
		for c in box.get_children():
			c.queue_free()
		var none_btn := Button.new()
		none_btn.text = "Clear slot" if _save.get_equipped(slot) != "" else "(none equipped)"
		none_btn.pressed.connect(func(): _equip(slot, ""))
		box.add_child(none_btn)
		for entry: Dictionary in AccessoryCatalogScript.get_for_slot(slot):
			var id: String = entry.get("id", "")
			if not _save.owns_accessory(id):
				continue
			var btn := Button.new()
			var mark := " *" if _save.get_equipped(slot) == id else ""
			btn.text = "%s%s" % [entry.get("name", id), mark]
			btn.pressed.connect(func(): _equip(slot, id))
			box.add_child(btn)


func _equip(slot: String, id: String) -> void:
	_save.equip_accessory(slot, id)
	_save.save_game()
	_refresh()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")
