class_name FollowerSquad
extends Node

const FollowerPuppyScript := preload("res://scripts/follower_puppy.gd")
const FollowerSnapScript := preload("res://scripts/follower_snap.gd")
const FollowerRoleScript := preload("res://scripts/follower_role.gd")

const RING_CAP: int = 512
const REAR_LOD_INDEX: int = 6
const PATH_REBUILD_BUDGET: int = 2

@export var max_followers: int = 5
@export var follow_spacing: float = 0.95
@export var min_history_step: float = 0.03
@export var max_history: int = 480
@export var exit_radius: float = 0.65
@export var gather_radius: float = 1.15
@export var player_still_threshold: float = 0.06
@export var gather_blend_time: float = 1.2
@export var min_player_clearance: float = 0.55

var _collar_id: String = ""
var _companion: Node3D = null
var _companion_id: String = ""
var _companion_coat_index: int = -1
var _escort: Node3D = null
var _escort_coat_index: int = -1
var _temporary_rescues: Array[Node3D] = []
var _history_ring: Array = []
var _hist_head: int = 0
var _hist_size: int = 0
var _trail_length_cached: float = 0.0
var _nav: MazeNav
var _floor_y: float = 0.24
var _parent: Node3D
var _active: bool = false
var _player_idle_time: float = 0.0
var _last_player_pos: Vector3 = Vector3.ZERO
var _has_last_player_pos: bool = false
var _snap_mode: int = FollowerSnapScript.MODE_TRAIL
var _path_budget: int = PATH_REBUILD_BUDGET
var _path_budget_frame: int = -1
var _tick_parity: int = 0
var _held_at_gather: Array[bool] = []
var _snap_grace_until_ms: int = 0


func is_active() -> bool:
	return _active or has_escort() or has_permanent_companion()


func has_permanent_companion() -> bool:
	return is_instance_valid(_companion)


func get_permanent_companion_id() -> String:
	return _companion_id if has_permanent_companion() else ""


func get_permanent_companion() -> Node3D:
	return _companion if has_permanent_companion() else null


func has_escort() -> bool:
	return is_instance_valid(_escort)


func has_island_escort() -> bool:
	return has_escort()


func get_escort() -> Node3D:
	return _escort if has_escort() else null


func get_island_escort() -> Node3D:
	return get_escort()


func spawn_escort(
	spawn_pos: Vector3,
	nav: MazeNav,
	floor_y: float,
	parent: Node3D,
	coat_index: int,
	player_start: Vector3 = Vector3.ZERO
) -> bool:
	return spawn_island_escort(spawn_pos, nav, floor_y, parent, coat_index, player_start)


func spawn_island_escort(
	spawn_pos: Vector3,
	nav: MazeNav,
	floor_y: float,
	parent: Node3D,
	coat_index: int,
	player_start: Vector3 = Vector3.ZERO
) -> bool:
	if has_escort():
		return false
	if nav == null or parent == null:
		return false
	if not _active:
		activate(nav, floor_y, parent, player_start if player_start != Vector3.ZERO else spawn_pos)
	var pup := Node3D.new()
	pup.name = "IslandEscort"
	pup.set_script(FollowerPuppyScript)
	parent.add_child(pup)
	var pos := spawn_pos
	pos.y = floor_y
	(pup as Node).call("setup", nav, pos, coat_index, -1)
	pup.call("set_follower_role", FollowerRoleScript.ROLE_ISLAND_ESCORT)
	_escort = pup
	_escort_coat_index = coat_index
	if _collar_id != "":
		pup.call("apply_collar", _collar_id)
	return true


func spawn_permanent_companion(
	spawn_pos: Vector3,
	nav: MazeNav,
	floor_y: float,
	parent: Node3D,
	companion_id: String,
	coat_index: int,
	player_start: Vector3 = Vector3.ZERO,
	collar_accessory_id: String = ""
) -> bool:
	if has_permanent_companion():
		return false
	if nav == null or parent == null or companion_id == "":
		return false
	if not _active:
		activate(nav, floor_y, parent, player_start if player_start != Vector3.ZERO else spawn_pos)
	var pup := Node3D.new()
	pup.name = "PermanentCompanion"
	pup.set_script(FollowerPuppyScript)
	parent.add_child(pup)
	var pos := spawn_pos
	pos.y = floor_y
	(pup as Node).call("setup", nav, pos, coat_index, -1)
	pup.call("set_follower_role", FollowerRoleScript.ROLE_PERMANENT_COMPANION)
	_companion = pup
	_companion_id = companion_id
	_companion_coat_index = coat_index
	var collar_id: String = collar_accessory_id if collar_accessory_id != "" else _collar_id
	if collar_id != "":
		pup.call("apply_collar", collar_id)
	return true


