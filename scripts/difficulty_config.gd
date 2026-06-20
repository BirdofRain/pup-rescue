class_name DifficultyConfig
extends RefCounted

enum Mode { BEGINNER, MEDIUM, MASTER }

const MODE_BEGINNER: int = 0
const MODE_MEDIUM: int = 1
const MODE_MASTER: int = 2

const MODE_LABELS := ["Beginner", "Medium", "Master"]

const MODE_HINTS := [
	"Same-size maze every level — new layout each time (ages 3–4)",
	"Maze grows slowly as you advance",
	"Full challenge — fewer speed boosts",
]

const BEGINNER_CELLS: int = 9
const PATHWAY_SCALE: float = 1.1
const MASTER_SPEED_BOOST_MULT: float = 0.72


static func clamp_mode(mode: int) -> int:
	return clampi(mode, MODE_BEGINNER, MODE_MASTER)


static func mode_label(mode: int) -> String:
	return MODE_LABELS[clamp_mode(mode)]


static func mode_hint(mode: int) -> String:
	return MODE_HINTS[clamp_mode(mode)]


static func maze_cells(level_index: int, mode: int) -> Vector2i:
	match clamp_mode(mode):
		Mode.BEGINNER:
			return Vector2i(BEGINNER_CELLS, BEGINNER_CELLS)
		Mode.MEDIUM:
			if level_index == 0:
				return Vector2i(7, 7)
			var step: int = maxi(1, level_index >> 1)
			var w: int = clampi(9 + step * 2, 9, 17)
			var h: int = clampi(9 + step * 2, 9, 15)
			return Vector2i(w, h)
		_:
			if level_index == 0:
				return Vector2i(7, 7)
			var w: int = clampi(9 + level_index * 2, 9, 19)
			var h: int = clampi(7 + level_index * 2, 7, 17)
			return Vector2i(w, h)


static func coin_pickup_count(level_index: int, mode: int, rng: RandomNumberGenerator) -> int:
	match clamp_mode(mode):
		Mode.BEGINNER:
			return rng.randi_range(2, 3)
		Mode.MEDIUM:
			if level_index == 0:
				return rng.randi_range(1, 2)
			if level_index <= 2:
				return rng.randi_range(2, 3)
			return rng.randi_range(2, 4)
		_:
			if level_index == 0:
				return rng.randi_range(1, 2)
			if level_index <= 2:
				return rng.randi_range(2, 3)
			return rng.randi_range(2, 4)


static func accessory_pickup_count(level_index: int, mode: int, rng: RandomNumberGenerator) -> int:
	match clamp_mode(mode):
		Mode.BEGINNER:
			return 0 if level_index == 0 else 1
		Mode.MEDIUM, Mode.MASTER:
			if level_index == 0:
				return 0
			if level_index <= 2:
				return 1
			return rng.randi_range(1, 2)
		_:
			return 0


static func ultra_pickup_count(level_index: int, mode: int, rng: RandomNumberGenerator) -> int:
	match clamp_mode(mode):
		Mode.BEGINNER:
			return 0
		Mode.MEDIUM:
			return 0 if level_index < 4 else rng.randi_range(0, 1)
		_:
			return 0 if level_index < 3 else rng.randi_range(0, 1)


static func powerup_marker_scale(level_index: int, mode: int) -> float:
	match clamp_mode(mode):
		Mode.BEGINNER:
			return 1.0
		Mode.MEDIUM:
			return 1.0 + clampf(float(level_index) * 0.08, 0.0, 0.6)
		_:
			return 1.0 + clampf(float(level_index) * 0.14, 0.0, 1.0)


static func speed_pickup_count(level_index: int, mode: int, rng: RandomNumberGenerator) -> int:
	match clamp_mode(mode):
		Mode.BEGINNER:
			return rng.randi_range(2, 3)
	var base: int = _base_speed_pickup_count(level_index, rng)
	match clamp_mode(mode):
		Mode.MEDIUM:
			return base
		_:
			return maxi(1, int(ceil(float(base) * MASTER_SPEED_BOOST_MULT)))


static func double_boost_count(level_index: int, mode: int, rng: RandomNumberGenerator) -> int:
	var base: int = _base_double_boost_count(level_index, rng)
	match clamp_mode(mode):
		Mode.BEGINNER:
			return 0
		Mode.MEDIUM:
			return base
		_:
			return maxi(0, int(floor(float(base) * MASTER_SPEED_BOOST_MULT)))


static func _base_speed_pickup_count(level_index: int, rng: RandomNumberGenerator) -> int:
	if level_index == 0:
		return rng.randi_range(1, 2)
	if level_index <= 2:
		return rng.randi_range(4, 5)
	if level_index <= 5:
		return rng.randi_range(5, 7)
	return rng.randi_range(6, mini(9, 10))


static func _base_double_boost_count(level_index: int, rng: RandomNumberGenerator) -> int:
	if level_index == 0:
		return 0
	if level_index <= 2:
		return 1
	if level_index <= 5:
		return rng.randi_range(1, 2)
	return rng.randi_range(2, 3)
