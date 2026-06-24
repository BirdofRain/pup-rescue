extends ProgressionFeedbackBase
class_name SpecialPupFoundPanel

const PupColorsScript := preload("res://scripts/pup_colors.gd")

var _title_label: Label
var _body_label: Label
var _portrait: ColorRect


func _ready() -> void:
	super._ready()
	_build_ui()
	_apply_panel_style(Color(0.92, 0.72, 0.28))


func show_discovery(pup_name: String, coat_index: int) -> void:
	_title_label.text = "Special Pup Found!"
	_body_label.text = "%s wants to explore the island with you!\nEscort them on levels to earn badges." % pup_name
	_portrait.color = PupColorsScript.get_color(coat_index)
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
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.92, 0.55, 0.12))
	vbox.add_child(_title_label)
	_portrait = ColorRect.new()
	_portrait.custom_minimum_size = Vector2(88, 88)
	vbox.add_child(_portrait)
	_body_label = Label.new()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_color_override("font_color", TEXT)
	vbox.add_child(_body_label)
	_add_skip_row(vbox)
