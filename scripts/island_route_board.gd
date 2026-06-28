extends Control
class_name IslandRouteBoard

const IslandRouteNodeScript := preload("res://scripts/island_route_node.gd")

signal level_node_selected(local_level: int)

var _nodes: Array[IslandRouteNode] = []
var _line_color: Color = Color(0.72, 0.78, 0.88, 0.95)
var _line_width: float = 5.0
var _positions: PackedVector2Array = PackedVector2Array()


func clear_board() -> void:
	for node: IslandRouteNode in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	_nodes.clear()
	_positions = PackedVector2Array()
	queue_redraw()


func build_route(
	level_states: Array,
	discovery_index: int,
	discovery_found: bool,
	level_titles: PackedStringArray
) -> void:
	clear_board()
	for i in range(level_states.size()):
		var node: IslandRouteNode = IslandRouteNodeScript.new()
		node.name = "RouteNode_%d" % i
		var state: IslandRouteNode.State = level_states[i]
		var title: String = level_titles[i] if i < level_titles.size() else "Level %d" % (i + 1)
		node.configure(
			i,
			state,
			i == discovery_index,
			i == discovery_index and not discovery_found,
			i == discovery_index and discovery_found,
			title
		)
		node.node_selected.connect(_on_node_selected)
		add_child(node)
		_nodes.append(node)
	call_deferred("_relayout")


func get_node_at(local_level: int) -> IslandRouteNode:
	if local_level < 0 or local_level >= _nodes.size():
		return null
	return _nodes[local_level]


func pulse_badge_at(local_level: int) -> void:
	var node: IslandRouteNode = get_node_at(local_level)
	if node == null:
		return
	var badge: Label = node.get_node_or_null("BadgeLabel") as Label
	if badge == null:
		return
	var tween := create_tween()
	tween.set_loops(3)
	tween.tween_property(badge, "scale", Vector2(1.35, 1.35), 0.18)
	tween.tween_property(badge, "scale", Vector2.ONE, 0.18)


func _on_node_selected(local_level: int) -> void:
	level_node_selected.emit(local_level)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_relayout")


func _relayout() -> void:
	if _nodes.is_empty():
		return
	var rect := get_rect()
	var w: float = maxf(rect.size.x, 1.0)
	var h: float = maxf(rect.size.y, 1.0)
	var landscape: bool = w > h * 1.05
	_positions = _route_positions(w, h, _nodes.size(), landscape)
	for i in range(_nodes.size()):
		var node: IslandRouteNode = _nodes[i]
		var center: Vector2 = _positions[i]
		var board_size: Vector2 = node.custom_minimum_size
		node.position = center - board_size * 0.5
	queue_redraw()


func _route_positions(w: float, h: float, count: int, landscape: bool) -> PackedVector2Array:
	var out: PackedVector2Array = []
	var margin := 48.0
	if landscape:
		for i in range(count):
			var t: float = float(i) / float(maxi(1, count - 1))
			var x: float = margin + t * (w - margin * 2.0)
			var wave: float = sin(t * PI) * (h * 0.12)
			var y: float = h * 0.5 + wave
			out.append(Vector2(x, y))
	else:
		var slots: Array[Vector2] = [
			Vector2(0.22, 0.14),
			Vector2(0.78, 0.14),
			Vector2(0.78, 0.42),
			Vector2(0.22, 0.42),
			Vector2(0.50, 0.78),
		]
		for i in range(count):
			var slot: Vector2 = slots[i] if i < slots.size() else Vector2(0.5, 0.5)
			out.append(Vector2(slot.x * w, slot.y * h))
	return out


func _draw() -> void:
	if _positions.size() < 2:
		return
	for i in range(_positions.size() - 1):
		draw_line(_positions[i], _positions[i + 1], _line_color, _line_width)
		draw_circle(_positions[i], _line_width * 0.55, _line_color)
	draw_circle(_positions[_positions.size() - 1], _line_width * 0.55, _line_color)
