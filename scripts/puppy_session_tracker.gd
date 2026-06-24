class_name PuppySessionTracker
extends RefCounted

var temporary_rescues_this_level: int = 0
var permanent_companion_id: String = ""
var island_escort_present: bool = false


func reset_for_level() -> void:
	temporary_rescues_this_level = 0
	permanent_companion_id = ""
	island_escort_present = false


func register_permanent_companion(companion_id: String) -> void:
	permanent_companion_id = companion_id.strip_edges()


func register_island_escort() -> void:
	island_escort_present = true


func record_temporary_rescues_spawned(count: int) -> void:
	if count <= 0:
		return
	temporary_rescues_this_level += count


func sync_temporary_rescue_count_from_squad(squad: FollowerSquad) -> void:
	if squad == null:
		return
	var squad_count: int = squad.count_temporary_rescues()
	temporary_rescues_this_level = maxi(temporary_rescues_this_level, squad_count)


func validate_no_double_count(squad: FollowerSquad) -> PackedStringArray:
	var errors: PackedStringArray = []
	if squad == null:
		return errors
	errors.append_array(squad.validate_role_separation())
	var squad_temp: int = squad.count_temporary_rescues()
	if temporary_rescues_this_level < squad_temp:
		errors.append(
			"Session temporary count (%d) is below active temporary followers (%d)."
			% [temporary_rescues_this_level, squad_temp]
		)
	if squad.has_permanent_companion() and permanent_companion_id == "":
		errors.append("Permanent companion spawned but session tracker has no companion id.")
	if squad.has_island_escort() and not island_escort_present:
		errors.append("Island escort spawned but session tracker flag is false.")
	return errors


func build_completion_report(
	save: GameSave,
	had_home_island_pup: bool,
	escort_badge_would_earn: bool,
	escort_badge_already: bool
) -> Dictionary:
	return {
		"temporary_rescues": temporary_rescues_this_level,
		"permanent_companion_id": permanent_companion_id,
		"permanent_companion_name": _companion_display_name(save),
		"island_escort_present": had_home_island_pup or island_escort_present,
		"escort_badge_earned": escort_badge_would_earn and not escort_badge_already,
		"escort_badge_already": escort_badge_already,
	}


func format_completion_summary(report: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var temp: int = int(report.get("temporary_rescues", 0))
	lines.append("Random pups rescued: %d" % temp)
	var companion_name: String = str(report.get("permanent_companion_name", "none"))
	if companion_name != "" and companion_name != "none":
		lines.append("Companion: %s" % companion_name)
	else:
		lines.append("Companion: none")
	if bool(report.get("island_escort_present", false)):
		if bool(report.get("escort_badge_earned", false)):
			lines.append("Island escort: badge earned!")
		elif bool(report.get("escort_badge_already", false)):
			lines.append("Island escort: present (badge already earned)")
		else:
			lines.append("Island escort: present")
	else:
		lines.append("Island escort: not present")
	return "\n".join(lines)


func _companion_display_name(save: GameSave) -> String:
	if permanent_companion_id == "":
		return "none"
	if save != null:
		return save.get_companion_display_name(permanent_companion_id)
	return permanent_companion_id