func clear_companion() -> void:
	if is_instance_valid(_companion):
		_companion.queue_free()
	_companion = null
	_companion_id = ""
	_companion_coat_index = -1


func clear_escort() -> void:
	if is_instance_valid(_escort):
		_escort.queue_free()
	_escort = null
	_escort_coat_index = -1


func clear_special_followers() -> void:
	clear_companion()
	clear_escort()


func is_escort_at_exit(exit_pos: Vector3, leader_pos: Vector3) -> bool:
	if not has_escort():
		return false
	var pup: Node3D = _escort
	var p: Vector3 = pup.global_position
	p.y = 0.0
	var exit_flat := exit_pos
	exit_flat.y = 0.0
	var leader_flat := leader_pos
	leader_flat.y = 0.0
	var at_exit: bool = p.distance_to(exit_flat) <= gather_radius
	var near_leader: bool = p.distance_to(leader_flat) <= gather_radius * 1.35
	var near_exit: bool = p.distance_to(exit_flat) <= gather_radius * 2.4
	return at_exit or near_leader or near_exit


func gather_escort_to_exit(exit_pos: Vector3) -> void:
	gather_special_followers_to_exit(exit_pos)


func gather_special_followers_to_exit(exit_pos: Vector3) -> void:
	if has_permanent_companion():
		var companion_pos := exit_pos + Vector3(-0.55, 0.0, 0.25)
		companion_pos.y = _floor_y
		_companion.call("snap_to", companion_pos)
	if has_escort():
		var escort_pos := exit_pos + Vector3(-0.35, 0.0, 0.35)
		escort_pos.y = _floor_y
		_escort.call("snap_to", escort_pos)


func tick_escort(delta: float, player_pos: Vector3, speed_mult: float = 1.0) -> void:
	if not has_escort():
		return
	if _hist_size == 0:
		seed_history(player_pos)
	var pup: Node3D = _escort
	var trail_avail: float = _trail_length_cached
	var slot: int = 1 if has_permanent_companion() else 0
	var need_dist: float = follow_spacing * (float(slot) + 0.5)
	var target: Vector3 = _trail_target_for_index(slot, player_pos, pup.global_position, trail_avail)
	target.y = _floor_y
	pup.call("set_path_rebuild_allowed", _consume_path_budget())
	pup.call("set_target", target)
	pup.call("update_follow", delta, speed_mult)


func tick_companion(delta: float, player_pos: Vector3, speed_mult: float = 1.0) -> void:
	if not has_permanent_companion():
		return
	if _hist_size == 0:
		seed_history(player_pos)
	var pup: Node3D = _companion
	var trail_avail: float = _trail_length_cached
	var need_dist: float = follow_spacing * 0.5
	var target: Vector3 = _trail_target_for_index(0, player_pos, pup.global_position, trail_avail)
	target.y = _floor_y
	pup.call("set_path_rebuild_allowed", _consume_path_budget())
	pup.call("set_target", target)
	pup.call("update_follow", delta, speed_mult)


func set_snap_mode(mode: int) -> void:
	_snap_mode = FollowerSnapScript.clamp_mode(mode)


func activate(nav: MazeNav, floor_y: float, parent: Node3D, seed_pos: Vector3 = Vector3.ZERO) -> void:
	_nav = nav
	_floor_y = floor_y
	_parent = parent
	_active = true
	if seed_pos != Vector3.ZERO:
		seed_history(seed_pos)


func seed_history(pos: Vector3) -> void:
	_clear_history()
	var p := pos
	p.y = _floor_y
	_ring_push_back(p)
	_last_player_pos = p
	_has_last_player_pos = true
	_player_idle_time = 0.0


func set_collar_accessory(accessory_id: String) -> void:
	_collar_id = accessory_id
	for pup: Node3D in _temporary_rescues:
		if is_instance_valid(pup):
			pup.call("apply_collar", accessory_id)
	if has_escort():
		_escort.call("apply_collar", accessory_id)
	if has_permanent_companion():
		_companion.call("apply_collar", accessory_id)


