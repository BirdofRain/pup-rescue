extends Node
class_name PlayerInputController

const TouchControlConfigScript := preload("res://scripts/touch_control_config.gd")
const TouchJoystickScript := preload("res://scripts/touch_joystick.gd")

enum InputSource { NONE, KEYBOARD, TOUCH_FOLLOW, JOYSTICK }

const SOURCE_ACTIVITY_THRESHOLD: float = 0.12
const KEYBOARD_HOLD_MS: int = 180

@export var debug_enabled: bool = false

var _touch_control_mode: int = TouchControlConfigScript.MODE_FOLLOW_TOUCH
var _gameplay_blocked: bool = false
var _active_source: int = InputSource.NONE

var _camera: Camera3D
var _puppy: CharacterBody3D
var _world: Node
var _floor_collision_mask: int = 1
var _target_update_threshold: float = 0.10
var _ui_root: Control
var _joystick: TouchJoystick
var _ui_layer: CanvasLayer

var _touch_follow_tracking: bool = false
var _touch_follow_id: int = -1
var _last_touch_target: Vector3 = Vector3.ZERO
var _has_last_touch_target: bool = false

var _keyboard_vector: Vector2 = Vector2.ZERO
var _keyboard_active_until_ms: int = 0

var _debug_label: Label


func setup(
	camera: Camera3D,
	puppy: CharacterBody3D,
	world: Node,
	floor_mask: int,
	target_threshold: float,
	ui_root: Control,
	ui_layer: CanvasLayer
) -> void:
	_camera = camera
	_puppy = puppy
	_world = world
	_floor_collision_mask = floor_mask
	_target_update_threshold = target_threshold
	_ui_root = ui_root
	_ui_layer = ui_layer
	_create_joystick()
	set_process_unhandled_input(true)


func set_touch_control_mode(mode: int) -> void:
	_touch_control_mode = TouchControlConfigScript.clamp_mode(mode)
	var joy_enabled: bool = _mode_allows_joystick()
	if _joystick != null:
		_joystick.configure_from_mode(joy_enabled)
	if not _mode_allows_follow() and _touch_follow_tracking:
		_end_touch_follow()


func get_touch_control_mode() -> int:
	return _touch_control_mode


func set_gameplay_blocked(blocked: bool) -> void:
	if blocked == _gameplay_blocked:
		return
	_gameplay_blocked = blocked
	if blocked:
		_reset_all_input()


func is_gameplay_input_blocked() -> bool:
	return _gameplay_blocked


func get_active_control_mode() -> int:
	return _touch_control_mode


func get_active_input_source() -> int:
	return _active_source


func get_movement_vector() -> Vector2:
	match _active_source:
		InputSource.KEYBOARD:
			return _keyboard_vector
		InputSource.JOYSTICK:
			return _joystick.get_vector() if _joystick != null else Vector2.ZERO
		_:
			return Vector2.ZERO


func get_touch_owner_id() -> int:
	if _joystick != null and _joystick.is_dragging():
		return _joystick.get_active_touch_id()
	if _touch_follow_tracking:
		return _touch_follow_id
	return -1


func process_movement(_delta: float) -> void:
	_update_debug_label()
	if _gameplay_blocked or _puppy == null:
		_apply_stop()
		return
	_update_keyboard_vector()
	_update_active_source()
	_apply_to_puppy()


func _create_joystick() -> void:
	if _ui_layer == null:
		return
	_joystick = TouchJoystickScript.new()
	_joystick.name = "TouchJoystick"
	_ui_layer.add_child(_joystick)
	_joystick.configure_from_mode(_mode_allows_joystick())


func _mode_allows_follow() -> bool:
	return _touch_control_mode in [
		TouchControlConfigScript.MODE_FOLLOW_TOUCH,
		TouchControlConfigScript.MODE_BOTH,
	]


func _mode_allows_joystick() -> bool:
	return _touch_control_mode in [
		TouchControlConfigScript.MODE_VIRTUAL_JOYSTICK,
		TouchControlConfigScript.MODE_BOTH,
	]


func _update_keyboard_vector() -> void:
	_keyboard_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _keyboard_vector.length() > SOURCE_ACTIVITY_THRESHOLD:
		_keyboard_active_until_ms = Time.get_ticks_msec() + KEYBOARD_HOLD_MS


func _update_active_source() -> void:
	var joy_active: bool = false
	var joy_vec: Vector2 = Vector2.ZERO
	if _joystick != null and _mode_allows_joystick():
		joy_vec = _joystick.get_vector()
		joy_active = _joystick.is_dragging() and joy_vec.length() > 0.0

	var kb_active: bool = _keyboard_vector.length() > SOURCE_ACTIVITY_THRESHOLD \
		or Time.get_ticks_msec() < _keyboard_active_until_ms

	var touch_active: bool = _touch_follow_tracking and _has_last_touch_target and _mode_allows_follow()

	if joy_active:
		_active_source = InputSource.JOYSTICK
	elif kb_active:
		_active_source = InputSource.KEYBOARD
	elif touch_active:
		_active_source = InputSource.TOUCH_FOLLOW
	else:
		_active_source = InputSource.NONE


