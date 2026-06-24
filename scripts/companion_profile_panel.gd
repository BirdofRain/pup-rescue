extends PanelContainer
class_name CompanionProfilePanel

signal closed
signal wardrobe_requested(companion_id: String)
signal selection_changed(companion_id: String)

const PupColorsScript := preload("res://scripts/pup_colors.gd")
const PupPatternLabelsScript := preload("res://scripts/pup_pattern_labels.gd")
const ProgressionRegistryScript := preload("res://scripts/progression/progression_registry.gd")
const ProgressTrackerScript := preload("res://scripts/progress_tracker.gd")
const AccessoryCatalogScript := preload("res://scripts/accessory_catalog.gd")
const CompanionAccessoryConfigScript := preload("res://scripts/companion_accessory_config.gd")
const UiItemIconScript := preload("res://scripts/ui_item_icon.gd")

const TEXT := Color(0.16, 0.22, 0.32)
const MUTED := Color(0.34, 0.40, 0.50)

var _companion_id: String = ""
var _save: GameSave
var _title_label: Label
var _preview: Control
var _preview_companion: CompanionDefinition
var _home_label: Label
var _unlock_label: Label
var _pattern_label: Label
var _name_edit: LineEdit
var _name_error_label: Label
var _accessory_row: HBoxContainer
var _select_btn: Button
var _active_label: Label


func _ready() -> void:
	_build_ui()
	_apply_style()
	visible = false


func setup(save: GameSave) -> void:
	_save = save


func show_profile(companion_id: String) -> void:
	_companion_id = ProgressionRegistryScript.normalize_companion_id(companion_id)
	var companion: CompanionDefinition = ProgressionRegistryScript.get_companion(_companion_id)
	if companion == null or not _save.owns_companion(_companion_id):
		return
	_preview_companion = companion
	_title_label.text = _save.get_companion_display_name(_companion_id)
	_name_edit.text = _companion_custom_name_or_default()
	_name_error_label.text = ""
	_home_label.text = "Home island: %s" % _home_island_name(companion.home_island_id)
	_unlock_label.text = "Status: %s" % _unlock_status(companion.home_island_id)
	_pattern_label.text = "Coat pattern: %s (fixed)" % PupPatternLabelsScript.display_name(companion.pattern_id)
	_refresh_accessory_preview()
	_refresh_selection_ui()
	_preview.queue_redraw()
	visible = true


func hide_panel() -> void:
	visible = false
	closed.emit()


func _companion_custom_name_or_default() -> String:
	if _save.companion_custom_names.has(_companion_id):
		return str(_save.companion_custom_names[_companion_id])
	var companion: CompanionDefinition = ProgressionRegistryScript.get_companion(_companion_id)
	return companion.default_name if companion != null else ""


func _home_island_name(island_id: String) -> String:
	var island: IslandDefinition = ProgressionRegistryScript.get_island(island_id)
	if island != null:
		return island.display_name
	return island_id.capitalize()


