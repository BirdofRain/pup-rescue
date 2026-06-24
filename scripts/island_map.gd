extends Control

const IslandCatalogScript := preload("res://scripts/island_catalog.gd")
const IslandProgressScript := preload("res://scripts/island_progress.gd")
const ProgressionRegistryScript := preload("res://scripts/progression/progression_registry.gd")
const IslandRouteBoardScript := preload("res://scripts/island_route_board.gd")
const IslandLevelPanelScript := preload("res://scripts/island_level_panel.gd")
const PupColorsScript := preload("res://scripts/pup_colors.gd")
const IslandRouteNodeScript := preload("res://scripts/island_route_node.gd")
const CompanionUnlockPanelScript := preload("res://scripts/companion_unlock_panel.gd")
const SpecialPupFoundPanelScript := preload("res://scripts/special_pup_found_panel.gd")
const EscortBadgeCelebrationPanelScript := preload("res://scripts/escort_badge_celebration_panel.gd")
const AccessoryRevealPanelScript := preload("res://scripts/accessory_reveal_panel.gd")
const ReplayConfirmPanelScript := preload("res://scripts/replay_confirm_panel.gd")

const TEXT := Color(0.16, 0.22, 0.32)
const MUTED := Color(0.34, 0.40, 0.50)

const THEME_PALETTE := {
	"beach": {
		"sky": Color(0.55, 0.78, 0.92),
		"sand": Color(0.96, 0.88, 0.72),
		"accent": Color(0.92, 0.72, 0.28),
	},
	"default": {
		"sky": Color(0.55, 0.72, 0.95),
		"sand": Color(0.94, 0.94, 0.98),
		"accent": Color(0.22, 0.48, 0.82),
	},
}

@onready var background: ColorRect = $Background
@onready var island_name_label: Label = $RootMargin/RootVBox/HeaderRow/TitleBox/IslandNameLabel
@onready var theme_label: Label = $RootMargin/RootVBox/HeaderRow/TitleBox/ThemeLabel
@onready var prev_island_btn: Button = $RootMargin/RootVBox/NavRow/PrevIslandBtn
@onready var next_island_btn: Button = $RootMargin/RootVBox/NavRow/NextIslandBtn
@onready var island_index_label: Label = $RootMargin/RootVBox/NavRow/IslandIndexLabel
@onready var main_split: BoxContainer = $RootMargin/RootVBox/MainSplit
@onready var pup_panel: PanelContainer = $RootMargin/RootVBox/MainSplit/PupPanel
@onready var portrait_frame: PanelContainer = $RootMargin/RootVBox/MainSplit/PupPanel/PupVBox/PortraitFrame
@onready var portrait_swatch: ColorRect = $RootMargin/RootVBox/MainSplit/PupPanel/PupVBox/PortraitFrame/PortraitCenter/PortraitSwatch
@onready var portrait_mark: Label = $RootMargin/RootVBox/MainSplit/PupPanel/PupVBox/PortraitFrame/PortraitCenter/PortraitMark
@onready var pup_name_label: Label = $RootMargin/RootVBox/MainSplit/PupPanel/PupVBox/PupNameLabel
@onready var pup_status_label: Label = $RootMargin/RootVBox/MainSplit/PupPanel/PupVBox/PupStatusLabel
@onready var route_host: Control = $RootMargin/RootVBox/MainSplit/RouteHost
@onready var locked_banner: Label = $RootMargin/RootVBox/MainSplit/RouteHost/LockedBanner
@onready var panel_backdrop: ColorRect = $PanelBackdrop
@onready var level_panel_host: CenterContainer = $LevelPanelHost

var _save: GameSave
var _route_board: IslandRouteBoard
var _level_panel: IslandLevelPanel
var _companion_celebration_backdrop: ColorRect
var _companion_celebration_panel: CompanionUnlockPanel
var _feedback_backdrop: ColorRect
var _feedback_host: CenterContainer
var _special_pup_panel: SpecialPupFoundPanel
var _badge_panel: EscortBadgeCelebrationPanel
var _accessory_panel: AccessoryRevealPanel
var _replay_panel: ReplayConfirmPanel
var _island_marker_row: HBoxContainer
var _clubhouse_btn: Button
var _feedback_busy: bool = false
var _island_ids: Array[String] = []
var _island_index: int = 0
var _current_island_id: String = ""


