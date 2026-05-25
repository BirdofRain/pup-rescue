# scripts/camera3D.gd
extends Camera3D
class_name CameraFitter

@export var use_ortho: bool = true
@export var fit_padding: float = 1.5
@export var follow_speed: float = 6.0

@export var ortho_min_size: float = 6.0
@export var ortho_max_size: float = 60.0

# If you ever switch to perspective mode
@export var min_height: float = 8.0
@export var max_height: float = 80.0

var _target_center: Vector3 = Vector3.ZERO
var _target_half_extents: Vector3 = Vector3.ONE
var _target_test_mode: bool = false
var _has_target: bool = false

func set_fit_target(center: Vector3, half_extents: Vector3, test_mode: bool) -> void:
	_target_center = center
	_target_half_extents = half_extents
	_target_test_mode = test_mode
	_has_target = true

func _process(delta: float) -> void:
	if not _has_target:
		return

	var pad: float = fit_padding * (0.75 if _target_test_mode else 1.0)

	var need_x: float = _target_half_extents.x + pad
	var need_z: float = _target_half_extents.z + pad

	var t: float = clamp(delta * follow_speed, 0.0, 1.0)

	# Center camera over maze (x/z)
	global_position.x = lerp(global_position.x, _target_center.x, t)
	global_position.z = lerp(global_position.z, _target_center.z, t)

	if use_ortho:
		projection = Camera3D.PROJECTION_ORTHOGONAL

		var view_size: Vector2 = get_viewport().get_visible_rect().size
		var denom: float = max(1.0, float(view_size.y))
		var aspect: float = float(view_size.x) / denom

		# Conservative fit: ensure both X and Z extents fit given aspect
		var need: float = max(need_z, need_x / aspect) * 2.0
		var target_size: float = clamp(need, ortho_min_size, ortho_max_size)

		size = lerp(size, target_size, t)
	else:
		projection = Camera3D.PROJECTION_PERSPECTIVE

		var need: float = max(need_x, need_z)
		var target_height: float = clamp(need * 2.0, min_height, max_height)

		var p: Vector3 = global_position
		p.y = lerp(p.y, target_height, t)
		global_position = p
