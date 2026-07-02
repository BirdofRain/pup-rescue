extends Control

const ProgressionRegistryScript := preload("res://scripts/progression/progression_registry.gd")
const IslandCatalogScript := preload("res://scripts/island_catalog.gd")
const CompanionSlotCardScript := preload("res://scripts/companion_slot_card.gd")
const CompanionProfilePanelScript := preload("res://scripts/companion_profile_panel.gd")
const CompanionWardrobePanelScript := preload("res://scripts/companion_wardrobe_panel.gd")

const TEXT := Color(0.16, 0.22, 0.32)
const MUTED := Color(0.34, 0.40, 0.50)

const THEME_PALETTE := {
	"beach": Color(0.92, 0.72, 0.28),
	"candy": Color(0.92, 0.38, 0.62),
	"default": Color(0.22, 0.48, 0.82),
}

@onready var background: ColorRect = $Background
@onready var title_label: Label = $RootMargin/RootVBox/Header/TitleLabel
@onready var subtitle_label: Label = $RootMargin/RootVBox/Header/SubtitleLabel
@onready var slots_scroll: ScrollContainer = $RootMargin/RootVBox/SlotsScroll
@onready var slots_grid: GridContainer = $RootMargin/RootVBox/SlotsScroll/SlotsGrid
@onready var profile_backdrop: ColorRect = $ProfileBackdrop
@onready var profile_host: CenterContainer = $ProfileHost
@onready var wardrobe_backdrop: ColorRect = $WardrobeBackdrop
@onready var wardrobe_host: CenterContainer = $WardrobeHost

var _save: GameSave
var _profile_panel: CompanionProfilePanel
var _wardrobe_panel: CompanionWardrobePanel


func _ready() -> void:
	_save = get_node("/root/SaveGame") as GameSave
	if _save.has_save():
		_save.load_save()
	ProgressionRegistryScript.ensure_loaded()
	_build_panels()
	_style_nav_buttons()
	_apply_slot_columns()
	_refresh()
	var focus_id: String = _save.consume_clubhouse_focus()
	if focus_id != "" and _save.owns_companion(focus_id):
		call_deferred("_open_profile", focus_id)


func _build_panels() -> void:
	_profile_panel = CompanionProfilePanelScript.new()
	_profile_panel.name = "ProfilePanel"
	_profile_panel.setup(_save)
	_profile_panel.closed.connect(_hide_profile)
	_profile_panel.wardrobe_requested.connect(_open_wardrobe)
	_profile_panel.selection_changed.connect(_on_selection_changed)
	profile_host.add_child(_profile_panel)
	profile_backdrop.gui_input.connect(_on_profile_backdrop_gui_input)

	_wardrobe_panel = CompanionWardrobePanelScript.new()
	_wardrobe_panel.name = "WardrobePanel"
	_wardrobe_panel.setup(_save)
	_wardrobe_panel.closed.connect(_hide_wardrobe)
	_wardrobe_panel.loadout_changed.connect(_on_wardrobe_loadout_changed)
	wardrobe_host.add_child(_wardrobe_panel)


func _refresh() -> void:
	for child in slots_grid.get_children():
		child.queue_free()
	var entries: Array[Dictionary] = _companion_slot_entries()
	for entry: Dictionary in entries:
		var card: CompanionSlotCard = CompanionSlotCardScript.new()
		var companion: CompanionDefinition = entry["companion"]
		card.configure(
			companion,
			bool(entry["unlocked"]),
			_save.selected_companion_id == companion.companion_id,
			entry["theme"] as Color,
			str(entry["display_name"]),
			str(entry["status"])
		)
		card.card_pressed.connect(_open_profile)
		slots_grid.add_child(card)
	if subtitle_label:
		var unlocked_count := 0
		for entry: Dictionary in entries:
			if bool(entry["unlocked"]):
				unlocked_count += 1
		subtitle_label.text = "%d of %d companions unlocked — tap a friend to visit their profile!" % [
			unlocked_count, entries.size()
		]


func _companion_slot_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for island: IslandDefinition in ProgressionRegistryScript.all_islands():
		var companion: CompanionDefinition = ProgressionRegistryScript.get_special_companion(island.island_id)
		if companion == null or seen.has(companion.companion_id):
			continue
		seen[companion.companion_id] = true
		var theme: Color = THEME_PALETTE.get(island.theme_id, THEME_PALETTE["default"])
		var unlocked: bool = _save.owns_companion(companion.companion_id)
		var display_name: String = (
			_save.get_companion_display_name(companion.companion_id)
			if unlocked else companion.default_name
		)
		out.append({
			"companion": companion,
			"unlocked": unlocked,
			"theme": theme,
			"display_name": display_name,
			"status": _slot_status_text(island.island_id, unlocked),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str((a["companion"] as CompanionDefinition).companion_id) < str(
			(b["companion"] as CompanionDefinition).companion_id
		)
	)
	return out


func _slot_status_text(island_id: String, unlocked: bool) -> String:
	var island: IslandDefinition = ProgressionRegistryScript.get_island(island_id)
	var island_name: String = island.display_name if island != null else island_id
	if unlocked:
		return island_name
	if _save.is_island_companion_unlocked(island_id):
		return "Unlocked on %s" % island_name
	if _save.is_special_pup_found(island_id):
		var badges: int = _save.escort_badge_count(island_id)
		var total: int = IslandCatalogScript.level_count(island_id)
		return "%s — badges %d/%d" % [island_name, badges, total]
	return "Adventure on %s" % island_name


func _open_profile(companion_id: String) -> void:
	if not _save.owns_companion(companion_id):
		return
	profile_backdrop.visible = true
	_profile_panel.show_profile(companion_id)
	SfxManager.play_coin()


func _hide_profile() -> void:
	profile_backdrop.visible = false
	if _profile_panel:
		_profile_panel.hide_panel()
	_refresh()


func _on_profile_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _wardrobe_panel == null or not _wardrobe_panel.visible:
			_hide_profile()


func _open_wardrobe(companion_id: String) -> void:
	wardrobe_backdrop.visible = true
	_wardrobe_panel.show_for_companion(companion_id)


func _hide_wardrobe() -> void:
	wardrobe_backdrop.visible = false
	if _wardrobe_panel:
		_wardrobe_panel.hide_panel()
	if _profile_panel and _profile_panel.visible:
		_profile_panel.refresh_from_wardrobe()


func _on_wardrobe_loadout_changed(_companion_id: String) -> void:
	if _profile_panel and _profile_panel.visible:
		_profile_panel.refresh_from_wardrobe()


func _on_selection_changed(_companion_id: String) -> void:
	_refresh()


func _style_nav_buttons() -> void:
	var nav_row: HBoxContainer = get_node_or_null("RootMargin/RootVBox/NavRow") as HBoxContainer
	if nav_row == null:
		return
	for child in nav_row.get_children():
		if child is Button:
			_style_button(child as Button, Color(0.22, 0.48, 0.82))
	var here_btn: Button = nav_row.get_node_or_null("HereBtn") as Button
	if here_btn:
		_style_button(here_btn, Color(0.18, 0.58, 0.38))
		here_btn.disabled = true


func _style_button(btn: Button, bg: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("disabled", style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.92, 0.94, 0.98))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_apply_slot_columns()


func _apply_slot_columns() -> void:
	if slots_grid == null:
		return
	var width: float = get_viewport_rect().size.x
	slots_grid.columns = clampi(int(width / 170.0), 2, 4)


func _on_island_map_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/WorldMap.tscn")


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")
