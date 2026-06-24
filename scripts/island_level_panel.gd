extends PanelContainer
class_name IslandLevelPanel

signal play_pressed(local_level: int)
signal replay_pressed(local_level: int)
signal closed

const TEXT := Color(0.16, 0.22, 0.32)
const MUTED := Color(0.34, 0.40, 0.50)

var _local_level: int = 0
var _title_label: Label
var _completion_label: Label
var _escort_label: Label
var _play_btn: Button
var _replay_btn: Button


func _ready() -> void:
	_build_ui()
	_apply_panel_style()
	visible = false


func _build_ui() -> void:
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 16)
	outer.add_theme_constant_override("margin_right", 16)
	outer.add_theme_constant_override("margin_top", 14)
	outer.add_theme_constant_override("margin_bottom", 14)
	add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	outer.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", TEXT)
	vbox.add_child(_title_label)

	_completion_label = Label.new()
	_completion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_completion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_completion_label.add_theme_color_override("font_color", MUTED)
	vbox.add_child(_completion_label)

	_escort_label = Label.new()
	_escort_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_escort_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_escort_label.add_theme_color_override("font_color", MUTED)
	vbox.add_child(_escort_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(buttons)

	_play_btn = _make_button("Play", Color(0.18, 0.58, 0.38))
	_play_btn.pressed.connect(_on_play_pressed)
	buttons.add_child(_play_btn)

	_replay_btn = _make_button("Replay", Color(0.22, 0.48, 0.82))
	_replay_btn.pressed.connect(_on_replay_pressed)
	buttons.add_child(_replay_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.focus_mode = Control.FOCUS_NONE
	_style_secondary_button(close_btn)
	close_btn.pressed.connect(hide_panel)
	vbox.add_child(close_btn)


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.99, 1.0, 0.98)
	style.border_color = Color(0.55, 0.68, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.12, 0.18, 0.28, 0.18)
	style.shadow_size = 8
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(280, 0)


func show_level(
	local_level: int,
	level_name: String,
	completed: bool,
	has_badge: bool,
	playable: bool
) -> void:
	_local_level = local_level
	_title_label.text = level_name
	_completion_label.text = "Completion: %s%s" % [
		"Cleared" if completed else "Not cleared yet",
		"  ·  ↻ Replay available" if completed else "",
	]
	if has_badge:
		_escort_label.text = "Escort: 🐾 Badge earned on this level"
	elif completed:
		_escort_label.text = "Escort: ↻ Replay with the island pup to earn a badge"
	else:
		_escort_label.text = "Escort: Finish with the island pup present"
	_play_btn.disabled = not playable
	_replay_btn.disabled = not completed
	visible = true


func hide_panel() -> void:
	visible = false
	closed.emit()


func _on_play_pressed() -> void:
	play_pressed.emit(_local_level)


func _on_replay_pressed() -> void:
	replay_pressed.emit(_local_level)


func _make_button(text: String, bg: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(108, 40)
	btn.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	return btn


func _style_secondary_button(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.90, 0.93, 0.98)
	style.border_color = Color(0.62, 0.70, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", TEXT)
