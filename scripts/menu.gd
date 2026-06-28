extends Control

const PupColorsScript := preload("res://scripts/pup_colors.gd")
const GameVersionScript := preload("res://scripts/game_version.gd")
const ProgressTrackerScript := preload("res://scripts/progress_tracker.gd")
const DifficultyConfigScript := preload("res://scripts/difficulty_config.gd")
const FollowerSnapScript := preload("res://scripts/follower_snap.gd")
const TouchControlConfigScript := preload("res://scripts/touch_control_config.gd")
const IslandCatalogScript := preload("res://scripts/island_catalog.gd")
const IslandProgressScript := preload("res://scripts/island_progress.gd")
const ProgressionRegistryScript := preload("res://scripts/progression/progression_registry.gd")

const MENU_TEXT := Color(0.16, 0.22, 0.32)
const MENU_MUTED := Color(0.34, 0.40, 0.50)
const MENU_BTN_TEXT := Color(0.12, 0.18, 0.28)
const SECTION_COLOR := Color(0.22, 0.48, 0.82)

const TOUCH_MENU_LABELS := [
	"Tap to move",
	"Joystick",
	"Both",
	"Keyboard only",
]

const TOGGLE_BTN_SIZE := Vector2(128, 42)

var _fallback_coat_names: PackedStringArray = PackedStringArray([
	"Golden", "Cream", "Brown", "Gray", "Tan", "Rose",
])
var _fallback_coat_colors: Array = [
	Color(0.85, 0.72, 0.38),
	Color(0.88, 0.82, 0.68),
	Color(0.55, 0.38, 0.26),
	Color(0.62, 0.62, 0.66),
	Color(0.72, 0.58, 0.42),
	Color(0.78, 0.52, 0.48),
]

@onready var coins_label: Label = $RootMargin/RootVBox/Scroll/SettingsPanel/VBox/CoinsLabel
@onready var play_btn: Button = $RootMargin/RootVBox/PlayPanel/PlayVBox/PlayBtn
@onready var continue_btn: Button = $RootMargin/RootVBox/PlayPanel/PlayVBox/ContinueBtn
@onready var wardrobe_btn: Button = $RootMargin/RootVBox/PlayPanel/PlayVBox/ExtraButtons/WardrobeBtn
@onready var test_btn: Button = $RootMargin/RootVBox/PlayPanel/PlayVBox/ExtraButtons/TestBtn
@onready var leaderboard_btn: Button = $RootMargin/RootVBox/PlayPanel/PlayVBox/ExtraButtons/LeaderboardBtn
@onready var progress_hint_label: Label = $RootMargin/RootVBox/Scroll/SettingsPanel/VBox/ProgressHintLabel
@onready var version_label: Label = $RootMargin/RootVBox/Scroll/SettingsPanel/VBox/VersionLabel
@onready var patch_notes_label: Label = $RootMargin/RootVBox/Scroll/SettingsPanel/VBox/PatchNotesLabel
@onready var pup_name_edit: LineEdit = $RootMargin/RootVBox/Scroll/SettingsPanel/VBox/NameRow/PupNameEdit
@onready var difficulty_hint_label: Label = $RootMargin/RootVBox/Scroll/SettingsPanel/VBox/DifficultyHintLabel
@onready var touch_hint_label: Label = $RootMargin/RootVBox/Scroll/SettingsPanel/VBox/TouchHintLabel
@onready var _settings_panel: PanelContainer = $RootMargin/RootVBox/Scroll/SettingsPanel
@onready var _play_panel: PanelContainer = $RootMargin/RootVBox/PlayPanel

var coat_preview: ColorRect
var coat_name_label: Label
var _coat_swatches: FlowContainer
var _name_presets: FlowContainer
var _difficulty_flow: FlowContainer
var _snap_flow: FlowContainer
var _touch_flow: FlowContainer
var _companion_flow: FlowContainer
var _selected_coat: int = 0
var _selected_difficulty: int = DifficultyConfigScript.MODE_BEGINNER
var _selected_snap: int = FollowerSnapScript.MODE_TRAIL
var _selected_touch: int = TouchControlConfigScript.MODE_FOLLOW_TOUCH
var _save: GameSave


