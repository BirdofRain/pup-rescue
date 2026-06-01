class_name ProgressionConfig
extends RefCounted

const COINS_LEVEL_COMPLETE: int = 5
const COINS_PER_RESCUE: int = 2
const COINS_PICKUP_C: int = 3
const COINS_FIRST_FIND_BONUS: int = 1
const COINS_DUPLICATE_ACCESSORY: int = 15

const BASE_SQUAD_CAP: int = 5
const SQUAD_HARD_CAP: int = 10
const DOUBLE_BOOST_SQUAD_BONUS: int = 1
const PEN_PUP_MIN: int = 3
const PEN_PUP_MAX: int = 7


static func roll_pen_pup_count(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(PEN_PUP_MIN, PEN_PUP_MAX)


static func pen_release_count(base_count: int, shop_bonus: int, run_bonus: int) -> int:
	return mini(maxi(PEN_PUP_MIN, base_count + shop_bonus + run_bonus), SQUAD_HARD_CAP)