func add_follower(spawn_pos: Vector3, _breed_index: int = -1) -> bool:
	if not _active or _parent == null or _nav == null:
		return false
	if _temporary_rescues.size() >= max_followers:
		return false
	var pup := Node3D.new()
	pup.name = "Follower_%d" % _temporary_rescues.size()
	pup.set_script(FollowerPuppyScript)
	_parent.add_child(pup)
	var pos := spawn_pos
	pos.y = _floor_y
	(pup as Node).call("setup", _nav, pos, -1, _temporary_rescues.size())
	pup.call("set_follower_role", FollowerRoleScript.ROLE_TEMPORARY_RESCUE)
	if _collar_id != "":
		pup.call("apply_collar", _collar_id)
	_temporary_rescues.append(pup)
	return true


func clear_temporary_rescues() -> void:
	for f in _temporary_rescues:
		if is_instance_valid(f):
			f.queue_free()
	_temporary_rescues.clear()
	_held_at_gather.clear()
	if has_escort() or has_permanent_companion():
		return
	_snap_grace_until_ms = 0
	_clear_history()
	_active = false
	_parent = null
	_has_last_player_pos = false
	_player_idle_time = 0.0


func clear_session_temporaries() -> void:
	clear_temporary_rescues()


func release_pen_followers(
	positions: Array[Vector3],
	nav: MazeNav,
	floor_y: float,
	parent: Node3D,
	seed_pos: Vector3,
	snap_grace_sec: float = 5.0
) -> int:
	clear_temporary_rescues()
	var seed: Vector3 = seed_pos
	if seed == Vector3.ZERO and not positions.is_empty():
		seed = positions[0]
	activate(nav, floor_y, parent, seed)
	_snap_grace_until_ms = Time.get_ticks_msec() + int(snap_grace_sec * 1000.0)
	var spawned := 0
	for pos in positions:
		if _temporary_rescues.size() >= max_followers:
			break
		if add_follower(pos, -1):
			spawned += 1
	return spawned


func spawn_rescue_group_at_positions(
	positions: Array[Vector3],
	nav: MazeNav,
	floor_y: float,
	parent: Node3D,
	seed_pos: Vector3 = Vector3.ZERO
) -> int:
	clear()
	var seed: Vector3 = seed_pos
	if seed == Vector3.ZERO and not positions.is_empty():
		seed = positions[0]
	activate(nav, floor_y, parent, seed)
	var spawned := 0
	for pos in positions:
		if _temporary_rescues.size() >= max_followers:
			break
		if add_follower(pos, -1):
			spawned += 1
	return spawned


func spawn_rescue_group(
	count: int,
	nav: MazeNav,
	pen_center: Vector3,
	floor_y: float,
	parent: Node3D,
	seed_pos: Vector3 = Vector3.ZERO
) -> int:
	clear()
	activate(nav, floor_y, parent, seed_pos if seed_pos != Vector3.ZERO else pen_center)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spawned := 0
	for i in count:
		if _temporary_rescues.size() >= max_followers:
			break
		var offset := Vector3(
			rng.randf_range(-0.35, 0.35),
			0.0,
			rng.randf_range(-0.35, 0.35)
		)
		if add_follower(pen_center + offset, -1):
			spawned += 1
	return spawned


func rebind_for_level(nav: MazeNav, floor_y: float, parent: Node3D, player_start: Vector3) -> void:
	if nav == null or parent == null:
		return
	_nav = nav
	_floor_y = floor_y
	_parent = parent
	_prune_invalid_temporary_rescues()
	if _temporary_rescues.is_empty() and not has_escort() and not has_permanent_companion():
		_active = false
		_clear_history()
		return
	_active = true
	seed_history(player_start)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for pup: Node3D in _temporary_rescues:
		if not is_instance_valid(pup):
			continue
		if pup.get_parent() != parent:
			pup.reparent(parent)
		var offset := Vector3(
			rng.randf_range(-0.35, 0.35),
			0.0,
			rng.randf_range(-0.35, 0.35)
		)
		var pos := player_start + offset
		pos.y = floor_y
		pup.call("rebind_nav", nav, pos)
	if has_permanent_companion():
		if _companion.get_parent() != parent:
			_companion.reparent(parent)
		var companion_pos := player_start + Vector3(-0.55, 0.0, 0.25)
		companion_pos.y = floor_y
		_companion.call("rebind_nav", nav, companion_pos)
	if has_escort():
		if _escort.get_parent() != parent:
			_escort.reparent(parent)
		var escort_pos := player_start + Vector3(-0.35, 0.0, 0.35)
		escort_pos.y = floor_y
		_escort.call("rebind_nav", nav, escort_pos)


