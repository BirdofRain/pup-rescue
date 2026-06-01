class_name FollowerSnap
extends RefCounted

enum Mode { OFF, DISTANCE, TRAIL }

const MODE_OFF: int = 0
const MODE_DISTANCE: int = 1
const MODE_TRAIL: int = 2

const MODE_LABELS := ["Off", "Distance", "Trail"]

const STUCK_SNAP_TIME: float = 0.5
const DISTANCE_EXTRA: float = 2.0
const DISTANCE_ABSOLUTE: float = 12.0
const TRAIL_RATIO: float = 0.9


static func clamp_mode(mode: int) -> int:
	return clampi(mode, MODE_OFF, MODE_TRAIL)


static func mode_label(mode: int) -> String:
	return MODE_LABELS[clamp_mode(mode)]


static func should_snap(
	mode: int,
	index: int,
	pup_pos: Vector3,
	player_pos: Vector3,
	need_dist: float,
	trail_length: float,
	follow_spacing: float,
	stuck_time: float
) -> bool:
	match clamp_mode(mode):
		Mode.OFF:
			return false
		Mode.DISTANCE:
			var flat_dist: float = Vector2(pup_pos.x, pup_pos.z).distance_to(
				Vector2(player_pos.x, player_pos.z)
			)
			var slot_dist: float = follow_spacing * float(index + 1) + DISTANCE_EXTRA
			return flat_dist > maxf(slot_dist, DISTANCE_ABSOLUTE) or stuck_time >= STUCK_SNAP_TIME
		_:
			if stuck_time >= STUCK_SNAP_TIME:
				return true
			return need_dist > trail_length * TRAIL_RATIO