func _ready() -> void:
	_save = get_node("/root/SaveGame") as GameSave
	if _save.has_save():
		_save.load_save()
	ProgressionRegistryScript.ensure_loaded()
	_build_dynamic_ui()
	_style_static_controls()
	_setup_footer_nav()
	_load_island_list()
	_current_island_id = _save.current_island_id
	if _current_island_id == "":
		_current_island_id = IslandCatalogScript.first_island_id()
	_island_index = _island_ids.find(_current_island_id)
	if _island_index < 0:
		_island_index = 0
	var return_island: String = _save.get_play_island_id()
	if return_island != "" and _island_ids.has(return_island):
		_current_island_id = return_island
		_island_index = _island_ids.find(return_island)
	_apply_layout_for_viewport()
	_setup_portrait_overlay()
	_save.island_progress_changed.connect(_on_island_progress_changed)
	_refresh()
	call_deferred("_process_map_feedback")


func _process_map_feedback() -> void:
	if _feedback_busy:
		return
	var pending_pup: String = _save.first_pending_special_pup_celebration()
	if pending_pup == _current_island_id:
		_feedback_busy = true
		_show_map_special_pup_celebration(pending_pup)
		return
	if _save.needs_portrait_reveal(_current_island_id):
		_feedback_busy = true
		_play_portrait_reveal(_current_island_id)
		return
	var badge_pending: Dictionary = _save.first_pending_badge_for_island(_current_island_id)
	if int(badge_pending.get("local_level", -1)) >= 0:
		_feedback_busy = true
		_show_badge_celebration(badge_pending)
		return
	var accessory_id: String = _save.first_pending_accessory_reveal()
	if accessory_id != "":
		_feedback_busy = true
		_show_accessory_reveal(accessory_id)
		return
	_maybe_show_companion_celebration()


func _finish_feedback_step() -> void:
	_feedback_busy = false
	if _feedback_backdrop:
		_feedback_backdrop.visible = false
	call_deferred("_process_map_feedback")


func _show_map_special_pup_celebration(island_id: String) -> void:
	var companion: CompanionDefinition = ProgressionRegistryScript.get_special_companion(island_id)
	var pup_name: String = companion.default_name if companion else "Special pup"
	var coat: int = companion.coat_index if companion else 0
	if _feedback_backdrop:
		_feedback_backdrop.visible = true
	_special_pup_panel.show_discovery(pup_name, coat)


func _on_map_special_pup_dismissed() -> void:
	_save.acknowledge_special_pup_celebration(_current_island_id)
	_finish_feedback_step()


func _play_portrait_reveal(island_id: String) -> void:
	var companion: CompanionDefinition = ProgressionRegistryScript.get_special_companion(island_id)
	if companion == null:
		_save.mark_portrait_revealed(island_id)
		_finish_feedback_step()
		return
	portrait_mark.visible = true
	portrait_mark.text = "?"
	portrait_mark.modulate.a = 1.0
	portrait_swatch.color = PupColorsScript.get_color(companion.coat_index)
	portrait_swatch.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(portrait_mark, "modulate:a", 0.0, 0.35)
	tween.parallel().tween_property(portrait_swatch, "modulate:a", 1.0, 0.45)
	tween.tween_callback(func() -> void:
		portrait_mark.visible = false
		_save.mark_portrait_revealed(island_id)
		_finish_feedback_step()
	)


func _show_badge_celebration(badge_pending: Dictionary) -> void:
	var local_level: int = int(badge_pending.get("local_level", -1))
	var island: IslandDefinition = ProgressionRegistryScript.get_island(_current_island_id)
	var level_name: String = _level_display_name(island, local_level)
	var badges: int = _save.escort_badge_count(_current_island_id)
	var required: int = IslandCatalogScript.badges_required(_current_island_id)
	if _feedback_backdrop:
		_feedback_backdrop.visible = true
	_badge_panel.show_badge(level_name, badges, required)
	if _route_board:
		_route_board.pulse_badge_at(local_level)


