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

var _nav: MazeNav
var _target: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _mesh: MeshInstance3D


func setup(nav: MazeNav, spawn_pos: Vector3, breed_index: int) -> void:
	_nav = nav
	_target = spawn_pos
	_velocity = Vector3.ZERO
	global_position = spawn_pos
	global_position.y = floor_y
	_build_mesh(breed_index)


func rebind_nav(nav: MazeNav, pos: Vector3) -> void:
	_nav = nav
	_target = pos
	_velocity = Vector3.ZERO
	global_position = pos
	global_position.y = floor_y


func set_target(world_pos: Vector3) -> void:
	_target = world_pos
	_target.y = floor_y


func update_follow(delta: float, speed_scale: float = 1.0) -> void:
	if _nav == null:
		return
	var from := global_position
	var to := _target
	to.y = floor_y
	var dist: float = Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))
	if dist < 0.04:
		_velocity = _velocity.lerp(Vector3.ZERO, minf(1.0, 10.0 * delta))
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


func _build_mesh(breed_index: int) -> void:
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh)
	_mesh.scale = Vector3.ONE * model_scale
	var idx: int = clampi(breed_index, 0, BREED_MESH_PATHS.size() - 1)
	var mesh_res: Mesh = load(BREED_MESH_PATHS[idx]) as Mesh
	if mesh_res != null:
		_mesh.mesh = mesh_res
