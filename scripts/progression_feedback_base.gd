class_name ProgressionFeedbackBase
extends PanelContainer

signal dismissed
signal skip_pressed

const TEXT := Color(0.16, 0.22, 0.32)
const MUTED := Color(0.34, 0.40, 0.50)

var _skip_btn: Button
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	pivot_offset = Vector2.ZERO


func show_feedback() -> void:
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.92, 0.92)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.22)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_feedback() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = false
	scale = Vector2.ONE
	modulate.a = 1.0


func _add_skip_row(parent: VBoxContainer) -> void:
	var skip_hint := Label.new()
	skip_hint.text = "Tap Skip to continue"
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_hint.add_theme_font_size_override("font_size", 11)
	skip_hint.add_theme_color_override("font_color", MUTED)
	parent.add_child(skip_hint)
	_skip_btn = Button.new()
	_skip_btn.text = "Skip"
	_skip_btn.custom_minimum_size = Vector2(120, 36)
	_skip_btn.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.55, 0.62, 0.72)
	style.set_corner_radius_all(10)
	_skip_btn.add_theme_stylebox_override("normal", style)
	_skip_btn.add_theme_color_override("font_color", Color.WHITE)
	_skip_btn.pressed.connect(_on_skip_pressed)
	parent.add_child(_skip_btn)


func _on_skip_pressed() -> void:
	hide_feedback()
	skip_pressed.emit()
	dismissed.emit()


func _apply_panel_style(accent: Color) -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.98, 0.99, 1.0, 0.98)
	panel_style.border_color = accent
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(18)
	panel_style.shadow_color = Color(0.12, 0.18, 0.28, 0.22)
	panel_style.shadow_size = 10
	add_theme_stylebox_override("panel", panel_style)
	custom_minimum_size = Vector2(320, 0)
