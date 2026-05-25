# scripts/level_data.gd
extends Node
class_name LevelData

# Optional tiny dev map for fast testing
static func make_micro_test_level() -> PackedStringArray:
	var arr: PackedStringArray = [
		"###########",
		"#S   #   E#",
		"# ## # ####",
		"# K  D    #",
		"###########",
	]
	return arr

# Backward-compatible signature:
# - You can still call make(level_index)
# - Or make(level_index, run_seed, use_micro_test)
static func make(level_index: int, run_seed: int = 0, use_micro_test: bool = false) -> PackedStringArray:
	if use_micro_test:
		return make_micro_test_level()

	var gen := LevelGenerator.new()

	# Size grows with level
	var w := clampi(9 + level_index * 2, 9, 19)
	var h := clampi(7 + level_index * 2, 7, 17)

	gen.set_seed(_mix_seed(level_index, run_seed))
	return gen.generate_level(level_index, w, h, true)


static func _mix_seed(level_index: int, run_seed: int) -> int:
	var s := int(run_seed)
	s = s ^ (level_index * 1103515245)
	s = (s + 12345) & 0x7fffffff
	if s == 0:
		s = 1
	return s

