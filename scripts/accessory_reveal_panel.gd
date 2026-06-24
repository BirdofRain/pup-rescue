extends ProgressionFeedbackBase
class_name AccessoryRevealPanel

const AccessoryCatalogScript := preload("res://scripts/accessory_catalog.gd")
const UiItemIconScript := preload("res://scripts/ui_item_icon.gd")

var _title_label: Label
var _name_label: Label
var _icon_host: CenterContainer


func _ready() -> void:
	super._ready()
	_build_ui()
	_apply_panel_style(Color(0.22, 0.48, 0.82))


func show_accessory(accessory_id: String) -> void:
	_title_label.text = "New Accessory!"
	var display_name: String = AccessoryCatalogScript.display_name_for(accessory_id)
	_name_label.text = display_name
	for child in _icon_host.get_children():
		child.queue_free()
	var entry: Dictionary = AccessoryCatalogScript.get_entry(accessory_id)
	if not entry.is_empty():
		var icon := UiItemIconScript.new()
		icon.custom_minimum_size = Vector2(72, 72)
		icon.setup_accessory(entry)
		_icon_host.add_child(icon)
	show_feedback()


func _build_ui() -> void:
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 20)
	outer.add_theme_constant_override("margin_right", 20)
	outer.add_theme_constant_override("margin_top", 18)
	outer.add_theme_constant_override("margin_bottom", 18)
	add_child(outer)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(vbox)
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.12, 0.28, 0.42))
	vbox.add_child(_title_label)
	_icon_host = CenterContainer.new()
	_icon_host.custom_minimum_size = Vector2(80, 80)
	vbox.add_child(_icon_host)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_color_override("font_color", TEXT)
	vbox.add_child(_name_label)
	var hint := Label.new()
	hint.text = "Added to your global wardrobe inventory."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", MUTED)
	vbox.add_child(hint)
	_add_skip_row(vbox)
