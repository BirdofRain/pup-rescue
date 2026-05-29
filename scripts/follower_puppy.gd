extends Node3D

const BREED_MESH_PATHS: Array[String] = [
	"res://assets/VoxelHusky.obj",
	"res://assets/VoxelLabrador.obj",
	"res://assets/VoxelPitbull.obj",
]

@export var move_speed: float = 6.5
@export var catchup_distance: float = 0.85
@export var catchup_multiplier: float = 1.65
@export var gather_speed_multiplier: float = 2.4
@export var model_scale: float = 0.52
@export var floor_y: float = 0.24

const PATH_REBUILD_DIST: float = 0.45
const WAYPOINT_REACH: float = 0.2
const STUCK_TIME: float = 0.4

var _nav: MazeNav
var _target: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _path: Array[Vector3] = []
var _path_index: int = 0
var _stuck_timer: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _mesh: MeshInstance3D


func setup(nav: MazeNav, spawn_pos: Vector3, breed_index: int) -> void:
	_nav = nav
	_target = spawn_pos
	_velocity = Vector3.ZERO
	_path.clear()
	_path_index = 0
	_stuck_timer = 0.0
	global_position = spawn_pos
	global_position.y = floor_y
	_last_pos = global_position
	_build_mesh(breed_index)


func rebind_nav(nav: MazeNav, pos: Vector3) -> void:
	_nav = nav
	_target = pos
	_velocity = Vector3.ZERO
	_path.clear()
	_path_index = 0
	_stuck_timer = 0.0
	global_position = pos
	global_position.y = floor_y
	_last_pos = global_position


func set_target(world_pos: Vector3) -> void:
	world_pos.y = floor_y
	if _target.distance_to(world_pos) > PATH_REBUILD_DIST:
		_target = world_pos
		_rebuild_path()
	else:
		_target = world_pos


func _rebuild_path() -> void:
	_path.clear()
	_path_index = 0
	_stuck_timer = 0.0
	if _nav == null:
		return
	_path = _nav.find_path(global_position, _target, floor_y)
	if _path.is_empty():
		_path.append(_target)


func _current_waypoint() -> Vector3:
	while _path_index < _path.size():
		var wp: Vector3 = _path[_path_index]
		wp.y = floor_y
		if Vector2(global_position.x, global_position.z).distance_to(Vector2(wp.x, wp.z)) <= WAYPOINT_REACH:
			_path_index += 1
		else:
			return wp
	return _target


func update_follow(delta: float, speed_scale: float = 1.0) -> void:
	if _nav == null:
		return
	if _path.is_empty():
		_rebuild_path()
	var from := global_position
	var to := _current_waypoint()
	to.y = floor_y
	var dist: float = Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))
	if dist < 0.04:
		_velocity = _velocity.lerp(Vector3.ZERO, minf(1.0, 10.0 * delta))
		_check_stuck(delta)
		return
	var speed: float = move_speed * speed_scale
	if dist > catchup_distance:
		speed *= catchup_multiplier
	var dir := Vector3(to.x - from.x, 0.0, to.z - from.z).normalized()
	var desired_vel := dir * speed
	_velocity = _velocity.lerp(desired_vel, minf(1.0, 9.0 * delta))
	var step: float = minf(dist, _velocity.length() * delta)
	var next := from + dir * step
	next = _nav.resolve_motion(from, next, floor_y)
	next.y = floor_y
	global_position = next
	if dir.length() > 0.01:
		var basis := Basis.looking_at(dir, Vector3.UP)
		global_basis = global_basis.slerp(basis, 10.0 * delta)
	_check_stuck(delta)


func _check_stuck(delta: float) -> void:
	var moved: float = Vector2(global_position.x, global_position.z).distance_to(
		Vector2(_last_pos.x, _last_pos.z)
	)
	if moved < 0.015:
		_stuck_timer += delta
		if _stuck_timer >= STUCK_TIME:
			_rebuild_path()
	else:
		_stuck_timer = 0.0
	_last_pos = global_position


func _build_mesh(breed_index: int) -> void:
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh)
	_mesh.scale = Vector3.ONE * model_scale
	var idx: int = clampi(breed_index, 0, BREED_MESH_PATHS.size() - 1)
	var mesh_res: Mesh = load(BREED_MESH_PATHS[idx]) as Mesh
	if mesh_res != null:
		_mesh.mesh = mesh_res
