extends Control

const PupColorsScript := preload("res://scripts/pup_colors.gd")
const GameVersionScript := preload("res://scripts/game_version.gd")
const ProgressTrackerScript := preload("res://scripts/progress_tracker.gd")
const DifficultyConfigScript := preload("res://scripts/difficulty_config.gd")
const FollowerSnapScript := preload("res://scripts/follower_snap.gd")

const MENU_TEXT := Color(0.16, 0.22, 0.32)
const MENU_MUTED := Color(0.34, 0.40, 0.50)
const MENU_BTN_TEXT := Color(0.12, 0.18, 0.28)

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

@onready var coins_label: Label = $Center/Panel/VBox/CoinsLabel
@onready var play_btn: Button = $Center/Panel/VBox/PlayBtn
@onready var continue_btn: Button = $Center/Panel/VBox/ContinueBtn
@onready var wardrobe_btn: Button = $Center/Panel/VBox/WardrobeBtn
@onready var test_btn: Button = $Center/Panel/VBox/TestBtn
@onready var leaderboard_btn: Button = $Center/Panel/VBox/LeaderboardBtn
@onready var progress_hint_label: Label = $Center/Panel/VBox/ProgressHintLabel
@onready var version_label: Label = $Center/Panel/VBox/VersionLabel
@onready var patch_notes_label: Label = $Center/Panel/VBox/PatchNotesLabel
@onready var pup_name_edit: LineEdit = $Center/Panel/VBox/NameRow/PupNameEdit
@onready var difficulty_hint_label: Label = $Center/Panel/VBox/DifficultyHintLabel

var coat_preview: ColorRect
var coat_name_label: Label
var _coat_swatches: HBoxContainer
var _name_presets: HBoxContainer
var _difficulty_row: HBoxContainer
var _snap_row: HBoxContainer
var _selected_coat: int = 0
var _selected_difficulty: int = DifficultyConfigScript.MODE_BEGINNER
var _selected_snap: int = FollowerSnapScript.MODE_TRAIL
var _save: GameSave


func _ready() -> void:
	_save = get_node("/root/SaveGame") as GameSave
	coat_preview = get_node_or_null("Center/Panel/VBox/CoatRow/CoatPreview") as ColorRect
	coat_name_label = get_node_or_null("Center/Panel/VBox/CoatRow/CoatName") as Label
	_coat_swatches = get_node_or_null("Center/Panel/VBox/CoatSwatches") as HBoxContainer
	_name_presets = get_node_or_null("Center/Panel/VBox/NamePresets") as HBoxContainer
	_difficulty_row = get_node_or_null("Center/Panel/VBox/DifficultyRow") as HBoxContainer
	_snap_row = get_node_or_null("Center/Panel/VBox/SnapRow") as HBoxContainer
	_build_coat_swatches()
	_build_name_presets()
	_build_difficulty_buttons()
	_build_snap_buttons()
	_apply_menu_styles()
	if _save.has_save():
		_save.load_save()
	_selected_coat = clampi(_save.coat_index, 0, _coat_count() - 1)
	_selected_difficulty = _save.get_difficulty_mode()
	_selected_snap = _save.get_snap_mode()
	_sync_coat_ui(_selected_coat)
	_sync_difficulty_ui(_selected_difficulty)
	_sync_snap_ui(_selected_snap)
	_style_all_menu_buttons()
	if pup_name_edit:
		pup_name_edit.text = _save.pup_name
		pup_name_edit.placeholder_text = "Tap a name or type here…"
		pup_name_edit.text_changed.connect(_on_pup_name_changed)
	continue_btn.disabled = not _save.has_save()
	_refresh_coins()
	_refresh_progress_ui()
	if version_label:
		version_label.text = GameVersionScript.version_label()
	if patch_notes_label:
		patch_notes_label.text = GameVersionScript.patch_notes_text()


