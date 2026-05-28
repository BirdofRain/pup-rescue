class_name MazeNav
extends RefCounted

const CP_WALL: int = 35  # '#'

var lines: PackedStringArray = PackedStringArray()
var tile_size: float = 1.0
var cols: int = 0
var rows: int = 0
var body_radius: float = 0.22
var blockers: Array[Vector3] = []


func _init(
	maze_lines: PackedStringArray,
	p_tile_size: float = 1.0,
	p_radius: float = 0.22
) -> void:
	lines = maze_lines
	tile_size = p_tile_size
	body_radius = p_radius
	if lines.is_empty():
		cols = 0
		rows = 0
	else:
		cols = lines[0].length()
		rows = lines.size()


func clear_blockers() -> void:
	blockers.clear()


func add_blocker(world_pos: Vector3) -> void:
	blockers.append(world_pos)


func is_tile_walkable(cell_x: int, cell_z: int) -> bool:
	if cell_x < 0 or cell_x >= cols or cell_z < 0 or cell_z >= rows:
		return false
	return is_code_walkable(lines[cell_z].unicode_at(cell_x))


static func is_code_walkable(cp: int) -> bool:
	return cp != CP_WALL


func is_position_walkable(pos: Vector3) -> bool:
	if lines.is_empty():
		return true
	var r: float = body_radius * 0.85
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
	for blocker: Vector3 in blockers:
		var b := blocker
		b.y = 0.0
		var p := world_pos
		p.y = 0.0
		if p.distance_to(b) < body_radius + 0.15:
			return false
	return is_tile_walkable(tile_x(world_pos.x), tile_z(world_pos.z))


func resolve_motion(from: Vector3, to: Vector3, floor_y: float) -> Vector3:
	var feet_from := from
	feet_from.y = floor_y
	var feet_to := to
	feet_to.y = floor_y
	if is_position_walkable(feet_to):
		return feet_to
	var slide_x := Vector3(feet_to.x, feet_from.y, feet_from.z)
	if is_position_walkable(slide_x):
		return slide_x
	var slide_z := Vector3(feet_from.x, feet_from.y, feet_to.z)
	if is_position_walkable(slide_z):
		return slide_z
	return feet_from


func clamp_to_walkable(pos: Vector3, floor_y: float) -> Vector3:
	if is_position_walkable(pos):
		return pos
	var tx: int = tile_x(pos.x)
	var tz: int = tile_z(pos.z)
	for radius in range(1, 4):
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var nx: int = tx + dx
				var nz: int = tz + dz
				if is_tile_walkable(nx, nz):
					var p := pos
					p.x = float(nx) * tile_size
					p.z = float(nz) * tile_size
					p.y = floor_y
					return p
	return pos


func tile_x(world_x: float) -> int:
	return int(round(world_x / tile_size))


func tile_z(world_z: float) -> int:
	return int(round(world_z / tile_size))
