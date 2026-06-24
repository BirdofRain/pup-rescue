extends ProgressionFeedbackBase
class_name CompanionUnlockPanel

signal acknowledged(companion_id: String)
signal clubhouse_requested(companion_id: String)

const ProgressionRegistryScript := preload("res://scripts/progression/progression_registry.gd")
const AccessoryCatalogScript := preload("res://scripts/accessory_catalog.gd")
const UiItemIconScript := preload("res://scripts/ui_item_icon.gd")

var _companion_id: String = ""
var _title_label: Label
var _body_label: Label
var _accessory_row: HBoxContainer
var _accessory_caption: Label
var _clubhouse_btn: Button


func _ready() -> void:
	super._ready()
	_build_ui()
	_apply_panel_style(Color(0.18, 0.58, 0.38))


func show_unlock(companion_id: String, save: GameSave) -> void:
	_companion_id = ProgressionRegistryScript.normalize_companion_id(companion_id)
	var companion: CompanionDefinition = ProgressionRegistryScript.get_companion(_companion_id)
	var display_name: String = save.get_companion_display_name(_companion_id)
	_title_label.text = "Companion Unlocked!"
	_body_label.text = "%s is now part of your rescue team!\nVisit the Puppy Clubhouse to customize their wardrobe." % display_name
	_refresh_accessory_icons(companion)
	show_feedback()


func _refresh_accessory_icons(companion: CompanionDefinition) -> void:
	for child in _accessory_row.get_children():
		child.queue_free()
	if companion == null or companion.starter_accessory_ids.is_empty():
		_accessory_caption.text = ""
		return
	_accessory_caption.text = "Starter gear added to your wardrobe:"
	for accessory_id: String in companion.starter_accessory_ids:
		var entry: Dictionary = AccessoryCatalogScript.get_entry(accessory_id)
		if entry.is_empty():
			continue
		var wrap := VBoxContainer.new()
		wrap.add_theme_constant_override("separation", 2)
		var icon := UiItemIconScript.new()
		icon.custom_minimum_size = Vector2(52, 52)
		icon.setup_accessory(entry)
		wrap.add_child(icon)
		var lbl := Label.new()
		lbl.text = AccessoryCatalogScript.display_name_for(accessory_id)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", MUTED)
		wrap.add_child(lbl)
		_accessory_row.add_child(wrap)


func hide_panel() -> void:
	hide_feedback()


func _build_ui() -> void:
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 20)
	outer.add_theme_constant_override("margin_right", 20)
	outer.add_theme_constant_override("margin_top", 18)
	outer.add_theme_constant_override("margin_bottom", 18)
	add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	outer.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.12, 0.28, 0.18))
	vbox.add_child(_title_label)

	_body_label = Label.new()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_color_override("font_color", TEXT)
	vbox.add_child(_body_label)

	_accessory_caption = Label.new()
	_accessory_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_accessory_caption.add_theme_font_size_override("font_size", 12)
	_accessory_caption.add_theme_color_override("font_color", MUTED)
	vbox.add_child(_accessory_caption)

	_accessory_row = HBoxContainer.new()
	_accessory_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_accessory_row.add_theme_constant_override("separation", 8)
	vbox.add_child(_accessory_row)

	_clubhouse_btn = Button.new()
	_clubhouse_btn.text = "Visit Puppy Clubhouse"
	_clubhouse_btn.custom_minimum_size = Vector2(220, 42)
	_clubhouse_btn.focus_mode = Control.FOCUS_NONE
	var clubhouse_style := StyleBoxFlat.new()
	clubhouse_style.bg_color = Color(0.92, 0.72, 0.28)
	clubhouse_style.set_corner_radius_all(10)
	_clubhouse_btn.add_theme_stylebox_override("normal", clubhouse_style)
	_clubhouse_btn.add_theme_color_override("font_color", Color(0.16, 0.22, 0.32))
	_clubhouse_btn.pressed.connect(_on_clubhouse_pressed)
	vbox.add_child(_clubhouse_btn)

	var ok_btn := Button.new()
	ok_btn.text = "Wonderful!"
	ok_btn.custom_minimum_size = Vector2(160, 42)
	ok_btn.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.58, 0.38)
	style.set_corner_radius_all(10)
	ok_btn.add_theme_stylebox_override("normal", style)
	ok_btn.add_theme_color_override("font_color", Color.WHITE)
	ok_btn.pressed.connect(_on_ack_pressed)
	vbox.add_child(ok_btn)
	_add_skip_row(vbox)


func _on_ack_pressed() -> void:
	var id := _companion_id
	hide_panel()
	acknowledged.emit(id)


func _on_clubhouse_pressed() -> void:
	var id := _companion_id
	hide_panel()
	clubhouse_requested.emit(id)
	acknowledged.emit(id)