func _on_badge_celebration_dismissed() -> void:
	var badge_pending: Dictionary = _save.first_pending_badge_for_island(_current_island_id)
	var local_level: int = int(badge_pending.get("local_level", -1))
	if local_level >= 0:
		_save.acknowledge_badge_celebration(_current_island_id, local_level)
	_finish_feedback_step()


func _show_accessory_reveal(accessory_id: String) -> void:
	if _feedback_backdrop:
		_feedback_backdrop.visible = true
	_accessory_panel.show_accessory(accessory_id)


func _on_accessory_reveal_dismissed() -> void:
	var accessory_id: String = _save.first_pending_accessory_reveal()
	if accessory_id != "":
		_save.acknowledge_accessory_reveal(accessory_id)
	_finish_feedback_step()


func _maybe_show_companion_celebration() -> void:
	var companion_id: String = _save.first_unacknowledged_companion_unlock()
	if companion_id == "" or _companion_celebration_panel == null:
		return
	_feedback_busy = true
	_hide_level_panel()
	_companion_celebration_backdrop.visible = true
	_companion_celebration_panel.show_unlock(companion_id, _save)
	_pulse_clubhouse_button()


func _pulse_clubhouse_button() -> void:
	if _clubhouse_btn == null:
		return
	var tween := create_tween()
	tween.set_loops(4)
	tween.tween_property(_clubhouse_btn, "scale", Vector2(1.06, 1.06), 0.2)
	tween.tween_property(_clubhouse_btn, "scale", Vector2.ONE, 0.2)


func _on_companion_celebration_acknowledged(companion_id: String) -> void:
	_save.acknowledge_companion_unlock(companion_id)
	if _companion_celebration_backdrop:
		_companion_celebration_backdrop.visible = false
	if _companion_celebration_panel:
		_companion_celebration_panel.hide_panel()
	_refresh()
	_finish_feedback_step()


func _on_companion_clubhouse_shortcut(companion_id: String) -> void:
	_save.acknowledge_companion_unlock(companion_id)
	if _companion_celebration_backdrop:
		_companion_celebration_backdrop.visible = false
	if _companion_celebration_panel:
		_companion_celebration_panel.hide_panel()
	_save.set_clubhouse_focus(companion_id)
	_on_clubhouse_pressed()


func _on_island_progress_changed(island_id: String) -> void:
	if island_id == "" or island_id == _current_island_id:
		if _save.has_save():
			_save.load_save()
		_refresh()
		call_deferred("_process_map_feedback")


func _setup_portrait_overlay() -> void:
	var center := portrait_frame.get_node_or_null("PortraitCenter")
	if center == null:
		return
	portrait_swatch.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_swatch.offset_left = 8
	portrait_swatch.offset_top = 8
	portrait_swatch.offset_right = -8
	portrait_swatch.offset_bottom = -8
	portrait_mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_mark.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		call_deferred("_apply_layout_for_viewport")