func _ready() -> void:
	_save = get_node("/root/SaveGame") as GameSave
	if _save.has_save():
		_save.load_save()
	_selected_coat = clampi(_save.coat_index, 0, _coat_count() - 1)
	_selected_difficulty = _save.get_difficulty_mode()
	_selected_snap = _save.get_snap_mode()
	_selected_touch = _save.get_touch_control_mode()

	coat_preview = get_node_or_null("RootMargin/RootVBox/Scroll/SettingsPanel/VBox/CoatRow/CoatPreview") as ColorRect
	coat_name_label = get_node_or_null("RootMargin/RootVBox/Scroll/SettingsPanel/VBox/CoatRow/CoatName") as Label
	_coat_swatches = get_node_or_null("RootMargin/RootVBox/Scroll/SettingsPanel/VBox/CoatSwatches") as FlowContainer
	_name_presets = get_node_or_null("RootMargin/RootVBox/Scroll/SettingsPanel/VBox/NamePresets") as FlowContainer
	_difficulty_flow = get_node_or_null("RootMargin/RootVBox/Scroll/SettingsPanel/VBox/DifficultyFlow") as FlowContainer
	_snap_flow = get_node_or_null("RootMargin/RootVBox/Scroll/SettingsPanel/VBox/SnapFlow") as FlowContainer
	_touch_flow = get_node_or_null("RootMargin/RootVBox/Scroll/SettingsPanel/VBox/TouchFlow") as FlowContainer

	_apply_menu_styles()
	_wire_buttons()
	_build_coat_swatches()
	_build_name_presets()
	_build_difficulty_buttons()
	_build_snap_buttons()
	_build_touch_control_buttons()
	_build_companion_buttons()
	_build_hub_navigation()
	_sync_coat_ui(_selected_coat)
	_sync_difficulty_ui(_selected_difficulty)
	_sync_snap_ui(_selected_snap)
	_sync_touch_ui(_selected_touch)
	_style_all_menu_buttons()

	if pup_name_edit:
		pup_name_edit.text = _save.pup_name
		pup_name_edit.text_changed.connect(_on_pup_name_changed)
	continue_btn.disabled = not _save.has_save()
	_refresh_coins()
	_refresh_progress_ui()
	if version_label:
		version_label.text = GameVersionScript.version_label()
	if patch_notes_label:
		patch_notes_label.text = GameVersionScript.patch_notes_text()
	call_deferred("_sync_scroll_width")


func _wire_buttons() -> void:
	_connect_btn(play_btn, _on_play_pressed)
	_connect_btn(continue_btn, _on_continue_pressed)
	_connect_btn(wardrobe_btn, _on_wardrobe_pressed)
	_connect_btn(test_btn, _on_test_pressed)
	_connect_btn(leaderboard_btn, _on_leaderboard_pressed)


func _connect_btn(btn: Button, callback: Callable) -> void:
	if btn == null:
		return
	if not btn.pressed.is_connected(callback):
		btn.pressed.connect(callback)


func _sync_scroll_width() -> void:
	var scroll := get_node_or_null("RootMargin/RootVBox/Scroll") as ScrollContainer
	if scroll == null or _settings_panel == null:
		return
	var width: float = maxf(scroll.size.x - 8.0, 320.0)
	_settings_panel.custom_minimum_size.x = width


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		call_deferred("_sync_scroll_width")


func _apply_menu_styles() -> void:
	_style_panel(_settings_panel)
	_style_panel(_play_panel)
	var vbox := get_node_or_null("RootMargin/RootVBox/Scroll/SettingsPanel/VBox")
	if vbox == null:
		return
	for child in vbox.get_children():
		_style_menu_node(child)
	_style_section_headers()
	_style_name_field()


func _style_panel(panel: PanelContainer) -> void:
	if panel == null:
		return
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.97, 0.98, 1.0, 0.98)
	panel_style.border_color = Color(0.55, 0.68, 0.82)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	panel_style.shadow_color = Color(0.12, 0.18, 0.28, 0.12)
	panel_style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", panel_style)


func _style_section_headers() -> void:
	for node_name in ["SectionPup", "SectionSettings", "SectionStatus"]:
		var label := get_node_or_null(
			"RootMargin/RootVBox/Scroll/SettingsPanel/VBox/%s" % node_name
		) as Label
		if label:
			label.add_theme_color_override("font_color", SECTION_COLOR)
			label.add_theme_font_size_override("font_size", 15)


