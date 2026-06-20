extends Button
class_name SafeButton

@export var drag_cancel_distance: float = 28.0

var _press_pos: Vector2 = Vector2.ZERO
var _cancelled: bool = false


func _ready() -> void:
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	focus_mode = Control.FOCUS_NONE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press_pos = touch.position
			_cancelled = false
		elif not _cancelled:
			if _press_pos.distance_to(touch.position) > drag_cancel_distance:
				_cancelled = true
				button_pressed = false
				accept_event()
	elif event is InputEventScreenDrag:
		if not _cancelled and _press_pos.distance_to(event.position) > drag_cancel_distance:
			_cancelled = true
			button_pressed = false
			accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_pos = mb.position
			_cancelled = false
		elif not _cancelled and _press_pos.distance_to(mb.position) > drag_cancel_distance:
			_cancelled = true
			button_pressed = false
			accept_event()
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _cancelled:
			if _press_pos.distance_to(event.position) > drag_cancel_distance:
				_cancelled = true
				button_pressed = false
				accept_event()
