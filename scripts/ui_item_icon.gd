class_name UiItemIcon
extends Control

const ICON_SIZE := Vector2(52, 52)


func setup_accessory(entry: Dictionary) -> void:
	custom_minimum_size = ICON_SIZE
	tooltip_text = str(entry.get("name", ""))
	set_meta("accessory_entry", entry)
	set_meta("upgrade_entry", null)
	queue_redraw()


func setup_upgrade(entry: Dictionary) -> void:
	custom_minimum_size = ICON_SIZE
	tooltip_text = str(entry.get("name", ""))
	set_meta("upgrade_entry", entry)
	set_meta("accessory_entry", null)
	queue_redraw()


func setup_clear_slot(slot: String) -> void:
	custom_minimum_size = ICON_SIZE
	tooltip_text = "Clear %s" % slot
	set_meta("clear_slot", slot)
	set_meta("accessory_entry", null)
	set_meta("upgrade_entry", null)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.94, 0.96, 0.99), true)
	draw_rect(rect, Color(0.72, 0.78, 0.88), false, 2.0)
	var pad: float = 6.0
	var inner := rect.grow(-pad)
	if has_meta("clear_slot"):
		_draw_none_icon(inner)
		return
	var acc: Variant = get_meta("accessory_entry", null)
	if acc is Dictionary and not (acc as Dictionary).is_empty():
		_draw_accessory_icon(inner, acc as Dictionary)
		return
	var upg: Variant = get_meta("upgrade_entry", null)
	if upg is Dictionary and not (upg as Dictionary).is_empty():
		_draw_upgrade_icon(inner, upg as Dictionary)


func _draw_none_icon(r: Rect2) -> void:
	var c: Color = Color(0.55, 0.58, 0.65)
	var cx: float = r.get_center().x
	var cy: float = r.get_center().y
	var rad: float = minf(r.size.x, r.size.y) * 0.22
	draw_arc(Vector2(cx, cy), rad, 0.0, TAU, 24, c, 2.5)
	draw_line(Vector2(cx - rad * 0.7, cy - rad * 0.7), Vector2(cx + rad * 0.7, cy + rad * 0.7), c, 2.5)


func _draw_accessory_icon(r: Rect2, entry: Dictionary) -> void:
	var shape: String = str(entry.get("shape", "bow"))
	var col: Color = Color.from_string(str(entry.get("color", "#888888")), Color.GRAY)
	var cx: float = r.get_center().x
	var cy: float = r.get_center().y
	match shape:
		"bow":
			draw_circle(Vector2(cx - r.size.x * 0.14, cy), r.size.y * 0.16, col)
			draw_circle(Vector2(cx + r.size.x * 0.14, cy), r.size.y * 0.16, col)
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(cx - r.size.x * 0.08, cy),
					Vector2(cx, cy - r.size.y * 0.1),
					Vector2(cx + r.size.x * 0.08, cy),
					Vector2(cx, cy + r.size.y * 0.1),
				]),
				col.darkened(0.12)
			)
		"cap":
			draw_rect(Rect2(cx - r.size.x * 0.28, cy - r.size.y * 0.08, r.size.x * 0.56, r.size.y * 0.22), col)
			draw_circle(Vector2(cx, cy - r.size.y * 0.02), r.size.x * 0.26, col)
		"bandana":
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(cx - r.size.x * 0.3, cy - r.size.y * 0.05),
					Vector2(cx + r.size.x * 0.3, cy - r.size.y * 0.05),
					Vector2(cx + r.size.x * 0.22, cy + r.size.y * 0.18),
					Vector2(cx - r.size.x * 0.22, cy + r.size.y * 0.18),
				]),
				col
			)
		"star_pin":
			_draw_star(Vector2(cx, cy), r.size.x * 0.22, col)
		"goggles":
			draw_circle(Vector2(cx - r.size.x * 0.14, cy), r.size.y * 0.14, col)
			draw_circle(Vector2(cx + r.size.x * 0.14, cy), r.size.y * 0.14, col)
			draw_line(
				Vector2(cx - r.size.x * 0.14, cy),
				Vector2(cx + r.size.x * 0.14, cy),
				col.darkened(0.2),
				3.0
			)
		"backpack_box":
			draw_rect(Rect2(cx - r.size.x * 0.2, cy - r.size.y * 0.22, r.size.x * 0.4, r.size.y * 0.44), col)
			draw_rect(Rect2(cx - r.size.x * 0.12, cy - r.size.y * 0.32, r.size.x * 0.24, r.size.y * 0.12), col.lightened(0.15))
		_:
			draw_circle(Vector2(cx, cy), r.size.x * 0.18, col)


