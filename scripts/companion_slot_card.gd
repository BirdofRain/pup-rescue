extends Button
class_name CompanionSlotCard

signal card_pressed(companion_id: String)

const PupColorsScript := preload("res://scripts/pup_colors.gd")
const PupPatternLabelsScript := preload("res://scripts/pup_pattern_labels.gd")

var companion_id: String = ""
var home_island_id: String = ""
var is_unlocked: bool = false
var is_selected: bool = false

var _frame: PanelContainer
var _preview: Control
var _name_label: Label
var _status_label: Label
var _active_badge: Label
var _preview_companion: CompanionDefinition
var _preview_theme: Color = Color.GRAY
var _preview_unlocked: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(148, 176)
	toggle_mode = false
	pressed.connect(_on_pressed)
	_build_children()
	_preview.draw.connect(_on_preview_draw)


func configure(
	companion: CompanionDefinition,
	unlocked: bool,
	selected: bool,
	island_theme: Color,
	display_name: String,
	status_text: String
) -> void:
	companion_id = companion.companion_id
	home_island_id = companion.home_island_id
	is_unlocked = unlocked
	is_selected = selected
	disabled = not unlocked
	tooltip_text = display_name if unlocked else status_text
	_name_label.text = display_name if unlocked else "???"
	_status_label.text = status_text
	_active_badge.visible = unlocked and selected
	_preview_companion = companion
	_preview_theme = island_theme
	_preview_unlocked = unlocked
	_apply_frame_style(island_theme, unlocked)
	_preview.queue_redraw()


func _build_children() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_frame = PanelContainer.new()
	_frame.custom_minimum_size = Vector2(132, 118)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_frame)

	var frame_inner := MarginContainer.new()
	frame_inner.add_theme_constant_override("margin_left", 8)
	frame_inner.add_theme_constant_override("margin_right", 8)
	frame_inner.add_theme_constant_override("margin_top", 8)
	frame_inner.add_theme_constant_override("margin_bottom", 8)
	_frame.add_child(frame_inner)

	_preview = Control.new()
	_preview.custom_minimum_size = Vector2(116, 96)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_inner.add_child(_preview)

	_active_badge = Label.new()
	_active_badge.text = "★ Active"
	_active_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_active_badge.add_theme_font_size_override("font_size", 11)
	_active_badge.add_theme_color_override("font_color", Color(0.92, 0.72, 0.18))
	_active_badge.visible = false
	_active_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_active_badge)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 15)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_name_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_status_label)


func _apply_frame_style(island_theme: Color, unlocked: bool) -> void:
	var frame_style := StyleBoxFlat.new()
	frame_style.set_corner_radius_all(18)
	frame_style.set_border_width_all(3)
	if is_selected and unlocked:
		frame_style.border_color = Color(0.92, 0.72, 0.28)
		frame_style.bg_color = Color(1.0, 0.98, 0.92)
	elif unlocked:
		frame_style.border_color = island_theme.darkened(0.15)
		frame_style.bg_color = Color(0.98, 0.99, 1.0)
	else:
		frame_style.border_color = Color(0.72, 0.76, 0.82)
		frame_style.bg_color = Color(0.90, 0.92, 0.96)
	_frame.add_theme_stylebox_override("panel", frame_style)

	var btn_style := frame_style.duplicate()
	btn_style.bg_color = Color(0, 0, 0, 0)
	add_theme_stylebox_override("normal", btn_style)
	var hover := btn_style.duplicate()
	hover.bg_color = Color(1, 1, 1, 0.08)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", btn_style)
	add_theme_stylebox_override("disabled", btn_style)

	_name_label.add_theme_color_override(
		"font_color",
		Color(0.16, 0.22, 0.32) if unlocked else Color(0.48, 0.52, 0.58)
	)
	_status_label.add_theme_color_override(
		"font_color",
		Color(0.34, 0.40, 0.50) if unlocked else island_theme.darkened(0.35)
	)


func _on_preview_draw() -> void:
	if _preview_companion == null:
		return
	var rect := Rect2(Vector2.ZERO, _preview.size)
	if _preview_unlocked:
		var coat: Color = PupColorsScript.get_color(_preview_companion.coat_index)
		_draw_unlocked_preview(rect, coat, _preview_companion.pattern_id)
	else:
		_draw_locked_silhouette(rect, _preview_theme)


func _draw_unlocked_preview(rect: Rect2, coat_color: Color, pattern_id: String) -> void:
	var center := rect.get_center()
	var body_w: float = rect.size.x * 0.62
	var body_h: float = rect.size.y * 0.48
	var body_rect := Rect2(center.x - body_w * 0.5, center.y - body_h * 0.15, body_w, body_h)
	_preview.draw_rect(body_rect, coat_color.darkened(0.08), true, 14.0)
	_preview.draw_rect(body_rect, coat_color.lightened(0.08), false, 14.0, 2.0)
	var head_size: float = body_w * 0.42
	var head_center := Vector2(center.x, body_rect.position.y - head_size * 0.22)
	_preview.draw_circle(head_center, head_size * 0.5, coat_color)
	_preview.draw_arc(head_center, head_size * 0.5, 0.0, TAU, 32, coat_color.darkened(0.12), 2.0)
	var pattern_rect := Rect2(body_rect.position.x + 8, body_rect.end.y + 4, body_rect.size.x - 16, 18)
	_preview.draw_rect(pattern_rect, Color(0.94, 0.96, 0.99), true, 6.0)
	_preview.draw_rect(pattern_rect, Color(0.62, 0.70, 0.82), false, 6.0, 1.5)
	var pattern_text: String = PupPatternLabelsScript.short_label(pattern_id)
	_preview.draw_string(
		ThemeDB.fallback_font,
		pattern_rect.position + Vector2(6, 14),
		pattern_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		Color(0.28, 0.34, 0.44)
	)


func _draw_locked_silhouette(rect: Rect2, island_theme: Color) -> void:
	var center := rect.get_center()
	var silhouette := island_theme.darkened(0.55)
	silhouette.a = 0.55
	var body_w: float = rect.size.x * 0.58
	var body_h: float = rect.size.y * 0.42
	var body_rect := Rect2(center.x - body_w * 0.5, center.y - body_h * 0.05, body_w, body_h)
	_preview.draw_rect(body_rect, silhouette, true, 14.0)
	var head_size: float = body_w * 0.38
	_preview.draw_circle(
		Vector2(center.x, body_rect.position.y - head_size * 0.28),
		head_size * 0.5,
		silhouette
	)
	_preview.draw_string(
		ThemeDB.fallback_font,
		rect.get_center() + Vector2(-10, head_size * 0.15),
		"?",
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		28,
		Color(1, 1, 1, 0.75)
	)


func _on_pressed() -> void:
	if companion_id != "" and is_unlocked:
		card_pressed.emit(companion_id)
