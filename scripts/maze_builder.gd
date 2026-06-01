# scripts/maze_builder.gd
extends Node
class_name MazeBuilder

@export var tile_size: float = 1.1
@export var wall_height: float = 0.65

# Thin wall thickness relative to tile size (try 0.10–0.18)
@export var wall_thickness_ratio: float = 0.12

# Seals tiny pin-holes at L/T/+ corners with a flush square (not protruding caps).
@export var corner_fill: bool = true

# Tiny square size fudge (just enough to close pinholes).
@export var corner_fill_epsilon: float = 0.0 # keep 0 unless you see pinholes

# Door tuning (Game handles logic; builder just places the physical door body)
@export var door_height_multiplier: float = 1.0
@export var door_thickness_multiplier: float = 1.2

# --- codepoints (Godot 4 string indexing is int codepoint) ---
# ASCII codepoints (compile-time constants)
const CP_WALL: int = 35  # '#'
const CP_S: int = 83     # 'S'
const CP_E: int = 69     # 'E'
const CP_K: int = 75     # 'K'
const CP_D: int = 68     # 'D'
const CP_R: int = 82     # 'R'
const CP_P: int = 80     # 'P'
const CP_G: int = 71     # 'G'
const CP_F: int = 70     # 'F'
const CP_B: int = 66     # 'B'
const CP_C: int = 67     # 'C'
const CP_A: int = 65     # 'A'
const CP_U: int = 85     # 'U'

# Dark, high-contrast wall colors (readable on light checker floor).
const WALL_PALETTE: Array[Color] = [
	Color(0.52, 0.22, 0.36),  # rose
	Color(0.22, 0.36, 0.52),  # slate blue
	Color(0.24, 0.42, 0.28),  # forest
	Color(0.48, 0.38, 0.22),  # brown
	Color(0.36, 0.26, 0.48),  # plum
]

var _wall_color: Color = WALL_PALETTE[0]


func clear_children(root: Node) -> void:
	for c in root.get_children():
		c.queue_free()

func build_from_lines(lines: PackedStringArray, maze_root: Node3D, level_index: int = 0) -> Dictionary:
	_wall_color = WALL_PALETTE[level_index % WALL_PALETTE.size()]
	var info := {
		"start": Vector3.ZERO,
		"exit": null,
		"key": null,
		"door": null,
		"rescue": [],
		"pen_gate": null,
		"pen_cells": [],
		"pen_pup_count": 0,
		"fruit": [],
		"double_boost": [],
		"coins": [],
		"accessories": [],
		"ultra": [],
	}

	clear_children(maze_root)

	var rows: int = lines.size()
	var cols: int = lines[0].length()
		# --- camera fit bounds (maze coordinates are built from 0..(cols-1) and 0..(rows-1)) ---
	var max_x: float = float(cols - 1) * tile_size
	var max_z: float = float(rows - 1) * tile_size
	info.center = Vector3(max_x * 0.5, 0.0, max_z * 0.5)
	info.half_extents = Vector3(max_x * 0.5, 0.0, max_z * 0.5)
	
	# Parse specials
	for z in range(rows):
		var line: String = lines[z]
		for x in range(cols):
			var cp: int = line.unicode_at(x)
			var pos := Vector3(float(x) * tile_size, 0.0, float(z) * tile_size)
			match cp:
				CP_S: info.start = pos
				CP_E: info.exit = pos
				CP_K: info.key = pos
				CP_D: info.door = pos
				CP_R: info.rescue.append(pos)
				CP_P: info.pen_cells.append(pos)
				CP_G: info.pen_gate = pos
				CP_F: info.fruit.append(pos)
				CP_B: info.double_boost.append(pos)
				CP_C: info.coins.append(pos)
				CP_A: info.accessories.append(pos)
				CP_U: info.ultra.append(pos)
				_: pass

	if info.pen_cells.size() > 0:
		var sum := Vector3.ZERO
		for p: Vector3 in info.pen_cells:
			sum += p
		info["pen_center"] = sum / float(info.pen_cells.size())
	elif info.pen_gate is Vector3:
		info["pen_center"] = info.pen_gate

	# Build thin boundary walls
	var walls := Node3D.new()
	walls.name = "Walls"
	maze_root.add_child(walls)

	_build_thin_boundary_walls(lines, cols, rows, walls)

	_build_rescue_room(lines, cols, rows, maze_root, info)

	# Add the door physical blocker (if present)
	if info.door != null:
		info["door_body"] = _add_door_block(
			lines, cols, rows, walls,
			Vector2i(int(info.door.x / tile_size), int(info.door.z / tile_size)),
			Color(1.0, 0.45, 0.1)
		)

	if info.pen_gate != null:
		info["pen_gate_body"] = _add_door_block(
			lines, cols, rows, walls,
			Vector2i(int(info.pen_gate.x / tile_size), int(info.pen_gate.z / tile_size)),
			Color(0.82, 0.22, 0.28),
			"RescueGate"
		)

	return info

# -------------------- wall building --------------------

