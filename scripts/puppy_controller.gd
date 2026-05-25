# scripts/puppy_controller.gd
extends CharacterBody3D

enum Breed { HUSKY, LABRADOR, PITBULL }

const BREED_MESH_PATHS: Dictionary = {
	Breed.HUSKY: "res://assets/VoxelHusky.obj",
	Breed.LABRADOR: "res://assets/VoxelLabrador.obj",
	Breed.PITBULL: "res://assets/VoxelPitbull.obj",
}
const CP_WALL: int = 35  # '#'

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

var _maze_lines: PackedStringArray = PackedStringArray()
var _tile_size: float = 1.0
var _maze_cols: int = 0
var _maze_rows: int = 0
var _door_blocks: bool = false
var _door_block_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	max_slides = 4
	if get_node_or_null("/root/SaveGame"):
		breed = clampi(SaveGame.breed, 0, 2) as Breed
	_apply_breed_mesh()
	_apply_collision_shape()
	snap_to_floor()


func set_maze_data(lines: PackedStringArray, tile_size: float) -> void:
	_maze_lines = lines
	_tile_size = tile_size
	if lines.is_empty():
		_maze_cols = 0
		_maze_rows = 0
	else:
		_maze_cols = lines[0].length()
		_maze_rows = lines.size()


func set_door_blocking(blocked: bool, world_pos: Vector3 = Vector3.ZERO) -> void:
	_door_blocks = blocked
	_door_block_pos = world_pos


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
	global_position = _clamp_to_walkable(pos)


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
	var next_pos: Vector3 = _resolve_motion(global_position, global_position + motion)
	next_pos.y = _capsule_half_height()
	global_position = next_pos

	if delta > 0.0:
		velocity = (global_position - prev_pos) / delta
	velocity.y = 0.0

	var flat_v: Vector3 = velocity
	if flat_v.length() > 0.12:
		var desired_basis: Basis = Basis.looking_at(flat_v.normalized(), Vector3.UP)
		global_basis = global_basis.slerp(desired_basis, rotate_speed * delta)


func _resolve_motion(from: Vector3, to: Vector3) -> Vector3:
	var feet_from := from
	feet_from.y = _capsule_half_height()
	var feet_to := to
	feet_to.y = _capsule_half_height()

	if _is_position_walkable(feet_to):
		return feet_to

	var slide_x := Vector3(feet_to.x, feet_from.y, feet_from.z)
	if _is_position_walkable(slide_x):
		return slide_x

	var slide_z := Vector3(feet_from.x, feet_from.y, feet_to.z)
	if _is_position_walkable(slide_z):
		return slide_z

	return feet_from


func _clamp_to_walkable(pos: Vector3) -> Vector3:
	if _is_position_walkable(pos):
		return pos
	# Nudge toward nearest walkable tile center if spawned slightly off.
	var tx: int = _tile_x(pos.x)
	var tz: int = _tile_z(pos.z)
	for radius in range(1, 4):
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var nx: int = tx + dx
				var nz: int = tz + dz
				if _is_tile_walkable(nx, nz):
					var p := pos
					p.x = float(nx) * _tile_size
					p.z = float(nz) * _tile_size
					p.y = _capsule_half_height()
					return p
	return pos


func _is_position_walkable(pos: Vector3) -> bool:
	if _maze_lines.is_empty():
		return true

	var r: float = collision_radius * 0.85
	var samples: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(r, 0.0, 0.0),
		Vector3(-r, 0.0, 0.0),
		Vector3(0.0, 0.0, r),
		Vector3(0.0, 0.0, -r),
	]
	for offset: Vector3 in samples:
		if not _is_world_point_walkable(pos + offset):
			return false
	return true


func _is_world_point_walkable(world_pos: Vector3) -> bool:
	if _door_blocks and _door_block_pos.distance_to(world_pos) < collision_radius + 0.15:
		return false
	return _is_tile_walkable(_tile_x(world_pos.x), _tile_z(world_pos.z))


func _tile_x(world_x: float) -> int:
	return int(round(world_x / _tile_size))


func _tile_z(world_z: float) -> int:
	return int(round(world_z / _tile_size))


func _is_tile_walkable(tile_x: int, tile_z: int) -> bool:
	if tile_x < 0 or tile_x >= _maze_cols or tile_z < 0 or tile_z >= _maze_rows:
		return false
	var cp: int = _maze_lines[tile_z].unicode_at(tile_x)
	if cp == CP_WALL:
		return false
	# Locked door tile is walkable on the map but blocked dynamically.
	return true
