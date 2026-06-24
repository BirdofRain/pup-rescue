extends ProgressionFeedbackBase
class_name ReplayConfirmPanel

signal confirmed(local_level: int)
signal cancelled

var _local_level: int = 0
var _title_label: Label
var _body_label: Label


func _ready() -> void:
	super._ready()
	_build_ui()
	_apply_panel_style(Color(0.22, 0.48, 0.82))


func show_replay(local_level: int, level_name: String) -> void:
	_local_level = local_level
	_title_label.text = "Replay Level?"
	_body_label.text = "Replay %s?\nProgress is already saved — replays won't reduce your completion." % level_name
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
	outer.add_child(vbox)
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", TEXT)
	vbox.add_child(_title_label)
	_body_label = Label.new()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_color_override("font_color", MUTED)
	vbox.add_child(_body_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(buttons)
	var play_btn := Button.new()
	play_btn.text = "Replay"
	play_btn.custom_minimum_size = Vector2(110, 40)
	play_btn.focus_mode = Control.FOCUS_NONE
	_style_btn(play_btn, Color(0.18, 0.58, 0.38))
	play_btn.pressed.connect(_on_confirm)
	buttons.add_child(play_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(110, 40)
	cancel_btn.focus_mode = Control.FOCUS_NONE
	_style_btn(cancel_btn, Color(0.55, 0.62, 0.72))
	cancel_btn.pressed.connect(_on_cancel)
	buttons.add_child(cancel_btn)


func _on_confirm() -> void:
	var level := _local_level
	hide_feedback()
	confirmed.emit(level)


func _on_cancel() -> void:
	hide_feedback()
	cancelled.emit()


func _style_btn(btn: Button, bg: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color.WHITE)
