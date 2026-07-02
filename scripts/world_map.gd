extends Control

const ProgressionRegistryScript := preload("res://scripts/progression/progression_registry.gd")
const WORLD_MAP_TEXTURE_PATH := "res://assets/maps/world/world_map.png"

const TEXT := Color(0.16, 0.22, 0.32)
const MUTED := Color(0.34, 0.40, 0.50)

const THEME_ACCENT := {
	"beach": Color(0.92, 0.72, 0.28),
	"candy": Color(0.92, 0.38, 0.62),
	"default": Color(0.22, 0.48, 0.82),
}

@onready var background: ColorRect = $Background
@onready var world_map_art: TextureRect = $RootMargin/RootVBox/MapHost/WorldMapArt
@onready var map_fallback: ColorRect = $RootMargin/RootVBox/MapHost/MapFallback
@onready var islands_layer: Control = $RootMargin/RootVBox/MapHost/IslandsLayer
@onready var locked_banner: Label = $RootMargin/RootVBox/MapHost/LockedBanner
@onready var subtitle_label: Label = $RootMargin/RootVBox/SubtitleLabel

var _save: GameSave
var _island_ids: Array[String] = []
var _lock_banner_timer: float = 0.0
var _relayout_pending: bool = false


func _ready() -> void:
	_save = get_node("/root/SaveGame") as GameSave
	if _save.has_save():
		_save.load_save()
	ProgressionRegistryScript.ensure_loaded()
	_load_island_list()
	_apply_world_map_art()
	_style_footer()
	_refresh()
	if not islands_layer.resized.is_connected(_relayout_island_markers):
		islands_layer.resized.connect(_relayout_island_markers)


func _process(delta: float) -> void:
	if _lock_banner_timer <= 0.0:
		return
	_lock_banner_timer = maxf(0.0, _lock_banner_timer - delta)
	if _lock_banner_timer <= 0.0 and locked_banner != null:
		locked_banner.visible = false


func _load_island_list() -> void:
	_island_ids.clear()
	for island: IslandDefinition in ProgressionRegistryScript.all_islands():
		_island_ids.append(island.island_id)


func _apply_world_map_art() -> void:
	var tex: Texture2D = _load_map_texture(WORLD_MAP_TEXTURE_PATH)
	var has_art: bool = tex != null and world_map_art != null
	if world_map_art != null:
		if has_art:
			world_map_art.texture = tex
			world_map_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			world_map_art.visible = true
		else:
			world_map_art.visible = false
			world_map_art.texture = null
	if map_fallback != null:
		map_fallback.visible = not has_art
	if background:
		background.color = Color(0.36, 0.52, 0.72, 1.0) if has_art else Color(0.42, 0.62, 0.88, 1.0)


func _load_map_texture(path: String) -> Texture2D:
	var clean: String = path.strip_edges()
	if clean == "":
		return null
	if ResourceLoader.exists(clean):
		var imported: Texture2D = load(clean) as Texture2D
		if imported != null:
			return imported
	var absolute: String = ProjectSettings.globalize_path(clean)
	if FileAccess.file_exists(absolute):
		var img: Image = Image.load_from_file(absolute)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


func _refresh() -> void:
	_clear_island_markers()
	for i in range(_island_ids.size()):
		var island_id: String = _island_ids[i]
		var island: IslandDefinition = ProgressionRegistryScript.get_island(island_id)
		if island == null:
			continue
		islands_layer.add_child(_make_island_marker(island))
	call_deferred("_relayout_island_markers")
	if subtitle_label:
		subtitle_label.text = "Tap an island — %d available on the map" % _island_ids.size()


func _clear_island_markers() -> void:
	for child in islands_layer.get_children():
		child.queue_free()


func _make_island_marker(island: IslandDefinition) -> Button:
	var unlocked: bool = _save.is_island_unlocked(island.island_id)
	var marker := Button.new()
	marker.name = "IslandMarker_%s" % island.island_id
	marker.focus_mode = Control.FOCUS_NONE
	marker.custom_minimum_size = Vector2(112, 72)
	marker.toggle_mode = false
	var marker_icon: String = _save.get_island_map_marker(island.island_id)
	marker.text = "%s\n%s" % [marker_icon, island.display_name]
	marker.tooltip_text = island.display_name if unlocked else _locked_island_message(island)
	marker.pressed.connect(func() -> void: _on_island_marker_pressed(island.island_id))
	_style_island_marker(marker, island.theme_id, unlocked)
	marker.set_meta("island_id", island.island_id)
	return marker