func _prune_invalid_temporary_rescues() -> void:
	var kept: Array[Node3D] = []
	for pup in _temporary_rescues:
		if is_instance_valid(pup):
			kept.append(pup)
	_temporary_rescues = kept


func get_temporary_rescues() -> Array[Node3D]:
	_prune_invalid_temporary_rescues()
	return _temporary_rescues.duplicate()


func total_special_follower_count() -> int:
	var count: int = 0
	if has_permanent_companion():
		count += 1
	if has_escort():
		count += 1
	return count


func count_all_present_puppies() -> int:
	return count_temporary_rescues() + total_special_follower_count()


func validate_role_separation() -> PackedStringArray:
	var errors: PackedStringArray = []
	_prune_invalid_temporary_rescues()
	for pup: Node3D in _temporary_rescues:
		if not is_instance_valid(pup):
			continue
		if pup == _companion:
			errors.append("Permanent companion is listed among temporary rescues.")
		if pup == _escort:
			errors.append("Island escort is listed among temporary rescues.")
		if pup.has_method("is_temporary_rescue") and not bool(pup.call("is_temporary_rescue")):
			errors.append("Non-temporary follower found in temporary rescue list.")
	if has_permanent_companion() and _companion.has_method("is_temporary_rescue"):
		if bool(_companion.call("is_temporary_rescue")):
			errors.append("Permanent companion has temporary rescue role.")
		if _companion.has_method("is_island_escort") and bool(_companion.call("is_island_escort")):
			errors.append("Permanent companion incorrectly marked as island escort.")
	if has_escort() and _escort.has_method("is_temporary_rescue"):
		if bool(_escort.call("is_temporary_rescue")):
			errors.append("Island escort has temporary rescue role.")
	return errors


func count_temporary_rescues() -> int:
	_prune_invalid_temporary_rescues()
	return _temporary_rescues.size()


func count_followers() -> int:
	return count_temporary_rescues()


func count_session_rescue_points() -> int:
	return count_temporary_rescues()


func clear() -> void:
	clear_special_followers()
	for f in _temporary_rescues:
		if is_instance_valid(f):
			f.queue_free()
	_temporary_rescues.clear()
	_held_at_gather.clear()
	_snap_grace_until_ms = 0
	_clear_history()
	_active = false
	_parent = null
	_has_last_player_pos = false
	_player_idle_time = 0.0


