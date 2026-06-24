extends Control

const IslandCatalogScript := preload("res://scripts/island_catalog.gd")
const IslandProgressScript := preload("res://scripts/island_progress.gd")

const MENU_TEXT := Color(0.16, 0.22, 0.32)
const MENU_MUTED := Color(0.34, 0.40, 0.50)

@onready var title_label: Label = $RootMargin/RootVBox/Scroll/Panel/VBox/TitleLabel
@onready var progress_label: Label = $RootMargin/RootVBox/Scroll/Panel/VBox/ProgressLabel
@onready var levels_grid: GridContainer = $RootMargin/RootVBox/Scroll/Panel/VBox/LevelsGrid

var _save: GameSave
var _island_id: String = ""


func _ready() -> void:
	_save = get_node("/root/SaveGame") as GameSave
	if _save.has_save():
		_save.load_save()
	_island_id = _save.current_island_id
	if _island_id == "":
		_island_id = IslandCatalogScript.first_island_id()
	_style_panel()
	_style_back_button()
	_refresh()


func _style_panel() -> void:
	var panel := get_node_or_null("RootMargin/RootVBox/Scroll/Panel") as PanelContainer
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.98, 1.0, 0.98)
	style.border_color = Color(0.55, 0.68, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)


func _style_back_button() -> void:
	var btn: Button = get_node_or_null("RootMargin/RootVBox/BackBtn") as Button
	if btn == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.48, 0.82)
	style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color.WHITE)


func _refresh() -> void:
	var island: Dictionary = IslandCatalogScript.get_island(_island_id)
	var progress: Dictionary = _save.get_island_progress(_island_id)
	var pup: Dictionary = IslandCatalogScript.get_special_pup(_island_id)
	var level_count: int = IslandCatalogScript.level_count(_island_id)
	var pup_name: String = str(pup.get("name", "Special pup"))
	var badges: int = _save.escort_badge_count(_island_id)
	var required: int = IslandCatalogScript.badges_required(_island_id)
	var found: bool = _save.is_special_pup_found(_island_id)
	var hidden_idx: int = IslandCatalogScript.hidden_level_index(_island_id)

	if title_label:
		title_label.text = str(island.get("name", _island_id))
	if progress_label:
		if found:
			progress_label.text = "%s is your escort  |  Badges %d/%d" % [pup_name, badges, required]
		else:
			progress_label.text = "Find %s on level %d  |  Badges %d/%d" % [
				pup_name, hidden_idx + 1, badges, required,
			]
		progress_label.add_theme_color_override("font_color", MENU_MUTED)

	for c in levels_grid.get_children():
		c.queue_free()

	for local_level in range(level_count):
		levels_grid.add_child(_make_level_button(local_level, progress, hidden_idx))


func _make_level_button(local_level: int, progress: Dictionary, hidden_idx: int) -> Button:
	var completed: bool = IslandProgressScript.is_level_completed(progress, local_level, _island_id)
	var has_badge: bool = IslandProgressScript.has_badge(progress, local_level, _island_id)
	var playable: bool = completed or local_level <= _save.current_local_level

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 72)
	btn.focus_mode = Control.FOCUS_NONE
	var lines: PackedStringArray = PackedStringArray(["Level %d" % (local_level + 1)])
	if local_level == hidden_idx and not _save.is_special_pup_found(_island_id):
		lines.append("★ Hidden pup")
	if has_badge:
		lines.append("Badge ✓")
	elif completed:
		lines.append("Done")
	btn.text = "\n".join(lines)

	if not playable:
		btn.disabled = true
		btn.tooltip_text = "Complete earlier levels first"
	elif completed:
		btn.tooltip_text = "Replay this level"
		btn.pressed.connect(_start_level.bind(local_level, true))
	else:
		btn.pressed.connect(_start_level.bind(local_level, false))

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	if has_badge:
		style.bg_color = Color(0.88, 0.96, 0.90)
		style.border_color = Color(0.18, 0.58, 0.38)
	elif completed:
		style.bg_color = Color(0.92, 0.95, 1.0)
		style.border_color = Color(0.55, 0.68, 0.82)
	else:
		style.bg_color = Color(1.0, 1.0, 1.0)
		style.border_color = Color(0.62, 0.70, 0.82)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", MENU_TEXT)
	return btn


func _start_level(local_level: int, replay: bool) -> void:
	_save.set_play_target(_island_id, local_level, replay)
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/IslandMap.tscn")
