class_name UiCoinBadge
extends Control

const COIN_GOLD := Color(1.0, 0.82, 0.18)
const COIN_RING := Color(0.72, 0.52, 0.06)
const COST_TEXT := Color(0.35, 0.22, 0.04)


func setup(cost: int) -> void:
	custom_minimum_size = Vector2(64, 52)
	tooltip_text = "%d Treat Coins" % cost
	set_meta("cost", cost)
	queue_redraw()


func _draw() -> void:
	var cost: int = int(get_meta("cost", 0))
	var cy: float = size.y * 0.5
	var coin_x: float = 18.0

	var pill := Rect2(34, cy - 16, size.x - 38, 32)
	draw_rect(pill, Color(1.0, 0.96, 0.82), true)
	draw_rect(pill, COIN_RING, false, 2.0)

	draw_circle(Vector2(coin_x, cy), 14, COIN_GOLD)
	draw_arc(Vector2(coin_x, cy), 14, 0.0, TAU, 24, COIN_RING, 2.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(coin_x - 5, cy + 5),
		"C",
		HORIZONTAL_ALIGNMENT_LEFT,
		16,
		13,
		COST_TEXT
	)

	var cost_str := str(cost)
	var font_size: int = 22 if cost < 100 else 18
	var text_w: float = ThemeDB.fallback_font.get_string_size(cost_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_x: float = pill.position.x + (pill.size.x - text_w) * 0.5
	draw_string(
		ThemeDB.fallback_font,
		Vector2(text_x, cy + font_size * 0.35),
		cost_str,
		HORIZONTAL_ALIGNMENT_LEFT,
		int(pill.size.x),
		font_size,
		COST_TEXT
	)
