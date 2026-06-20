class_name TouchControlConfig
extends RefCounted

enum Mode { FOLLOW_TOUCH, VIRTUAL_JOYSTICK, BOTH, OFF }

const MODE_FOLLOW_TOUCH: int = 0
const MODE_VIRTUAL_JOYSTICK: int = 1
const MODE_BOTH: int = 2
const MODE_OFF: int = 3

const MODE_LABELS := [
	"Follow Touch",
	"Virtual Joystick",
	"Both",
	"Off",
]

const MODE_HINTS := [
	"Tap the maze to move your pup.",
	"Use the on-screen joystick only.",
	"Joystick plus tap-to-move in open areas.",
	"Keyboard only — no touch movement.",
]


static func clamp_mode(mode: int) -> int:
	return clampi(mode, MODE_FOLLOW_TOUCH, MODE_OFF)


static func mode_label(mode: int) -> String:
	return MODE_LABELS[clamp_mode(mode)]


static func mode_hint(mode: int) -> String:
	return MODE_HINTS[clamp_mode(mode)]


static func default_mode() -> int:
	if DisplayServer.is_touchscreen_available():
		return MODE_FOLLOW_TOUCH
	return MODE_FOLLOW_TOUCH