func _apply_menu_styles() -> void:
	var panel := get_node_or_null("Center/Panel") as PanelContainer
	if panel != null:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.97, 0.98, 1.0, 0.96)
		panel_style.border_color = Color(0.72, 0.78, 0.88)
		panel_style.set_border_width_all(2)
		panel_style.set_corner_radius_all(14)
		panel_style.content_margin_left = 18
		panel_style.content_margin_right = 18
		panel_style.content_margin_top = 16
		panel_style.content_margin_bottom = 16
		panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := get_node_or_null("Center/Panel/VBox")
	if vbox == null:
		return
	for child in vbox.get_children():
		_style_menu_node(child)
	_style_all_menu_buttons()


func _style_all_menu_buttons() -> void:
	_style_primary_button(play_btn)
	_style_primary_button(continue_btn)
	_style_primary_button(wardrobe_btn)
	_style_primary_button(test_btn)
	if leaderboard_btn:
		_style_primary_button(leaderboard_btn)
	if _name_presets:
		for child in _name_presets.get_children():
			if child is Button:
				_style_preset_button(child as Button)


func _style_primary_button(btn: Button) -> void:
	if btn == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.48, 0.82)
	style.set_corner_radius_all(10)
	style.set_border_width_all(0)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.75, 0.80, 0.88))


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
	if selected:
		style.bg_color = Color(0.55, 0.82, 0.98)
		style.border_color = Color(0.12, 0.45, 0.72)
	else:
		style.bg_color = Color(0.92, 0.94, 0.98)
		style.border_color = Color(0.65, 0.72, 0.82)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", MENU_BTN_TEXT)
	btn.add_theme_color_override("font_hover_color", MENU_BTN_TEXT)
	btn.add_theme_color_override("font_pressed_color", MENU_BTN_TEXT)


func _style_menu_node(node: Node) -> void:
	if node is Label:
		var label: Label = node
		var muted: bool = label in [progress_hint_label, difficulty_hint_label, patch_notes_label, version_label]
		label.add_theme_color_override("font_color", MENU_MUTED if muted else MENU_TEXT)
	elif node is HBoxContainer:
		for sub in node.get_children():
			if sub is Label:
				(sub as Label).add_theme_color_override("font_color", MENU_TEXT)
	elif node is LineEdit:
		var edit: LineEdit = node
		edit.add_theme_color_override("font_color", MENU_TEXT)
		edit.add_theme_color_override("font_placeholder_color", Color(MENU_MUTED.r, MENU_MUTED.g, MENU_MUTED.b, 0.65))


func _build_name_presets() -> void:
	if _name_presets == null:
		return
	for c in _name_presets.get_children():
		c.queue_free()
	for preset: String in ProgressTrackerScript.QUICK_NAMES:
		var btn := Button.new()
		btn.text = preset
		btn.custom_minimum_size = Vector2(56, 36)
		btn.focus_mode = Control.FOCUS_NONE
		_style_preset_button(btn)
		btn.pressed.connect(func(): _apply_preset_name(preset))
		_name_presets.add_child(btn)


func _apply_preset_name(preset: String) -> void:
	if pup_name_edit:
		pup_name_edit.text = preset
	_save.set_pup_name(preset)


func _on_pup_name_changed(new_text: String) -> void:
	_save.set_pup_name(new_text)


func _build_difficulty_buttons() -> void:
	if _difficulty_row == null:
		return
	for c in _difficulty_row.get_children():
		if c.name != "DifficultyLabel":
			c.queue_free()
	for mode in range(DifficultyConfigScript.MODE_LABELS.size()):
		var btn := Button.new()
		btn.text = DifficultyConfigScript.MODE_LABELS[mode]
		btn.custom_minimum_size = Vector2(92, 40)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func(): _select_difficulty(mode))
		btn.set_meta("difficulty_mode", mode)
		_difficulty_row.add_child(btn)
	_sync_difficulty_ui(_selected_difficulty)


func _select_difficulty(mode: int) -> void:
	_selected_difficulty = DifficultyConfigScript.clamp_mode(mode)
	_sync_difficulty_ui(_selected_difficulty)
	_save.set_difficulty_mode(_selected_difficulty)