func _is_wall(lines: PackedStringArray, x: int, z: int, cols: int, rows: int) -> bool:
	if x < 0 or x >= cols or z < 0 or z >= rows:
		return false
	return (lines[z].unicode_at(x) == CP_WALL)

func _is_walkable(lines: PackedStringArray, x: int, z: int, cols: int, rows: int) -> bool:
	if x < 0 or x >= cols or z < 0 or z >= rows:
		return false
	return (lines[z].unicode_at(x) != CP_WALL)

func _build_thin_boundary_walls(lines: PackedStringArray, cols: int, rows: int, walls_root: Node3D) -> void:
	var t: float = tile_size * wall_thickness_ratio
	var y_center: float = wall_height * 0.5
	var vert_endpoints: Dictionary = {}
	var horiz_endpoints: Dictionary = {}

	for z in range(rows):
		for x in range(cols):
			if not _is_wall(lines, x, z, cols, rows):
				continue

			if not _is_wall(lines, x - 1, z, cols, rows):
				var cx := (float(x) - 0.5) * tile_size
				var cz := float(z) * tile_size
				_add_visual_segment(walls_root, Vector3(cx, y_center, cz), Vector3(t, wall_height, tile_size))
				_mark_endpoint(vert_endpoints, x, z)
				_mark_endpoint(vert_endpoints, x, z + 1)

			if not _is_wall(lines, x + 1, z, cols, rows):
				var cx := (float(x) + 0.5) * tile_size
				var cz := float(z) * tile_size
				_add_visual_segment(walls_root, Vector3(cx, y_center, cz), Vector3(t, wall_height, tile_size))
				_mark_endpoint(vert_endpoints, x + 1, z)
				_mark_endpoint(vert_endpoints, x + 1, z + 1)

			if not _is_wall(lines, x, z - 1, cols, rows):
				var cx := float(x) * tile_size
				var cz := (float(z) - 0.5) * tile_size
				_add_visual_segment(walls_root, Vector3(cx, y_center, cz), Vector3(tile_size, wall_height, t))
				_mark_endpoint(horiz_endpoints, x, z)
				_mark_endpoint(horiz_endpoints, x + 1, z)

			if not _is_wall(lines, x, z + 1, cols, rows):
				var cx := float(x) * tile_size
				var cz := (float(z) + 0.5) * tile_size
				_add_visual_segment(walls_root, Vector3(cx, y_center, cz), Vector3(tile_size, wall_height, t))
				_mark_endpoint(horiz_endpoints, x, z + 1)
				_mark_endpoint(horiz_endpoints, x + 1, z + 1)

	if corner_fill:
		var s: float = t + corner_fill_epsilon
		for key: String in vert_endpoints.keys():
			if not horiz_endpoints.has(key):
				continue
			var parts: PackedStringArray = key.split(",")
			var vx: int = int(parts[0])
			var vz: int = int(parts[1])
			var wx: float = (float(vx) - 0.5) * tile_size
			var wz: float = (float(vz) - 0.5) * tile_size
			_add_visual_segment(walls_root, Vector3(wx, y_center, wz), Vector3(s, wall_height, s))


func _mark_endpoint(d: Dictionary, vx: int, vz: int) -> void:
	d["%d,%d" % [vx, vz]] = true


# -------------------- door --------------------

# -------------------- rescue room --------------------

func _build_rescue_room(
	lines: PackedStringArray,
	cols: int,
	rows: int,
	maze_root: Node3D,
	info: Dictionary
) -> void:
	if info.pen_cells.is_empty() and info.pen_gate == null:
		return
	var room_root := Node3D.new()
	room_root.name = "RescueRoom"
	maze_root.add_child(room_root)
	info["rescue_room_root"] = room_root
	info["pen_wall_blockers"] = []

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.78, 0.68, 0.92)
	floor_mat.roughness = 0.88
	floor_mat.emission_enabled = true
	floor_mat.emission = Color(0.68, 0.55, 0.85)
	floor_mat.emission_energy_multiplier = 0.15

	for p: Vector3 in info.pen_cells:
		var plane := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(tile_size * 0.94, tile_size * 0.94)
		plane.mesh = pm
		plane.material_override = floor_mat
		plane.position = p + Vector3(0.0, 0.025, 0.0)
		plane.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		room_root.add_child(plane)

	if info.pen_cells.size() > 0:
		_add_rescue_room_walls(room_root, info.pen_cells, lines, cols, rows, info)