func _build_dynamic_ui() -> void:
	_route_board = IslandRouteBoardScript.new()
	_route_board.name = "RouteBoard"
	_route_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_route_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_route_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_route_board.level_node_selected.connect(_on_level_node_selected)
	route_host.add_child(_route_board)
	route_host.move_child(_route_board, 0)

	_level_panel = IslandLevelPanelScript.new()
	_level_panel.name = "LevelPanel"
	_level_panel.play_pressed.connect(_on_panel_play)
	_level_panel.replay_pressed.connect(_on_panel_replay)
	_level_panel.closed.connect(_hide_level_panel)
	level_panel_host.add_child(_level_panel)

	_companion_celebration_backdrop = ColorRect.new()
	_companion_celebration_backdrop.name = "CompanionCelebrationBackdrop"
	_companion_celebration_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_companion_celebration_backdrop.color = Color(0.05, 0.08, 0.14, 0.55)
	_companion_celebration_backdrop.visible = false
	_companion_celebration_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_companion_celebration_backdrop.z_index = 40
	add_child(_companion_celebration_backdrop)

	var celebration_host := CenterContainer.new()
	celebration_host.name = "CompanionCelebrationHost"
	celebration_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	celebration_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	celebration_host.z_index = 41
	add_child(celebration_host)

	_companion_celebration_panel = CompanionUnlockPanelScript.new()
	_companion_celebration_panel.name = "CompanionCelebrationPanel"
	_companion_celebration_panel.acknowledged.connect(_on_companion_celebration_acknowledged)
	_companion_celebration_panel.clubhouse_requested.connect(_on_companion_clubhouse_shortcut)
	celebration_host.add_child(_companion_celebration_panel)

	_feedback_backdrop = ColorRect.new()
	_feedback_backdrop.name = "FeedbackBackdrop"
	_feedback_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_feedback_backdrop.color = Color(0.05, 0.08, 0.14, 0.55)
	_feedback_backdrop.visible = false
	_feedback_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_feedback_backdrop.z_index = 38
	add_child(_feedback_backdrop)

	_feedback_host = CenterContainer.new()
	_feedback_host.name = "FeedbackHost"
	_feedback_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_feedback_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_host.z_index = 39
	add_child(_feedback_host)

	_special_pup_panel = SpecialPupFoundPanelScript.new()
	_special_pup_panel.name = "SpecialPupPanel"
	_special_pup_panel.dismissed.connect(_on_map_special_pup_dismissed)
	_feedback_host.add_child(_special_pup_panel)

	_badge_panel = EscortBadgeCelebrationPanelScript.new()
	_badge_panel.name = "BadgePanel"
	_badge_panel.dismissed.connect(_on_badge_celebration_dismissed)
	_feedback_host.add_child(_badge_panel)

	_accessory_panel = AccessoryRevealPanelScript.new()
	_accessory_panel.name = "AccessoryPanel"
	_accessory_panel.dismissed.connect(_on_accessory_reveal_dismissed)
	_feedback_host.add_child(_accessory_panel)

	_replay_panel = ReplayConfirmPanelScript.new()
	_replay_panel.name = "ReplayPanel"
	_replay_panel.confirmed.connect(_on_replay_confirmed)
	_replay_panel.cancelled.connect(_on_replay_cancelled)
	_feedback_host.add_child(_replay_panel)

	var nav_row: HBoxContainer = get_node_or_null("RootMargin/RootVBox/NavRow") as HBoxContainer
	if nav_row != null:
		_island_marker_row = HBoxContainer.new()
		_island_marker_row.name = "IslandMarkerRow"
		_island_marker_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_island_marker_row.add_theme_constant_override("separation", 8)
		var root_vbox: VBoxContainer = nav_row.get_parent() as VBoxContainer
		if root_vbox != null:
			root_vbox.add_child(_island_marker_row)
			root_vbox.move_child(_island_marker_row, nav_row.get_index() + 1)

	prev_island_btn.pressed.connect(_on_prev_island)
	next_island_btn.pressed.connect(_on_next_island)
	panel_backdrop.gui_input.connect(_on_backdrop_gui_input)


func _style_static_controls() -> void:
	_style_primary_button(prev_island_btn)
	_style_primary_button(next_island_btn)
	_style_panel(pup_panel)
	var back_btn: Button = get_node_or_null("RootMargin/RootVBox/FooterRow/BackBtn") as Button
	if back_btn:
		_style_primary_button(back_btn, Color(0.22, 0.48, 0.82))


func _setup_footer_nav() -> void:
	var footer: HBoxContainer = get_node_or_null("RootMargin/RootVBox/FooterRow") as HBoxContainer
	if footer == null:
		return
	var back_btn: Button = footer.get_node_or_null("BackBtn") as Button
	if back_btn:
		back_btn.text = "Main Menu"
	if footer.get_node_or_null("IslandMapHereBtn") != null:
		return
	var map_here_btn := Button.new()
	map_here_btn.name = "IslandMapHereBtn"
	map_here_btn.text = "Island Map"
	map_here_btn.disabled = true
	map_here_btn.custom_minimum_size = Vector2(140, 44)
	_style_primary_button(map_here_btn, Color(0.18, 0.58, 0.38))
	footer.add_child(map_here_btn)
	var clubhouse_btn := Button.new()
	clubhouse_btn.name = "ClubhouseBtn"
	clubhouse_btn.text = "Puppy Clubhouse"
	clubhouse_btn.custom_minimum_size = Vector2(150, 44)
	clubhouse_btn.pressed.connect(_on_clubhouse_pressed)
	_style_primary_button(clubhouse_btn, Color(0.92, 0.72, 0.28))
	footer.add_child(clubhouse_btn)
	_clubhouse_btn = clubhouse_btn
	if back_btn:
		footer.move_child(back_btn, footer.get_child_count() - 1)


