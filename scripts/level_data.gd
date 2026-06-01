# scripts/level_data.gd
extends Node
class_name LevelData

const _DifficultyConfig := preload("res://scripts/difficulty_config.gd")

# Optional tiny dev map for fast testing
static func make_micro_test_level() -> PackedStringArray:
	var arr: PackedStringArray = [
		"###########",
		"#S K . . E#",
		"# # # G # #",
		"# # # P P #",
		"# ####P ###",
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