func _add_rescue_room_walls(
	parent: Node3D,
	pen_cells: Array,
	lines: PackedStringArray,
	cols: int,
	rows: int,
	info: Dictionary
) -> void:
	var cell_set: Dictionary = {}
	var min_x: int = 9999
	var max_x: int = -9999
	var min_z: int = 9999
	var max_z: int = -9999
	for p: Vector3 in pen_cells:
		var tx: int = int(round(p.x / tile_size))
		var tz: int = int(round(p.z / tile_size))
		cell_set["%d,%d" % [tx, tz]] = true
		min_x = mini(min_x, tx)
		max_x = maxi(max_x, tx)
		min_z = mini(min_z, tz)
		max_z = maxi(max_z, tz)

	var gate_tx: int = -1
	var gate_tz: int = -1
	if info.pen_gate is Vector3:
		gate_tx = int(round((info.pen_gate as Vector3).x / tile_size))
		gate_tz = int(round((info.pen_gate as Vector3).z / tile_size))

	var blockers: Array = info.get("pen_wall_blockers", [])

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.52, 0.32, 0.68)
	wall_mat.roughness = 0.9
	var t: float = tile_size * wall_thickness_ratio
	var h: float = wall_height * 0.55
	var y: float = h * 0.5

	for tx in range(min_x, max_x + 1):
		for tz in range(min_z, max_z + 1):
			if not cell_set.has("%d,%d" % [tx, tz]):
				continue
			var base := Vector3(float(tx) * tile_size, y, float(tz) * tile_size)
			if _needs_rescue_wall(lines, tx - 1, tz, cols, rows, cell_set, gate_tx, gate_tz):
				_add_rescue_wall_segment(
					parent, base + Vector3(-tile_size * 0.5, 0.0, 0.0),
					Vector3(t, h, tile_size), wall_mat, blockers
				)
			if _needs_rescue_wall(lines, tx + 1, tz, cols, rows, cell_set, gate_tx, gate_tz):
				_add_rescue_wall_segment(
					parent, base + Vector3(tile_size * 0.5, 0.0, 0.0),
					Vector3(t, h, tile_size), wall_mat, blockers
				)
			if _needs_rescue_wall(lines, tx, tz - 1, cols, rows, cell_set, gate_tx, gate_tz):
				_add_rescue_wall_segment(
					parent, base + Vector3(0.0, 0.0, -tile_size * 0.5),
					Vector3(tile_size, h, t), wall_mat, blockers
				)
			if _needs_rescue_wall(lines, tx, tz + 1, cols, rows, cell_set, gate_tx, gate_tz):
				_add_rescue_wall_segment(
					parent, base + Vector3(0.0, 0.0, tile_size * 0.5),
					Vector3(tile_size, h, t), wall_mat, blockers
				)


func _needs_rescue_wall(
	lines: PackedStringArray,
	nx: int,
	nz: int,
	cols: int,
	rows: int,
	cell_set: Dictionary,
	gate_tx: int,
	gate_tz: int
) -> bool:
	if nx == gate_tx and nz == gate_tz:
		return false
	if cell_set.has("%d,%d" % [nx, nz]):
		return false
	return true


func _add_rescue_wall_segment(
	parent: Node3D,
	center: Vector3,
	size: Vector3,
	mat: StandardMaterial3D,
	blockers: Array = []
) -> void:
	var body := StaticBody3D.new()
	body.name = "RescueWall"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	parent.add_child(body)

	var vis := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	vis.mesh = box
	vis.material_override = mat
	body.add_child(vis)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	blockers.append(center)


func _add_door_block(
	lines: PackedStringArray,
	cols: int,
	rows: int,
	parent: Node3D,
	door_cell: Vector2i,
	tint: Color = Color(1.0, 0.45, 0.1),
	body_name: String = "Door"
) -> StaticBody3D:
	var x := door_cell.x
	var z := door_cell.y

	var t: float = tile_size * wall_thickness_ratio
	var door_h: float = wall_height * door_height_multiplier
	var door_t: float = (t * door_thickness_multiplier)
	var y_center: float = door_h * 0.5

	var open_w: float = max(0.05, tile_size - t)

	var L := _is_walkable(lines, x - 1, z, cols, rows)
	var R := _is_walkable(lines, x + 1, z, cols, rows)
	var U := _is_walkable(lines, x, z - 1, cols, rows)
	var Dn := _is_walkable(lines, x, z + 1, cols, rows)

	var dir := Vector2i(0, 0)
	if R:
		dir = Vector2i(1, 0)
	elif L:
		dir = Vector2i(-1, 0)
	elif Dn:
		dir = Vector2i(0, 1)
	elif U:
		dir = Vector2i(0, -1)

	var base := Vector3(float(x) * tile_size, y_center, float(z) * tile_size)

	var center := base
	var size := Vector3(open_w, door_h, door_t)

	if dir.x != 0:
		center = base + Vector3(float(dir.x) * tile_size * 0.5, 0.0, 0.0)
		size = Vector3(door_t, door_h, open_w)
	elif dir.y != 0:
		center = base + Vector3(0.0, 0.0, float(dir.y) * tile_size * 0.5)
		size = Vector3(open_w, door_h, door_t)

	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	parent.add_child(body)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(mesh)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = 0.0
	mat.roughness = 0.9
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesh.material_override = mat

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return body

# -------------------- segment --------------------

func _add_visual_segment(parent: Node3D, center: Vector3, size: Vector3) -> void:
	var vis := Node3D.new()
	vis.name = "WallVis"
	vis.position = center
	parent.add_child(vis)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	vis.add_child(mesh)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = _wall_color
	mat.metallic = 0.0
	mat.roughness = 0.85
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.emission_enabled = true
	mat.emission = _wall_color.lightened(0.15)
	mat.emission_energy_multiplier = 0.12
	mesh.material_override = mat
