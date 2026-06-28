extends PanelContainer
class_name CompanionWardrobePanel

signal closed
signal loadout_changed(companion_id: String)

const AccessoryCatalogScript := preload("res://scripts/accessory_catalog.gd")
const CompanionAccessoryConfigScript := preload("res://scripts/companion_accessory_config.gd")
const ProgressionRegistryScript := preload("res://scripts/progression/progression_registry.gd")
const UiItemIconScript := preload("res://scripts/ui_item_icon.gd")

const TEXT := Color(0.16, 0.22, 0.32)
const MUTED := Color(0.34, 0.40, 0.50)
const FILTER_ALL := "all"

var _companion_id: String = ""
var _save: GameSave
var _title_label: Label
var _status_label: Label
var _filter_row: HBoxContainer
var _filter_buttons: Dictionary = {}
var _active_filter: String = FILTER_ALL
var _unequip_btn: Button
var _items_scroll: ScrollContainer
var _items_grid: GridContainer


func _ready() -> void:
	_build_ui()
	_apply_style()
	visible = false


func setup(save: GameSave) -> void:
	_save = save


func show_for_companion(companion_id: String) -> void:
	_companion_id = ProgressionRegistryScript.normalize_companion_id(companion_id)
	if _companion_id == "" or not _save.owns_companion(_companion_id):
		return
	var display_name: String = _save.get_companion_display_name(_companion_id)
	_title_label.text = "%s's Wardrobe" % display_name
	_active_filter = FILTER_ALL
	_set_filter(FILTER_ALL)
	_refresh()
	visible = true


func hide_panel() -> void:
	visible = false
	closed.emit()


func _build_ui() -> void:
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 18)
	outer.add_theme_constant_override("margin_right", 18)
	outer.add_theme_constant_override("margin_top", 16)
	outer.add_theme_constant_override("margin_bottom", 16)
	add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	outer.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", TEXT)
	vbox.add_child(_title_label)

	var filter_caption := Label.new()
	filter_caption.text = "Category"
	filter_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	filter_caption.add_theme_font_size_override("font_size", 11)
	filter_caption.add_theme_color_override("font_color", MUTED)
	vbox.add_child(filter_caption)

	_filter_row = HBoxContainer.new()
	_filter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_filter_row.add_theme_constant_override("separation", 6)
	vbox.add_child(_filter_row)

	_add_filter_button(FILTER_ALL, "All")
	for category: String in CompanionAccessoryConfigScript.ALL_CATEGORIES:
		_add_filter_button(category, CompanionAccessoryConfigScript.category_label(category))

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", MUTED)
	vbox.add_child(_status_label)

	_unequip_btn = Button.new()
	_unequip_btn.text = "Unequip"
	_unequip_btn.custom_minimum_size = Vector2(0, 36)
	_unequip_btn.focus_mode = Control.FOCUS_NONE
	_style_button(_unequip_btn, Color(0.78, 0.42, 0.22))
	_unequip_btn.pressed.connect(_on_unequip_pressed)
	vbox.add_child(_unequip_btn)

	_items_scroll = ScrollContainer.new()
	_items_scroll.custom_minimum_size = Vector2(360, 240)
	_items_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_items_scroll)

	_items_grid = GridContainer.new()
	_items_grid.columns = 4
	_items_grid.add_theme_constant_override("h_separation", 8)
	_items_grid.add_theme_constant_override("v_separation", 8)
	_items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_scroll.add_child(_items_grid)

	var close_btn := Button.new()
	close_btn.text = "Back to Profile"
	close_btn.custom_minimum_size = Vector2(0, 42)
	close_btn.focus_mode = Control.FOCUS_NONE
	_style_button(close_btn, Color(0.22, 0.48, 0.82))
	close_btn.pressed.connect(hide_panel)
	vbox.add_child(close_btn)


func _add_filter_button(filter_id: String, label: String) -> void:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(52, 30)
	btn.pressed.connect(func(): _set_filter(filter_id))
	_filter_row.add_child(btn)
	_filter_buttons[filter_id] = btn


func _set_filter(filter_id: String) -> void:
	_active_filter = filter_id
	for key: String in _filter_buttons.keys():
		var btn: Button = _filter_buttons[key] as Button
		var active: bool = key == filter_id
		_style_filter_button(btn, active)
	_refresh()


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.99, 1.0, 0.98)
	style.border_color = Color(0.55, 0.68, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.12, 0.18, 0.28, 0.18)
	style.shadow_size = 8
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(400, 0)


func _refresh() -> void:
	_update_status()
	_update_unequip_button()
	for child in _items_grid.get_children():
		child.queue_free()

	var owned_ids: Array[String] = _owned_accessory_ids_for_filter()
	if owned_ids.is_empty():
		var empty := Label.new()
		empty.text = "No accessories in this category yet."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", MUTED)
		_items_grid.add_child(empty)
		return

	for accessory_id: String in owned_ids:
		var entry: Dictionary = AccessoryCatalogScript.get_entry(accessory_id)
		if entry.is_empty():
			continue
		var socket: String = AccessoryCatalogScript.get_socket_for_accessory(accessory_id)
		var equipped_here: bool = _save.get_companion_equipped(_companion_id, socket) == accessory_id
		_items_grid.add_child(_tile(entry, socket, equipped_here))


