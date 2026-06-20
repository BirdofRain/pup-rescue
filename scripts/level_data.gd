# scripts/level_data.gd
extends Node
class_name LevelData

const _DifficultyConfig := preload("res://scripts/difficulty_config.gd")

# Optional tiny dev map for fast testing
static func make_micro_test_level() -> PackedStringArray:
	var arr: PackedStringArray = [
		"###########",
		"#S K . . E#",
		"# ####### #",
		"# ..G.. # #",
		"# ##P## # #",
		"# ##P## # #",
		"# ####### #",
		"###########",
	]
	return arr

# Backward-compatible signature:
# - make(level_index, run_seed, use_micro_test, difficulty_mode)
static func make(
	level_index: int,
	run_seed: int = 0,
	use_micro_test: bool = false,
	difficulty_mode: int = _DifficultyConfig.MODE_BEGINNER
) -> PackedStringArray:
	if use_micro_test:
		return make_micro_test_level()

	var gen := LevelGenerator.new()
	var cells: Vector2i = _DifficultyConfig.maze_cells(level_index, difficulty_mode)
	var with_key_door := level_index > 0
	var base_seed: int = _mix_seed(level_index, run_seed)

	var last_lines: PackedStringArray = []
	for attempt in range(24):
		gen.set_seed(base_seed + attempt * 7919)
		last_lines = gen.generate_level(
			level_index,
			cells.x,
			cells.y,
			with_key_door,
			difficulty_mode
		)
		if not with_key_door or _has_rescue_room(last_lines):
			return last_lines
	return last_lines


static func _mix_seed(level_index: int, run_seed: int) -> int:
	var s := int(run_seed)
	s = s ^ (level_index * 1103515245)
	s = (s + 12345) & 0x7fffffff
	if s == 0:
		s = 1
	return s


static func _has_rescue_room(lines: PackedStringArray) -> bool:
	var has_gate := false
	var has_pen := false
	for line: String in lines:
		if line.find("G") >= 0:
			has_gate = true
		if line.find("P") >= 0:
			has_pen = true
		if has_gate and has_pen:
			return true
	return false


static func _validate_rescue_room_sealed(lines: PackedStringArray) -> bool:
	if not _has_rescue_room(lines):
		return false
	var door := Vector2i(-1, -1)
	var pen_cells: Array[Vector2i] = []
	for y in range(lines.size()):
		var line: String = lines[y]
		for x in range(line.length()):
			var cp: int = line.unicode_at(x)
			if cp == "G".unicode_at(0):
				door = Vector2i(x, y)
			elif cp == "P".unicode_at(0):
				pen_cells.append(Vector2i(x, y))
	if door.x < 0 or pen_cells.is_empty():
		return false
	var min_x := pen_cells[0].x
	var max_x := pen_cells[0].x
	var min_y := pen_cells[0].y
	var max_y := pen_cells[0].y
	for cell: Vector2i in pen_cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)
	min_x -= 1
	max_x += 1
	min_y = mini(min_y, door.y)
	max_y = maxi(max_y, door.y)
	max_y += 1
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var cp: int = lines[y].unicode_at(x)
			var on_border := (
				x == min_x or x == max_x or y == min_y or y == max_y or (x == door.x and y == door.y)
			)
			var in_interior := (
				x > min_x and x < max_x and y > min_y and y < max_y and not (x == door.x and y == door.y)
			)
			if in_interior and cp != "P".unicode_at(0):
				return false
			if on_border and x == door.x and y == door.y:
				if cp != "G".unicode_at(0):
					return false
			elif on_border and cp != "#".unicode_at(0):
				return false
	return true

