extends ProgressionFeedbackBase
class_name EscortBadgeCelebrationPanel

var _title_label: Label
var _body_label: Label
var _badge_icon: Label
var _badge_tween: Tween


func _ready() -> void:
	super._ready()
	_build_ui()
	_apply_panel_style(Color(0.18, 0.58, 0.38))


func show_badge(level_display: String, badges_done: int, badges_required: int) -> void:
	_title_label.text = "Escort Badge Earned!"
	_body_label.text = "%s cleared with your island pup.\nEscort progress: %d / %d" % [
		level_display, badges_done, badges_required
	]
	show_feedback()
	_play_badge_pop()


func _play_badge_pop() -> void:
	if _badge_tween != null and _badge_tween.is_valid():
		_badge_tween.kill()
	_badge_icon.scale = Vector2(0.2, 0.2)
	_badge_icon.modulate.a = 0.0
	_badge_tween = create_tween()
	_badge_tween.set_parallel(true)
	_badge_tween.tween_property(_badge_icon, "scale", Vector2(1.15, 1.15), 0.28).set_trans(Tween.TRANS_BACK)
	_badge_tween.tween_property(_badge_icon, "modulate:a", 1.0, 0.18)
	_badge_tween.chain().tween_property(_badge_icon, "scale", Vector2.ONE, 0.12)


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
	_badge_icon = Label.new()
	_badge_icon.text = "🐾"
	_badge_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_icon.add_theme_font_size_override("font_size", 56)
	vbox.add_child(_badge_icon)
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.12, 0.28, 0.18))
	vbox.add_child(_title_label)
	_body_label = Label.new()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_color_override("font_color", TEXT)
	vbox.add_child(_body_label)
	_add_skip_row(vbox)
