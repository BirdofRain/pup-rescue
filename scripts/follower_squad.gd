class_name FollowerSquad
extends Node

const FollowerPuppyScript := preload("res://scripts/follower_puppy.gd")

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
var _followers: Array[Node3D] = []
var _history: Array[Vector3] = []
var _nav: MazeNav
var _floor_y: float = 0.24
var _parent: Node3D
var _active: bool = false
var _player_idle_time: float = 0.0
var _last_player_pos: Vector3 = Vector3.ZERO
var _has_last_player_pos: bool = false


func is_active() -> bool:
	return _active


func activate(nav: MazeNav, floor_y: float, parent: Node3D, seed_pos: Vector3 = Vector3.ZERO) -> void:
	_nav = nav
	_floor_y = floor_y
	_parent = parent
	_active = true
	if seed_pos != Vector3.ZERO:
		seed_history(seed_pos)


func seed_history(pos: Vector3) -> void:
	_history.clear()
	var p := pos
	p.y = _floor_y
	_history.append(p)
	_last_player_pos = p
	_has_last_player_pos = true
	_player_idle_time = 0.0


func set_collar_accessory(accessory_id: String) -> void:
	_collar_id = accessory_id
	for pup: Node3D in _followers:
		if is_instance_valid(pup):
			pup.call("apply_collar", accessory_id)


func add_follower(spawn_pos: Vector3, _breed_index: int = -1) -> bool:
	if not _active or _parent == null or _nav == null:
		return false
	if _followers.size() >= max_followers:
		return false
	var pup := Node3D.new()
	pup.name = "Follower_%d" % _followers.size()
	pup.set_script(FollowerPuppyScript)
	_parent.add_child(pup)
	var pos := spawn_pos
	pos.y = _floor_y
	(pup as Node).call("setup", _nav, pos, -1, _followers.size())
	if _collar_id != "":
		pup.call("apply_collar", _collar_id)
	_followers.append(pup)
	return true


func spawn_in_pen(nav: MazeNav, pen_center: Vector3, floor_y: float, parent: Node3D, seed_pos: Vector3 = Vector3.ZERO) -> void:
	if not _active:
		clear()
	activate(nav, floor_y, parent, seed_pos if seed_pos != Vector3.ZERO else pen_center)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var slots: int = maxi(0, max_followers - _followers.size())
	for i in slots:
		var offset := Vector3(
			rng.randf_range(-0.35, 0.35),
			0.0,
			rng.randf_range(-0.35, 0.35)
		)
		add_follower(pen_center + offset, -1)


func rebind_for_level(nav: MazeNav, floor_y: float, parent: Node3D, player_start: Vector3) -> void:
	if nav == null or parent == null:
		return
	_nav = nav
	_floor_y = floor_y
	_parent = parent
	_prune_invalid_followers()
	if _followers.is_empty():
		_active = false
		_history.clear()
		return
	_active = true
	seed_history(player_start)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(_followers.size()):
		var pup: Node3D = _followers[i]
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


func _prune_invalid_followers() -> void:
	var kept: Array[Node3D] = []
	for pup in _followers:
		if is_instance_valid(pup):
			kept.append(pup)
	_followers = kept


func count_followers() -> int:
	_prune_invalid_followers()
	return _followers.size()


func clear() -> void:
	for f in _followers:
		if is_instance_valid(f):
			f.queue_free()
	_followers.clear()
	_history.clear()
	_active = false
	_parent = null
	_has_last_player_pos = false
	_player_idle_time = 0.0


func tick(delta: float, player_pos: Vector3, gather_point: Vector3 = Vector3.ZERO, speed_mult: float = 1.0) -> void:
	if not _active:
		return
	_update_player_idle(player_pos, delta)
	_record_player(player_pos)
	if _history.is_empty():
		return
	var count: int = _followers.size()
	var gathering: bool = gather_point != Vector3.ZERO
	var gather_blend: float = 0.0
	if gathering:
		gather_blend = 1.0
	elif _player_idle_time > 0.12:
		gather_blend = clampf((_player_idle_time - 0.12) / gather_blend_time, 0.0, 1.0)
	for i in range(count):
		var pup: Node3D = _followers[i]
		if not is_instance_valid(pup):
			continue
		var target: Vector3 = _trail_target_for_index(i, player_pos, pup.global_position)
		var speed_scale: float = 1.0
		var need_dist: float = follow_spacing * float(i + 1)
		var trail_avail: float = _trail_length()
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
		pup.call("set_target", target)
		pup.call("update_follow", delta, speed_scale * speed_mult)


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


