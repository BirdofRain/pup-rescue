class_name ShopPanel
extends Control

const AccessoryCatalogScript := preload("res://scripts/accessory_catalog.gd")
const UpgradeCatalogScript := preload("res://scripts/upgrade_catalog.gd")
const UiItemIconScript := preload("res://scripts/ui_item_icon.gd")
const UiCoinBadgeScript := preload("res://scripts/ui_coin_badge.gd")

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

const CLR_TEXT := Color(0.14, 0.20, 0.30)
const CLR_MUTED := Color(0.38, 0.44, 0.52)
const CLR_COINS := Color(0.72, 0.48, 0.06)
const CLR_COINS_BRIGHT := Color(0.92, 0.62, 0.08)


func setup(save: GameSave) -> void:
	_save = save
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 0
	root.offset_top = 0
	root.offset_right = 0
	root.offset_bottom = 0
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.add_theme_color_override("font_color", CLR_TEXT)
	root.add_child(_summary_label)

	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 18)
	_coins_label.add_theme_color_override("font_color", CLR_COINS_BRIGHT)
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
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_contents = true
	root.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		var total: int = _save.treat_coins
		var line := "Treat Coins: %d" % total
		if _last_coin_summary != "":
			line += "   (%s)" % _last_coin_summary
		_coins_label.text = line
		_coins_label.add_theme_color_override("font_color", CLR_COINS_BRIGHT)


func refresh() -> void:
	_refresh_coins()
	_rebuild_content()


func _switch_tab(tab: String) -> void:
	_current_tab = tab
	tab_changed.emit(tab)
	_style_tab_buttons()
	_rebuild_content()


func _style_tab_buttons() -> void:
	_style_tab_button(_shop_tab_btn, _current_tab == "shop")
	_style_tab_button(_wardrobe_tab_btn, _current_tab == "wardrobe")


func _style_tab_button(btn: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	if active:
		style.bg_color = Color(0.55, 0.82, 0.98)
		style.border_color = Color(0.12, 0.45, 0.72)
	else:
		style.bg_color = Color(0.92, 0.94, 0.98)
		style.border_color = Color(0.65, 0.72, 0.82)
	style.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color(0.14, 0.20, 0.30))


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
		var tip: String = str(entry.get("name", id))
		var icon := UiItemIconScript.new()
		icon.setup_accessory(entry)
		var row := _shop_row(
			icon,
			str(entry.get("name", id)),
			int(entry.get("cost", 0)),
			"✓" if owned else "+",
			owned,
			tip,
			func(): purchase_requested.emit("accessory", id)
		)
		_content.add_child(row)

	_add_section_header("Upgrades")
	for entry: Dictionary in UpgradeCatalogScript.all():
		var id: String = entry.get("id", "")
		var maxed: bool = _save.upgrade_maxed(id)
		var stacks: int = _save.upgrade_stack_count(id)
		var tip: String = str(entry.get("name", id))
		if entry.get("stackable", false) and int(entry.get("max_stacks", 1)) > 1:
			tip += " (%d/%d)" % [stacks, int(entry.get("max_stacks", 1))]
		var icon := UiItemIconScript.new()
		icon.setup_upgrade(entry)
		icon.tooltip_text = tip
		var row := _shop_row(
			icon,
			str(entry.get("name", id)),
			int(entry.get("cost", 0)),
			"✓" if maxed else "+",
			maxed,
			tip,
			func(): purchase_requested.emit("upgrade", id)
		)
		_content.add_child(row)


func _build_wardrobe_tab() -> void:
	for slot: String in ["hat", "collar", "pack"]:
		_add_section_header(slot.capitalize())
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		_content.add_child(grid)
		grid.add_child(_wardrobe_tile(null, slot, _save.get_equipped(slot) == ""))
		for entry: Dictionary in AccessoryCatalogScript.get_for_slot(slot):
			var id: String = entry.get("id", "")
			if not _save.owns_accessory(id):
				continue
			grid.add_child(_wardrobe_tile(entry, slot, _save.get_equipped(slot) == id))


func _wardrobe_tile(entry: Variant, slot: String, equipped: bool) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(58, 58)
	var item_name: String = "None" if entry == null else str((entry as Dictionary).get("name", ""))
	btn.tooltip_text = "Clear slot" if entry == null else item_name
	btn.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
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
		btn.pressed.connect(func(): purchase_requested.emit("equip_clear", slot))
	else:
		icon.setup_accessory(entry as Dictionary)
		var acc_id: String = (entry as Dictionary).get("id", "")
		btn.pressed.connect(func(): purchase_requested.emit("equip", acc_id))
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 3
	icon.offset_top = 3
	icon.offset_right = -3
	icon.offset_bottom = -3
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	wrap.add_child(btn)
	var lbl := Label.new()
	lbl.text = item_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", CLR_TEXT)
	wrap.add_child(lbl)
	return wrap


func _add_section_header(text: String) -> void:
	var h := Label.new()
	h.text = "— %s —" % text
	h.add_theme_font_size_override("font_size", 14)
	h.add_theme_color_override("font_color", CLR_MUTED)
	_content.add_child(h)


func _shop_row(
	icon: Control,
	item_name: String,
	cost: int,
	btn_glyph: String,
	disabled: bool,
	tooltip: String,
	callback: Callable
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.tooltip_text = tooltip
	row.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = item_name
	name_lbl.custom_minimum_size = Vector2(88, 0)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", CLR_TEXT)
	row.add_child(name_lbl)
	var badge := UiCoinBadgeScript.new()
	badge.setup(cost)
	if disabled:
		badge.modulate = Color(0.72, 0.72, 0.72, 0.85)
	row.add_child(badge)
	var btn := Button.new()
	btn.text = btn_glyph
	btn.custom_minimum_size = Vector2(44, 52)
	btn.tooltip_text = tooltip
	btn.disabled = disabled
	btn.focus_mode = Control.FOCUS_NONE
	_style_action_btn(btn, disabled)
	btn.pressed.connect(callback)
	row.add_child(btn)
	return row


func _style_action_btn(btn: Button, disabled: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	if disabled:
		style.bg_color = Color(0.88, 0.90, 0.94)
		style.border_color = Color(0.72, 0.76, 0.82)
	else:
		style.bg_color = Color(0.22, 0.52, 0.88)
		style.border_color = Color(0.12, 0.38, 0.68)
	style.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.45, 0.48, 0.55) if disabled else Color.WHITE)