func _unlock_status(island_id: String) -> String:
	if _save.is_island_companion_unlocked(island_id):
		return "Permanent companion unlocked"
	if _save.is_special_pup_found(island_id):
		return "Special pup found — collect escort badges"
	return "Still waiting to be discovered"


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
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.12, 0.28, 0.18))
	vbox.add_child(_title_label)

	_preview = Control.new()
	_preview.custom_minimum_size = Vector2(0, 120)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.draw.connect(_on_preview_draw)
	vbox.add_child(_preview)

	_home_label = Label.new()
	_home_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home_label.add_theme_color_override("font_color", MUTED)
	vbox.add_child(_home_label)

	_unlock_label = Label.new()
	_unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_unlock_label.add_theme_color_override("font_color", MUTED)
	vbox.add_child(_unlock_label)

	_pattern_label = Label.new()
	_pattern_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pattern_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pattern_label.add_theme_color_override("font_color", TEXT)
	vbox.add_child(_pattern_label)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	vbox.add_child(name_row)

	var name_caption := Label.new()
	name_caption.text = "Nickname"
	name_caption.custom_minimum_size = Vector2(72, 0)
	name_caption.add_theme_color_override("font_color", TEXT)
	name_row.add_child(name_caption)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Companion nickname"
	_name_edit.max_length = ProgressTrackerScript.MAX_NAME_LEN + 4
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(_on_name_submitted)
	name_row.add_child(_name_edit)

	var name_buttons := HBoxContainer.new()
	name_buttons.add_theme_constant_override("separation", 6)
	vbox.add_child(name_buttons)

	var save_name_btn := Button.new()
	save_name_btn.text = "Save Name"
	save_name_btn.focus_mode = Control.FOCUS_NONE
	_style_button(save_name_btn, Color(0.18, 0.58, 0.38))
	save_name_btn.pressed.connect(_on_save_name_pressed)
	name_buttons.add_child(save_name_btn)

	var restore_name_btn := Button.new()
	restore_name_btn.text = "Restore Default"
	restore_name_btn.focus_mode = Control.FOCUS_NONE
	_style_button(restore_name_btn, Color(0.22, 0.48, 0.82))
	restore_name_btn.pressed.connect(_on_restore_name_pressed)
	name_buttons.add_child(restore_name_btn)

	_name_error_label = Label.new()
	_name_error_label.add_theme_color_override("font_color", Color(0.78, 0.22, 0.18))
	_name_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_name_error_label)

	var accessory_caption := Label.new()
	accessory_caption.text = "Equipped gear preview"
	accessory_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	accessory_caption.add_theme_color_override("font_color", TEXT)
	vbox.add_child(accessory_caption)

	_accessory_row = HBoxContainer.new()
	_accessory_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_accessory_row.add_theme_constant_override("separation", 10)
	vbox.add_child(_accessory_row)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 10)
	vbox.add_child(action_row)

	_select_btn = Button.new()
	_select_btn.text = "Set Active Companion"
	_select_btn.custom_minimum_size = Vector2(170, 42)
	_select_btn.focus_mode = Control.FOCUS_NONE
	_style_button(_select_btn, Color(0.92, 0.72, 0.28))
	_select_btn.pressed.connect(_on_select_pressed)
	action_row.add_child(_select_btn)

	var wardrobe_btn := Button.new()
	wardrobe_btn.text = "Open Wardrobe"
	wardrobe_btn.custom_minimum_size = Vector2(150, 42)
	wardrobe_btn.focus_mode = Control.FOCUS_NONE
	_style_button(wardrobe_btn, Color(0.22, 0.48, 0.82))
	wardrobe_btn.pressed.connect(_on_wardrobe_pressed)
	action_row.add_child(wardrobe_btn)

	_active_label = Label.new()
	_active_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_active_label.add_theme_color_override("font_color", Color(0.92, 0.72, 0.18))
	vbox.add_child(_active_label)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.focus_mode = Control.FOCUS_NONE
	_style_button(close_btn, Color(0.55, 0.62, 0.72))
	close_btn.pressed.connect(hide_panel)
	vbox.add_child(close_btn)


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.99, 1.0, 0.98)
	style.border_color = Color(0.18, 0.58, 0.38)
	style.set_border_width_all(3)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0.12, 0.18, 0.28, 0.2)
	style.shadow_size = 10
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(420, 0)


func _on_preview_draw() -> void:
	if _preview_companion == null:
		return
	var rect := Rect2(Vector2.ZERO, _preview.size)
	var coat: Color = PupColorsScript.get_color(_preview_companion.coat_index)
	var center := rect.get_center()
	var body_w: float = rect.size.x * 0.34
	var body_h: float = rect.size.y * 0.34
	var body_rect := Rect2(center.x - body_w * 0.5, center.y - body_h * 0.05, body_w, body_h)
	_preview.draw_rect(body_rect, coat.darkened(0.08), true, 18.0)
	_preview.draw_rect(body_rect, coat.lightened(0.1), false, 18.0, 2.5)
	var head_size: float = body_w * 0.44
	_preview.draw_circle(Vector2(center.x, body_rect.position.y - head_size * 0.18), head_size * 0.5, coat)