func _owned_accessory_ids_for_filter() -> Array[String]:
	var out: Array[String] = []
	for accessory_id: String in _save.accessory_inventory:
		if not _save.owns_accessory(accessory_id):
			continue
		if _active_filter == FILTER_ALL:
			out.append(accessory_id)
			continue
		var category: String = AccessoryCatalogScript.get_category_for_accessory(accessory_id)
		if category == _active_filter:
			out.append(accessory_id)
	out.sort()
	return out


func _update_status() -> void:
	if _active_filter == FILTER_ALL:
		var parts: PackedStringArray = PackedStringArray()
		for category: String in CompanionAccessoryConfigScript.ALL_CATEGORIES:
			var socket: String = CompanionAccessoryConfigScript.socket_for_category(category)
			var equipped_id: String = _save.get_companion_equipped(_companion_id, socket)
			if equipped_id == "":
				continue
			parts.append(
				"%s: %s" % [
					CompanionAccessoryConfigScript.category_label(category),
					AccessoryCatalogScript.display_name_for(equipped_id),
				]
			)
		_status_label.text = ", ".join(parts) if parts.size() > 0 else "Nothing equipped yet."
		return

	var category_label: String = CompanionAccessoryConfigScript.category_label(_active_filter)
	var socket: String = CompanionAccessoryConfigScript.socket_for_category(_active_filter)
	var equipped_id: String = _save.get_companion_equipped(_companion_id, socket)
	if equipped_id == "":
		_status_label.text = "%s slot is empty." % category_label
		return
	var wearer_note: String = ""
	var other_wearer: String = _save.find_companion_wearing_accessory(equipped_id)
	if other_wearer != "" and other_wearer != _companion_id:
		wearer_note = " (also tracked on %s)" % _save.get_companion_display_name(other_wearer)
	_status_label.text = "%s: %s%s" % [
		category_label,
		AccessoryCatalogScript.display_name_for(equipped_id),
		wearer_note,
	]


func _update_unequip_button() -> void:
	if _active_filter == FILTER_ALL:
		_unequip_btn.visible = false
		return
	var socket: String = CompanionAccessoryConfigScript.socket_for_category(_active_filter)
	var equipped_id: String = _save.get_companion_equipped(_companion_id, socket)
	_unequip_btn.visible = equipped_id != ""
	_unequip_btn.text = "Unequip %s" % CompanionAccessoryConfigScript.category_label(_active_filter)


func _tile(entry: Dictionary, socket: String, equipped_here: bool) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	var accessory_id: String = str(entry.get("id", ""))
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(72, 72)
	btn.focus_mode = Control.FOCUS_NONE
	var item_name: String = AccessoryCatalogScript.display_name_for(accessory_id)
	btn.tooltip_text = item_name
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	if equipped_here:
		style.bg_color = Color(0.55, 0.82, 0.98)
		style.border_color = Color(0.12, 0.45, 0.72)
		style.set_border_width_all(3)
	else:
		style.bg_color = Color(0.96, 0.97, 0.99)
		style.border_color = Color(0.72, 0.78, 0.88)
		style.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", style)
	var icon := UiItemIconScript.new()
	icon.setup_accessory(entry)
	btn.pressed.connect(func(): _equip(accessory_id))
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = -4
	icon.offset_bottom = -4
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	wrap.add_child(btn)

	var lbl := Label.new()
	lbl.text = item_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(72, 0)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", TEXT)
	wrap.add_child(lbl)

	var wearer_id: String = _save.find_companion_wearing_accessory(accessory_id)
	if wearer_id != "" and wearer_id != _companion_id and not AccessoryCatalogScript.allows_duplicate_equip(accessory_id):
		var note := Label.new()
		note.text = "On %s" % _save.get_companion_display_name(wearer_id)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", 9)
		note.add_theme_color_override("font_color", Color(0.78, 0.52, 0.18))
		wrap.add_child(note)
	elif wearer_id == _companion_id:
		var note := Label.new()
		note.text = "Equipped"
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.add_theme_font_size_override("font_size", 9)
		note.add_theme_color_override("font_color", Color(0.18, 0.58, 0.38))
		wrap.add_child(note)

	return wrap


func _equip(accessory_id: String) -> void:
	if _save.equip_companion_accessory(_companion_id, accessory_id):
		SfxManager.play_shop_buy()
		_refresh()
		loadout_changed.emit(_companion_id)


func _on_unequip_pressed() -> void:
	if _active_filter == FILTER_ALL:
		return
	_save.unequip_companion_category(_companion_id, _active_filter)
	SfxManager.play_coin()
	_refresh()
	loadout_changed.emit(_companion_id)


func _style_button(btn: Button, bg: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color.WHITE)


func _style_filter_button(btn: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	if active:
		style.bg_color = Color(0.22, 0.48, 0.82)
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		style.bg_color = Color(0.92, 0.94, 0.98)
		btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_stylebox_override("normal", style)