func _apply_to_puppy() -> void:
	match _active_source:
		InputSource.JOYSTICK:
			if _puppy.has_method("clear_target"):
				_puppy.clear_target()
			if _puppy.has_method("set_move_direction"):
				_puppy.set_move_direction(_joystick.get_vector())
		InputSource.KEYBOARD:
			if _puppy.has_method("clear_target"):
				_puppy.clear_target()
			if _puppy.has_method("set_move_direction"):
				var dir := _keyboard_vector
				if dir.length() > SOURCE_ACTIVITY_THRESHOLD:
					dir = dir.normalized()
				else:
					dir = Vector2.ZERO
				_puppy.set_move_direction(dir)
		InputSource.TOUCH_FOLLOW:
			if _puppy.has_method("clear_move_direction"):
				_puppy.clear_move_direction()
			if _has_last_touch_target and _puppy.has_method("set_target"):
				_puppy.set_target(_last_touch_target)
		InputSource.NONE:
			_apply_stop()


func _apply_stop() -> void:
	if _puppy != null and _puppy.has_method("clear_move_direction"):
		_puppy.clear_move_direction()


func _reset_all_input() -> void:
	_end_touch_follow()
	if _joystick != null:
		_joystick.reset()
	if _puppy != null and _puppy.has_method("clear_move_direction"):
		_puppy.clear_move_direction()
	if _puppy != null and _puppy.has_method("clear_target"):
		_puppy.clear_target()
	_active_source = InputSource.NONE
	_keyboard_vector = Vector2.ZERO


func _end_touch_follow() -> void:
	_touch_follow_tracking = false
	_touch_follow_id = -1


func _unhandled_input(event: InputEvent) -> void:
	if _gameplay_blocked:
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_screen_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		if _joystick != null and _joystick.contains_global_point(touch.position):
			return
		if _is_point_over_interactive_ui(touch.position):
			return
		if not _mode_allows_follow():
			return
		_touch_follow_tracking = true
		_touch_follow_id = touch.index
		_update_touch_target(touch.position)
	else:
		if touch.index == _touch_follow_id:
			_end_touch_follow()


func _handle_screen_drag(drag: InputEventScreenDrag) -> void:
	if not _touch_follow_tracking or drag.index != _touch_follow_id:
		return
	if _joystick != null and _joystick.owns_touch_index(drag.index):
		return
	_update_touch_target(drag.position)


func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		if _joystick != null and _joystick.contains_global_point(mb.position):
			return
		if _is_point_over_interactive_ui(mb.position):
			return
		if not _mode_allows_follow():
			return
		_touch_follow_tracking = true
		_touch_follow_id = 0
		_update_touch_target(mb.position)
	else:
		if _touch_follow_id == 0:
			_end_touch_follow()


func _handle_mouse_motion(motion: InputEventMouseMotion) -> void:
	if not _touch_follow_tracking or _touch_follow_id != 0:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	_update_touch_target(motion.position)


func _update_touch_target(screen_pos: Vector2) -> void:
	if _camera == null or _puppy == null or _world == null:
		return
	var from := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 500.0)
	query.collision_mask = _floor_collision_mask
	query.exclude = [_puppy.get_rid()]
	var result: Dictionary = _world.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var p: Vector3 = result.position
	if _has_last_touch_target and p.distance_to(_last_touch_target) < _target_update_threshold:
		return
	_last_touch_target = p
	_has_last_touch_target = true


func _is_point_over_interactive_ui(global_pos: Vector2) -> bool:
	if _ui_root == null:
		return false
	return _find_interactive_control_at(_ui_root, global_pos) != null


func _find_interactive_control_at(node: Control, global_pos: Vector2) -> Control:
	if not node.is_visible_in_tree():
		return null
	for i in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		if child is Control:
			var found := _find_interactive_control_at(child as Control, global_pos)
			if found != null:
				return found
	if node == _joystick:
		return null
	if node.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return null
	if not node.get_global_rect().has_point(global_pos):
		return null
	if node is BaseButton or node is CheckButton or node is LineEdit:
		return node
	return null


func set_debug_enabled(on: bool) -> void:
	debug_enabled = on
	if on:
		_ensure_debug_label()
	elif _debug_label != null and is_instance_valid(_debug_label):
		_debug_label.visible = false


func _ensure_debug_label() -> void:
	if _ui_layer == null:
		return
	if _debug_label == null or not is_instance_valid(_debug_label):
		_debug_label = Label.new()
		_debug_label.name = "InputDebugLabel"
		_debug_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_debug_label.offset_left = 12.0
		_debug_label.offset_bottom = -80.0
		_debug_label.add_theme_font_size_override("font_size", 11)
		_debug_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.7, 0.9))
		_ui_layer.add_child(_debug_label)
	_debug_label.visible = true


func _update_debug_label() -> void:
	if not debug_enabled:
		return
	_ensure_debug_label()
	if _debug_label == null:
		return
	var src_names: PackedStringArray = PackedStringArray(["None", "Keyboard", "TouchFollow", "Joystick"])
	var vec := get_movement_vector()
	_debug_label.text = (
		"Input mode: %s\nSource: %s\nMove: (%.2f, %.2f)\nBlocked: %s\nTouch id: %d"
		% [
			TouchControlConfigScript.mode_label(_touch_control_mode),
			src_names[_active_source],
			vec.x,
			vec.y,
			str(_gameplay_blocked),
			get_touch_owner_id(),
		]
	)