func tick(
	delta: float,
	player_pos: Vector3,
	gather_point: Vector3 = Vector3.ZERO,
	speed_mult: float = 1.0,
	snap_mode: int = FollowerSnapScript.MODE_TRAIL
) -> void:
	if not _active and not has_escort() and not has_permanent_companion():
		return
	_snap_mode = FollowerSnapScript.clamp_mode(snap_mode)
	_reset_path_budget_if_needed()
	if has_permanent_companion():
		tick_companion(delta, player_pos, speed_mult)
	if has_escort():
		tick_escort(delta, player_pos, speed_mult)
	if not _active:
		return
	_reset_path_budget_if_needed()
	_tick_parity += 1
	_update_player_idle(player_pos, delta)
	_record_player(player_pos)
	if _hist_size == 0:
		return
	var count: int = _temporary_rescues.size()
	var trail_avail: float = _trail_length_cached
	var gathering: bool = gather_point != Vector3.ZERO
	var gather_blend: float = 0.0
	if gathering:
		gather_blend = 1.0
	elif _player_idle_time > 0.12:
		gather_blend = clampf((_player_idle_time - 0.12) / gather_blend_time, 0.0, 1.0)
	if not gathering:
		_held_at_gather.clear()
	for i in range(count):
		var pup: Node3D = _temporary_rescues[i]
		if not is_instance_valid(pup):
			continue
		while _held_at_gather.size() <= i:
			_held_at_gather.append(false)
		var need_dist: float = follow_spacing * float(i + 1)
		var use_lod: bool = i >= REAR_LOD_INDEX and (_tick_parity % 2) != 0
		if gathering:
			var center: Vector3 = gather_point
			center.y = _floor_y
			var ring := _ring_offset(i, count, 0.38)
			var gather_target: Vector3 = center + ring
			var pup_pos: Vector3 = pup.global_position
			pup_pos.y = _floor_y
			if pup_pos.distance_to(center) <= gather_radius * 0.92:
				_held_at_gather[i] = true
			if _held_at_gather[i]:
				pup.call("set_target", gather_target)
				pup.call("update_follow", delta, 0.08)
				continue
			var target: Vector3 = gather_target
			var speed_scale: float = 1.0 + gather_blend * 2.2 if gather_blend > 0.0 else 2.4
			pup.call("set_path_rebuild_allowed", _consume_path_budget())
			pup.call("set_target", target)
			pup.call("update_follow", delta, speed_scale * speed_mult)
			continue
		if use_lod and need_dist <= trail_avail + follow_spacing:
			continue
		var target: Vector3 = _trail_target_for_index(i, player_pos, pup.global_position, trail_avail)
		var speed_scale: float = 1.0
		if need_dist > trail_avail - follow_spacing * 0.25:
			speed_scale *= clampf(1.35 + (need_dist - trail_avail) * 0.4, 1.35, 3.0)
		if gather_blend > 0.0:
			var center: Vector3 = gather_point if gathering else player_pos
			center.y = _floor_y
			var ring := _ring_offset(i, count, 0.38)
			var gather_target: Vector3 = center + ring
			if gathering:
				target = gather_target
			else:
				var effective_spacing: float = lerpf(follow_spacing, 0.0, gather_blend)
				var trail_target: Vector3 = _sample_trail(effective_spacing * float(i + 1))
				if trail_target == Vector3.ZERO:
					trail_target = player_pos
				trail_target.y = _floor_y
				target = trail_target.lerp(gather_target, gather_blend)
			target = _clamp_min_distance_from(target, player_pos, min_player_clearance)
			speed_scale = 1.0 + gather_blend * 2.2
		var stuck_time: float = float(pup.call("get_stuck_time"))
		var snap_allowed: bool = Time.get_ticks_msec() >= _snap_grace_until_ms
		if snap_allowed and (
			FollowerSnapScript.should_snap(
				_snap_mode, i, pup.global_position, player_pos,
				need_dist, trail_avail, follow_spacing, stuck_time
			) or bool(pup.call("needs_snap_request"))
		):
			_snap_puppy(pup, i, count, player_pos, need_dist, trail_avail)
			stuck_time = 0.0
		pup.call("set_path_rebuild_allowed", _consume_path_budget())
		pup.call("set_target", target)
		pup.call("update_follow", delta, speed_scale * speed_mult)


func _snap_puppy(
	pup: Node3D,
	index: int,
	count: int,
	player_pos: Vector3,
	need_dist: float,
	trail_avail: float
) -> void:
	var dist: float = minf(need_dist, maxf(follow_spacing * 0.55, trail_avail - follow_spacing * 0.35))
	var snap_pos: Vector3 = _sample_trail(dist)
	if snap_pos == Vector3.ZERO:
		snap_pos = player_pos
	snap_pos.y = _floor_y
	if _nav != null and not _nav.is_position_walkable(snap_pos):
		var ring := _ring_offset(index, count, follow_spacing * 0.45)
		snap_pos = player_pos + ring
		snap_pos.y = _floor_y
		if _nav != null:
			snap_pos = _nav.clamp_to_walkable(snap_pos, _floor_y)
	pup.call("snap_to", snap_pos)


func _reset_path_budget_if_needed() -> void:
	var frame: int = Engine.get_physics_frames()
	if frame != _path_budget_frame:
		_path_budget_frame = frame
		_path_budget = PATH_REBUILD_BUDGET


func _consume_path_budget() -> bool:
	if _path_budget <= 0:
		return false
	_path_budget -= 1
	return true


func _clamp_min_distance_from(target: Vector3, center: Vector3, min_dist: float) -> Vector3:
	var flat_target := Vector2(target.x, target.z)
	var flat_center := Vector2(center.x, center.z)
	var offset := flat_target - flat_center
	if offset.length() < min_dist:
		if offset.length() < 0.001:
			offset = Vector2(1.0, 0.0)
		else:
			offset = offset.normalized()
		offset *= min_dist
		target.x = flat_center.x + offset.x
		target.z = flat_center.y + offset.y
	target.y = _floor_y
	return target


