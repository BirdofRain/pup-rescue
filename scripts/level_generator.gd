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
#   D door (optional)

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

	# Optional: place Key + Door on guaranteed path S->E
	if with_key_door:
		var path: Array[Vector2i] = _bfs_path(far1, far2)
		if path.size() >= 8:
			var key_i: int = clampi(int(path.size() * 0.30), 2, path.size() - 3)
			var door_i: int = clampi(int(path.size() * 0.70), 2, path.size() - 3)

			var key_pos: Vector2i = path[key_i]
			var door_pos: Vector2i = path[door_i]

			if _tile_is_floor(key_pos.x, key_pos.y):
				_set_tile(key_pos.x, key_pos.y, "K")
			if _tile_is_floor(door_pos.x, door_pos.y):
				_set_tile(door_pos.x, door_pos.y, "D")

	# Convert to PackedStringArray
	var out := PackedStringArray()
	out.resize(_tile_h)
	for y in range(_tile_h):
		out[y] = _rows[y]
	return out

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
