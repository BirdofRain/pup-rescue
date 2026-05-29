class_name ProgressTracker
extends RefCounted

const UNLOCK_AT_LEVEL_INDEX: int = 2
const LEADERBOARD_MAX: int = 10
const MAX_NAME_LEN: int = 18

const QUICK_NAMES := ["Buddy", "Max", "Luna", "Coco", "Bailey", "Rocky"]


static func sanitize_name(raw: String) -> String:
	var name := raw.strip_edges()
	if name.length() > MAX_NAME_LEN:
		name = name.substr(0, MAX_NAME_LEN)
	return name


static func display_name(raw: String) -> String:
	var name := sanitize_name(raw)
	return name if name != "" else "Pup"


static func sort_leaderboard(a: Dictionary, b: Dictionary) -> bool:
	var la: int = int(a.get("level", 0))
	var lb: int = int(b.get("level", 0))
	if la != lb:
		return la > lb
	var sa: int = int(a.get("squad", 0))
	var sb: int = int(b.get("squad", 0))
	if sa != sb:
		return sa > sb
	return int(a.get("rescued", 0)) > int(b.get("rescued", 0))