func _trail_target_for_index(
	index: int,
	player_pos: Vector3,
	pup_pos: Vector3,
	trail_avail: float
) -> Vector3:
	var dist: float = follow_spacing * float(index + 1)
	if dist > trail_avail - follow_spacing * 0.25:
		dist = maxf(follow_spacing * 0.55, trail_avail - follow_spacing * 0.35)
	var target: Vector3 = _sample_trail(dist)
	if target == Vector3.ZERO:
		target = player_pos
	target.y = _floor_y
	var pup_dist: float = Vector2(pup_pos.x, pup_pos.z).distance_to(Vector2(player_pos.x, player_pos.z))
	var target_dist: float = Vector2(target.x, target.z).distance_to(Vector2(player_pos.x, player_pos.z))
	if pup_dist + 0.3 < target_dist:
		var closer_dist: float = maxf(follow_spacing * 0.4, pup_dist - follow_spacing * 0.15)
		target = _sample_trail(closer_dist)
		if target == Vector3.ZERO:
			target = player_pos
		target.y = _floor_y
	return target


func _update_player_idle(player_pos: Vector3, delta: float) -> void:
	var p := player_pos
	p.y = _floor_y
	if not _has_last_player_pos:
		_last_player_pos = p
		_has_last_player_pos = true
		_player_idle_time = 0.0
		return
	var moved: float = Vector2(p.x, p.z).distance_to(Vector2(_last_player_pos.x, _last_player_pos.z))
	if moved <= player_still_threshold:
		_player_idle_time += delta
	else:
		_player_idle_time = 0.0
	_last_player_pos = p


func _ring_offset(index: int, total: int, radius: float) -> Vector3:
	if total <= 1:
		return Vector3.ZERO
	var angle: float = TAU * float(index) / float(total)
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _clear_history() -> void:
	_history_ring.clear()
	_hist_head = 0
	_hist_size = 0
	_trail_length_cached = 0.0


func _ring_get(logical_idx: int) -> Vector3:
	return _history_ring[(_hist_head + logical_idx) % RING_CAP] as Vector3


func _ring_set(logical_idx: int, value: Vector3) -> void:
	if _history_ring.size() < RING_CAP:
		_history_ring.resize(RING_CAP)
	_history_ring[(_hist_head + logical_idx) % RING_CAP] = value


func _ring_push_back(value: Vector3) -> void:
	if _hist_size > 0:
		_trail_length_cached += Vector2(value.x, value.z).distance_to(
			Vector2(_ring_get(_hist_size - 1).x, _ring_get(_hist_size - 1).z)
		)
	if _hist_size >= RING_CAP:
		if _hist_size >= 2:
			_trail_length_cached -= Vector2(_ring_get(0).x, _ring_get(0).z).distance_to(
				Vector2(_ring_get(1).x, _ring_get(1).z)
			)
		elif _hist_size == 1:
			_trail_length_cached = 0.0
		_hist_head = (_hist_head + 1) % RING_CAP
		_hist_size -= 1
	var tail_idx: int = (_hist_head + _hist_size) % RING_CAP
	if _history_ring.size() < RING_CAP:
		_history_ring.resize(RING_CAP)
	_history_ring[tail_idx] = value
	_hist_size += 1


func _record_player(player_pos: Vector3) -> void:
	var p := player_pos
	p.y = _floor_y
	if _hist_size == 0:
		_ring_push_back(p)
		return
	var last: Vector3 = _ring_get(_hist_size - 1)
	if Vector2(p.x, p.z).distance_to(Vector2(last.x, last.z)) >= min_history_step:
		if _hist_size >= 2:
			var prev: Vector3 = _ring_get(_hist_size - 2)
			var new_dir := Vector2(p.x - last.x, p.z - last.z)
			var old_dir := Vector2(last.x - prev.x, last.z - prev.z)
			if new_dir.length() > 0.001 and old_dir.length() > 0.001:
				if new_dir.normalized().dot(old_dir.normalized()) < 0.25:
					var min_keep: int = _min_history_keep()
					while _hist_size > min_keep:
						if _hist_size >= 2:
							_trail_length_cached -= Vector2(_ring_get(0).x, _ring_get(0).z).distance_to(
								Vector2(_ring_get(1).x, _ring_get(1).z)
							)
						_hist_head = (_hist_head + 1) % RING_CAP
						_hist_size -= 1
		_ring_push_back(p)
	else:
		if _hist_size >= 2:
			_trail_length_cached -= Vector2(last.x, last.z).distance_to(
				Vector2(_ring_get(_hist_size - 2).x, _ring_get(_hist_size - 2).z)
			)
		_ring_set(_hist_size - 1, p)
		if _hist_size >= 2:
			_trail_length_cached += Vector2(p.x, p.z).distance_to(
				Vector2(_ring_get(_hist_size - 2).x, _ring_get(_hist_size - 2).z)
			)
	var capacity: int = _history_capacity()
	while _hist_size > capacity:
		if _hist_size >= 2:
			_trail_length_cached -= Vector2(_ring_get(0).x, _ring_get(0).z).distance_to(
				Vector2(_ring_get(1).x, _ring_get(1).z)
			)
		_hist_head = (_hist_head + 1) % RING_CAP
		_hist_size -= 1


