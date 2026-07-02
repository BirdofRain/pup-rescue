extends Button
class_name IslandRouteNode

enum State { LOCKED, AVAILABLE, COMPLETED, COMPLETED_BADGE }

const STATE_COLORS := {
	State.LOCKED: {
		"fill": Color(0.82, 0.84, 0.88),
		"border": Color(0.62, 0.66, 0.72),
		"text": Color(0.48, 0.52, 0.58),
	},
	State.AVAILABLE: {
		"fill": Color(1.0, 0.98, 0.92),
		"border": Color(0.92, 0.72, 0.28),
		"text": Color(0.18, 0.22, 0.32),
	},
	State.COMPLETED: {
		"fill": Color(0.90, 0.94, 1.0),
		"border": Color(0.42, 0.58, 0.82),
		"text": Color(0.16, 0.22, 0.32),
	},
	State.COMPLETED_BADGE: {
		"fill": Color(0.86, 0.96, 0.88),
		"border": Color(0.18, 0.58, 0.38),
		"text": Color(0.12, 0.28, 0.18),
	},
}

signal node_selected(local_level: int)

var local_level: int = 0
var node_state: State = State.LOCKED
var is_discovery_level: bool = false
var show_discovery_marker: bool = false
var show_discovery_found_marker: bool = false

var _badge_label: Label
var _discovery_label: Label
var _index_label: Label
var _completed_label: Label
var _replay_label: Label


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(56, 56)
	toggle_mode = false
	pressed.connect(_on_pressed)
	_build_children()


func _build_children() -> void:
	_index_label = Label.new()
	_index_label.name = "IndexLabel"
	_index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_index_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_index_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_index_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_index_label)

	_discovery_label = Label.new()
	_discovery_label.name = "DiscoveryLabel"
	_discovery_label.text = "?"
	_discovery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discovery_label.add_theme_font_size_override("font_size", 16)
	_discovery_label.position = Vector2(34, -4)
	_discovery_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_discovery_label)

	_badge_label = Label.new()
	_badge_label.name = "BadgeLabel"
	_badge_label.text = "🐾"
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.add_theme_font_size_override("font_size", 16)
	_badge_label.position = Vector2(-6, -8)
	_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge_label)

	_completed_label = Label.new()
	_completed_label.name = "CompletedLabel"
	_completed_label.text = "✓"
	_completed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_completed_label.add_theme_font_size_override("font_size", 14)
	_completed_label.position = Vector2(2, 36)
	_completed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_completed_label)

	_replay_label = Label.new()
	_replay_label.name = "ReplayLabel"
	_replay_label.text = "↻"
	_replay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_replay_label.add_theme_font_size_override("font_size", 13)
	_replay_label.position = Vector2(36, 36)
	_replay_label.tooltip_text = "Replay available"
	_replay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_replay_label)


func configure(
	level_index: int,
	state: State,
	discovery_level: bool,
	discovery_marker_visible: bool,
	discovery_found_marker_visible: bool,
	level_title: String
) -> void:
	local_level = level_index
	node_state = state
	is_discovery_level = discovery_level
	show_discovery_marker = discovery_marker_visible
	show_discovery_found_marker = discovery_found_marker_visible
	disabled = state == State.LOCKED
	tooltip_text = level_title if state != State.LOCKED else "Complete earlier levels first"
	_apply_visuals(level_index)


func _apply_visuals(level_index: int) -> void:
	var colors: Dictionary = STATE_COLORS[node_state]
	var style := StyleBoxFlat.new()
	style.bg_color = colors["fill"]
	style.border_color = colors["border"]
	style.set_border_width_all(3)
	style.set_corner_radius_all(int(custom_minimum_size.x * 0.5))
	add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = colors["fill"].lightened(0.06)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("disabled", style)
	add_theme_color_override("font_color", colors["text"])
	add_theme_color_override("font_disabled_color", colors["text"])

	if _index_label:
		_index_label.text = str(level_index + 1)
		_index_label.add_theme_font_size_override("font_size", 18)
		_index_label.add_theme_color_override("font_color", colors["text"])

	if _discovery_label:
		_discovery_label.visible = is_discovery_level and (show_discovery_marker or show_discovery_found_marker)
		if show_discovery_marker:
			_discovery_label.text = "?"
			_discovery_label.add_theme_color_override("font_color", Color(0.92, 0.72, 0.18))
		elif show_discovery_found_marker:
			_discovery_label.text = "🐾"
			_discovery_label.add_theme_color_override("font_color", Color(0.18, 0.58, 0.38))

	if _badge_label:
		_badge_label.visible = node_state == State.COMPLETED_BADGE
		_badge_label.add_theme_color_override("font_color", Color(0.18, 0.58, 0.38))
		_badge_label.tooltip_text = "Escort badge earned"

	var completed: bool = node_state == State.COMPLETED or node_state == State.COMPLETED_BADGE
	if _completed_label:
		_completed_label.visible = completed
		_completed_label.add_theme_color_override("font_color", Color(0.22, 0.48, 0.82))
	if _replay_label:
		_replay_label.visible = completed
		_replay_label.add_theme_color_override("font_color", Color(0.55, 0.58, 0.68))


func _on_pressed() -> void:
	if node_state == State.LOCKED:
		return
	node_selected.emit(local_level)
