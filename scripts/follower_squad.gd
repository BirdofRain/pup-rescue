class_name FollowerSquad
extends Node

const FollowerPuppyScript := preload("res://scripts/follower_puppy.gd")

@export var max_followers: int = 6
@export var follow_spacing: float = 0.95
@export var min_history_step: float = 0.04
@export var max_history: int = 240
@export var exit_radius: float = 0.65
@export var gather_radius: float = 1.15
@export var player_still_threshold: float = 0.06
@export var gather_blend_time: float = 0.9

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


func add_follower(spawn_pos: Vector3, breed_index: int = -1) -> bool:
	if not _active or _parent == null or _nav == null:
		return false
	if _followers.size() >= max_followers:
		return false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if breed_index < 0:
		breed_index = rng.randi_range(0, 2)
	var pup := Node3D.new()
	pup.name = "Follower_%d" % _followers.size()
	pup.set_script(FollowerPuppyScript)
	_parent.add_child(pup)
	var pos := spawn_pos
	pos.y = _floor_y
	(pup as Node).call("setup", _nav, pos, breed_index)
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
		add_follower(pen_center + offset, rng.randi_range(0, 2))


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


func tick(delta: float, player_pos: Vector3, gather_point: Vector3 = Vector3.ZERO) -> void:
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
		var dist_behind: float = (float(i) + 1.0) * follow_spacing
		var trail_target: Vector3 = _sample_trail(dist_behind)
		var target: Vector3 = trail_target
		var speed_scale: float = 1.0
		if gather_blend > 0.0:
			var center: Vector3 = gather_point if gathering else player_pos
			center.y = _floor_y
			var ring := _ring_offset(i, count, 0.38)
			var gather_target: Vector3 = center + ring
			var effective_spacing: float = lerpf(dist_behind, 0.0, gather_blend)
			trail_target = _sample_trail(effective_spacing)
			target = trail_target.lerp(gather_target, gather_blend)
			speed_scale = 1.0 + gather_blend * 1.8
		pup.call("set_target", target)
		pup.call("update_follow", delta, speed_scale)


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
		_history.append(p)
	else:
		_history[_history.size() - 1] = p
	while _history.size() > max_history:
		_history.remove_at(0)


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