func _history_capacity() -> int:
	var slots: int = maxi(max_followers, _temporary_rescues.size())
	var needed_dist: float = follow_spacing * float(slots + 3)
	return mini(RING_CAP, maxi(max_history, int(needed_dist / min_history_step) + 96))


func _min_history_keep() -> int:
	var slots: int = maxi(max_followers, _temporary_rescues.size())
	return mini(_hist_size, int((follow_spacing * float(slots + 1)) / min_history_step) + 48)


func _sample_trail(distance_behind: float) -> Vector3:
	if _hist_size == 0:
		return Vector3.ZERO
	if _hist_size == 1 or distance_behind <= 0.0:
		return _ring_get(_hist_size - 1)
	var traveled: float = 0.0
	for i in range(_hist_size - 1, 0, -1):
		var a: Vector3 = _ring_get(i)
		var b: Vector3 = _ring_get(i - 1)
		var seg: float = Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
		if seg <= 0.0001:
			continue
		if traveled + seg >= distance_behind:
			var t: float = (distance_behind - traveled) / seg
			return a.lerp(b, t)
		traveled += seg
	return _ring_get(0)


func snap_all_to(pos: Vector3) -> void:
	_prune_invalid_temporary_rescues()
	var count: int = _temporary_rescues.size()
	for i in range(count):
		var pup: Node3D = _temporary_rescues[i]
		if not is_instance_valid(pup):
			continue
		var ring := _ring_offset(i, count, 0.35)
		var p := pos + ring
		p.y = _floor_y
		pup.call("snap_to", p)
	if has_escort():
		var escort_pos := pos + Vector3(-0.35, 0.0, 0.35)
		escort_pos.y = _floor_y
		_escort.call("snap_to", escort_pos)
	if has_permanent_companion():
		var companion_pos := pos + Vector3(-0.55, 0.0, 0.25)
		companion_pos.y = _floor_y
		_companion.call("snap_to", companion_pos)


func count_escorted_at(exit_pos: Vector3, leader_pos: Vector3) -> int:
	var n := 0
	for pup in _temporary_rescues:
		if not is_instance_valid(pup):
			continue
		var p: Vector3 = pup.global_position
		p.y = 0.0
		var exit_flat := exit_pos
		exit_flat.y = 0.0
		var leader_flat := leader_pos
		leader_flat.y = 0.0
		if p.distance_to(exit_flat) <= gather_radius or p.distance_to(leader_flat) <= gather_radius:
			n += 1
	return n


func count_gathered_at(gather_pos: Vector3) -> int:
	var n := 0
	for pup in _temporary_rescues:
		if not is_instance_valid(pup):
			continue
		var p: Vector3 = pup.global_position
		p.y = 0.0
		var g := gather_pos
		g.y = 0.0
		if p.distance_to(g) <= gather_radius:
			n += 1
	return n


func required_at_exit_count(required_ratio: float = 0.75) -> int:
	if _temporary_rescues.is_empty():
		return 0
	return ceili(float(_temporary_rescues.size()) * required_ratio)


func all_gathered_at(gather_pos: Vector3, required_ratio: float = 0.75) -> bool:
	if _temporary_rescues.is_empty():
		return true
	return count_gathered_at(gather_pos) >= required_at_exit_count(required_ratio)


func count_near_exit(exit_pos: Vector3) -> int:
	return count_gathered_at(exit_pos)


func all_required_at_exit(exit_pos: Vector3, required_ratio: float = 0.75) -> bool:
	return all_gathered_at(exit_pos, required_ratio)