func _load_island_list() -> void:
	_island_ids.clear()
	for island: IslandDefinition in ProgressionRegistryScript.all_islands():
		_island_ids.append(island.island_id)


func _apply_layout_for_viewport() -> void:
	var vp := get_viewport_rect().size
	var landscape: bool = vp.x > vp.y * 1.05
	if main_split is HBoxContainer and not landscape:
		_swap_main_split(false)
	elif main_split is VBoxContainer and landscape:
		_swap_main_split(true)
	if pup_panel:
		pup_panel.custom_minimum_size = Vector2(220 if landscape else 0, 0 if landscape else 180)


func _swap_main_split(landscape: bool) -> void:
	var parent := main_split.get_parent()
	var idx := main_split.get_index()
	var pup := main_split.get_node("PupPanel")
	var route := main_split.get_node("RouteHost")
	main_split.remove_child(pup)
	main_split.remove_child(route)
	main_split.queue_free()
	var replacement: BoxContainer = HBoxContainer.new() if landscape else VBoxContainer.new()
	replacement.name = "MainSplit"
	replacement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replacement.size_flags_vertical = Control.SIZE_EXPAND_FILL
	replacement.add_theme_constant_override("separation", 12)
	parent.add_child(replacement)
	parent.move_child(replacement, idx)
	replacement.add_child(pup)
	replacement.add_child(route)
	route.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split = replacement
	pup_panel = replacement.get_node("PupPanel")
	route_host = replacement.get_node("RouteHost")
	locked_banner = route_host.get_node("LockedBanner")


func _refresh() -> void:
	if _island_ids.is_empty():
		return
	_current_island_id = _island_ids[_island_index]
	_save.current_island_id = _current_island_id
	var island: IslandDefinition = ProgressionRegistryScript.get_island(_current_island_id)
	var legacy: Dictionary = IslandCatalogScript.get_island(_current_island_id)
	var progress: Dictionary = _save.get_island_progress(_current_island_id)
	var unlocked: bool = _save.is_island_unlocked(_current_island_id)
	var theme_id: String = island.theme_id if island else str(legacy.get("theme", "default"))
	_apply_theme(theme_id)

	island_name_label.text = island.display_name if island else str(legacy.get("name", _current_island_id))
	theme_label.text = theme_id.capitalize()
	island_index_label.text = "Island %d / %d" % [_island_index + 1, _island_ids.size()]
	prev_island_btn.disabled = _island_ids.size() <= 1
	next_island_btn.disabled = _island_ids.size() <= 1

	_refresh_island_markers(theme_id)
	_refresh_pup_card(island, progress, unlocked)
	_refresh_route(island, progress, unlocked)
	_hide_level_panel()


func _apply_theme(theme_id: String) -> void:
	var palette: Dictionary = THEME_PALETTE.get(theme_id, THEME_PALETTE["default"])
	if background:
		background.color = palette["sky"]
	if _route_board:
		_route_board._line_color = palette["accent"].darkened(0.1)
	if portrait_frame:
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = palette["sand"]
		frame_style.set_corner_radius_all(14)
		frame_style.set_border_width_all(2)
		frame_style.border_color = palette["accent"]
		portrait_frame.add_theme_stylebox_override("panel", frame_style)


func _refresh_island_markers(theme_id: String) -> void:
	if _island_marker_row == null:
		return
	for child in _island_marker_row.get_children():
		child.queue_free()
	var palette: Dictionary = THEME_PALETTE.get(theme_id, THEME_PALETTE["default"])
	for i in range(_island_ids.size()):
		var island_id: String = _island_ids[i]
		var marker := Label.new()
		marker.text = "%s %s" % [_save.get_island_map_marker(island_id), _marker_island_name(island_id)]
		marker.add_theme_font_size_override("font_size", 11)
		var color: Color = MUTED
		if island_id == _current_island_id:
			color = palette["accent"]
		elif not _save.is_island_unlocked(island_id):
			color = Color(0.58, 0.62, 0.68)
		marker.add_theme_color_override("font_color", color)
		marker.tooltip_text = _marker_tooltip(island_id)
		_island_marker_row.add_child(marker)