func _trail_target_for_index(index: int, player_pos: Vector3, pup_pos: Vector3) -> Vector3:
	var dist: float = follow_spacing * float(index + 1)
	var available: float = _trail_length()
	if dist > available - follow_spacing * 0.25:
		dist = maxf(follow_spacing * 0.55, available - follow_spacing * 0.35)
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


func _record_player(player_pos: Vector3) -> void:
	var p := player_pos
	p.y = _floor_y
	if _history.is_empty():
		_history.append(p)
		return
	var last: Vector3 = _history[_history.size() - 1]
	if Vector2(p.x, p.z).distance_to(Vector2(last.x, last.z)) >= min_history_step:
		if _history.size() >= 2:
			var prev: Vector3 = _history[_history.size() - 2]
			var new_dir := Vector2(p.x - last.x, p.z - last.z)
			var old_dir := Vector2(last.x - prev.x, last.z - prev.z)
			if new_dir.length() > 0.001 and old_dir.length() > 0.001:
				if new_dir.normalized().dot(old_dir.normalized()) < 0.25:
					var min_keep: int = _min_history_keep()
					while _history.size() > min_keep:
						_history.remove_at(0)
		_history.append(p)
	else:
		_history[_history.size() - 1] = p
	var capacity: int = _history_capacity()
	while _history.size() > capacity:
		_history.remove_at(0)


func _history_capacity() -> int:
	var slots: int = maxi(max_followers, _followers.size())
	var needed_dist: float = follow_spacing * float(slots + 3)
	return maxi(max_history, int(needed_dist / min_history_step) + 96)


func _min_history_keep() -> int:
	var slots: int = maxi(max_followers, _followers.size())
	return mini(_history.size(), int((follow_spacing * float(slots + 1)) / min_history_step) + 48)


func _trail_length() -> float:
	if _history.size() < 2:
		return 0.0
	var total: float = 0.0
	for i in range(_history.size() - 1, 0, -1):
		var a: Vector3 = _history[i]
		var b: Vector3 = _history[i - 1]
		total += Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
	return total


func _sample_trail(distance_behind: float) -> Vector3:
	if _history.is_empty():
		return Vector3.ZERO
	if _history.size() == 1 or distance_behind <= 0.0:
		return _history[_history.size() - 1]
	var traveled: float = 0.0
	for i in range(_history.size() - 1, 0, -1):
		var a: Vector3 = _history[i]
		var b: Vector3 = _history[i - 1]
		var seg: float = Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
		if seg <= 0.0001:
			continue
		if traveled + seg >= distance_behind:
			var t: float = (distance_behind - traveled) / seg
			return a.lerp(b, t)
		traveled += seg
	return _history[0]


func snap_all_to(pos: Vector3) -> void:
	_prune_invalid_followers()
	var count: int = _followers.size()
	for i in range(count):
		var pup: Node3D = _followers[i]
		if not is_instance_valid(pup):
			continue
		var ring := _ring_offset(i, count, 0.35)
		var p := pos + ring
		p.y = _floor_y
		pup.global_position = p
		if pup.has_method("rebind_nav"):
			pup.call("rebind_nav", _nav, p)


func count_gathered_at(gather_pos: Vector3) -> int:
	var n := 0
	for pup in _followers:
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
	if _followers.is_empty():
		return 0
	return ceili(float(_followers.size()) * required_ratio)


func all_gathered_at(gather_pos: Vector3, required_ratio: float = 0.75) -> bool:
	if _followers.is_empty():
		return true
	return count_gathered_at(gather_pos) >= required_at_exit_count(required_ratio)


func count_near_exit(exit_pos: Vector3) -> int:
	return count_gathered_at(exit_pos)


func all_required_at_exit(exit_pos: Vector3, required_ratio: float = 0.75) -> bool:
	return all_gathered_at(exit_pos, required_ratio)
