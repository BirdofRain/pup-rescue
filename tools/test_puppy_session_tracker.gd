extends SceneTree

const PuppySessionTrackerScript := preload("res://scripts/puppy_session_tracker.gd")
const FollowerSquadScript := preload("res://scripts/follower_squad.gd")
const FollowerRoleScript := preload("res://scripts/follower_role.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_session_reset()
	_test_temporary_rescues_do_not_touch_companion_fields()
	_test_completion_report_separates_roles()
	_test_squad_role_separation_with_mock_nodes()
	if _failures == 0:
		print("puppy_session_tracker: all tests passed")
	else:
		print("puppy_session_tracker: %d failure(s)" % _failures)
	quit(0 if _failures == 0 else 1)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("  OK: %s" % label)
	else:
		print("  FAIL: %s" % label)
		_failures += 1


func _test_session_reset() -> void:
	print("test_session_reset")
	var session: PuppySessionTracker = PuppySessionTrackerScript.new()
	session.record_temporary_rescues_spawned(4)
	session.register_permanent_companion("companion_sandy")
	session.register_island_escort()
	session.reset_for_level()
	_assert_true(session.temporary_rescues_this_level == 0, "temporary count resets")
	_assert_true(session.permanent_companion_id == "", "companion id resets")
	_assert_true(not session.island_escort_present, "escort flag resets")


func _test_temporary_rescues_do_not_touch_companion_fields() -> void:
	print("test_temporary_rescues_do_not_touch_companion_fields")
	var session: PuppySessionTracker = PuppySessionTrackerScript.new()
	session.register_permanent_companion("companion_sandy")
	session.record_temporary_rescues_spawned(2)
	session.record_temporary_rescues_spawned(1)
	_assert_true(session.temporary_rescues_this_level == 3, "temporary count accumulates")
	_assert_true(session.permanent_companion_id == "companion_sandy", "companion id unchanged")
	_assert_true(not session.island_escort_present, "escort flag still false")


func _test_completion_report_separates_roles() -> void:
	print("test_completion_report_separates_roles")
	var session: PuppySessionTracker = PuppySessionTrackerScript.new()
	session.record_temporary_rescues_spawned(2)
	session.register_permanent_companion("companion_sandy")
	session.register_island_escort()
	var report: Dictionary = session.build_completion_report(null, true, true, false)
	_assert_true(int(report.get("temporary_rescues", -1)) == 2, "report temp rescues")
	_assert_true(str(report.get("permanent_companion_id", "")) == "companion_sandy", "report companion")
	_assert_true(bool(report.get("island_escort_present", false)), "report escort present")
	_assert_true(bool(report.get("escort_badge_earned", false)), "report badge earned")
	var summary: String = session.format_completion_summary(report)
	_assert_true(summary.find("Random pups rescued: 2") >= 0, "summary mentions temp rescues")
	_assert_true(summary.find("Companion:") >= 0, "summary mentions companion")
	_assert_true(summary.find("Island escort:") >= 0, "summary mentions escort")


func _test_squad_role_separation_with_mock_nodes() -> void:
	print("test_squad_role_separation_with_mock_nodes")
	var squad: FollowerSquad = FollowerSquadScript.new()
	var temp := Node3D.new()
	temp.set_script(load("res://scripts/follower_puppy.gd"))
	temp.call("set_follower_role", FollowerRoleScript.ROLE_TEMPORARY_RESCUE)
	squad._temporary_rescues.append(temp)
	_assert_true(squad.count_temporary_rescues() == 1, "squad counts only temp list")
	_assert_true(squad.validate_role_separation().is_empty(), "valid temp role passes validation")
	temp.call("set_follower_role", FollowerRoleScript.ROLE_PERMANENT_COMPANION)
	var errors: PackedStringArray = squad.validate_role_separation()
	_assert_true(not errors.is_empty(), "companion role in temp list fails validation")
	temp.queue_free()
