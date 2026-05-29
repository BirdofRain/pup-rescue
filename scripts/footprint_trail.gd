class_name FootprintTrail
extends Node3D

@export var step_distance: float = 0.22
@export var floor_y: float = 0.042
@export var foot_spacing: float = 0.07
@export var footprint_size: Vector2 = Vector2(0.12, 0.16)
@export var muddy_color: Color = Color(0.44, 0.34, 0.24, 0.52)

var _prints: Array[MeshInstance3D] = []
var _last_pos: Vector3 = Vector3.ZERO
var _has_last: bool = false
var _dist_accum: float = 0.0
var _left_foot: bool = true
var _mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = muddy_color
	_mat.roughness = 1.0
	_mat.metallic = 0.0
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.render_priority = 1


func clear() -> void:
	for p in _prints:
		if is_instance_valid(p):
			p.queue_free()
	_prints.clear()
	_has_last = false
	_dist_accum = 0.0
	_left_foot = true


func tick(player_pos: Vector3, velocity: Vector3) -> void:
	var p := player_pos
	p.y = floor_y
	var move_dir := Vector3(velocity.x, 0.0, velocity.z)
	if not _has_last:
		_last_pos = p
		_has_last = true
		if move_dir.length() < 0.01:
			move_dir = Vector3(0.0, 0.0, 1.0)
		else:
			move_dir = move_dir.normalized()
		_spawn_at(p, move_dir)
		_left_foot = not _left_foot
		return
	var moved: float = Vector2(p.x, p.z).distance_to(Vector2(_last_pos.x, _last_pos.z))
	if moved <= 0.01:
		return
	if move_dir.length() < 0.01:
		move_dir = Vector3(p.x - _last_pos.x, 0.0, p.z - _last_pos.z)
	if move_dir.length() < 0.01:
		move_dir = Vector3(0.0, 0.0, 1.0)
	else:
		move_dir = move_dir.normalized()
	_dist_accum += moved
	while _dist_accum >= step_distance:
		_dist_accum -= step_distance
		var t: float = 1.0 - clampf(_dist_accum / maxf(step_distance, 0.001), 0.0, 1.0)
		var foot_pos: Vector3 = _last_pos.lerp(p, t)
		_spawn_at(foot_pos, move_dir)
		_left_foot = not _left_foot
	_last_pos = p


func _spawn_at(pos: Vector3, move_dir: Vector3) -> void:
	var flat_dir := Vector3(move_dir.x, 0.0, move_dir.z).normalized()
	var side := Vector3(-flat_dir.z, 0.0, flat_dir.x)
	var lateral: float = foot_spacing if _left_foot else -foot_spacing
	var world_pos := pos + side * lateral
	world_pos.y = floor_y
	var yaw: float = atan2(flat_dir.x, flat_dir.z) + _rng.randf_range(-0.15, 0.15)
	var size_jitter: float = _rng.randf_range(0.94, 1.06)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = footprint_size * size_jitter
	mi.mesh = plane
	mi.material_override = _mat
	# PlaneMesh default lies flat on XZ — only rotate around Y for heading.
	mi.rotation = Vector3(0.0, yaw, 0.0)
	add_child(mi)
	mi.global_position = world_pos
	_prints.append(mi)