func _style_name_field() -> void:
	if pup_name_edit == null:
		return
	var field_style := StyleBoxFlat.new()
	field_style.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	field_style.border_color = Color(0.62, 0.70, 0.82)
	field_style.set_border_width_all(2)
	field_style.set_corner_radius_all(8)
	field_style.content_margin_left = 10
	field_style.content_margin_right = 10
	pup_name_edit.add_theme_stylebox_override("normal", field_style)
	pup_name_edit.add_theme_stylebox_override("focus", field_style)
	pup_name_edit.add_theme_color_override("font_color", MENU_TEXT)
	pup_name_edit.add_theme_color_override("font_placeholder_color", Color(MENU_MUTED.r, MENU_MUTED.g, MENU_MUTED.b, 0.85))


func _style_all_menu_buttons() -> void:
	_style_primary_button(play_btn, Color(0.18, 0.58, 0.38))
	_style_primary_button(continue_btn, Color(0.22, 0.48, 0.82))
	_style_secondary_button(wardrobe_btn)
	_style_secondary_button(test_btn)
	_style_secondary_button(leaderboard_btn)
	if _name_presets:
		for child in _name_presets.get_children():
			if child is Button:
				_style_preset_button(child as Button)


func _style_primary_button(btn: Button, bg: Color = Color(0.22, 0.48, 0.82)) -> void:
	if btn == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(10)
	style.set_border_width_all(0)
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = bg.lightened(0.08)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = bg.darkened(0.08)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.75, 0.80, 0.88))
	btn.add_theme_font_size_override("font_size", 17)


