# scripts/level_generator.gd
extends Node
class_name LevelGenerator

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
#   F fruit treat (optional powerup)
#   R rescue pup marker (optional)

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


func set_seed(seed_value: int) -> void:
	_rng_seed = seed_value if seed_value != 0 else 1


func generate_level(level_index: int, cells_w: int, cells_h: int, with_key_door: bool = true) -> PackedStringArray:
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
		var mx: int = (ax + bx) / 2
		var my: int = (ay + by) / 2

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

	# Optional: Key on path + rescue pen (or classic door fallback)
	if with_key_door:
		var path: Array[Vector2i] = _bfs_path(far1, far2)
		if path.size() >= 8:
			var key_i: int = clampi(int(path.size() * 0.30), 2, path.size() - 3)
			var key_pos: Vector2i = path[key_i]
			if _tile_is_floor(key_pos.x, key_pos.y):
				_set_tile(key_pos.x, key_pos.y, "K")

			if not _place_rescue_pen(path, far1, far2):
				var door_i: int = clampi(int(path.size() * 0.70), 2, path.size() - 3)
				var door_pos: Vector2i = path[door_i]
				if _tile_is_floor(door_pos.x, door_pos.y):
					_set_tile(door_pos.x, door_pos.y, "D")

	_place_fruit_pickups(rng, level_index)
	if level_index > 0:
		_place_rescue_markers(rng)

	# Convert to PackedStringArray
	var out := PackedStringArray()
	out.resize(_tile_h)
	for y in range(_tile_h):
		out[y] = _rows[y]
	return out

func _place_fruit_pickups(rng: RandomNumberGenerator, level_index: int) -> void:
	var candidates: Array[Vector2i] = []
	for y in range(_tile_h):
		for x in range(_tile_w):
			if _get_tile(x, y) != ".".unicode_at(0):
				continue
			candidates.append(Vector2i(x, y))
	if candidates.size() < 4:
		return
	var fruit_count: int = rng.randi_range(0, 2)
	if level_index == 0:
		fruit_count = mini(fruit_count, 1)
	for _i in range(fruit_count):
		if candidates.is_empty():
			break
		var pick: int = rng.randi_range(0, candidates.size() - 1)
		var pos: Vector2i = candidates[pick]
		candidates.remove_at(pick)
		_set_tile(pos.x, pos.y, "F")


func _place_rescue_markers(rng: RandomNumberGenerator) -> void:
	var candidates: Array[Vector2i] = []
	for y in range(_tile_h):
		for x in range(_tile_w):
			if _get_tile(x, y) != ".".unicode_at(0):
				continue
			candidates.append(Vector2i(x, y))
	if candidates.size() < 6:
		return
	var rescue_count: int = rng.randi_range(1, 2)
	for _i in range(rescue_count):
		if candidates.is_empty():
			break
		var pick: int = rng.randi_range(0, candidates.size() - 1)
		var pos: Vector2i = candidates[pick]
		candidates.remove_at(pick)
		_set_tile(pos.x, pos.y, "R")


func _place_rescue_pen(path: Array[Vector2i], start: Vector2i, goal: Vector2i) -> bool:
	if path.size() < 10:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng_seed ^ (path.size() * 7919)
	var indices: Array[int] = []
	for i in range(4, path.size() - 4):
		indices.append(i)
	for _swap in range(indices.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, _swap)
		var tmp: int = indices[_swap]
		indices[_swap] = indices[j]
		indices[j] = tmp
	for idx in indices:
		var branch: Vector2i = path[idx]
		if branch == start or branch == goal:
			continue
		if not _tile_is_walkable(branch.x, branch.y):
			continue
		var bcp: int = _get_tile(branch.x, branch.y)
		if bcp != ".".unicode_at(0):
			continue
		var along: Vector2i = path[idx + 1] - branch
		if along == Vector2i.ZERO:
			along = branch - path[idx - 1]
		for dir: Vector2i in _perp_dirs(along):
			if _try_carve_pen_at(branch, dir):
				return true
	return false


func _perp_dirs(along: Vector2i) -> Array[Vector2i]:
	if along.x != 0:
		return [Vector2i(0, 1), Vector2i(0, -1)]
	return [Vector2i(1, 0), Vector2i(-1, 0)]


func _try_carve_pen_at(branch: Vector2i, dir: Vector2i) -> bool:
	var perp: Vector2i = _perp_dirs(dir)[0]
	var pen_cells: Array[Vector2i] = []
	const DEPTH: int = 2
	const WIDTH: int = 2
	for d in range(1, DEPTH + 1):
		for w in range(WIDTH):
			var p: Vector2i = branch + dir * d + perp * w
			if p.x < 1 or p.x >= _tile_w - 1 or p.y < 1 or p.y >= _tile_h - 1:
				return false
			if _get_tile(p.x, p.y) != "#".unicode_at(0):
				return false
			pen_cells.append(p)
	for cell: Vector2i in pen_cells:
		_set_tile(cell.x, cell.y, "P")
	_set_tile(branch.x, branch.y, "G")
	return true


# ---------------- Tile helpers ----------------

func _set_tile(x: int, y: int, s: String) -> void:
	var b: PackedByteArray = _rows[y].to_utf8_buffer()
	b[x] = s.unicode_at(0)
	_rows[y] = b.get_string_from_utf8()

func _get_tile(x: int, y: int) -> int:
	var b: PackedByteArray = _rows[y].to_utf8_buffer()
	return int(b[x])

func _tile_is_walkable(x: int, y: int) -> bool:
	return _get_tile(x, y) != "#".unicode_at(0)

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
	return Vector2i(_tile_w / 2, _tile_h / 2)

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
		var cy: int = cur_idx / w
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

	return Vector2i(best_idx % w, best_idx / w)

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
		var cy: int = cur_idx / w

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
		path.push_front(Vector2i(cur2 % w, cur2 / w))
		if cur2 == s_idx:
			break
		cur2 = prev[cur2]
	return path
