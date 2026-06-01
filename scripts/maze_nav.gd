class_name MazeNav
extends RefCounted

const CP_WALL: int = 35  # '#'

var lines: PackedStringArray = PackedStringArray()
var tile_size: float = 1.0
var cols: int = 0
var rows: int = 0
var body_radius: float = 0.22
var static_blockers: Array[Vector3] = []
var dynamic_blockers: Array[Vector3] = []
var _pen_sealed: bool = false
var _sealed_cells: Dictionary = {}


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
	clear_dynamic_blockers()


func clear_dynamic_blockers() -> void:
	dynamic_blockers.clear()


func set_static_blockers(positions: Array) -> void:
	static_blockers.clear()
	for p in positions:
		if p is Vector3:
			static_blockers.append(p)


func add_dynamic_blocker(world_pos: Vector3) -> void:
	dynamic_blockers.append(world_pos)


func configure_sealed_pen(pen_cell_coords: Array, gate_cell: Vector2i, sealed: bool) -> void:
	_sealed_cells.clear()
	for cell in pen_cell_coords:
		if cell is Vector2i:
			_sealed_cells["%d,%d" % [cell.x, cell.y]] = true
	if gate_cell.x >= 0 and gate_cell.y >= 0:
		_sealed_cells["%d,%d" % [gate_cell.x, gate_cell.y]] = true
	_pen_sealed = sealed


func set_pen_open(open: bool) -> void:
	_pen_sealed = not open


func is_tile_walkable(cell_x: int, cell_z: int) -> bool:
	if cell_x < 0 or cell_x >= cols or cell_z < 0 or cell_z >= rows:
		return false
	if _pen_sealed and _sealed_cells.has("%d,%d" % [cell_x, cell_z]):
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
	for blocker: Vector3 in static_blockers:
		if _point_blocked_by(world_pos, blocker):
			return false
	for blocker: Vector3 in dynamic_blockers:
		if _point_blocked_by(world_pos, blocker):
			return false
	return is_tile_walkable(tile_x(world_pos.x), tile_z(world_pos.z))


func _point_blocked_by(world_pos: Vector3, blocker: Vector3) -> bool:
	var b := blocker
	b.y = 0.0
	var p := world_pos
	p.y = 0.0
	return p.distance_to(b) < body_radius + 0.15


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


func tile_center(cell_x: int, cell_z: int, floor_y: float = 0.0) -> Vector3:
	return Vector3(float(cell_x) * tile_size, floor_y, float(cell_z) * tile_size)


func find_path(from_world: Vector3, to_world: Vector3, floor_y: float = 0.0) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if lines.is_empty():
		var direct := to_world
		direct.y = floor_y
		result.append(direct)
		return result
	var start: Vector2i = _nearest_walkable_tile(from_world)
	var goal: Vector2i = _nearest_walkable_tile(to_world)
	if start == goal:
		result.append(tile_center(start.x, start.y, floor_y))
		return result
	var queue: Array[Vector2i] = [start]
	var queue_head: int = 0
	var came_from: Dictionary = {}
	came_from[start] = start
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]
	var found_goal := false
	while not queue.is_empty():
		var current: Vector2i = queue[queue_head]
		queue_head += 1
		if current == goal:
			found_goal = true
			break
		for d: Vector2i in dirs:
			var next: Vector2i = current + d
			if not _is_cell_reachable(next.x, next.y):
				continue
			if came_from.has(next):
				continue
			came_from[next] = current
			queue.append(next)
	if not found_goal:
		var fallback := to_world
		fallback.y = floor_y
		result.append(fallback)
		return result
	var cells: Array[Vector2i] = []
	var cur: Vector2i = goal
	while cur != start:
		cells.push_front(cur)
		cur = came_from[cur]
	cells.push_front(start)
	for cell: Vector2i in cells:
		result.append(tile_center(cell.x, cell.y, floor_y))
	return result


func _is_cell_reachable(cell_x: int, cell_z: int) -> bool:
	if not is_tile_walkable(cell_x, cell_z):
		return false
	return is_position_walkable(tile_center(cell_x, cell_z, 0.0))


func _nearest_walkable_tile(world_pos: Vector3) -> Vector2i:
	var tx: int = tile_x(world_pos.x)
	var tz: int = tile_z(world_pos.z)
	if _is_cell_reachable(tx, tz):
		return Vector2i(tx, tz)
	for radius in range(1, 6):
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var nx: int = tx + dx
				var nz: int = tz + dz
				if _is_cell_reachable(nx, nz):
					return Vector2i(nx, nz)
	return Vector2i(tx, tz)
