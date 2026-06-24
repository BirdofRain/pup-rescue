extends Node3D

const PupColorsScript := preload("res://scripts/pup_colors.gd")
const PupAppearanceScript := preload("res://scripts/pup_appearance.gd")
const FollowerRoleScript := preload("res://scripts/follower_role.gd")

@export var move_speed: float = 6.5
@export var catchup_distance: float = 0.85
@export var catchup_multiplier: float = 2.0
@export var gather_speed_multiplier: float = 2.4
@export var model_scale: float = 0.52
@export var floor_y: float = 0.24
@export var arrival_slow_radius: float = 0.9
@export var direct_follow_range: float = 4.5

const PATH_REBUILD_DIST: float = 0.28
const WAYPOINT_REACH: float = 0.22
const STUCK_TIME: float = 0.25
const MAX_STUCK_REBUILDS: int = 2

var _nav: MazeNav
var _target: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _path: Array[Vector3] = []
var _path_index: int = 0
var _stuck_timer: float = 0.0
var _stuck_rebuilds: int = 0
var _spin_cooldown: float = 0.0
var _path_rebuild_allowed: bool = true
var _last_pos: Vector3 = Vector3.ZERO
var _mesh: MeshInstance3D
var _appearance = null
var _coat_color: Color = Color.WHITE
var _follower_index: int = 0
var _mesh_loaded: bool = false
var follower_role: int = FollowerRoleScript.ROLE_TEMPORARY_RESCUE


func setup(nav: MazeNav, spawn_pos: Vector3, breed_index: int = -1, follower_index: int = -1) -> void:
	_nav = nav
	_target = spawn_pos
	_velocity = Vector3.ZERO
	_path.clear()
	_path_index = 0
	_stuck_timer = 0.0
	_stuck_rebuilds = 0
	_spin_cooldown = 0.0
	global_position = spawn_pos
	global_position.y = floor_y
	_last_pos = global_position
	if breed_index >= 0:
		_coat_color = PupColorsScript.get_color(breed_index)
	elif follower_index >= 0:
		_follower_index = follower_index
		_coat_color = PupColorsScript.get_color(follower_index)
	_build_mesh()


func set_follower_role(role: int) -> void:
	follower_role = role


func get_follower_role() -> int:
	return follower_role


func is_temporary_rescue() -> bool:
	return follower_role == FollowerRoleScript.ROLE_TEMPORARY_RESCUE


func is_island_escort() -> bool:
	return follower_role == FollowerRoleScript.ROLE_ISLAND_ESCORT


func is_permanent_companion() -> bool:
	return follower_role == FollowerRoleScript.ROLE_PERMANENT_COMPANION


func set_coat_index(coat_index: int) -> void:
	_coat_color = PupColorsScript.get_color(coat_index)
	if _mesh != null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _coat_color
		mat.roughness = 0.85
		mat.metallic = 0.0
		mat.emission_enabled = true
		mat.emission = _coat_color * 0.22
		_mesh.material_override = mat
		if _mesh.mesh != null:
			for i in range(_mesh.mesh.get_surface_count()):
				_mesh.set_surface_override_material(i, mat)
	else:
		_build_mesh()


func apply_collar(accessory_id: String) -> void:
	_ensure_appearance()
	_appearance.apply_collar_only(accessory_id)


func apply_companion_loadout(save: GameSave, companion_id: String) -> void:
	_ensure_appearance()
	var loadout: Dictionary = save.get_companion_loadout(companion_id)
	_appearance.apply_loadout(loadout)


func _ensure_appearance() -> void:
	if _appearance != null:
		return
	_appearance = PupAppearanceScript.new()
	_appearance.name = "FollowerAppearance"
	if _mesh != null:
		_appearance.mount_to(_mesh)
	else:
		add_child(_appearance)


func rebind_nav(nav: MazeNav, pos: Vector3) -> void:
	_nav = nav
	_target = pos
	_velocity = Vector3.ZERO
	_path.clear()
	_path_index = 0
	_stuck_timer = 0.0
	_stuck_rebuilds = 0
	global_position = pos
	global_position.y = floor_y
	_last_pos = global_position


func set_path_rebuild_allowed(allowed: bool) -> void:
	_path_rebuild_allowed = allowed


func get_stuck_time() -> float:
	return _stuck_timer


func snap_to(pos: Vector3) -> void:
	pos.y = floor_y
	if _nav != null:
		pos = _nav.clamp_to_walkable(pos, floor_y)
	global_position = pos
	_target = pos
	_velocity = Vector3.ZERO
	_path.clear()
	_path_index = 0
	_stuck_timer = 0.0
	_stuck_rebuilds = 0
	_spin_cooldown = 0.2
	_last_pos = global_position


