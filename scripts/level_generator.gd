# scripts/level_generator.gd
extends Node
class_name LevelGenerator

const _DifficultyConfig := preload("res://scripts/difficulty_config.gd")

# Generates a SOLVABLE maze as PackedStringArray lines.
# Perfect maze (recursive backtracker) on a cell grid,
# expanded to a tile grid:
#   tile_w = cells_w*2 + 1
#   tile_h = cells_h*2 + 1
#
# Output chars:
#   # wall
#   . floor
#   S start
#   E exit
#   K key (optional)
#   D door (optional, fallback if pen fails)
#   P pen floor (post-process)
#   G pen gate (post-process)
#   F speed boost (common powerup)
#   B double-rescue boost (uncommon powerup)
#   C treat coin pickup
#   A accessory pickup
#   U ultra powerup
const DIRS: Array[Vector2i] = [
	Vector2i(0, -1), # N
	Vector2i(1, 0),  # E
	Vector2i(0, 1),  # S
	Vector2i(-1, 0)  # W
]

# Internal working grid for one generation pass
var _rows: Array[String] = []
var _tile_w: int = 0
var _tile_h: int = 0
var _rng_seed: int = 1234544
var _difficulty_mode: int = _DifficultyConfig.MODE_MASTER

var _rescue_room_active: bool = false
var _rescue_room_min: Vector2i = Vector2i.ZERO
var _rescue_room_max: Vector2i = Vector2i.ZERO
var _rescue_room_door: Vector2i = Vector2i(-1, -1)


func set_seed(seed_value: int) -> void:
	_rng_seed = seed_value if seed_value != 0 else 1


func generate_level(
	level_index: int,
	cells_w: int,
	cells_h: int,
	with_key_door: bool = true,
	difficulty_mode: int = _DifficultyConfig.MODE_MASTER
) -> PackedStringArray:
	_difficulty_mode = _DifficultyConfig.clamp_mode(difficulty_mode)
	_rescue_room_active = false
	_rescue_room_door = Vector2i(-1, -1)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _rng_seed + level_index * 1336

	_tile_w = cells_w * 2 + 1
	_tile_h = cells_h * 2 + 1

	# Init tile grid full of walls '#'
	_rows.clear()
	_rows.resize(_tile_h)
	for y in range(_tile_h):
		_rows[y] = "#".repeat(_tile_w)

	# visited on cell grid (bytes 0/1)
	var visited: Array[PackedByteArray] = []
	visited.resize(cells_h)
	for cy in range(cells_h):
		var rowv := PackedByteArray()
		rowv.resize(cells_w)
		for cx in range(cells_w):
			rowv[cx] = 0
		visited[cy] = rowv

	# Choose random start cell
	var start_cell: Vector2i = Vector2i(rng.randi_range(0, cells_w - 1), rng.randi_range(0, cells_h - 1))
	var stack: Array[Vector2i] = [start_cell]
	visited[start_cell.y][start_cell.x] = 1

	# Mark start cell center as floor
	_set_tile(start_cell.x * 2 + 1, start_cell.y * 2 + 1, ".")

	# Carve perfect maze (DFS backtracker)
	while stack.size() > 0:
		var cur: Vector2i = stack[stack.size() - 1]
		var neighbors: Array[Vector2i] = []

		for d: Vector2i in DIRS:
			var nx: int = cur.x + d.x
			var ny: int = cur.y + d.y
			if nx < 0 or nx >= cells_w or ny < 0 or ny >= cells_h:
				continue
			if visited[ny][nx] == 0:
				neighbors.append(Vector2i(nx, ny))

		if neighbors.is_empty():
			stack.pop_back()
			continue

		var next: Vector2i = neighbors[rng.randi_range(0, neighbors.size() - 1)]

		# Convert cell coords to tile-center coords
		var ax: int = cur.x * 2 + 1
		var ay: int = cur.y * 2 + 1
		var bx: int = next.x * 2 + 1
		var by: int = next.y * 2 + 1

		# Knock down wall between them (midpoint)
		var mx: int = (ax + bx) >> 1
		var my: int = (ay + by) >> 1

		_set_tile(bx, by, ".")
		_set_tile(mx, my, ".")

		visited[next.y][next.x] = 1
		stack.append(next)

	# Pick far endpoints on tile grid (S and E)
	var a: Vector2i = _random_floor_tile(rng)
	var far1: Vector2i = _bfs_farthest(a)
	var far2: Vector2i = _bfs_farthest(far1)

	_set_tile(far1.x, far1.y, "S")
	_set_tile(far2.x, far2.y, "E")

	# Optional: side rescue alcove + key on main path before the branch
	if with_key_door:
		var path: Array[Vector2i] = _bfs_path(far1, far2)
		if path.size() >= 6:
			var junction_idx: int = _place_side_rescue_pen(path, far1, far2)
			if junction_idx < 0:
				_force_side_rescue_pen(path, far1, far2)
				junction_idx = _find_pen_junction_on_path(path)
			_place_key_before_pen(path, junction_idx, rng)

	_place_speed_pickups(rng, level_index, far1)
	_place_double_boost_pickups(rng, level_index, far1)
	_place_coin_pickups(rng, level_index, far1)
	_place_accessory_pickups(rng, level_index, far1)
	_place_ultra_pickups(rng, level_index, far1)

	sealRescueRoom()

	# Convert to PackedStringArray
	var out := PackedStringArray()
	out.resize(_tile_h)
	for y in range(_tile_h):
		out[y] = _rows[y]
	return out