func _marker_island_name(island_id: String) -> String:
	var island: IslandDefinition = ProgressionRegistryScript.get_island(island_id)
	if island != null:
		return island.display_name
	return island_id.capitalize()


func _marker_tooltip(island_id: String) -> String:
	if not _save.is_island_unlocked(island_id):
		return "Island locked"
	if _save.is_island_companion_unlocked(island_id):
		return "Companion unlocked"
	if not _save.is_special_pup_found(island_id):
		return "Special pup not found yet"
	var badges: int = _save.escort_badge_count(island_id)
	var required: int = IslandCatalogScript.badges_required(island_id)
	if badges < required:
		return "Escort badges %d / %d" % [badges, required]
	return "Escort complete"


func _refresh_pup_card(island: IslandDefinition, progress: Dictionary, unlocked: bool) -> void:
	var companion: CompanionDefinition = ProgressionRegistryScript.get_special_companion(_current_island_id)
	var pup_name: String = companion.default_name if companion else "Special pup"
	var found: bool = _save.is_special_pup_found(_current_island_id)
	var badges: int = _save.escort_badge_count(_current_island_id)
	var required: int = IslandCatalogScript.badges_required(_current_island_id)
	var companion_unlocked: bool = bool(progress.get("companion_unlocked", false))

	if not unlocked:
		pup_name_label.text = "???"
		pup_status_label.text = "🔒 Island locked"
		portrait_mark.text = "?"
		portrait_mark.visible = true
		portrait_swatch.color = Color(0.35, 0.38, 0.42)
		portrait_swatch.modulate.a = 1.0
		_set_portrait_border(Color(0.62, 0.66, 0.72))
		return

	if companion_unlocked:
		pup_name_label.text = "⭐ %s" % (
			_save.get_companion_display_name(companion.companion_id) if companion else pup_name
		)
		pup_status_label.text = "Companion unlocked — tap portrait for Clubhouse"
		if pup_panel and not pup_panel.has_meta("clubhouse_wired"):
			pup_panel.set_meta("clubhouse_wired", true)
			pup_panel.gui_input.connect(_on_pup_card_gui_input)
		_set_portrait_border(Color(0.18, 0.58, 0.38))
	elif found:
		pup_name_label.text = "🐾 %s" % pup_name
		pup_status_label.text = "Escort badges: %d / %d" % [badges, required]
		_set_portrait_border(Color(0.92, 0.72, 0.28))
	else:
		pup_name_label.text = "❓ Unknown pup"
		pup_status_label.text = "Find the special pup on the discovery level"
		_set_portrait_border(Color(0.55, 0.58, 0.65))

	if found or companion_unlocked:
		portrait_mark.visible = _save.needs_portrait_reveal(_current_island_id)
		var coat: int = companion.coat_index if companion else 0
		if portrait_mark.visible:
			portrait_mark.text = "?"
			portrait_swatch.color = Color(0.35, 0.38, 0.42)
		else:
			portrait_swatch.color = PupColorsScript.get_color(coat)
			portrait_swatch.modulate.a = 1.0
	else:
		portrait_mark.visible = true
		portrait_mark.text = "?"
		portrait_swatch.color = Color(0.35, 0.38, 0.42)
		portrait_swatch.modulate.a = 1.0


func _set_portrait_border(color: Color) -> void:
	if portrait_frame == null:
		return
	var palette: Dictionary = THEME_PALETTE.get(
		ProgressionRegistryScript.get_island(_current_island_id).theme_id
		if ProgressionRegistryScript.get_island(_current_island_id) != null else "default",
		THEME_PALETTE["default"]
	)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = palette["sand"]
	frame_style.set_corner_radius_all(14)
	frame_style.set_border_width_all(3)
	frame_style.border_color = color
	portrait_frame.add_theme_stylebox_override("panel", frame_style)


