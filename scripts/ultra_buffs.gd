class_name UltraBuffs
extends RefCounted

const UltraPowerupCatalogScript := preload("res://scripts/ultra_powerup_catalog.gd")

var _active: Dictionary = {}  # id -> until_ms
var _bubble_bumps_left: int = 0
var _rainbow_trail: bool = false
var _reveal_rescue: bool = false


func clear() -> void:
	_active.clear()
	_bubble_bumps_left = 0
	_rainbow_trail = false
	_reveal_rescue = false


func apply(id: String) -> Dictionary:
	var entry: Dictionary = UltraPowerupCatalogScript.get_entry(id)
	if entry.is_empty():
		return {}
	var duration: float = float(entry.get("duration", 15.0))
	var until_ms: int = Time.get_ticks_msec() + int(duration * 1000.0)
	_active[id] = until_ms
	match str(entry.get("effect", "")):
		"bubble_bump":
			_bubble_bumps_left = int(entry.get("value", 1))
		"rainbow_trail":
			_rainbow_trail = true
		"reveal_rescue":
			_reveal_rescue = true
	return entry


func tick() -> void:
	var now: int = Time.get_ticks_msec()
	var expired: Array[String] = []
	for id: String in _active:
		if now >= int(_active[id]):
			expired.append(id)
	for id: String in expired:
		_on_expire(id)
		_active.erase(id)


func _on_expire(id: String) -> void:
	var entry: Dictionary = UltraPowerupCatalogScript.get_entry(id)
	match str(entry.get("effect", "")):
		"rainbow_trail":
			_rainbow_trail = false
		"reveal_rescue":
			_reveal_rescue = false


func is_active(id: String) -> bool:
	return _active.has(id) and Time.get_ticks_msec() < int(_active[id])


func seconds_left(id: String) -> float:
	if not _active.has(id):
		return 0.0
	return maxf(0.0, float(int(_active[id]) - Time.get_ticks_msec()) / 1000.0)


func follower_speed_mult() -> float:
	if is_active("magnet_leash"):
		var entry: Dictionary = UltraPowerupCatalogScript.get_entry("magnet_leash")
		return float(entry.get("value", 1.4))
	return 1.0


func has_bubble_bump() -> bool:
	return _bubble_bumps_left > 0


func consume_bubble_bump() -> bool:
	if _bubble_bumps_left <= 0:
		return false
	_bubble_bumps_left -= 1
	if _bubble_bumps_left <= 0:
		_active.erase("bubble_paw")
	return true


func wants_rainbow_trail() -> bool:
	return _rainbow_trail


func wants_reveal_rescue() -> bool:
	return _reveal_rescue


func active_labels() -> PackedStringArray:
	var parts: PackedStringArray = PackedStringArray()
	for id: String in _active:
		var entry: Dictionary = UltraPowerupCatalogScript.get_entry(id)
		var name: String = entry.get("name", id)
		if id == "bubble_paw" and _bubble_bumps_left > 0:
			parts.append("%s (%d)" % [name, _bubble_bumps_left])
		else:
			parts.append("%s: %.0fs" % [name, seconds_left(id)])
	return parts