func _style_secondary_button(btn: Button) -> void:
	if btn == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.90, 0.93, 0.98)
	style.border_color = Color(0.62, 0.70, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", MENU_BTN_TEXT)
	btn.add_theme_color_override("font_hover_color", MENU_BTN_TEXT)


func _style_preset_button(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.90, 0.93, 0.98)
	style.border_color = Color(0.62, 0.70, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", MENU_BTN_TEXT)
	btn.add_theme_color_override("font_hover_color", MENU_BTN_TEXT)


func _style_toggle_button(btn: Button, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	if selected:
		style.bg_color = Color(0.22, 0.48, 0.82)
		style.border_color = Color(0.12, 0.45, 0.72)
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		style.bg_color = Color(1.0, 1.0, 1.0, 1.0)
		style.border_color = Color(0.62, 0.70, 0.82)
		btn.add_theme_color_override("font_color", MENU_BTN_TEXT)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_hover_color", btn.get_theme_color("font_color"))
	btn.add_theme_color_override("font_pressed_color", btn.get_theme_color("font_color"))


func _style_menu_node(node: Node) -> void:
	if node is Label:
		var label: Label = node
		var muted: bool = label in [
			progress_hint_label,
			difficulty_hint_label,
			touch_hint_label,
			patch_notes_label,
			version_label,
		]
		var is_header: bool = label.name.ends_with("Header")
		if not muted and not is_header and not label.name.begins_with("Section"):
			label.add_theme_color_override("font_color", MENU_TEXT)
		elif muted:
			label.add_theme_color_override("font_color", MENU_MUTED)
		elif is_header:
			label.add_theme_color_override("font_color", MENU_TEXT)
			label.add_theme_font_size_override("font_size", 14)
	elif node is HBoxContainer or node is FlowContainer:
		for sub in node.get_children():
			if sub is Label:
				(sub as Label).add_theme_color_override("font_color", MENU_TEXT)


func _make_toggle_button(text: String, meta_key: String, meta_value: int, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = TOGGLE_BTN_SIZE
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_meta(meta_key, meta_value)
	btn.pressed.connect(callback)
	return btn


func _build_name_presets() -> void:
	if _name_presets == null:
		return
	for c in _name_presets.get_children():
		c.queue_free()
	for preset: String in ProgressTrackerScript.QUICK_NAMES:
		var btn := Button.new()
		btn.text = preset
		btn.custom_minimum_size = Vector2(64, 38)
		btn.focus_mode = Control.FOCUS_NONE
		_style_preset_button(btn)
		btn.pressed.connect(_apply_preset_name.bind(preset))
		_name_presets.add_child(btn)


func _apply_preset_name(preset: String) -> void:
	if pup_name_edit:
		pup_name_edit.text = preset
	_save.set_pup_name(preset)


func _on_pup_name_changed(new_text: String) -> void:
	_save.set_pup_name(new_text)


func _build_difficulty_buttons() -> void:
	if _difficulty_flow == null:
		return
	for c in _difficulty_flow.get_children():
		c.queue_free()
	for mode in range(DifficultyConfigScript.MODE_LABELS.size()):
		var btn := _make_toggle_button(
			DifficultyConfigScript.MODE_LABELS[mode],
			"difficulty_mode",
			mode,
			_select_difficulty.bind(mode)
		)
		_difficulty_flow.add_child(btn)
	_sync_difficulty_ui(_selected_difficulty)


func _select_difficulty(mode: int) -> void:
	_selected_difficulty = DifficultyConfigScript.clamp_mode(mode)
	_sync_difficulty_ui(_selected_difficulty)
	_save.set_difficulty_mode(_selected_difficulty)


func _sync_difficulty_ui(mode: int) -> void:
	if difficulty_hint_label:
		difficulty_hint_label.text = DifficultyConfigScript.mode_hint(mode)
	if _difficulty_flow == null:
		return
	for child in _difficulty_flow.get_children():
		if child is Button:
			var btn: Button = child
			var m: int = int(btn.get_meta("difficulty_mode", -1))
			_style_toggle_button(btn, m == mode)


func _commit_difficulty() -> void:
	_save.set_difficulty_mode(_selected_difficulty)


func _build_snap_buttons() -> void:
	if _snap_flow == null:
		return
	for c in _snap_flow.get_children():
		c.queue_free()
	for mode in range(FollowerSnapScript.MODE_LABELS.size()):
		var btn := _make_toggle_button(
			FollowerSnapScript.MODE_LABELS[mode],
			"snap_mode",
			mode,
			_select_snap.bind(mode)
		)
		_snap_flow.add_child(btn)
	_sync_snap_ui(_selected_snap)


func _select_snap(mode: int) -> void:
	_selected_snap = FollowerSnapScript.clamp_mode(mode)
	_sync_snap_ui(_selected_snap)
	_save.set_snap_mode(_selected_snap)


func _sync_snap_ui(mode: int) -> void:
	if _snap_flow == null:
		return
	for child in _snap_flow.get_children():
		if child is Button:
			var btn: Button = child
			var m: int = int(btn.get_meta("snap_mode", -1))
			_style_toggle_button(btn, m == mode)


func _commit_snap() -> void:
	_save.set_snap_mode(_selected_snap)


func _build_touch_control_buttons() -> void:
	if _touch_flow == null:
		return
	for c in _touch_flow.get_children():
		c.queue_free()
	for mode in range(TouchControlConfigScript.MODE_LABELS.size()):
		var label: String = TOUCH_MENU_LABELS[mode] if mode < TOUCH_MENU_LABELS.size() else TouchControlConfigScript.MODE_LABELS[mode]
		var btn := _make_toggle_button(
			label,
			"touch_mode",
			mode,
			_select_touch.bind(mode)
		)
		_touch_flow.add_child(btn)
	_sync_touch_ui(_selected_touch)


func _select_touch(mode: int) -> void:
	_selected_touch = TouchControlConfigScript.clamp_mode(mode)
	_sync_touch_ui(_selected_touch)
	_save.set_touch_control_mode(_selected_touch)


func _sync_touch_ui(mode: int) -> void:
	if touch_hint_label:
		touch_hint_label.text = TouchControlConfigScript.mode_hint(mode)
	if _touch_flow == null:
		return
	for child in _touch_flow.get_children():
		if child is Button:
			var btn: Button = child
			var m: int = int(btn.get_meta("touch_mode", -1))
			_style_toggle_button(btn, m == mode)


func _commit_touch() -> void:
	_save.set_touch_control_mode(_selected_touch)


func _build_companion_buttons() -> void:
	var vbox := get_node_or_null("RootMargin/RootVBox/Scroll/SettingsPanel/VBox")
	if vbox == null:
		return
	if get_node_or_null("RootMargin/RootVBox/Scroll/SettingsPanel/VBox/CompanionFlow") != null:
		_companion_flow = get_node_or_null(
			"RootMargin/RootVBox/Scroll/SettingsPanel/VBox/CompanionFlow"
		) as FlowContainer
		_refresh_companion_buttons()
		return
	var status := vbox.get_node_or_null("SectionStatus")
	var insert_idx: int = status.get_index() if status != null else vbox.get_child_count()
	var section := Label.new()
	section.name = "SectionCompanions"
	section.text = "Companions"
	section.add_theme_font_size_override("font_size", 14)
	section.add_theme_color_override("font_color", SECTION_COLOR)
	vbox.add_child(section)
	vbox.move_child(section, insert_idx)
	insert_idx += 1
	_companion_flow = FlowContainer.new()
	_companion_flow.name = "CompanionFlow"
	_companion_flow.add_theme_constant_override("h_separation", 8)
	_companion_flow.add_theme_constant_override("v_separation", 8)
	_companion_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	vbox.add_child(_companion_flow)
	vbox.move_child(_companion_flow, insert_idx)
	_refresh_companion_buttons()


func _refresh_companion_buttons() -> void:
	if _companion_flow == null:
		return
	for c in _companion_flow.get_children():
		c.queue_free()
	var none_btn := Button.new()
	none_btn.text = "None"
	none_btn.custom_minimum_size = Vector2(72, 38)
	none_btn.focus_mode = Control.FOCUS_NONE
	_style_preset_button(none_btn)
	none_btn.pressed.connect(_select_companion.bind(""))
	_companion_flow.add_child(none_btn)
	for companion_id: String in _save.owned_companions:
		var pup_def: Dictionary = _companion_def_for_id(companion_id)
		var btn := Button.new()
		btn.text = str(pup_def.get("name", companion_id))
		btn.custom_minimum_size = Vector2(88, 38)
		btn.focus_mode = Control.FOCUS_NONE
		_style_preset_button(btn)
		btn.pressed.connect(_select_companion.bind(companion_id))
		_companion_flow.add_child(btn)
	_sync_companion_ui()


func _companion_def_for_id(companion_id: String) -> Dictionary:
	var companion: CompanionDefinition = ProgressionRegistryScript.get_companion(companion_id)
	if companion != null:
		return {
			"id": companion.companion_id,
			"name": companion.default_name,
		}
	return {"name": companion_id}


func _select_companion(companion_id: String) -> void:
	_save.set_selected_companion(companion_id)
	_save.save_game()
	_sync_companion_ui()


func _sync_companion_ui() -> void:
	if _companion_flow == null:
		return
	var selected := _save.selected_companion_id
	for child in _companion_flow.get_children():
		if child is Button:
			var btn: Button = child
			var id := "" if btn.text == "None" else _companion_id_for_name(btn.text)
			if btn.text == "None" and selected == "":
				btn.modulate = Color(1.0, 1.0, 0.85)
			elif id == selected:
				btn.modulate = Color(1.0, 1.0, 0.85)
			else:
				btn.modulate = Color.WHITE


func _companion_id_for_name(display_name: String) -> String:
	for companion: CompanionDefinition in ProgressionRegistryScript.all_companions():
		if companion.default_name == display_name:
			return companion.companion_id
	return ""


func _coat_count() -> int:
	var n := PupColorsScript.count()
	if n > 0:
		return n
	return _fallback_coat_names.size()


func _coat_name(index: int) -> String:
	if PupColorsScript.count() > 0:
		return PupColorsScript.get_coat_name(index)
	return _fallback_coat_names[clampi(index, 0, _fallback_coat_names.size() - 1)]


func _coat_color(index: int) -> Color:
	if PupColorsScript.count() > 0:
		return PupColorsScript.get_color(index)
	return _fallback_coat_colors[clampi(index, 0, _fallback_coat_colors.size() - 1)] as Color


func _build_coat_swatches() -> void:
	if _coat_swatches == null:
		return
	for c in _coat_swatches.get_children():
		c.queue_free()
	for i in _coat_count():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(44, 44)
		btn.tooltip_text = _coat_name(i)
		btn.focus_mode = Control.FOCUS_NONE
		var col: Color = _coat_color(i)
		var style := StyleBoxFlat.new()
		style.bg_color = col
		style.border_color = Color(0.15, 0.15, 0.2)
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal", style)
		btn.pressed.connect(_select_coat.bind(i))
		btn.set_meta("coat_index", i)
		_coat_swatches.add_child(btn)


func _select_coat(index: int) -> void:
	_selected_coat = clampi(index, 0, _coat_count() - 1)
	_sync_coat_ui(_selected_coat)


func _sync_coat_ui(index: int) -> void:
	if coat_preview != null:
		coat_preview.color = _coat_color(index)
	if coat_name_label != null:
		coat_name_label.text = _coat_name(index)
	if _coat_swatches != null:
		for child in _coat_swatches.get_children():
			if child is Button:
				var btn: Button = child
				var i: int = int(btn.get_meta("coat_index", -1))
				var style := StyleBoxFlat.new()
				style.bg_color = _coat_color(i)
				style.set_corner_radius_all(8)
				if i == index:
					style.border_color = Color(1.0, 0.92, 0.35)
					style.set_border_width_all(3)
				else:
					style.border_color = Color(0.15, 0.15, 0.2)
					style.set_border_width_all(2)
				btn.add_theme_stylebox_override("normal", style)


func _selected_coat_index() -> int:
	return _selected_coat


func _commit_pup_name() -> void:
	if pup_name_edit:
		_save.set_pup_name(pup_name_edit.text)


func _refresh_coins() -> void:
	if coins_label:
		coins_label.text = "Treat Coins: %d" % _save.treat_coins


func _refresh_progress_ui() -> void:
	var unlocked := _save.progress_features_unlocked()
	if leaderboard_btn:
		leaderboard_btn.visible = unlocked
		leaderboard_btn.disabled = not unlocked
	if progress_hint_label:
		if unlocked:
			var island_id: String = _save.current_island_id
			if island_id == "":
				island_id = IslandCatalogScript.first_island_id()
			var island_def: Dictionary = IslandCatalogScript.get_island(island_id)
			var progress: Dictionary = _save.get_island_progress(island_id)
			var badges: int = _save.escort_badge_count(island_id)
			var required: int = IslandCatalogScript.badges_required(island_id)
			var completed: int = IslandProgressScript.completed_count(
				progress, IslandCatalogScript.level_count(island_id)
			)
			progress_hint_label.text = "%s  |  Levels %d  |  Badges %d/%d  |  Best Lv %d" % [
				str(island_def.get("name", "Island")),
				completed,
				badges,
				required,
				_save.get_best_level(),
			]
		else:
			progress_hint_label.text = "Beat level 2 to unlock save & leaderboard"


func _on_play_pressed() -> void:
	_commit_pup_name()
	_commit_difficulty()
	_commit_snap()
	_commit_touch()
	_save.prepare_new_game(_selected_coat_index())
	get_tree().change_scene_to_file("res://scenes/IslandMap.tscn")


func _on_continue_pressed() -> void:
	_commit_pup_name()
	_commit_difficulty()
	_commit_snap()
	_commit_touch()
	_save.prepare_continue()
	_save.coat_index = _selected_coat_index()
	_save.set_play_target(_save.current_island_id, _save.current_local_level, false)
	_save.save_game()
	_go_to_game()


func _on_test_pressed() -> void:
	_commit_pup_name()
	_commit_difficulty()
	_commit_snap()
	_commit_touch()
	_save.prepare_test_maze(_selected_coat_index())
	_go_to_game()


func _go_to_game() -> void:
	var err := get_tree().change_scene_to_file("res://scenes/Game.tscn")
	if err != OK:
		push_error("Failed to open game scene: %s" % error_string(err))


func _on_wardrobe_pressed() -> void:
	_commit_pup_name()
	if _save.has_save():
		_save.load_save()
	get_tree().change_scene_to_file("res://scenes/Wardrobe.tscn")


func _on_leaderboard_pressed() -> void:
	if not _save.progress_features_unlocked():
		return
	get_tree().change_scene_to_file("res://scenes/Leaderboard.tscn")


func _build_hub_navigation() -> void:
	var play_vbox: VBoxContainer = get_node_or_null("RootMargin/RootVBox/PlayPanel/PlayVBox") as VBoxContainer
	if play_vbox == null:
		return
	if play_vbox.get_node_or_null("HubNavRow") != null:
		return
	var row := HBoxContainer.new()
	row.name = "HubNavRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var extra_idx: int = play_vbox.get_node("ExtraButtons").get_index()
	play_vbox.add_child(row)
	play_vbox.move_child(row, extra_idx)
	if _save.has_save():
		var map_btn := Button.new()
		map_btn.text = "Island Map"
		map_btn.custom_minimum_size = Vector2(0, 44)
		map_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		map_btn.pressed.connect(_on_island_map_pressed)
		row.add_child(map_btn)
	var clubhouse_btn := Button.new()
	clubhouse_btn.text = "Puppy Clubhouse"
	clubhouse_btn.custom_minimum_size = Vector2(0, 44)
	clubhouse_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clubhouse_btn.pressed.connect(_on_clubhouse_pressed)
	row.add_child(clubhouse_btn)


func _on_island_map_pressed() -> void:
	_commit_pup_name()
	_commit_difficulty()
	_commit_snap()
	_commit_touch()
	if _save.has_save():
		_save.load_save()
	get_tree().change_scene_to_file("res://scenes/IslandMap.tscn")


func _on_clubhouse_pressed() -> void:
	_commit_pup_name()
	if _save.has_save():
		_save.load_save()
	get_tree().change_scene_to_file("res://scenes/PuppyClubhouse.tscn")