func _refresh_route(island: IslandDefinition, progress: Dictionary, unlocked: bool) -> void:
	locked_banner.visible = not unlocked
	var level_count: int = IslandCatalogScript.level_count(_current_island_id)
	var discovery_idx: int = IslandCatalogScript.hidden_level_index(_current_island_id)
	var discovery_found: bool = _save.is_special_pup_found(_current_island_id)
	var states: Array = []
	var titles: PackedStringArray = PackedStringArray()
	for local_level in range(level_count):
		states.append(_node_state(local_level, progress, unlocked))
		titles.append(_level_display_name(island, local_level))
	_route_board.build_route(states, discovery_idx, discovery_found, titles)


func _node_state(local_level: int, progress: Dictionary, island_unlocked: bool) -> IslandRouteNode.State:
	if not island_unlocked:
		return IslandRouteNodeScript.State.LOCKED
	if IslandProgressScript.has_badge(progress, local_level, _current_island_id):
		return IslandRouteNodeScript.State.COMPLETED_BADGE
	if IslandProgressScript.is_level_completed(progress, local_level, _current_island_id):
		return IslandRouteNodeScript.State.COMPLETED
	if _current_island_id == _save.current_island_id and local_level <= _save.current_local_level:
		return IslandRouteNodeScript.State.AVAILABLE
	return IslandRouteNodeScript.State.LOCKED


func _level_display_name(island: IslandDefinition, local_level: int) -> String:
	var level_id: String = IslandCatalogScript.get_level_id(_current_island_id, local_level)
	var level: LevelDefinition = ProgressionRegistryScript.get_level(level_id)
	if level != null and level.display_name != "":
		return level.display_name
	return "Level %d" % (local_level + 1)


func _on_level_node_selected(local_level: int) -> void:
	if not _save.is_island_unlocked(_current_island_id):
		return
	var progress: Dictionary = _save.get_island_progress(_current_island_id)
	var completed: bool = IslandProgressScript.is_level_completed(progress, local_level, _current_island_id)
	var has_badge: bool = IslandProgressScript.has_badge(progress, local_level, _current_island_id)
	var playable: bool = (
		completed
		or (
			_current_island_id == _save.current_island_id
			and local_level <= _save.current_local_level
		)
	)
	var island: IslandDefinition = ProgressionRegistryScript.get_island(_current_island_id)
	_level_panel.show_level(
		local_level,
		_level_display_name(island, local_level),
		completed,
		has_badge,
		playable
	)
	panel_backdrop.visible = true


func _hide_level_panel() -> void:
	if _level_panel:
		_level_panel.hide_panel()
	panel_backdrop.visible = false


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_level_panel()


func _on_panel_play(local_level: int) -> void:
	_start_level(local_level, false)


func _on_panel_replay(local_level: int) -> void:
	var island: IslandDefinition = ProgressionRegistryScript.get_island(_current_island_id)
	var level_name: String = _level_display_name(island, local_level)
	_hide_level_panel()
	if _feedback_backdrop:
		_feedback_backdrop.visible = true
	_replay_panel.show_replay(local_level, level_name)


func _on_replay_confirmed(local_level: int) -> void:
	if _feedback_backdrop:
		_feedback_backdrop.visible = false
	_start_level(local_level, true)


func _on_replay_cancelled() -> void:
	if _feedback_backdrop:
		_feedback_backdrop.visible = false


func _start_level(local_level: int, replay: bool) -> void:
	_save.set_play_target(_current_island_id, local_level, replay)
	_save.save_game()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_prev_island() -> void:
	if _island_ids.is_empty():
		return
	_island_index = (_island_index - 1 + _island_ids.size()) % _island_ids.size()
	_refresh()


func _on_next_island() -> void:
	if _island_ids.is_empty():
		return
	_island_index = (_island_index + 1) % _island_ids.size()
	_refresh()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")


func _on_pup_card_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var companion: CompanionDefinition = ProgressionRegistryScript.get_special_companion(_current_island_id)
		if companion != null and _save.owns_companion(companion.companion_id):
			_save.set_clubhouse_focus(companion.companion_id)
			_on_clubhouse_pressed()


func _on_clubhouse_pressed() -> void:
	if _save.has_save():
		_save.load_save()
	get_tree().change_scene_to_file("res://scenes/PuppyClubhouse.tscn")


func _style_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.99, 1.0, 0.94)
	style.border_color = Color(0.55, 0.68, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)


func _style_primary_button(btn: Button, bg: Color = Color(0.22, 0.48, 0.82)) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.78, 0.82, 0.88))
