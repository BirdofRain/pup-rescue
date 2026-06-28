extends Control
class_name TouchJoystick

enum JoystickSide { BOTTOM_RIGHT, BOTTOM_LEFT }

@export var joystick_size: float = 140.0
@export var thumb_size: float = 56.0
@export var deadzone: float = 0.15
@export var max_drag_distance: float = 52.0
@export var opacity: float = 0.42
@export var screen_margin: float = 28.0
@export var enabled: bool = true
@export var joystick_side: JoystickSide = JoystickSide.BOTTOM_RIGHT

var _vector: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _touch_id: int = -1
var _base_center: Vector2 = Vector2.ZERO
var _thumb_center: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	resized.connect(_layout_centers)
	_apply_side_anchors()
	_layout_centers()
	queue_redraw()


func _apply_side_anchors() -> void:
	custom_minimum_size = Vector2(joystick_size, joystick_size)
	if joystick_side == JoystickSide.BOTTOM_LEFT:
		set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		offset_left = screen_margin
		offset_bottom = -screen_margin
		offset_right = screen_margin + joystick_size
		offset_top = -screen_margin - joystick_size
	else:
		set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		offset_right = -screen_margin
		offset_bottom = -screen_margin
		offset_left = -screen_margin - joystick_size
		offset_top = -screen_margin - joystick_size


func _layout_centers() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	_base_center = size * 0.5
	if not _dragging:
		_thumb_center = _base_center


func configure_from_mode(mode_enabled: bool) -> void:
	enabled = mode_enabled
	visible = mode_enabled
	if not enabled:
		reset()


func contains_global_point(global_pos: Vector2) -> bool:
	return get_global_rect().has_point(global_pos)


func owns_touch_index(index: int) -> bool:
	return _dragging and _touch_id == index


func get_active_touch_id() -> int:
	return _touch_id if _dragging else -1


func get_vector() -> Vector2:
	if not enabled or not _dragging:
		return Vector2.ZERO
	var magnitude: float = _vector.length()
	if magnitude <= deadzone:
		return Vector2.ZERO
	var scaled: float = (magnitude - deadzone) / maxf(1.0 - deadzone, 0.001)
	return _vector.normalized() * scaled


func is_dragging() -> bool:
	return _dragging and enabled


func reset() -> void:
	_dragging = false
	_touch_id = -1
	_vector = Vector2.ZERO
	_thumb_center = _base_center
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _dragging:
				return
			_touch_id = touch.index
			_dragging = true
			_update_from_local(_event_local_position(event))
			accept_event()
		elif _dragging and touch.index == _touch_id:
			reset()
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _dragging and drag.index == _touch_id:
			_update_from_local(_event_local_position(event))
			accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if _dragging:
				return
			_touch_id = 0
			_dragging = true
			_update_from_local(_event_local_position(event))
			accept_event()
		elif _dragging and _touch_id == 0:
			reset()
			accept_event()
	elif event is InputEventMouseMotion:
		if _dragging and _touch_id == 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_update_from_local(_event_local_position(event))
			accept_event()


func _event_local_position(event: InputEvent) -> Vector2:
	# _gui_input delivers positions in this Control's local space — do not re-transform.
	var local_event := make_input_local(event)
	if local_event is InputEventMouse:
		return (local_event as InputEventMouse).position
	if local_event is InputEventScreenTouch:
		return (local_event as InputEventScreenTouch).position
	if local_event is InputEventScreenDrag:
		return (local_event as InputEventScreenDrag).position
	return Vector2.ZERO


func _update_from_local(local_pos: Vector2) -> void:
	if _base_center == Vector2.ZERO and size.x >= 1.0 and size.y >= 1.0:
		_layout_centers()
	var delta: Vector2 = local_pos - _base_center
	var max_dist: float = maxf(max_drag_distance, 8.0)
	if delta.length() > max_dist:
		delta = delta.normalized() * max_dist
	_thumb_center = _base_center + delta
	_vector = delta / max_dist if max_dist > 0.0 else Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	var base_col := Color(1.0, 1.0, 1.0, opacity * 0.35)
	var ring_col := Color(1.0, 1.0, 1.0, opacity * 0.55)
	var thumb_col := Color(1.0, 1.0, 1.0, opacity * 0.75)
	draw_circle(_base_center, joystick_size * 0.5, base_col)
	draw_arc(_base_center, joystick_size * 0.5, 0.0, TAU, 48, ring_col, 2.0, true)
	draw_circle(_thumb_center, thumb_size * 0.5, thumb_col)