func _sync_difficulty_ui(mode: int) -> void:
	if difficulty_hint_label:
		difficulty_hint_label.text = DifficultyConfigScript.mode_hint(mode)
	if _difficulty_row == null:
		return
	for child in _difficulty_row.get_children():
		if not child is Button:
			continue
		var btn: Button = child
		var m: int = int(btn.get_meta("difficulty_mode", -1))
		_style_toggle_button(btn, m == mode)


func _commit_difficulty() -> void:
	_save.set_difficulty_mode(_selected_difficulty)


func _build_snap_buttons() -> void:
	if _snap_row == null:
		return
	for c in _snap_row.get_children():
		if c.name != "SnapLabel":
			c.queue_free()
	for mode in range(FollowerSnapScript.MODE_LABELS.size()):
		var btn := Button.new()
		btn.text = FollowerSnapScript.MODE_LABELS[mode]
		btn.custom_minimum_size = Vector2(92, 40)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func(): _select_snap(mode))
		btn.set_meta("snap_mode", mode)
		_snap_row.add_child(btn)
	_sync_snap_ui(_selected_snap)


func _select_snap(mode: int) -> void:
	_selected_snap = FollowerSnapScript.clamp_mode(mode)
	_sync_snap_ui(_selected_snap)
	_save.set_snap_mode(_selected_snap)


func _sync_snap_ui(mode: int) -> void:
	if _snap_row == null:
		return
	for child in _snap_row.get_children():
		if not child is Button:
			continue
		var btn: Button = child
		var m: int = int(btn.get_meta("snap_mode", -1))
		_style_toggle_button(btn, m == mode)


func _commit_snap() -> void:
	_save.set_snap_mode(_selected_snap)


func _coat_count() -> int:
	var n := PupColorsScript.count()
	if n > 0:
		return n
	return _fallback_coat_names.size()


func _coat_name(index: int) -> String:
	if PupColorsScript.count() > 0:
		return PupColorsScript.get_name(index)
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
		btn.custom_minimum_size = Vector2(40, 40)
		btn.tooltip_text = _coat_name(i)
		btn.focus_mode = Control.FOCUS_NONE
		var col: Color = _coat_color(i)
		var style := StyleBoxFlat.new()
		style.bg_color = col
		style.border_color = Color(0.15, 0.15, 0.2)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", style)
		var sel := style.duplicate()
		sel.border_color = Color(1.0, 0.92, 0.35)
		sel.set_border_width_all(3)
		btn.add_theme_stylebox_override("focus", sel)
		btn.pressed.connect(func(): _select_coat(i))
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
				style.set_corner_radius_all(6)
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
			progress_hint_label.text = "Best: Level %d  |  Squad %d  |  %d rescued" % [
				_save.get_best_level(),
				_save.get_best_squad(),
				_save.get_best_rescued(),
			]
		else:
			progress_hint_label.text = "Beat level 2 to unlock save & leaderboard"


func _on_play_pressed() -> void:
	_commit_pup_name()
	_commit_difficulty()
	_commit_snap()
	_save.prepare_new_game(_selected_coat_index())
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_continue_pressed() -> void:
	_commit_pup_name()
	_commit_difficulty()
	_commit_snap()
	_save.prepare_continue()
	_save.coat_index = _selected_coat_index()
	_save.save_game()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_test_pressed() -> void:
	_commit_pup_name()
	_commit_difficulty()
	_commit_snap()
	_save.prepare_test_maze(_selected_coat_index())
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_wardrobe_pressed() -> void:
	_commit_pup_name()
	if _save.has_save():
		_save.load_save()
	get_tree().change_scene_to_file("res://scenes/Wardrobe.tscn")


func _on_leaderboard_pressed() -> void:
	if not _save.progress_features_unlocked():
		return
	get_tree().change_scene_to_file("res://scenes/Leaderboard.tscn")
