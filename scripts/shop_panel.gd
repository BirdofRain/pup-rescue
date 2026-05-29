class_name ShopPanel
extends Control

const AccessoryCatalogScript := preload("res://scripts/accessory_catalog.gd")
const UpgradeCatalogScript := preload("res://scripts/upgrade_catalog.gd")

signal purchase_requested(item_type: String, item_id: String)
signal tab_changed(tab: String)

var _save: GameSave
var _summary_label: Label
var _coins_label: Label
var _shop_tab_btn: Button
var _wardrobe_tab_btn: Button
var _content: VBoxContainer
var _current_tab: String = "shop"
var _last_coin_summary: String = ""


func setup(save: GameSave) -> void:
	_save = save
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 16
	offset_top = 16
	offset_right = -16
	offset_bottom = -16

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_summary_label)

	_coins_label = Label.new()
	root.add_child(_coins_label)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	_shop_tab_btn = Button.new()
	_shop_tab_btn.text = "Shop"
	_shop_tab_btn.pressed.connect(func(): _switch_tab("shop"))
	tabs.add_child(_shop_tab_btn)
	_wardrobe_tab_btn = Button.new()
	_wardrobe_tab_btn.text = "Wardrobe"
	_wardrobe_tab_btn.pressed.connect(func(): _switch_tab("wardrobe"))
	tabs.add_child(_wardrobe_tab_btn)
	root.add_child(tabs)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_content = VBoxContainer.new()
	_content.custom_minimum_size = Vector2(360, 0)
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)

	_switch_tab("shop")


func set_summary(text: String, coin_summary: String = "") -> void:
	_last_coin_summary = coin_summary
	if _summary_label:
		_summary_label.text = text
	_refresh_coins()


func _refresh_coins() -> void:
	if _coins_label and _save:
		var line := "Treat Coins: %d" % _save.treat_coins
		if _last_coin_summary != "":
			line += "  (%s)" % _last_coin_summary
		_coins_label.text = line


func refresh() -> void:
	_refresh_coins()
	_rebuild_content()


func _switch_tab(tab: String) -> void:
	_current_tab = tab
	tab_changed.emit(tab)
	_rebuild_content()


func _rebuild_content() -> void:
	for c in _content.get_children():
		c.queue_free()
	if _current_tab == "shop":
		_build_shop_tab()
	else:
		_build_wardrobe_tab()


func _build_shop_tab() -> void:
	_add_section_header("Accessories")
	for entry: Dictionary in AccessoryCatalogScript.all():
		var id: String = entry.get("id", "")
		var owned: bool = _save.owns_accessory(id)
		var row := _shop_row(
			"%s (%d)" % [entry.get("name", id), int(entry.get("cost", 0))],
			"Owned" if owned else "Buy",
			owned,
			func(): purchase_requested.emit("accessory", id)
		)
		_content.add_child(row)
	_add_section_header("Upgrades")
	for entry: Dictionary in UpgradeCatalogScript.all():
		var id: String = entry.get("id", "")
		var maxed: bool = _save.upgrade_maxed(id)
		var stacks: int = _save.upgrade_stack_count(id)
		var stack_note := ""
		if entry.get("stackable", false) and int(entry.get("max_stacks", 1)) > 1:
			stack_note = " [%d/%d]" % [stacks, int(entry.get("max_stacks", 1))]
		var row := _shop_row(
			"%s (%d) — %s%s" % [entry.get("name", id), int(entry.get("cost", 0)), entry.get("description", ""), stack_note],
			"Maxed" if maxed else "Buy",
			maxed,
			func(): purchase_requested.emit("upgrade", id)
		)
		_content.add_child(row)


func _build_wardrobe_tab() -> void:
	for slot: String in ["hat", "collar", "pack"]:
		_add_section_header(slot.capitalize())
		var none_row := _shop_row("(None)", "Equip" if _save.get_equipped(slot) == "" else "Equipped", _save.get_equipped(slot) == "", func(): purchase_requested.emit("equip_clear", slot))
		_content.add_child(none_row)
		for entry: Dictionary in AccessoryCatalogScript.get_for_slot(slot):
			var id: String = entry.get("id", "")
			if not _save.owns_accessory(id):
				continue
			var equipped: bool = _save.get_equipped(slot) == id
			var row := _shop_row(entry.get("name", id), "Equipped" if equipped else "Equip", equipped, func(): purchase_requested.emit("equip", id))
			_content.add_child(row)


func _add_section_header(text: String) -> void:
	var h := Label.new()
	h.text = "— %s —" % text
	h.add_theme_font_size_override("font_size", 14)
	_content.add_child(h)


func _shop_row(label_text: String, btn_text: String, disabled: bool, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(lbl)
	var btn := Button.new()
	btn.text = btn_text
	btn.disabled = disabled
	btn.pressed.connect(callback)
	row.add_child(btn)
	return row