func set_target(world_pos: Vector3, _wander_offset: Vector3 = Vector3.ZERO) -> void:
	world_pos.y = floor_y
	var moved: float = _target.distance_to(world_pos)
	_target = world_pos
	if _should_rebuild_path(moved):
		_rebuild_path()


func _should_rebuild_path(moved: float) -> bool:
	if _path.is_empty():
		return true
	if not _path_rebuild_allowed and _path.size() > 0:
		return false
	if moved > PATH_REBUILD_DIST:
		return true
	var to_goal := _target - global_position
	to_goal.y = 0.0
	if to_goal.length() < 0.15:
		return false
	var wp := _current_waypoint() - global_position
	wp.y = 0.0
	if wp.length() < 0.05:
		return true
	var alignment: float = Vector2(to_goal.x, to_goal.z).normalized().dot(
		Vector2(wp.x, wp.z).normalized()
	)
	return alignment < 0.15


func _rebuild_path() -> void:
	if not _path_rebuild_allowed:
		if _path.is_empty():
			_path.append(_target)
		return
	_path.clear()
	_path_index = 0
	_stuck_timer = 0.0
	if _nav == null:
		return
	var flat_dist: float = Vector2(global_position.x, global_position.z).distance_to(
		Vector2(_target.x, _target.z)
	)
	if flat_dist <= direct_follow_range:
		_path.append(_target)
		return
	_path = _nav.find_path(global_position, _target, floor_y)
	if _path.is_empty():
		_path.append(_target)
	_path = _trim_path_behind(global_position, _path)


func _trim_path_behind(from: Vector3, path: Array[Vector3]) -> Array[Vector3]:
	if path.size() <= 1:
		return path
	var best_i: int = 0
	var best_dist: float = INF
	for i in range(path.size()):
		var wp: Vector3 = path[i]
		var d: float = Vector2(from.x, from.z).distance_to(Vector2(wp.x, wp.z))
		if d < best_dist:
			best_dist = d
			best_i = i
	if best_i > 0:
		return path.slice(best_i)
	return path


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
	if _spin_cooldown > 0.0:
		_spin_cooldown = maxf(0.0, _spin_cooldown - delta)
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
	var arrival_scale: float = clampf(dist / arrival_slow_radius, 0.15, 1.0)
	speed *= arrival_scale
	var dir := Vector3(to.x - from.x, 0.0, to.z - from.z).normalized()
	var desired_vel := dir * speed
	_velocity = _velocity.lerp(desired_vel, minf(1.0, 9.0 * delta))
	var step: float = minf(dist, _velocity.length() * delta)
	var next := from + dir * step
	next = _nav.resolve_motion(from, next, floor_y)
	next.y = floor_y
	global_position = next
	if step >= 0.02 and _spin_cooldown <= 0.0 and _stuck_timer < STUCK_TIME * 0.5 and _mesh != null:
		var target_yaw: float = atan2(dir.x, dir.z) + PupColorsScript.MODEL_YAW_OFFSET
		_mesh.rotation.y = lerp_angle(_mesh.rotation.y, target_yaw, 10.0 * delta)
	_check_stuck(delta)


func needs_snap_request() -> bool:
	return _stuck_rebuilds >= MAX_STUCK_REBUILDS


func _check_stuck(delta: float) -> void:
	var moved: float = Vector2(global_position.x, global_position.z).distance_to(
		Vector2(_last_pos.x, _last_pos.z)
	)
	if moved < 0.015:
		_stuck_timer += delta
		if _stuck_timer >= STUCK_TIME:
			_stuck_rebuilds += 1
			if _stuck_rebuilds < MAX_STUCK_REBUILDS:
				_rebuild_path()
	else:
		_stuck_timer = 0.0
		_stuck_rebuilds = 0
	_last_pos = global_position


func _build_mesh() -> void:
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh)
	var scale_mult: float = 0.94 + float(_follower_index % 3) * 0.06
	_mesh.scale = PupColorsScript.scaled_body(model_scale * scale_mult)
	if not _mesh_loaded:
		var mesh_res: Mesh = load(PupColorsScript.MESH_PATH) as Mesh
		if mesh_res != null:
			_mesh.mesh = mesh_res
			_mesh_loaded = true
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _coat_color
	mat.roughness = 0.85
	mat.metallic = 0.0
	mat.emission_enabled = true
	mat.emission = _coat_color * 0.22
	_mesh.material_override = mat
	if _mesh.mesh != null:
		for i in range(_mesh.mesh.get_surface_count()):
			_mesh.set_surface_override_material(i, mat)