func _style_island_marker(btn: Button, theme_id: String, unlocked: bool) -> void:
	var accent: Color = THEME_ACCENT.get(theme_id, THEME_ACCENT["default"])
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(14)
	style.set_border_width_all(3)
	if unlocked:
		style.bg_color = Color(0.98, 0.99, 1.0, 0.94)
		style.border_color = accent
		btn.add_theme_color_override("font_color", TEXT)
	else:
		style.bg_color = Color(0.78, 0.80, 0.84, 0.88)
		style.border_color = Color(0.58, 0.62, 0.68)
		btn.add_theme_color_override("font_color", MUTED)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_font_size_override("font_size", 13)


func _relayout_island_markers() -> void:
	if _relayout_pending or islands_layer == null:
		return
	_relayout_pending = true
	var rect := islands_layer.get_rect()
	var w: float = maxf(rect.size.x, 1.0)
	var h: float = maxf(rect.size.y, 1.0)
	var auto_slots: PackedVector2Array = _auto_world_slots(_island_ids.size())
	for i in range(islands_layer.get_child_count()):
		var marker: Control = islands_layer.get_child(i) as Control
		if marker == null:
			continue
		var island_id: String = str(marker.get_meta("island_id", ""))
		var slot: Vector2 = _world_slot_for_island(island_id, i, auto_slots)
		var marker_size: Vector2 = marker.custom_minimum_size
		marker.position = Vector2(slot.x * w, slot.y * h) - marker_size * 0.5
	_relayout_pending = false


func _world_slot_for_island(island_id: String, index: int, auto_slots: PackedVector2Array) -> Vector2:
	var island: IslandDefinition = ProgressionRegistryScript.get_island(island_id)
	if island != null and island.world_map_slot.x >= 0.0 and island.world_map_slot.y >= 0.0:
		return island.world_map_slot
	if index >= 0 and index < auto_slots.size():
		return auto_slots[index]
	return Vector2(0.5, 0.5)


func _auto_world_slots(count: int) -> PackedVector2Array:
	var out: PackedVector2Array = []
	if count <= 0:
		return out
	if count == 1:
		out.append(Vector2(0.5, 0.5))
		return out
	if count == 2:
		out.append(Vector2(0.34, 0.58))
		out.append(Vector2(0.66, 0.42))
		return out
	for i in range(count):
		var t: float = float(i) / float(count)
		var angle: float = PI * 0.85 + t * PI * 0.5
		out.append(Vector2(0.5 + cos(angle) * 0.28, 0.52 + sin(angle) * 0.24))
	return out


func _on_island_marker_pressed(island_id: String) -> void:
	var island: IslandDefinition = ProgressionRegistryScript.get_island(island_id)
	if island == null:
		return
	if not _save.is_island_unlocked(island_id):
		_show_locked_message(island)
		return
	_save.current_island_id = island_id
	_save.save_game()
	get_tree().change_scene_to_file("res://scenes/IslandMap.tscn")


func _show_locked_message(island: IslandDefinition) -> void:
	if locked_banner == null:
		return
	locked_banner.text = _locked_island_message(island)
	locked_banner.visible = true
	_lock_banner_timer = 3.5


func _locked_island_message(island: IslandDefinition) -> String:
	if island != null and island.unlock_requirement != null:
		var req_island_id: String = island.unlock_requirement.required_island_id
		if req_island_id != "":
			var prev_island: IslandDefinition = ProgressionRegistryScript.get_island(req_island_id)
			if prev_island != null:
				return "Complete all %s levels to unlock!" % prev_island.display_name
	return "Island locked — keep exploring!"


func _style_footer() -> void:
	var back_btn: Button = get_node_or_null("RootMargin/RootVBox/FooterRow/BackBtn") as Button
	if back_btn == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.48, 0.82)
	style.set_corner_radius_all(10)
	back_btn.add_theme_stylebox_override("normal", style)
	back_btn.add_theme_color_override("font_color", Color.WHITE)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")