func _draw_star(center: Vector2, radius: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 5:
		var outer_angle: float = -PI * 0.5 + float(i) * TAU / 5.0
		var inner_angle: float = outer_angle + TAU / 10.0
		pts.append(center + Vector2(cos(outer_angle), sin(outer_angle)) * radius)
		pts.append(center + Vector2(cos(inner_angle), sin(inner_angle)) * radius * 0.45)
	draw_colored_polygon(pts, col)


func _draw_upgrade_icon(r: Rect2, entry: Dictionary) -> void:
	var effect: String = str(entry.get("effect", ""))
	var id: String = str(entry.get("id", ""))
	match effect:
		"speed_mult":
			_draw_speed_icon(r, Color(0.95, 0.45, 0.12))
		"max_followers":
			_draw_squad_icon(r, Color(0.55, 0.38, 0.95))
		"speed_boost_duration":
			_draw_fruit_icon(r, Color(0.95, 0.35, 0.15))
		"coin_per_rescue":
			_draw_coin_icon(r, Color(0.95, 0.82, 0.2))
		"rainbow_trail":
			_draw_rainbow_icon(r)
		"exit_roundup":
			_draw_roundup_icon(r, Color(0.35, 0.65, 0.95))
		_:
			draw_string(
				ThemeDB.fallback_font,
				r.position + Vector2(8, r.size.y * 0.65),
				id.substr(0, 1).to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT,
				int(r.size.x),
				16,
				Color(0.3, 0.35, 0.45)
			)


func _draw_speed_icon(r: Rect2, col: Color) -> void:
	var cx: float = r.get_center().x
	var cy: float = r.get_center().y
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(cx, cy - r.size.y * 0.28),
			Vector2(cx + r.size.x * 0.22, cy + r.size.y * 0.2),
			Vector2(cx - r.size.x * 0.22, cy + r.size.y * 0.2),
		]),
		col
	)


func _draw_squad_icon(r: Rect2, col: Color) -> void:
	var cy: float = r.get_center().y + r.size.y * 0.06
	var offsets: Array = [-0.2, 0.0, 0.2]
	for ox in offsets:
		var px: float = r.get_center().x + r.size.x * float(ox)
		draw_circle(Vector2(px, cy), r.size.y * 0.11, col)
		draw_circle(Vector2(px, cy - r.size.y * 0.08), r.size.y * 0.07, col.lightened(0.25))


func _draw_fruit_icon(r: Rect2, col: Color) -> void:
	var cx: float = r.get_center().x
	var cy: float = r.get_center().y
	draw_circle(Vector2(cx, cy + r.size.y * 0.04), r.size.x * 0.2, col)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(cx - r.size.x * 0.04, cy - r.size.y * 0.18),
			Vector2(cx + r.size.x * 0.04, cy - r.size.y * 0.18),
			Vector2(cx, cy - r.size.y * 0.28),
		]),
		Color(0.35, 0.65, 0.28)
	)


func _draw_coin_icon(r: Rect2, col: Color) -> void:
	var cx: float = r.get_center().x
	var cy: float = r.get_center().y
	draw_circle(Vector2(cx, cy), r.size.x * 0.22, col)
	draw_arc(Vector2(cx, cy), r.size.x * 0.22, 0.0, TAU, 24, col.darkened(0.25), 2.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(cx - 5, cy + 6),
		"C",
		HORIZONTAL_ALIGNMENT_LEFT,
		20,
		14,
		col.darkened(0.35)
	)


func _draw_rainbow_icon(r: Rect2) -> void:
	var colors: Array = [
		Color(1.0, 0.35, 0.35),
		Color(1.0, 0.75, 0.2),
		Color(0.45, 0.85, 0.4),
		Color(0.35, 0.6, 1.0),
		Color(0.75, 0.45, 0.95),
	]
	var bar_h: float = r.size.y / float(colors.size())
	for i in colors.size():
		draw_rect(Rect2(r.position.x + 4, r.position.y + i * bar_h, r.size.x - 8, bar_h - 1), colors[i])


func _draw_roundup_icon(r: Rect2, col: Color) -> void:
	var cx: float = r.get_center().x
	var cy: float = r.get_center().y
	draw_circle(Vector2(cx, cy), r.size.x * 0.1, col)
	for i in 4:
		var ang: float = float(i) * TAU / 4.0 + PI * 0.25
		var p: Vector2 = Vector2(cx, cy) + Vector2(cos(ang), sin(ang)) * r.size.x * 0.24
		draw_circle(p, r.size.y * 0.08, col.lightened(0.2))
		draw_line(p, Vector2(cx, cy), col, 1.5)