func _refresh_accessory_preview() -> void:
	for child in _accessory_row.get_children():
		child.queue_free()
	for socket: String in CompanionAccessoryConfigScript.ALL_SOCKETS:
		var category: String = CompanionAccessoryConfigScript.category_for_socket(socket)
		var wrap := VBoxContainer.new()
		wrap.add_theme_constant_override("separation", 2)
		var slot_lbl := Label.new()
		slot_lbl.text = CompanionAccessoryConfigScript.category_label(category)
		slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_lbl.add_theme_font_size_override("font_size", 10)
		slot_lbl.add_theme_color_override("font_color", MUTED)
		wrap.add_child(slot_lbl)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(56, 56)
		btn.focus_mode = Control.FOCUS_NONE
		btn.disabled = true
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.bg_color = Color(0.96, 0.97, 0.99)
		style.border_color = Color(0.72, 0.78, 0.88)
		style.set_border_width_all(2)
		btn.add_theme_stylebox_override("disabled", style)
		var icon := UiItemIconScript.new()
		var equipped_id: String = _save.get_companion_equipped(_companion_id, socket)
		if equipped_id == "":
			icon.setup_clear_slot(socket)
		else:
			var entry: Dictionary = AccessoryCatalogScript.get_entry(equipped_id)
			if entry.is_empty():
				icon.setup_clear_slot(socket)
			else:
				icon.setup_accessory(entry)
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 4
		icon.offset_top = 4
		icon.offset_right = -4
		icon.offset_bottom = -4
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)
		wrap.add_child(btn)
		_accessory_row.add_child(wrap)
	_preview.queue_redraw()


func _refresh_selection_ui() -> void:
	var selected: bool = _save.selected_companion_id == _companion_id
	_active_label.text = "★ Currently active companion" if selected else ""
	_select_btn.disabled = selected
	_select_btn.text = "Active Companion" if selected else "Set Active Companion"


func _on_save_name_pressed() -> void:
	_apply_name_edit()


func _on_name_submitted(_text: String) -> void:
	_apply_name_edit()


func _apply_name_edit() -> void:
	var sanitized: String = ProgressTrackerScript.sanitize_name(_name_edit.text)
	if sanitized == "":
		_name_error_label.text = "Enter a nickname (%d characters max)." % ProgressTrackerScript.MAX_NAME_LEN
		return
	if _save.set_companion_custom_name(_companion_id, sanitized):
		_save.save_game()
		_name_error_label.text = ""
		_title_label.text = sanitized
		SfxManager.play_shop_buy()
	else:
		_name_error_label.text = "Could not save that nickname."


func _on_restore_name_pressed() -> void:
	_save.restore_companion_default_name(_companion_id)
	var companion: CompanionDefinition = ProgressionRegistryScript.get_companion(_companion_id)
	_name_edit.text = companion.default_name if companion != null else ""
	_title_label.text = _save.get_companion_display_name(_companion_id)
	_name_error_label.text = ""
	SfxManager.play_coin()


func _on_select_pressed() -> void:
	_save.set_selected_companion(_companion_id)
	_save.save_game()
	_refresh_selection_ui()
	selection_changed.emit(_companion_id)
	SfxManager.play_shop_buy()


func _on_wardrobe_pressed() -> void:
	wardrobe_requested.emit(_companion_id)


func refresh_from_wardrobe() -> void:
	_refresh_accessory_preview()
	_refresh_selection_ui()


func _style_button(btn: Button, bg: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var disabled := style.duplicate()
	disabled.bg_color = bg.darkened(0.25)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", Color(0.92, 0.94, 0.98))
