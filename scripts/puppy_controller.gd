# scripts/puppy_controller.gd
extends CharacterBody3D

enum Breed { HUSKY, LABRADOR, PITBULL }

const BREED_MESH_PATHS: Dictionary = {
	Breed.HUSKY: "res://assets/VoxelHusky.obj",
	Breed.LABRADOR: "res://assets/VoxelLabrador.obj",
	Breed.PITBULL: "res://assets/VoxelPitbull.obj",
}
@export var breed: Breed = Breed.HUSKY
@export var speed: float = 6.0
@export var accel: float = 20.0
@export var rotate_speed: float = 12.0

@export var stop_radius: float = 0.25
@export var slow_radius: float = 2.0
@export var min_speed_factor: float = 0.15

@export var collision_radius: float = 0.22
@export var collision_height: float = 0.45
@export var model_ground_offset: float = 0.0

@export var debug_enabled: bool = true
@export var debug_log_target: bool = false
@export var debug_log_stop: bool = false

@onready var model: MeshInstance3D = $Model
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var target_point: Vector3 = Vector3.ZERO
var has_target: bool = false

var _nav: MazeNav


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	max_slides = 4
	var save := get_node_or_null("/root/SaveGame") as GameSave
	if save:
		breed = clampi(save.breed, 0, 2) as Breed
	_apply_breed_mesh()
	_apply_collision_shape()
	snap_to_floor()


func set_maze_data(lines: PackedStringArray, tile_size: float) -> void:
	_nav = MazeNav.new(lines, tile_size, collision_radius)


func get_nav() -> MazeNav:
	return _nav


func set_dynamic_blockers(positions: Array) -> void:
	if _nav == null:
		return
	_nav.clear_blockers()
	for p in positions:
		if p is Vector3:
			_nav.add_blocker(p)


func set_door_blocking(blocked: bool, world_pos: Vector3 = Vector3.ZERO) -> void:
	if blocked:
		set_dynamic_blockers([world_pos])
	else:
		set_dynamic_blockers([])


func _apply_breed_mesh() -> void:
	if model == null:
		return
	var mesh_path: String = BREED_MESH_PATHS[breed]
	var mesh_res: Mesh = load(mesh_path) as Mesh
	if mesh_res != null:
		model.mesh = mesh_res


func _capsule_half_height() -> float:
	var h: float = maxf(collision_height, collision_radius * 2.1)
	return collision_radius + h * 0.5


func snap_to_floor() -> void:
	var pos := global_position
	pos.y = _capsule_half_height()
	if _nav != null:
		global_position = _nav.clamp_to_walkable(pos, _capsule_half_height())
	else:
		global_position = pos


func _apply_collision_shape() -> void:
	if collision_shape == null:
		return
	var capsule := CapsuleShape3D.new()
	capsule.radius = collision_radius
	capsule.height = maxf(collision_height, collision_radius * 2.1)
	collision_shape.shape = capsule
	collision_shape.disabled = false
	collision_shape.position = Vector3(0.0, _capsule_half_height(), 0.0)
	if model != null:
		model.position = Vector3(0.0, model_ground_offset, 0.0)


func set_target(p: Vector3) -> void:
	target_point = p
	has_target = true
	if debug_enabled and debug_log_target:
		print("Puppy set_target:", p)


func _physics_process(delta: float) -> void:
	var prev_pos: Vector3 = global_position

	if not has_target:
		velocity = velocity.move_toward(Vector3.ZERO, accel * delta)
	else:
		var to_target: Vector3 = target_point - global_position
		to_target.y = 0.0
		var dist: float = to_target.length()

		if dist < stop_radius:
			has_target = false
			velocity = velocity.move_toward(Vector3.ZERO, accel * delta)
			if debug_enabled and debug_log_stop:
				print("Puppy stop at dist:", dist, " pos:", global_position)
		else:
			var t: float = clampf(dist / slow_radius, min_speed_factor, 1.0)
			var desired: Vector3 = to_target.normalized() * (speed * t)
			velocity = velocity.move_toward(desired, accel * delta)

	var motion: Vector3 = velocity * delta
	motion.y = 0.0
	var next_pos: Vector3 = global_position + motion
	if _nav != null:
		next_pos = _nav.resolve_motion(global_position, next_pos, _capsule_half_height())
	next_pos.y = _capsule_half_height()
	global_position = next_pos

	if delta > 0.0:
		velocity = (global_position - prev_pos) / delta
	velocity.y = 0.0

	var flat_v: Vector3 = velocity
	if flat_v.length() > 0.12:
		var desired_basis: Basis = Basis.looking_at(flat_v.normalized(), Vector3.UP)
		global_basis = global_basis.slerp(desired_basis, rotate_speed * delta)