func _speed_pickup_count(level_index: int, rng: RandomNumberGenerator) -> int:
	return _DifficultyConfig.speed_pickup_count(level_index, _difficulty_mode, rng)


func _double_boost_count(level_index: int, rng: RandomNumberGenerator) -> int:
	return _DifficultyConfig.double_boost_count(level_index, _difficulty_mode, rng)


func _collect_floor_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y in range(_tile_h):
		for x in range(_tile_w):
			if _tile_is_floor(x, y):
				tiles.append(Vector2i(x, y))
	return tiles


func _quadrant_of(tile: Vector2i) -> int:
	var cx: int = _tile_w >> 1
	var cz: int = _tile_h >> 1
	var east: bool = tile.x >= cx
	var south: bool = tile.y >= cz
	if not east and not south:
		return 0
	if east and not south:
		return 1
	if not east and south:
		return 2
	return 3


func _tile_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _is_far_enough_from(pos: Vector2i, others: Array[Vector2i], min_sep: int) -> bool:
	for other: Vector2i in others:
		if _tile_distance(pos, other) < min_sep:
			return false
	return true


func _pick_corner_floor_tiles(
	count: int,
	start: Vector2i,
	rng: RandomNumberGenerator,
	min_sep: int = 4
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = _collect_floor_tiles()
	if candidates.is_empty():
		return []
	var picked: Array[Vector2i] = []
	var quadrants: Array[int] = [0, 1, 2, 3]
	for i in range(quadrants.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = quadrants[i]
		quadrants[i] = quadrants[j]
		quadrants[j] = tmp
	for quad: int in quadrants:
		if picked.size() >= count:
			break
		var best: Vector2i = Vector2i(-1, -1)
		var best_score: int = -1
		for tile: Vector2i in candidates:
			if _quadrant_of(tile) != quad:
				continue
			if not _is_far_enough_from(tile, picked, min_sep):
				continue
			var score: int = _tile_distance(tile, start)
			if score > best_score:
				best_score = score
				best = tile
		if best.x >= 0:
			picked.append(best)
			candidates.erase(best)
	while picked.size() < count and not candidates.is_empty():
		var best: Vector2i = Vector2i(-1, -1)
		var best_score: int = -1
		for tile: Vector2i in candidates:
			if not _is_far_enough_from(tile, picked, min_sep):
				continue
			var score: int = _tile_distance(tile, start)
			if score > best_score:
				best_score = score
				best = tile
		if best.x < 0:
			break
		picked.append(best)
		candidates.erase(best)
	return picked


func _place_tiles_at(positions: Array[Vector2i], tile_char: String) -> void:
	for pos: Vector2i in positions:
		_set_tile(pos.x, pos.y, tile_char)


func _place_speed_pickups(rng: RandomNumberGenerator, level_index: int, _start: Vector2i) -> void:
	var candidates: Array[Vector2i] = _collect_floor_tiles()
	if candidates.size() < 4:
		return
	var speed_count: int = _speed_pickup_count(level_index, rng)
	for _i in range(speed_count):
		if candidates.is_empty():
			break
		var pick: int = rng.randi_range(0, candidates.size() - 1)
		var pos: Vector2i = candidates[pick]
		candidates.remove_at(pick)
		_set_tile(pos.x, pos.y, "F")


func _place_double_boost_pickups(rng: RandomNumberGenerator, level_index: int, start: Vector2i) -> void:
	var boost_count: int = _double_boost_count(level_index, rng)
	if boost_count <= 0:
		return
	var positions: Array[Vector2i] = _pick_corner_floor_tiles(boost_count, start, rng, 5)
	_place_tiles_at(positions, "B")


func _coin_pickup_count(level_index: int, rng: RandomNumberGenerator) -> int:
	return _DifficultyConfig.coin_pickup_count(level_index, _difficulty_mode, rng)


func _accessory_pickup_count(level_index: int, rng: RandomNumberGenerator) -> int:
	return _DifficultyConfig.accessory_pickup_count(level_index, _difficulty_mode, rng)


func _ultra_pickup_count(level_index: int, rng: RandomNumberGenerator) -> int:
	return _DifficultyConfig.ultra_pickup_count(level_index, _difficulty_mode, rng)


func _place_coin_pickups(rng: RandomNumberGenerator, level_index: int, _start: Vector2i) -> void:
	var candidates: Array[Vector2i] = _collect_floor_tiles()
	if candidates.size() < 4:
		return
	var count: int = _coin_pickup_count(level_index, rng)
	for _i in range(count):
		if candidates.is_empty():
			break
		var pick: int = rng.randi_range(0, candidates.size() - 1)
		var pos: Vector2i = candidates[pick]
		candidates.remove_at(pick)
		_set_tile(pos.x, pos.y, "C")


func _place_accessory_pickups(rng: RandomNumberGenerator, level_index: int, start: Vector2i) -> void:
	var count: int = _accessory_pickup_count(level_index, rng)
	if count <= 0:
		return
	var positions: Array[Vector2i] = _pick_corner_floor_tiles(count, start, rng, 5)
	_place_tiles_at(positions, "A")


func _place_ultra_pickups(rng: RandomNumberGenerator, level_index: int, start: Vector2i) -> void:
	var count: int = _ultra_pickup_count(level_index, rng)
	if count <= 0:
		return
	var positions: Array[Vector2i] = _pick_corner_floor_tiles(count, start, rng, 6)
	_place_tiles_at(positions, "U")


func _place_side_rescue_pen(path: Array[Vector2i], start: Vector2i, goal: Vector2i) -> int:
	if path.size() < 8:
		return -1
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng_seed ^ (path.size() * 7919)
	var max_idx: int = maxi(4, int(path.size() * 0.45))
	var indices: Array[int] = []
	for i in range(3, mini(max_idx, path.size() - 3)):
		indices.append(i)
	for _swap in range(indices.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, _swap)
		var tmp: int = indices[_swap]
		indices[_swap] = indices[j]
		indices[j] = tmp
	for idx in indices:
		var junction: Vector2i = path[idx]
		if junction == start or junction == goal:
			continue
		if _get_tile(junction.x, junction.y) != ".".unicode_at(0):
			continue
		var along: Vector2i = path[idx + 1] - junction
		if along == Vector2i.ZERO:
			along = junction - path[idx - 1]
		if along == Vector2i.ZERO:
			continue
		for side_dir: Vector2i in _perp_dirs(along):
			if _try_create_side_rescue_room(junction, side_dir):
				return idx
	return -1


func _force_side_rescue_pen(path: Array[Vector2i], start: Vector2i, goal: Vector2i) -> bool:
	for idx in range(2, path.size() - 2):
		var junction: Vector2i = path[idx]
		if junction == start or junction == goal:
			continue
		if _get_tile(junction.x, junction.y) != ".".unicode_at(0):
			continue
		for side_dir: Vector2i in DIRS:
			if _try_create_side_rescue_room(junction, side_dir):
				return true
	return false


func _find_pen_junction_on_path(path: Array[Vector2i]) -> int:
	for idx in range(path.size()):
		var tile: Vector2i = path[idx]
		for side_dir: Vector2i in DIRS:
			var n: Vector2i = tile + side_dir
			if _get_tile(n.x, n.y) == "G".unicode_at(0):
				return idx
	return clampi(int(path.size() * 0.22), 1, maxi(1, path.size() - 3))


func _place_key_before_pen(path: Array[Vector2i], junction_idx: int, rng: RandomNumberGenerator) -> void:
	if path.size() < 3:
		return
	var max_key_idx: int = maxi(1, junction_idx - 1)
	if max_key_idx <= 0:
		max_key_idx = clampi(int(path.size() * 0.18), 1, path.size() - 2)
	var min_key_idx: int = maxi(1, max_key_idx - 3)
	var key_i: int = rng.randi_range(min_key_idx, max_key_idx)
	var key_pos: Vector2i = path[key_i]
	if _get_tile(key_pos.x, key_pos.y) == ".".unicode_at(0):
		_set_tile(key_pos.x, key_pos.y, "K")


func _try_create_side_rescue_room(junction: Vector2i, side_dir: Vector2i) -> bool:
	var perp_dirs: Array[Vector2i] = _perp_dirs(side_dir)
	for perp: Vector2i in perp_dirs:
		for width: int in [1, 2, 3]:
			for depth: int in [2, 3]:
				if createRescueRoom(junction, side_dir, perp, width, depth):
					return true
	return false


func createRescueRoom(
	junction: Vector2i,
	side_dir: Vector2i,
	perp: Vector2i,
	interior_width: int,
	interior_depth: int
) -> bool:
	if side_dir == Vector2i.ZERO or perp == Vector2i.ZERO or interior_width < 1 or interior_depth < 1:
		return false
	if _get_tile(junction.x, junction.y) != ".".unicode_at(0):
		return false

	var door: Vector2i = junction + side_dir
	if not _cell_in_bounds(door):
		return false

	var interior: Array[Vector2i] = []
	for d in range(1, interior_depth + 1):
		for w in range(interior_width):
			var offset: int = w - ((interior_width - 1) >> 1)
			var cell: Vector2i = door + side_dir * d + perp * offset
			if not _cell_in_bounds(cell):
				return false
			interior.append(cell)

	if interior.is_empty():
		return false

	var ix0: int = interior[0].x
	var ix1: int = interior[0].x
	var iy0: int = interior[0].y
	var iy1: int = interior[0].y
	for cell: Vector2i in interior:
		ix0 = mini(ix0, cell.x)
		ix1 = maxi(ix1, cell.x)
		iy0 = mini(iy0, cell.y)
		iy1 = maxi(iy1, cell.y)

	var room_min := Vector2i(ix0 - 1, iy0 - 1)
	var room_max := Vector2i(ix1 + 1, iy1 + 1)
	if side_dir.x > 0:
		room_min.x = door.x
		room_max.x = door.x + interior_depth + 1
	elif side_dir.x < 0:
		room_min.x = door.x - interior_depth - 1
		room_max.x = door.x
	if side_dir.y > 0:
		room_min.y = door.y
		room_max.y = door.y + interior_depth + 1
	elif side_dir.y < 0:
		room_min.y = door.y - interior_depth - 1
		room_max.y = door.y

	if not _cell_in_bounds(room_min) or not _cell_in_bounds(room_max):
		return false

	for cell: Vector2i in interior:
		if _get_tile(cell.x, cell.y) != "#".unicode_at(0):
			return false
	if _get_tile(door.x, door.y) != "#".unicode_at(0):
		return false

	var snapshot: Array[String] = _rows.duplicate()
	_rescue_room_active = true
	_rescue_room_min = room_min
	_rescue_room_max = room_max
	_rescue_room_door = door
	sealRescueRoom()
	if not _main_route_still_open():
		_rows = snapshot
		_rescue_room_active = false
		_rescue_room_door = Vector2i(-1, -1)
		return false
	return true


func _main_route_still_open() -> bool:
	var start: Vector2i = _find_tile("S")
	var goal: Vector2i = _find_tile("E")
	if start.x < 0 or goal.x < 0:
		return false
	return not _bfs_path(start, goal).is_empty()


func _find_tile(ch: String) -> Vector2i:
	for y in range(_tile_h):
		for x in range(_tile_w):
			if _get_tile(x, y) == ch.unicode_at(0):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func sealRescueRoom() -> void:
	if not _rescue_room_active:
		return
	for y in range(_rescue_room_min.y, _rescue_room_max.y + 1):
		for x in range(_rescue_room_min.x, _rescue_room_max.x + 1):
			if isInsideRescueRoom(x, y):
				_set_tile(x, y, "P")
			elif isRescueRoomBorder(x, y):
				if x == _rescue_room_door.x and y == _rescue_room_door.y:
					if _get_tile(x, y) != ".".unicode_at(0):
						_set_tile(x, y, "G")
				else:
					_set_tile(x, y, "#")


func openRescueRoomDoor() -> void:
	if not _rescue_room_active or _rescue_room_door.x < 0:
		return
	_set_tile(_rescue_room_door.x, _rescue_room_door.y, ".")


static func open_rescue_room_door(lines: PackedStringArray, door: Vector2i) -> PackedStringArray:
	if door.x < 0 or door.y < 0:
		return lines
	if door.y >= lines.size():
		return lines
	var row: String = lines[door.y]
	if door.x >= row.length():
		return lines
	var cp: int = row.unicode_at(door.x)
	if cp != "G".unicode_at(0) and cp != "#".unicode_at(0):
		return lines
	var updated: PackedStringArray = lines.duplicate()
	var bytes: PackedByteArray = updated[door.y].to_utf8_buffer()
	bytes[door.x] = ".".unicode_at(0)
	updated[door.y] = bytes.get_string_from_utf8()
	return updated


func isInsideRescueRoom(x: int, y: int) -> bool:
	if not _rescue_room_active:
		return false
	return _is_rescue_interior_cell(x, y, _rescue_room_min, _rescue_room_max, _rescue_room_door)


func _is_rescue_interior_cell(
	x: int,
	y: int,
	room_min: Vector2i,
	room_max: Vector2i,
	door: Vector2i
) -> bool:
	if x < room_min.x or x > room_max.x or y < room_min.y or y > room_max.y:
		return false
	if x == door.x and y == door.y:
		return false
	if _is_rescue_border_cell(x, y, room_min, room_max, door):
		return false
	return true


func isRescueRoomBorder(x: int, y: int) -> bool:
	if not _rescue_room_active:
		return false
	return _is_rescue_border_cell(x, y, _rescue_room_min, _rescue_room_max, _rescue_room_door)


func _is_rescue_border_cell(
	x: int,
	y: int,
	room_min: Vector2i,
	room_max: Vector2i,
	door: Vector2i
) -> bool:
	if x == door.x and y == door.y:
		return true
	if x < room_min.x or x > room_max.x or y < room_min.y or y > room_max.y:
		return false
	return (
		x == room_min.x
		or x == room_max.x
		or y == room_min.y
		or y == room_max.y
	)


func _cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.x < _tile_w - 1 and cell.y >= 1 and cell.y < _tile_h - 1


func _perp_dirs(along: Vector2i) -> Array[Vector2i]:
	if along.x != 0:
		return [Vector2i(0, 1), Vector2i(0, -1)]
	return [Vector2i(1, 0), Vector2i(-1, 0)]


# ---------------- Tile helpers ----------------

func _set_tile(x: int, y: int, s: String) -> void:
	var b: PackedByteArray = _rows[y].to_utf8_buffer()
	b[x] = s.unicode_at(0)
	_rows[y] = b.get_string_from_utf8()

func _get_tile(x: int, y: int) -> int:
	var b: PackedByteArray = _rows[y].to_utf8_buffer()
	return int(b[x])

func _tile_is_walkable(x: int, y: int) -> bool:
	var cp: int = _get_tile(x, y)
	if cp == "#".unicode_at(0) or cp == "G".unicode_at(0) or cp == "P".unicode_at(0):
		return false
	return true

func _tile_is_floor(x: int, y: int) -> bool:
	return _get_tile(x, y) == ".".unicode_at(0)

func _random_floor_tile(rng: RandomNumberGenerator) -> Vector2i:
	# Godot wants all code paths to return a value, so we guard + fallback.
	var guard: int = 0
	var max_tries: int = _tile_w * _tile_h * 5

	while guard < max_tries:
		guard += 1
		var x: int = rng.randi_range(0, _tile_w - 1)
		var y: int = rng.randi_range(0, _tile_h - 1)
		if _tile_is_floor(x, y):
			return Vector2i(x, y)

	# Fallback scan (should never hit)
	for yy in range(_tile_h):
		for xx in range(_tile_w):
			if _tile_is_floor(xx, yy):
				return Vector2i(xx, yy)

	# Absolute fallback
	return Vector2i(_tile_w >> 1, _tile_h >> 1)

# ---------------- BFS helpers (typed arrays) ----------------

func _bfs_farthest(start: Vector2i) -> Vector2i:
	var w: int = _tile_w
	var h: int = _tile_h
	var n: int = w * h

	var dist := PackedInt32Array()
	dist.resize(n)
	for i in range(n):
		dist[i] = -1

	var q := PackedInt32Array()
	q.resize(0)

	var s_idx: int = start.y * w + start.x
	dist[s_idx] = 0
	q.append(s_idx)

	var best_idx: int = s_idx
	var best_d: int = 0

	var head: int = 0
	while head < q.size():
		var cur_idx: int = q[head]
		head += 1

		var cx: int = cur_idx % w
		var cy: int = int(cur_idx / float(w))
		var cd: int = dist[cur_idx]

		if cd > best_d:
			best_d = cd
			best_idx = cur_idx

		for d: Vector2i in DIRS:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if nx < 0 or nx >= w or ny < 0 or ny >= h:
				continue
			if not _tile_is_walkable(nx, ny):
				continue

			var ni: int = ny * w + nx
			if dist[ni] != -1:
				continue

			dist[ni] = cd + 1
			q.append(ni)

	return Vector2i(best_idx % w, int(best_idx / float(w)))

func _bfs_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var w: int = _tile_w
	var h: int = _tile_h
	var n: int = w * h

	var prev := PackedInt32Array()
	prev.resize(n)
	for i in range(n):
		prev[i] = -1

	var q := PackedInt32Array()
	q.resize(0)

	var s_idx: int = start.y * w + start.x
	var g_idx: int = goal.y * w + goal.x

	prev[s_idx] = s_idx
	q.append(s_idx)

	var head: int = 0
	while head < q.size():
		var cur_idx: int = q[head]
		head += 1
		if cur_idx == g_idx:
			break

		var cx: int = cur_idx % w
		var cy: int = int(cur_idx / float(w))

		for d: Vector2i in DIRS:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if nx < 0 or nx >= w or ny < 0 or ny >= h:
				continue
			if not _tile_is_walkable(nx, ny):
				continue

			var ni: int = ny * w + nx
			if prev[ni] != -1:
				continue

			prev[ni] = cur_idx
			q.append(ni)

	if prev[g_idx] == -1:
		return []

	var path: Array[Vector2i] = []
	var cur2: int = g_idx
	while true:
		path.push_front(Vector2i(cur2 % w, int(cur2 / float(w))))
		if cur2 == s_idx:
			break
		cur2 = prev[cur2]
	return path
