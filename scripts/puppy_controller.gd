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

# Movement tuning
@export var stop_radius: float = 0.25
@export var slow_radius: float = 2.0
@export var min_speed_factor: float = 0.15

# Debug toggles
@export var debug_enabled: bool = true
@export var debug_log_target: bool = false
@export var debug_log_stop: bool = false

@onready var model: MeshInstance3D = $Model

var target_point: Vector3 = Vector3.ZERO
var has_target: bool = false


func _ready() -> void:
	_apply_breed_mesh()
	if debug_enabled:
		print("\n=== Puppy Controller _ready ===")
		print("Puppy node path:", get_path())
		print("Breed:", Breed.keys()[breed])
		print("==============================\n")


func _apply_breed_mesh() -> void:
	if model == null:
		return
	var mesh_path: String = BREED_MESH_PATHS[breed]
	var mesh_res: Mesh = load(mesh_path) as Mesh
	if mesh_res != null:
		model.mesh = mesh_res


func set_target(p: Vector3) -> void:
	target_point = p
	has_target = true
	if debug_enabled and debug_log_target:
		print("Puppy set_target:", p)


func _physics_process(delta: float) -> void:
	if not has_target:
		velocity = velocity.move_toward(Vector3.ZERO, accel * delta)
		move_and_slide()
		return

	var to_target: Vector3 = target_point - global_position
	to_target.y = 0.0

	var dist: float = to_target.length()

	if dist < stop_radius:
		has_target = false
		velocity = velocity.move_toward(Vector3.ZERO, accel * delta)
		move_and_slide()
		if debug_enabled and debug_log_stop:
			print("Puppy stop at dist:", dist, " pos:", global_position)
		return

	var t: float = clampf(dist / slow_radius, min_speed_factor, 1.0)
	var desired: Vector3 = to_target.normalized() * (speed * t)

	velocity = velocity.move_toward(desired, accel * delta)
	move_and_slide()

	var flat_v: Vector3 = velocity
	flat_v.y = 0.0
	if flat_v.length() > 0.12:
		var desired_basis: Basis = Basis.looking_at(flat_v.normalized(), Vector3.UP)
		global_basis = global_basis.slerp(desired_basis, rotate_speed * delta)
