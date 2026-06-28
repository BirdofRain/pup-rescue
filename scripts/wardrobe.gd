extends Control

const AccessoryCatalogScript := preload("res://scripts/accessory_catalog.gd")
const UiItemIconScript := preload("res://scripts/ui_item_icon.gd")

const MENU_TEXT := Color(0.16, 0.22, 0.32)

@onready var coins_label: Label = $Center/Panel/VBox/CoinsLabel
@onready var slot_tabs: TabContainer = $Center/Panel/VBox/SlotTabs
@onready var title_label: Label = $Center/Panel/VBox/Title

var _save: GameSave


func _ready() -> void:
	_save = get_node("/root/SaveGame") as GameSave
	if _save.has_save():
		_save.load_save()
	_apply_styles()
	_refresh()


func _apply_styles() -> void:
	var panel := get_node_or_null("Center/Panel") as PanelContainer
	if panel != null:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.97, 0.98, 1.0, 0.96)
		panel_style.border_color = Color(0.72, 0.78, 0.88)
		panel_style.set_border_width_all(2)
		panel_style.set_corner_radius_all(14)
		panel_style.content_margin_left = 18
		panel_style.content_margin_right = 18
		panel_style.content_margin_top = 16
		panel_style.content_margin_bottom = 16
		panel.add_theme_stylebox_override("panel", panel_style)
	if title_label:
		title_label.add_theme_color_override("font_color", MENU_TEXT)
	if coins_label:
		coins_label.add_theme_color_override("font_color", MENU_TEXT)
	var back_btn: Button = get_node_or_null("Center/Panel/VBox/BackBtn") as Button
	if back_btn:
		_style_primary_button(back_btn)


func _refresh() -> void:
	if coins_label:
		coins_label.text = "Treat Coins: %d" % _save.treat_coins
	var slots: Array[String] = ["hat", "collar", "pack"]
	var tab_names: Array[String] = ["Hats", "Collars", "Packs"]
	for i in range(slots.size()):
		slot_tabs.set_tab_title(i, tab_names[i])
		var box: VBoxContainer = slot_tabs.get_tab_control(i) as VBoxContainer
		if box == null:
			continue
		for c in box.get_children():
			c.queue_free()
		var grid := GridContainer.new()
		grid.columns = 4
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		box.add_child(grid)
		var slot: String = slots[i]
		grid.add_child(_wardrobe_tile(null, slot, _save.get_equipped(slot) == ""))
		for entry: Dictionary in AccessoryCatalogScript.get_for_slot(slot):
			var id: String = entry.get("id", "")
			if not _save.owns_accessory(id):
				continue
			grid.add_child(_wardrobe_tile(entry, slot, _save.get_equipped(slot) == id))


func _wardrobe_tile(entry: Variant, slot: String, equipped: bool) -> Control:
	var wrapped_label := VBoxContainer.new()
	wrapped_label.add_theme_constant_override("separation", 2)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(72, 72)
	var item_name: String = "None" if entry == null else str((entry as Dictionary).get("name", ""))
	btn.tooltip_text = "Clear slot" if entry == null else item_name
	btn.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	if equipped:
		style.bg_color = Color(0.55, 0.82, 0.98)
		style.border_color = Color(0.12, 0.45, 0.72)
		style.set_border_width_all(3)
	else:
		style.bg_color = Color(0.96, 0.97, 0.99)
		style.border_color = Color(0.72, 0.78, 0.88)
		style.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", style)

	var icon := UiItemIconScript.new()
	if entry == null:
		icon.setup_clear_slot(slot)
		btn.pressed.connect(func(): _equip(slot, ""))
	else:
		icon.setup_accessory(entry as Dictionary)
		var acc_id: String = (entry as Dictionary).get("id", "")
		btn.pressed.connect(func(): _equip(slot, acc_id))
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = -4
	icon.offset_bottom = -4
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	if equipped:
		var check := Label.new()
		check.text = "✓"
		check.add_theme_font_size_override("font_size", 18)
		check.add_theme_color_override("font_color", Color(0.08, 0.42, 0.72))
		check.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		check.offset_top = 2
		check.offset_right = -4
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(check)
	wrapped_label.add_child(btn)
	var lbl := Label.new()
	lbl.text = item_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(72, 0)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", MENU_TEXT)
	wrapped_label.add_child(lbl)
	return wrapped_label


func _style_primary_button(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.48, 0.82)
	style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color.WHITE)


func _equip(slot: String, id: String) -> void:
	_save.equip_accessory(slot, id)
	_save.save_game()
	_refresh()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")
