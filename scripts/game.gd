# scripts/game.gd
extends Node3D

@export var test_mode: bool = false
@export var auto_fit_camera_on_load: bool = true
@export var debug_enabled: bool = false
@export var target_update_threshold: float = 0.10
@export var randomize_each_load: bool = true
@export var island_pup_debug: bool = false
@export var pickup_radius: float = 0.6
@export var door_unlock_radius: float = 1.1
@export var speed_boost_multiplier: float = 1.55
@export var speed_boost_duration: float = 10.0
@export var double_rescue_duration: float = 30.0
@export var ui_safe_margin: int = 28
@export var floor_collision_mask: int = 1

@onready var floor_mesh: MeshInstance3D = $World/Floor/MeshInstance3D
@onready var cam_fitter: CameraFitter = $Camera3D
@onready var floor_body: StaticBody3D = $World/Floor
@onready var floor_collision: CollisionShape3D = $World/Floor/CollisionShape3D
@onready var maze_root: Node3D = $World/MazeRoot
@onready var puppy: CharacterBody3D = $World/ActorsRoot/Puppy

const PupAppearanceScript := preload("res://scripts/pup_appearance.gd")
const ShopPanelScript := preload("res://scripts/shop_panel.gd")
const UltraBuffsScript := preload("res://scripts/ultra_buffs.gd")
const ProgressionConfigScript := preload("res://scripts/progression_config.gd")
const AccessoryCatalogScript := preload("res://scripts/accessory_catalog.gd")
const UpgradeCatalogScript := preload("res://scripts/upgrade_catalog.gd")
const UltraPowerupCatalogScript := preload("res://scripts/ultra_powerup_catalog.gd")
const MazeBuilderScript := preload("res://scripts/maze_builder.gd")
const FootprintTrailScript := preload("res://scripts/footprint_trail.gd")
const GameVersionScript := preload("res://scripts/game_version.gd")
const DifficultyConfigScript := preload("res://scripts/difficulty_config.gd")
const FollowerSnapScript := preload("res://scripts/follower_snap.gd")
const PupColorsScript := preload("res://scripts/pup_colors.gd")
const LevelGeneratorScript := preload("res://scripts/level_generator.gd")
const PlayerInputControllerScript := preload("res://scripts/player_input_controller.gd")
const TouchControlConfigScript := preload("res://scripts/touch_control_config.gd")
const SafeButtonScript := preload("res://scripts/safe_button.gd")
const IslandCatalogScript := preload("res://scripts/island_catalog.gd")
const SpecialPupScript := preload("res://scripts/special_pup.gd")
const ProgressionRegistryScript := preload("res://scripts/progression/progression_registry.gd")
const CompanionUnlockPanelScript := preload("res://scripts/companion_unlock_panel.gd")
const SpecialPupFoundPanelScript := preload("res://scripts/special_pup_found_panel.gd")
const PuppySessionTrackerScript := preload("res://scripts/puppy_session_tracker.gd")
const PAUSE_TOUCH_LABELS := ["Tap", "Joystick", "Both", "Off"]
const LAYER_PLAYER := 2

var cam: Camera3D
var builder: MazeBuilder
var run_seed: int = 0
var current_level: int = 0
var play_island_id: String = ""
var play_local_level: int = 0
var play_replay: bool = false
var hidden_pup_node: Node3D = null
var _last_completion_result: Dictionary = {}
var _pending_had_island_escort: bool = false
var _escort_joined_this_level_start: bool = false
var _toast_timer: Timer = null
var _toast_restore_hint: String = ""
var _companion_unlock_panel: CompanionUnlockPanel = null
var _companion_unlock_backdrop: ColorRect = null
var _special_pup_found_panel: SpecialPupFoundPanel = null
var _special_pup_found_backdrop: ColorRect = null
var _pending_after_companion_celebration: Callable = Callable()
var _special_pup_rescued_this_run: bool = false
var _session: PuppySessionTracker = PuppySessionTrackerScript.new()

var has_key: bool = false
var key_node: Node3D = null
var key_area: Area3D = null
var exit_node: Node3D = null
var exit_area: Area3D = null
var door_area: Area3D = null
var door_body: StaticBody3D = null
var door_unlock_center: Vector3 = Vector3.ZERO
var door_opened: bool = false

var has_pen: bool = false
var pen_gate_body: StaticBody3D = null
var pen_gate_center: Vector3 = Vector3.ZERO
var pen_gate_cell: Vector2i = Vector2i(-1, -1)
var pen_gate_area: Area3D = null
var pen_opened: bool = false
var pen_center: Vector3 = Vector3.ZERO
var pen_pup_base: int = 0
var follower_squad: FollowerSquad = null
var rescue_room_pups: Array[Node3D] = []
var rescue_room_root: Node3D = null
var footprint_trail: Node3D = null

var speed_nodes: Array[Node3D] = []
var double_boost_nodes: Array[Node3D] = []
var coin_nodes: Array[Node3D] = []
var accessory_nodes: Array[Node3D] = []
var ultra_nodes: Array[Node3D] = []
var _accessory_pickup_ids: Dictionary = {}
var _ultra_pickup_ids: Dictionary = {}
var coins_this_level: int = 0
var _level_coin_awarded: bool = false
var _last_coin_summary: String = ""
var ultra_buffs = UltraBuffsScript.new()
var pup_appearance = null
var shop_panel = null
var puppy_base_speed: float = 6.0
var speed_boost_until_ms: int = 0
var double_rescue_until_ms: int = 0
var level_won: bool = false
var _exit_wait_start_ms: int = -1
var run_squad_bonus: int = 0
var _exit_roundup_snapped: bool = false

const EXIT_GRACE_MS: int = 1200

var ui_layer: CanvasLayer = null
var ui_root: Control = null
var level_label: Label = null
var coins_label: Label = null
var boost_label: Label = null
var hint_label: Label = null
var win_panel: Panel = null
var win_label: Label = null
var restart_btn: Button = null
var menu_btn: Button = null
var test_toggle: CheckButton = null
var next_btn: Button = null
var restart_btn2: Button = null
var save_progress_btn: Button = null
var pause_btn: Button = null
var key_status_label: Label = null

var player_input: PlayerInputController = null
var pause_backdrop: ColorRect = null
var pause_panel: PanelContainer = null
var win_backdrop: ColorRect = null
var confirm_dialog: ConfirmationDialog = null
var _touch_control_buttons: Array[Button] = []
var _paused: bool = false
var _pending_confirm: Callable = Callable()

var _save: GameSave


func _ready() -> void:
	_save = get_node("/root/SaveGame") as GameSave
	set_process_unhandled_input(false)
	set_process_input(false)
	run_seed = int(Time.get_unix_time_from_system()) ^ randi()
	cam = cam_fitter
	builder = MazeBuilderScript.new()
	_apply_boot_settings()
	_build_ui()
	_setup_player_input()
	follower_squad = FollowerSquad.new()
	follower_squad.name = "FollowerSquad"
	add_child(follower_squad)
	footprint_trail = FootprintTrailScript.new()
	footprint_trail.name = "FootprintTrail"
	$World.add_child(footprint_trail)
	set_physics_process(true)
	_sync_play_context_from_save()
	load_level(_resolve_load_level_index())


func _sync_play_context_from_save() -> void:
	if test_mode or _save.boot_test_mode:
		return
	if _save.play_island_id == "":
		_save.set_play_target(_save.current_island_id, _save.current_local_level, false)
	play_island_id = _save.get_play_island_id()
	play_local_level = _save.get_play_local_level()
	play_replay = _save.play_replay


func _resolve_load_level_index() -> int:
	if test_mode or _save.boot_test_mode:
		return 0
	return _save.resolve_global_level_index(play_island_id, play_local_level)


func _apply_boot_settings() -> void:
	if _save.boot_test_mode:
		test_mode = true
	if puppy.has_method("set_coat_index"):
		puppy.call_deferred("set_coat_index", _save.coat_index)
	elif puppy.has_method("_apply_coat_mesh"):
		puppy.call_deferred("_apply_coat_mesh")
	_setup_pup_appearance()


func load_level(level_index: int) -> void:
	current_level = level_index
	_save.current_level = level_index
	play_island_id = _save.get_play_island_id()
	play_local_level = _save.get_play_local_level()
	play_replay = _save.play_replay
	level_won = false
	_clear_runtime_pickups()
	_clear_hidden_pup()
	_special_pup_rescued_this_run = false

	if _save.boot_new_game or _save.boot_test_mode:
		run_squad_bonus = 0
	if _save.boot_new_game:
		_save.boot_new_game = false
	_exit_roundup_snapped = false

	if randomize_each_load:
		run_seed = (run_seed + 1337) ^ randi()
	else:
		run_seed = Time.get_ticks_msec()

	var lines := LevelData.make(level_index, run_seed, test_mode, _save.get_difficulty_mode())
	var ts: float = builder.tile_size
	fit_floor_to_level(lines, ts)

	var wall_palette: int = -1
	if not test_mode and play_island_id != "":
		var island_def: Dictionary = IslandCatalogScript.get_island(play_island_id)
		wall_palette = int(island_def.get("wall_palette_index", -1))
	var info := builder.build_from_lines(lines, maze_root, level_index, wall_palette)

	if auto_fit_camera_on_load and cam_fitter != null:
		cam_fitter.set_fit_target(info["center"], info["half_extents"], test_mode)

	has_key = false
	door_opened = false
	pen_opened = false
	has_pen = info.get("pen_gate") is Vector3
	pen_center = _info_vec3(info, "pen_center")
	_session.reset_for_level()
	_escort_joined_this_level_start = false
	coins_this_level = 0
	_level_coin_awarded = false
	ultra_buffs.clear()
	speed_boost_until_ms = 0
	double_rescue_until_ms = 0
	_exit_wait_start_ms = -1

	_spawn_key_if_present(info)
	_spawn_exit_if_present(info)
	_spawn_door_if_present(info)
	_spawn_speed_pickups_if_present(info)
	_spawn_double_boost_pickups_if_present(info)
	_spawn_coin_pickups_if_present(info)
	_spawn_accessory_pickups_if_present(info)
	_spawn_ultra_pickups_if_present(info)
	if has_pen:
		_spawn_pen_gate_if_present(info)
		var pen_rng := RandomNumberGenerator.new()
		pen_rng.seed = run_seed ^ (level_index * 7919)
		pen_pup_base = ProgressionConfigScript.roll_pen_pup_count(pen_rng)
		info["pen_pup_count"] = pen_pup_base
		_spawn_waiting_pups_in_room(info)
	else:
		pen_pup_base = 0

	if puppy.has_method("set_maze_data"):
		puppy.set_maze_data(lines, ts)
	_configure_maze_nav(info, ts)

	if puppy.has_method("set_coat_index"):
		puppy.set_coat_index(_save.coat_index)

	puppy_base_speed = puppy.speed if "speed" in puppy else 6.0
	_apply_meta_upgrades()
	puppy.speed = puppy_base_speed

	puppy.global_position = info["start"]
	if puppy.has_method("snap_to_floor"):
		puppy.snap_to_floor()
	_refresh_pup_appearance()
	_apply_follower_collar()

	if follower_squad != null:
		follower_squad.clear()
		follower_squad.max_followers = _compute_max_followers()
		follower_squad.set_snap_mode(_save.get_snap_mode())

	_setup_permanent_companion(info)
	_setup_island_special_pup(info)

	_hide_win_panel()
	_hide_pause_menu()
	_update_level_label()

	if current_level == 0 and not test_mode:
		_set_hint("Level 1 — walk to the blue exit!")
	elif test_mode:
		if has_pen:
			_set_hint("Test maze — key opens rescue room; escort pups to exit.")
		else:
			_set_hint("Test maze — collect key, open door, reach exit.")
	elif has_pen:
		_set_hint("Find the key, then optionally visit the side rescue room!")
	else:
		_set_hint("Find the key, open the door, reach the exit.")
	_apply_island_level_hint()
	if _escort_joined_this_level_start and play_island_id != "":
		var pup_def: Dictionary = IslandCatalogScript.get_special_pup(play_island_id)
		var join_name: String = str(pup_def.get("name", "Special pup"))
		_show_toast("%s is joining this rescue!" % join_name)
	_update_coins_label()
	_update_key_status()


func _physics_process(delta: float) -> void:
	_try_collect_key_near_puppy()
	_try_collect_speed_near_puppy()
	_try_collect_double_boost_near_puppy()
	_try_collect_coin_near_puppy()
	_try_collect_accessory_near_puppy()
	_try_collect_ultra_near_puppy()
	_update_speed_boost()
	ultra_buffs.tick()
	if footprint_trail != null and footprint_trail.has_method("set_rainbow_mode"):
		footprint_trail.set_rainbow_mode(_wants_rainbow_trail())
	_update_boost_label()
	_update_coins_label()
	_try_unlock_door_near_puppy()
	_try_open_pen_near_puppy()
	_try_claim_hidden_pup()
	if follower_squad != null and (
		follower_squad.is_active()
		or follower_squad.has_escort()
		or follower_squad.has_permanent_companion()
	):
		var ultra_mult: float = ultra_buffs.follower_speed_mult()
		follower_squad.tick(
			delta,
			puppy.global_position,
			Vector3.ZERO,
			ultra_mult,
			_save.get_snap_mode()
		)
	if footprint_trail != null and puppy != null:
		footprint_trail.tick(puppy.global_position, puppy.velocity)
	_try_reach_exit_near_puppy()
	if player_input != null:
		player_input.process_movement(delta)
	_update_key_status()


func _update_level_label() -> void:
	if level_label == null:
		return
	var name := "Test maze" if test_mode else "Level %d" % (current_level + 1)
	if not test_mode and play_island_id != "":
		var island_def: Dictionary = IslandCatalogScript.get_island(play_island_id)
		var island_name: String = str(island_def.get("name", play_island_id))
		name = "%s %d/%d" % [island_name, play_local_level + 1, IslandCatalogScript.level_count(play_island_id)]
		if play_replay:
			name += " (replay)"
	var leader := _save.get_pup_name()
	var mode := DifficultyConfigScript.mode_label(_save.get_difficulty_mode())
	level_label.text = "%s  |  %s  |  %s  |  Rescued: %d" % [name, mode, leader, _save.total_rescued]
	_update_progress_ui()


func _update_coins_label() -> void:
	if coins_label == null:
		return
	coins_label.text = "Coins: %d (+%d)" % [_save.treat_coins, coins_this_level]


func _setup_pup_appearance() -> void:
	if pup_appearance != null and is_instance_valid(pup_appearance):
		return
	pup_appearance = PupAppearanceScript.new()
	pup_appearance.name = "PupAppearance"
	if puppy != null:
		var mount: Node3D = puppy.get_model_node() if puppy.has_method("get_model_node") else null
		if mount != null:
			pup_appearance.mount_to(mount)
		else:
			puppy.add_child(pup_appearance)


func _refresh_pup_appearance() -> void:
	_setup_pup_appearance()
	if pup_appearance != null:
		if puppy != null and puppy.has_method("get_model_node"):
			var mount: Node3D = puppy.get_model_node()
			if mount != null:
				pup_appearance.mount_to(mount)
		pup_appearance.apply_loadout(_save.equipped)


func _apply_follower_collar() -> void:
	if follower_squad == null:
		return
	var collar_id: String = _save.get_equipped("collar")
	if follower_squad.has_method("set_collar_accessory"):
		follower_squad.set_collar_accessory(collar_id)


func _compute_max_followers() -> int:
	var cap: int = ProgressionConfigScript.BASE_SQUAD_CAP \
		+ run_squad_bonus \
		+ int(_save.get_upgrade_value("max_followers", 0.0))
	return mini(cap, ProgressionConfigScript.SQUAD_HARD_CAP)


func _wants_rainbow_trail() -> bool:
	return _save.has_rainbow_trail() or ultra_buffs.wants_rainbow_trail()


func _compute_pen_release_count() -> int:
	var shop_bonus: int = int(_save.get_upgrade_value("max_followers", 0.0))
	var base_count: int = pen_pup_base if pen_pup_base > 0 else ProgressionConfigScript.PEN_PUP_MIN
	return mini(
		ProgressionConfigScript.pen_release_count(base_count, shop_bonus, run_squad_bonus),
		_compute_max_followers()
	)


func _spawn_waiting_pups_in_room(info: Dictionary) -> void:
	_clear_waiting_pups_in_room()
	if not has_pen or pen_opened:
		return
	rescue_room_root = info.get("rescue_room_root") as Node3D
	var cells: Array = info.get("pen_cells", [])
	if cells.is_empty():
		return
	var show_count: int = mini(_compute_pen_release_count(), cells.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed ^ (current_level * 4423)
	for i in show_count:
		var cell_pos: Vector3 = cells[i]
		var nav: MazeNav = puppy.get_nav() if puppy != null and puppy.has_method("get_nav") else null
		var start_pos: Vector3 = _info_vec3(info, "start")
		if nav != null:
			cell_pos = _resolve_pup_spawn(
				nav,
				cell_pos,
				_follower_floor_y(),
				start_pos if start_pos != Vector3.ZERO else puppy.global_position,
				true,
				false,
				"rescue_room_marker"
			)
		var offset := Vector3(
			rng.randf_range(-0.12, 0.12),
			0.0,
			rng.randf_range(-0.12, 0.12)
		)
		var pup := _make_waiting_pup_marker(cell_pos + offset, i)
		if rescue_room_root != null:
			rescue_room_root.add_child(pup)
		else:
			maze_root.add_child(pup)
		rescue_room_pups.append(pup)


func _make_waiting_pup_marker(pos: Vector3, index: int) -> Node3D:
	var node := Node3D.new()
	node.name = "WaitingPup_%d" % index
	var mesh := MeshInstance3D.new()
	var mesh_res: Mesh = load(PupColorsScript.MESH_PATH) as Mesh
	if mesh_res != null:
		mesh.mesh = mesh_res
	mesh.scale = PupColorsScript.scaled_body(0.36)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PupColorsScript.get_color(index)
	mat.roughness = 0.85
	mat.emission_enabled = true
	mat.emission = mat.albedo_color * 0.2
	mesh.material_override = mat
	if mesh.mesh != null:
		for s in range(mesh.mesh.get_surface_count()):
			mesh.set_surface_override_material(s, mat)
	node.add_child(mesh)
	node.position = pos + Vector3(0.0, 0.2, 0.0)
	node.rotation.y = float(index) * 0.9
	return node


func _clear_waiting_pups_in_room() -> void:
	for pup in rescue_room_pups:
		if is_instance_valid(pup):
			pup.queue_free()
	rescue_room_pups.clear()
	rescue_room_root = null


func _apply_meta_upgrades() -> void:
	var base: float = 6.0 if not ("speed" in puppy) else float(puppy.get("speed"))
	puppy_base_speed = base * _save.get_upgrade_mult("speed_mult", 1.0)
	speed_boost_duration = 10.0 + _save.get_upgrade_value("speed_boost_duration", 0.0)
	if follower_squad != null:
		follower_squad.max_followers = _compute_max_followers()
	if footprint_trail != null and footprint_trail.has_method("set_rainbow_mode"):
		footprint_trail.set_rainbow_mode(_wants_rainbow_trail())


func _award_level_coins() -> Dictionary:
	var breakdown: Dictionary = {}
	var total: int = 0
	var base: int = ProgressionConfigScript.COINS_LEVEL_COMPLETE
	breakdown["complete"] = base
	total += base
	var per_rescue: int = ProgressionConfigScript.COINS_PER_RESCUE + int(_save.get_upgrade_value("coin_per_rescue", 0.0))
	var rescue_coins: int = _temporary_rescues_this_level() * per_rescue
	breakdown["rescues"] = rescue_coins
	total += rescue_coins
	breakdown["pickups"] = coins_this_level
	total += coins_this_level
	_save.add_coins(total)
	_last_coin_summary = "+%d (+%d rescues, +%d found)" % [total, rescue_coins, coins_this_level]
	return breakdown


func _add_coins_this_level(amount: int) -> void:
	if amount <= 0:
		return
	coins_this_level += amount
	_update_coins_label()


func _purchase_shop_item(item_type: String, item_id: String) -> void:
	match item_type:
		"accessory":
			var entry: Dictionary = AccessoryCatalogScript.get_entry(item_id)
			if entry.is_empty() or _save.owns_accessory(item_id):
				return
			var cost: int = int(entry.get("cost", 0))
			if not _save.spend_coins(cost):
				_set_hint("Not enough Treat Coins!")
				return
			_save.unlock_accessory(item_id)
			var slot: String = entry.get("slot", "")
			if _save.get_equipped(slot) == "":
				_save.equip_accessory(slot, item_id)
			_refresh_pup_appearance()
			_apply_follower_collar()
			SfxManager.play_shop_buy()
			_save.save_game()
		"upgrade":
			var uentry: Dictionary = UpgradeCatalogScript.get_entry(item_id)
			if uentry.is_empty() or _save.owns_upgrade(item_id):
				return
			var ucost: int = int(uentry.get("cost", 0))
			if not _save.spend_coins(ucost):
				_set_hint("Not enough Treat Coins!")
				return
			_save.unlock_upgrade(item_id)
			_apply_meta_upgrades()
			puppy.speed = puppy_base_speed
			SfxManager.play_shop_buy()
			_save.save_game()
		"equip":
			var e: Dictionary = AccessoryCatalogScript.get_entry(item_id)
			if e.is_empty() or not _save.owns_accessory(item_id):
				return
			var slot: String = e.get("slot", "")
			_save.equip_accessory(slot, item_id)
			_save.save_game()
			_refresh_pup_appearance()
			_apply_follower_collar()
		"equip_clear":
			_save.equip_accessory(item_id, "")
			_save.save_game()
			_refresh_pup_appearance()
			_apply_follower_collar()
	if shop_panel != null:
		shop_panel.refresh()


func _spawn_coin_pickups_if_present(info: Dictionary) -> void:
	coin_nodes.clear()
	if not info.has("coins"):
		return
	for pos: Vector3 in info.coins:
		var node := _make_marker("CoinMarker", pos + Vector3(0.0, 0.28, 0.0), Color(1.0, 0.85, 0.2), 0.1, 0.18)
		coin_nodes.append(node)
		_add_pickup_area(node, 0.36, _on_coin_body_entered)


func _spawn_accessory_pickups_if_present(info: Dictionary) -> void:
	accessory_nodes.clear()
	_accessory_pickup_ids.clear()
	if not info.has("accessories"):
		return
	var idx := 0
	for pos: Vector3 in info.accessories:
		var acc_id: String = AccessoryCatalogScript.random_shop_id(_save.owned_accessories)
		var entry: Dictionary = AccessoryCatalogScript.get_entry(acc_id)
		var col: Color = Color.from_string(str(entry.get("color", "#E878A8")), Color(0.9, 0.5, 0.8))
		var node := _make_marker("AccessoryMarker", pos + Vector3(0.0, 0.34, 0.0), col, 0.13, 0.24)
		accessory_nodes.append(node)
		_accessory_pickup_ids[node] = acc_id
		_add_pickup_area(node, 0.4, _on_accessory_body_entered)
		idx += 1


func _spawn_ultra_pickups_if_present(info: Dictionary) -> void:
	ultra_nodes.clear()
	_ultra_pickup_ids.clear()
	if not info.has("ultra"):
		return
	for pos: Vector3 in info.ultra:
		var ultra_id: String = UltraPowerupCatalogScript.random_id()
		var entry: Dictionary = UltraPowerupCatalogScript.get_entry(ultra_id)
		var col: Color = Color.from_string(str(entry.get("color", "#FFD700")), Color(1.0, 0.85, 0.3))
		var node := _make_marker("UltraMarker", pos + Vector3(0.0, 0.38, 0.0), col, 0.15, 0.28)
		ultra_nodes.append(node)
		_ultra_pickup_ids[node] = ultra_id
		_add_pickup_area(node, 0.44, _on_ultra_body_entered)


func _on_coin_body_entered(body: Node) -> void:
	if body == puppy:
		_try_collect_coin_near_puppy()


func _try_collect_coin_near_puppy() -> void:
	if puppy == null:
		return
	var nearest: Node3D = null
	var nearest_dist: float = pickup_radius + 1.0
	for node in coin_nodes:
		if not is_instance_valid(node):
			continue
		var dist: float = _flat_distance(puppy.global_position, node.global_position)
		if dist <= pickup_radius and dist < nearest_dist:
			nearest_dist = dist
			nearest = node
	if nearest != null:
		_collect_coin_node(nearest)


func _collect_coin_node(node: Node3D) -> void:
	if node == null or not coin_nodes.has(node):
		return
	coin_nodes.erase(node)
	var burst_pos: Vector3 = node.global_position
	node.queue_free()
	_add_coins_this_level(ProgressionConfigScript.COINS_PICKUP_C)
	SfxManager.play_coin()
	_burst_at(burst_pos, Color(1.0, 0.88, 0.2))
	_set_hint("+%d Treat Coins!" % ProgressionConfigScript.COINS_PICKUP_C)


func _on_accessory_body_entered(body: Node) -> void:
	if body == puppy:
		_try_collect_accessory_near_puppy()


func _try_collect_accessory_near_puppy() -> void:
	if puppy == null:
		return
	var nearest: Node3D = null
	var nearest_dist: float = pickup_radius + 1.0
	for node in accessory_nodes:
		if not is_instance_valid(node):
			continue
		var dist: float = _flat_distance(puppy.global_position, node.global_position)
		if dist <= pickup_radius and dist < nearest_dist:
			nearest_dist = dist
			nearest = node
	if nearest != null:
		_collect_accessory_node(nearest)


func _collect_accessory_node(node: Node3D) -> void:
	if node == null or not accessory_nodes.has(node):
		return
	var acc_id: String = str(_accessory_pickup_ids.get(node, ""))
	accessory_nodes.erase(node)
	_accessory_pickup_ids.erase(node)
	var burst_pos: Vector3 = node.global_position
	node.queue_free()
	var entry: Dictionary = AccessoryCatalogScript.get_entry(acc_id)
	if acc_id == "" or entry.is_empty():
		return
	if _save.owns_accessory(acc_id):
		_add_coins_this_level(ProgressionConfigScript.COINS_DUPLICATE_ACCESSORY)
		_set_hint("Duplicate! +%d coins" % ProgressionConfigScript.COINS_DUPLICATE_ACCESSORY)
	else:
		_save.unlock_accessory(acc_id)
		var slot: String = entry.get("slot", "")
		_save.equip_accessory(slot, acc_id)
		_save.add_coins(ProgressionConfigScript.COINS_FIRST_FIND_BONUS)
		_refresh_pup_appearance()
		_apply_follower_collar()
		_set_hint("New %s equipped!" % entry.get("name", acc_id))
	_save.save_game()
	SfxManager.play_shop_buy()
	_burst_at(burst_pos, Color.from_string(str(entry.get("color", "#E878A8")), Color.PINK))


func _on_ultra_body_entered(body: Node) -> void:
	if body == puppy:
		_try_collect_ultra_near_puppy()


func _try_collect_ultra_near_puppy() -> void:
	if puppy == null:
		return
	var nearest: Node3D = null
	var nearest_dist: float = pickup_radius + 1.0
	for node in ultra_nodes:
		if not is_instance_valid(node):
			continue
		var dist: float = _flat_distance(puppy.global_position, node.global_position)
		if dist <= pickup_radius and dist < nearest_dist:
			nearest_dist = dist
			nearest = node
	if nearest != null:
		_collect_ultra_node(nearest)


func _collect_ultra_node(node: Node3D) -> void:
	if node == null or not ultra_nodes.has(node):
		return
	var ultra_id: String = str(_ultra_pickup_ids.get(node, ""))
	ultra_nodes.erase(node)
	_ultra_pickup_ids.erase(node)
	var burst_pos: Vector3 = node.global_position
	node.queue_free()
	var entry: Dictionary = ultra_buffs.apply(ultra_id)
	if entry.is_empty():
		return
	if footprint_trail != null:
		footprint_trail.set_rainbow_mode(_wants_rainbow_trail())
	SfxManager.play_ultra()
	_burst_at(burst_pos, Color.from_string(str(entry.get("color", "#FFD700")), Color.GOLD))
	_set_hint("Ultra: %s!" % entry.get("name", ultra_id))
	_update_boost_label()


func fit_floor_to_level(lines: PackedStringArray, tile_size: float, margin_tiles: float = 2.0) -> void:
	var cols: int = lines[0].length()
	var rows: int = lines.size()
	var w: float = (float(cols) + margin_tiles) * tile_size
	var h: float = (float(rows) + margin_tiles) * tile_size
	var center: Vector3 = Vector3((cols - 1) * 0.5 * tile_size, 0.0, (rows - 1) * 0.5 * tile_size)
	var pm := floor_mesh.mesh as PlaneMesh
	if pm != null:
		pm.size = Vector2(w, h)
	_apply_grass_floor_material(cols, rows, tile_size)
	floor_body.global_position = center
	var bs := floor_collision.shape as BoxShape3D
	if bs == null:
		bs = BoxShape3D.new()
		floor_collision.shape = bs
	bs.size = Vector3(w, 0.1, h)


func _apply_grass_floor_material(cols: int, rows: int, tile_size: float) -> void:
	var tile_px: int = 32
	var tex_w: int = cols * tile_px
	var tex_h: int = rows * tile_px
	var img := Image.create(tex_w, tex_h, false, Image.FORMAT_RGB8)
	var grass_a := Color(0.44, 0.66, 0.34)
	var grass_b := Color(0.38, 0.58, 0.30)
	var grass_light := Color(0.52, 0.74, 0.40)
	var grass_dark := Color(0.32, 0.48, 0.26)
	for y in tex_h:
		for x in tex_w:
			var tx: int = x / tile_px
			var ty: int = y / tile_px
			var c: Color = grass_a if (tx + ty) % 2 == 0 else grass_b
			var speck: int = (x * 7 + y * 13 + tx * 5 + ty * 11) % 17
			if speck == 0:
				c = grass_light
			elif speck == 1 or speck == 2:
				c = grass_dark
			elif speck == 3:
				c = c.lightened(0.05)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.92
	floor_mesh.material_override = mat


func _apply_checker_floor_material(cols: int, rows: int, tile_size: float) -> void:
	_apply_grass_floor_material(cols, rows, tile_size)


# --- Pickups ---

func _spawn_key_if_present(info: Dictionary) -> void:
	if not info.has("key") or info.key == null:
		return
	key_node = _make_key_pickup(info.key + Vector3(0.0, 0.3, 0.0))
	key_area = _add_pickup_area(key_node, 0.35, _on_key_body_entered)


func _spawn_exit_if_present(info: Dictionary) -> void:
	if not info.has("exit") or info.exit == null:
		return
	exit_node = _make_marker("ExitMarker", info.exit + Vector3(0.0, 0.25, 0.0), Color(0.2, 0.6, 1.0), 0.18, 0.35, true)
	exit_area = _add_pickup_area(exit_node, 0.45, _on_exit_body_entered)


func _spawn_speed_pickups_if_present(info: Dictionary) -> void:
	speed_nodes.clear()
	if not info.has("fruit"):
		return
	var marker_scale: float = _powerup_marker_scale(current_level)
	for pos: Vector3 in info.fruit:
		var node := _make_star_pickup(
			pos + Vector3(0.0, 0.32 * marker_scale, 0.0),
			marker_scale
		)
		speed_nodes.append(node)
		_add_pickup_area(node, 0.38 * marker_scale, _on_speed_body_entered)


func _spawn_double_boost_pickups_if_present(info: Dictionary) -> void:
	double_boost_nodes.clear()
	if not info.has("double_boost"):
		return
	var marker_scale: float = _powerup_marker_scale(current_level) * 1.12
	for pos: Vector3 in info.double_boost:
		var node := _make_heart_pickup(
			pos + Vector3(0.0, 0.34 * marker_scale, 0.0),
			marker_scale
		)
		double_boost_nodes.append(node)
		_add_pickup_area(node, 0.42 * marker_scale, _on_double_boost_body_entered)


func _powerup_marker_scale(level_index: int) -> float:
	return DifficultyConfigScript.powerup_marker_scale(level_index, _save.get_difficulty_mode())


func _make_marker(marker_name: String, pos: Vector3, color: Color, radius: float, height: float, box: bool = false) -> Node3D:
	var node := Node3D.new()
	node.name = marker_name
	node.position = pos
	maze_root.add_child(node)
	var mesh := MeshInstance3D.new()
	if box:
		var b := BoxMesh.new()
		b.size = Vector3(radius * 2.0, height, radius * 2.0)
		mesh.mesh = b
	else:
		var c := CylinderMesh.new()
		c.top_radius = radius
		c.bottom_radius = radius
		c.height = height
		mesh.mesh = c
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	node.add_child(mesh)
	return node


func _make_key_pickup(pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = "KeyMarker"
	node.position = pos
	maze_root.add_child(node)
	var gold := Color(1.0, 0.88, 0.15)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = gold
	mat.emission_enabled = true
	mat.emission = gold * 0.35
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.06
	torus.outer_radius = 0.13
	torus.rings = 12
	torus.ring_segments = 18
	ring.mesh = torus
	ring.material_override = mat
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	node.add_child(ring)
	var shank := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.2, 0.035, 0.035)
	shank.mesh = bar
	shank.material_override = mat
	shank.position = Vector3(0.16, 0.0, 0.0)
	node.add_child(shank)
	return node


func _make_star_pickup(pos: Vector3, scale: float) -> Node3D:
	var node := Node3D.new()
	node.name = "SpeedMarker"
	node.position = pos
	maze_root.add_child(node)
	var col := Color(1.0, 0.82, 0.12)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col * 0.45
	var s: float = 0.22 * scale
	for i in range(4):
		var arm := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(s * 0.32, s * 0.1, s)
		arm.mesh = box
		arm.material_override = mat
		arm.rotation_degrees = Vector3(0.0, float(i) * 45.0, 0.0)
		node.add_child(arm)
	var center := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = s * 0.18
	sphere.height = s * 0.22
	center.mesh = sphere
	center.material_override = mat
	node.add_child(center)
	return node


func _make_heart_pickup(pos: Vector3, scale: float) -> Node3D:
	var node := Node3D.new()
	node.name = "DoubleBoostMarker"
	node.position = pos
	maze_root.add_child(node)
	var col := Color(0.95, 0.28, 0.42)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col * 0.4
	var s: float = 0.2 * scale
	for side in [-1.0, 1.0]:
		var lobe := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = s * 0.42
		sphere.height = s * 0.72
		lobe.mesh = sphere
		lobe.material_override = mat
		lobe.position = Vector3(side * s * 0.28, s * 0.12, 0.0)
		node.add_child(lobe)
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = s * 0.52
	cone.height = s * 0.55
	tip.mesh = cone
	tip.material_override = mat
	tip.position = Vector3(0.0, -s * 0.18, 0.0)
	node.add_child(tip)
	return node


func _add_pickup_area(parent: Node3D, radius: float, handler: Callable) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = LAYER_PLAYER
	area.monitoring = true
	parent.add_child(area)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(handler)
	return area


func _spawn_door_if_present(info: Dictionary) -> void:
	if not info.has("door") or info.door == null:
		return
	door_body = info.get("door_body") as StaticBody3D
	if door_body == null:
		return
	door_unlock_center = door_body.global_position
	_refresh_dynamic_blockers()
	door_area = Area3D.new()
	door_area.collision_mask = LAYER_PLAYER
	door_area.monitoring = true
	door_body.add_child(door_area)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = door_unlock_radius
	col.shape = shape
	door_area.add_child(col)
	door_area.body_entered.connect(_on_door_body_entered)


func _on_key_body_entered(body: Node) -> void:
	if body == puppy:
		_collect_key()


func _try_collect_key_near_puppy() -> void:
	if has_key or key_node == null or puppy == null:
		return
	if _near(puppy.global_position, key_node.global_position):
		_collect_key()


func _collect_key() -> void:
	if has_key:
		return
	has_key = true
	_update_key_status()
	SfxManager.play_key()
	var burst_pos: Vector3 = key_node.global_position if key_node else puppy.global_position
	_burst_at(burst_pos, Color(1.0, 0.9, 0.2))
	if key_node:
		key_node.queue_free()
	key_node = null
	key_area = null
	if has_pen:
		_set_hint("Key collected! Open the rescue room gate.")
	else:
		_set_hint("Key collected! Touch the door.")
	_try_unlock_door_near_puppy()
	_try_open_pen_near_puppy()


func _on_speed_body_entered(body: Node) -> void:
	if body == puppy:
		_try_collect_speed_near_puppy()


func _try_collect_speed_near_puppy() -> void:
	if puppy == null:
		return
	var nearest: Node3D = null
	var nearest_dist: float = pickup_radius + 1.0
	for node in speed_nodes:
		if not is_instance_valid(node):
			continue
		var dist: float = _flat_distance(puppy.global_position, node.global_position)
		if dist <= pickup_radius and dist < nearest_dist:
			nearest_dist = dist
			nearest = node
	if nearest != null:
		_collect_speed_node(nearest)


func _collect_speed_node(node: Node3D) -> void:
	if node == null or not speed_nodes.has(node):
		return
	speed_nodes.erase(node)
	var burst_pos: Vector3 = node.global_position
	node.queue_free()
	_apply_speed_boost()
	SfxManager.play_fruit()
	_burst_at(burst_pos, Color(0.95, 0.55, 0.1))
	_set_hint("Speed boost! +%.0fs (stackable)." % speed_boost_duration)


func _on_double_boost_body_entered(body: Node) -> void:
	if body == puppy:
		_try_collect_double_boost_near_puppy()


func _try_collect_double_boost_near_puppy() -> void:
	if puppy == null:
		return
	var nearest: Node3D = null
	var nearest_dist: float = pickup_radius + 1.0
	for node in double_boost_nodes:
		if not is_instance_valid(node):
			continue
		var dist: float = _flat_distance(puppy.global_position, node.global_position)
		if dist <= pickup_radius and dist < nearest_dist:
			nearest_dist = dist
			nearest = node
	if nearest != null:
		_collect_double_boost_node(nearest)


func _collect_double_boost_node(node: Node3D) -> void:
	if node == null or not double_boost_nodes.has(node):
		return
	double_boost_nodes.erase(node)
	var burst_pos: Vector3 = node.global_position
	node.queue_free()
	_apply_double_rescue_boost()
	run_squad_bonus += ProgressionConfigScript.DOUBLE_BOOST_SQUAD_BONUS
	_apply_meta_upgrades()
	SfxManager.play_double_boost()
	_burst_at(burst_pos, Color(0.75, 0.45, 1.0))
	_set_hint("Squad boost! +1 rescue room cap (up to %d pups)" % _compute_max_followers())


func _apply_speed_boost() -> void:
	if puppy == null:
		return
	var now: int = Time.get_ticks_msec()
	var remaining_ms: int = maxi(0, speed_boost_until_ms - now)
	speed_boost_until_ms = now + remaining_ms + int(speed_boost_duration * 1000.0)
	puppy.speed = puppy_base_speed * speed_boost_multiplier
	_update_boost_label()


func _apply_double_rescue_boost() -> void:
	double_rescue_until_ms = Time.get_ticks_msec() + int(double_rescue_duration * 1000.0)
	_update_boost_label()


func _update_speed_boost() -> void:
	if puppy == null or speed_boost_until_ms <= 0:
		return
	if Time.get_ticks_msec() >= speed_boost_until_ms:
		speed_boost_until_ms = 0
		puppy.speed = puppy_base_speed


func _is_speed_boost_active() -> bool:
	return speed_boost_until_ms > 0 and Time.get_ticks_msec() < speed_boost_until_ms


func _is_double_rescue_active() -> bool:
	return double_rescue_until_ms > 0 and Time.get_ticks_msec() < double_rescue_until_ms


func _speed_boost_seconds_left() -> float:
	if not _is_speed_boost_active():
		return 0.0
	return float(speed_boost_until_ms - Time.get_ticks_msec()) / 1000.0


func _double_rescue_seconds_left() -> float:
	if not _is_double_rescue_active():
		return 0.0
	return float(double_rescue_until_ms - Time.get_ticks_msec()) / 1000.0


func _update_boost_label() -> void:
	if boost_label == null:
		return
	var parts: PackedStringArray = PackedStringArray()
	if _is_speed_boost_active():
		parts.append("Speed: %.1fs" % _speed_boost_seconds_left())
	if _is_double_rescue_active():
		parts.append("Squad cap +1: %.1fs" % _double_rescue_seconds_left())
	for label: String in ultra_buffs.active_labels():
		parts.append(label)
	if parts.is_empty():
		boost_label.visible = false
		return
	boost_label.visible = true
	boost_label.text = "  |  ".join(parts)


func _configure_maze_nav(info: Dictionary, ts: float) -> void:
	if puppy == null or not puppy.has_method("get_nav"):
		return
	var nav: MazeNav = puppy.get_nav()
	if nav == null:
		return
	nav.set_static_blockers(info.get("pen_wall_blockers", []))
	if has_pen:
		var pen_tiles: Array[Vector2i] = []
		for p: Variant in info.get("pen_cells", []):
			if p is Vector3:
				pen_tiles.append(Vector2i(int(round((p as Vector3).x / ts)), int(round((p as Vector3).z / ts))))
		if info.get("pen_gate_cell") is Vector2i:
			pen_gate_cell = info.pen_gate_cell as Vector2i
		else:
			pen_gate_cell = Vector2i(-1, -1)
			if info.get("pen_gate") is Vector3:
				var g: Vector3 = info.pen_gate as Vector3
				pen_gate_cell = Vector2i(int(round(g.x / ts)), int(round(g.z / ts)))
		if pen_gate_cell.x >= 0:
			pen_gate_center = nav.tile_center(pen_gate_cell.x, pen_gate_cell.y, 0.0)
		nav.configure_rescue_door(pen_gate_cell, pen_opened)
		nav.configure_sealed_pen(pen_tiles, pen_gate_cell, not pen_opened)
	_refresh_dynamic_blockers()


func _follower_floor_y() -> float:
	var floor_y: float = 0.24
	if puppy != null and puppy.has_method("_capsule_half_height"):
		floor_y = puppy._capsule_half_height() * 0.55
	return floor_y


func _temporary_rescues_this_level() -> int:
	return _session.temporary_rescues_this_level


func _sync_session_rescue_count() -> void:
	if follower_squad != null:
		_session.sync_temporary_rescue_count_from_squad(follower_squad)


func _validate_session_tracking(context: String) -> void:
	if follower_squad == null:
		return
	_sync_session_rescue_count()
	var errors: PackedStringArray = _session.validate_no_double_count(follower_squad)
	if errors.is_empty():
		return
	for err: String in errors:
		push_warning("[%s] %s" % [context, err])
		if debug_enabled or island_pup_debug:
			_pup_debug("SESSION VALIDATION: %s" % err)


func _pup_debug(message: String) -> void:
	if island_pup_debug:
		print("[IslandPup] ", message)


func _clear_hidden_pup() -> void:
	if hidden_pup_node != null and is_instance_valid(hidden_pup_node):
		hidden_pup_node.queue_free()
	hidden_pup_node = null


func _resolve_pup_spawn(
	nav: MazeNav,
	requested: Vector3,
	floor_y: float,
	reach_from: Vector3,
	allow_sealed_pen_interior: bool,
	require_reachable: bool,
	role_label: String,
	entity_id: String = ""
) -> Vector3:
	var result: Dictionary = nav.find_safe_spawn_position(
		requested,
		floor_y,
		reach_from,
		allow_sealed_pen_interior,
		require_reachable
	)
	if bool(result.get("corrected", false)) and (island_pup_debug or debug_enabled):
		push_warning(
			"Pup spawn corrected [%s] island=%s level=%d id=%s reason=%s requested=%s corrected=%s"
			% [
				role_label,
				play_island_id,
				play_local_level,
				entity_id,
				str(result.get("reason", "")),
				str(result.get("requested", requested)),
				str(result.get("position", requested)),
			]
		)
	return result.get("position", requested) as Vector3


func _apply_island_level_hint() -> void:
	if test_mode or play_island_id == "":
		return
	var pup_def: Dictionary = IslandCatalogScript.get_special_pup(play_island_id)
	if pup_def.is_empty():
		return
	var pup_name: String = str(pup_def.get("name", "Special pup"))
	if _save.is_special_pup_found(play_island_id):
		if _had_home_island_pup_present():
			if _save.is_island_companion_unlocked(play_island_id):
				_set_hint("Bring your companion to earn any missing escort badges!")
			else:
				_set_hint("%s is escorting you — finish the level to earn an escort badge!" % pup_name)
		return
	var hidden_idx: int = IslandCatalogScript.hidden_level_index(play_island_id)
	if play_local_level == hidden_idx:
		_set_hint("Find %s hidden somewhere on this level!" % pup_name)


func _island_special_companion_id() -> String:
	if play_island_id == "":
		return ""
	var companion: CompanionDefinition = ProgressionRegistryScript.get_special_companion(play_island_id)
	return companion.companion_id if companion != null else ""


func _setup_permanent_companion(_info: Dictionary) -> void:
	if test_mode or follower_squad == null:
		return
	var selected_id: String = _save.selected_companion_id
	if selected_id == "" or not _save.owns_companion(selected_id):
		return
	var companion: CompanionDefinition = ProgressionRegistryScript.get_companion(selected_id)
	if companion == null:
		return
	var nav: MazeNav = puppy.get_nav() if puppy.has_method("get_nav") else null
	var floor_y: float = _follower_floor_y()
	if nav == null:
		return
	if follower_squad.has_permanent_companion():
		return
	var offset := Vector3(-0.55, 0.0, 0.25)
	var requested: Vector3 = puppy.global_position + offset
	var spawn_pos: Vector3 = _resolve_pup_spawn(
		nav,
		requested,
		floor_y,
		puppy.global_position,
		false,
		true,
		"permanent_companion",
		selected_id
	)
	var collar_id: String = _save.get_companion_equipped(selected_id, "collar")
	var spawned: bool = follower_squad.spawn_permanent_companion(
		spawn_pos,
		nav,
		floor_y,
		$World/ActorsRoot,
		selected_id,
		companion.coat_index,
		puppy.global_position,
		collar_id
	)
	if spawned:
		_session.register_permanent_companion(selected_id)
		if selected_id == _island_special_companion_id():
			_session.register_island_escort()
		var companion_node: Node3D = follower_squad.get_permanent_companion()
		if companion_node != null and companion_node.has_method("apply_companion_loadout"):
			companion_node.call("apply_companion_loadout", _save, selected_id)
		_pup_debug("Permanent companion %s spawned" % selected_id)


func _should_spawn_island_escort(special_companion_id: String) -> bool:
	if play_island_id == "" or not _save.is_special_pup_found(play_island_id):
		return false
	if _save.is_island_companion_unlocked(play_island_id):
		return false
	if special_companion_id == "":
		return true
	if follower_squad.has_permanent_companion():
		return follower_squad.get_permanent_companion_id() != special_companion_id
	return true


func _setup_island_special_pup(info: Dictionary) -> void:
	if test_mode or play_island_id == "" or follower_squad == null:
		return
	var pup_def: Dictionary = IslandCatalogScript.get_special_pup(play_island_id)
	if pup_def.is_empty():
		return
	var coat_index: int = int(pup_def.get("coat_index", 0))
	var pup_name: String = str(pup_def.get("name", "Special pup"))
	var nav: MazeNav = puppy.get_nav() if puppy.has_method("get_nav") else null
	var floor_y: float = _follower_floor_y()
	if nav == null:
		return
	if follower_squad.has_island_escort():
		_pup_debug("Escort already active — skip spawn")
		return
	var special_companion_id: String = _island_special_companion_id()
	if _should_spawn_island_escort(special_companion_id):
		if _special_pup_rescued_this_run or _save.is_special_pup_found(play_island_id):
			var hidden_idx: int = IslandCatalogScript.hidden_level_index(play_island_id)
			if _save.is_special_pup_found(play_island_id) or (
				play_local_level == hidden_idx and _special_pup_rescued_this_run
			):
				_pup_debug("Spawning ISLAND_ESCORT for badge progression")
				_spawn_island_escort_at_start(nav, floor_y, coat_index, pup_name)
				return
	if _save.is_special_pup_found(play_island_id):
		return
	var hidden_idx: int = IslandCatalogScript.hidden_level_index(play_island_id)
	if play_local_level != hidden_idx:
		return
	if _special_pup_rescued_this_run:
		_pup_debug("Discovery level retry — spawning rescued ISLAND_ESCORT at start")
		_spawn_island_escort_at_start(nav, floor_y, coat_index, pup_name)
		return
	var start_pos: Vector3 = info.get("start", puppy.global_position)
	var exit_pos: Vector3 = _info_vec3(info, "exit")
	if exit_pos == Vector3.ZERO and exit_node != null:
		exit_pos = exit_node.global_position
	var hidden_pos: Vector3 = _pick_hidden_pup_position(nav, floor_y, start_pos, exit_pos)
	if hidden_pos == Vector3.ZERO:
		_pup_debug("No hidden pup position found on discovery level")
		return
	var hidden := Node3D.new()
	hidden.name = "HiddenSpecialPup"
	hidden.set_script(SpecialPupScript)
	maze_root.add_child(hidden)
	hidden.call("setup", hidden_pos, floor_y, coat_index, pup_name)
	hidden_pup_node = hidden
	_pup_debug("Spawned discoverable special pup at %s on level %d" % [hidden_pos, play_local_level])


func _spawn_island_escort_at_start(nav: MazeNav, floor_y: float, coat_index: int, pup_name: String) -> void:
	if follower_squad == null or follower_squad.has_island_escort():
		return
	var offset := Vector3(-0.8, 0.0, 0.35)
	var requested: Vector3 = puppy.global_position + offset
	var spawn_pos: Vector3 = _resolve_pup_spawn(
		nav,
		requested,
		floor_y,
		puppy.global_position,
		false,
		true,
		"island_escort",
		_island_special_companion_id()
	)
	var spawned: bool = follower_squad.spawn_island_escort(
		spawn_pos,
		nav,
		floor_y,
		$World/ActorsRoot,
		coat_index,
		puppy.global_position
	)
	if spawned:
		_session.register_island_escort()
		_escort_joined_this_level_start = true
		_pup_debug("%s spawned as ISLAND_ESCORT at level start" % pup_name)
	else:
		_pup_debug("Failed to spawn ISLAND_ESCORT for %s" % pup_name)


func _pick_hidden_pup_position(
	nav: MazeNav,
	floor_y: float,
	start_pos: Vector3,
	exit_pos: Vector3
) -> Vector3:
	if nav == null or nav.lines.is_empty():
		return Vector3.ZERO
	var ts: float = nav.tile_size
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed ^ (play_local_level * 9187) ^ 7717
	var candidates: Array[Vector3] = []
	for z in range(nav.rows):
		for x in range(nav.cols):
			if not nav.is_spawn_cell_walkable(x, z, false):
				continue
			if not nav.can_reach_spawn_cell(start_pos, x, z, floor_y):
				continue
			var pos: Vector3 = nav.tile_center(x, z, floor_y)
			if _flat_distance(pos, start_pos) < ts * 3.5:
				continue
			candidates.append(pos)
	if candidates.is_empty():
		return Vector3.ZERO
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		var score_a: float = _flat_distance(a, start_pos) + _flat_distance(a, exit_pos) * 0.35
		var score_b: float = _flat_distance(b, start_pos) + _flat_distance(b, exit_pos) * 0.35
		return score_a > score_b
	)
	var pick: int = mini(rng.randi_range(0, 2), candidates.size() - 1)
	return _resolve_pup_spawn(
		nav,
		candidates[pick],
		floor_y,
		start_pos,
		false,
		true,
		"special_discovery",
		_island_special_companion_id()
	)


func _try_claim_hidden_pup() -> void:
	if hidden_pup_node == null or not is_instance_valid(hidden_pup_node):
		return
	if not hidden_pup_node.call("can_claim", puppy.global_position):
		return
	var pup_def: Dictionary = IslandCatalogScript.get_special_pup(play_island_id)
	var nav: MazeNav = puppy.get_nav() if puppy.has_method("get_nav") else null
	if nav == null or follower_squad == null:
		return
	if follower_squad.has_island_escort():
		_pup_debug("Hidden pup claimed but escort already exists — removing marker only")
		hidden_pup_node.queue_free()
		hidden_pup_node = null
		return
	var coat_index: int = int(pup_def.get("coat_index", 0))
	var requested: Vector3 = hidden_pup_node.global_position
	var spawn_pos: Vector3 = _resolve_pup_spawn(
		nav,
		requested,
		_follower_floor_y(),
		puppy.global_position,
		false,
		true,
		"island_escort_claim",
		_island_special_companion_id()
	)
	var spawned: bool = follower_squad.spawn_island_escort(
		spawn_pos,
		nav,
		_follower_floor_y(),
		$World/ActorsRoot,
		coat_index,
		puppy.global_position
	)
	if not spawned:
		_pup_debug("Failed to spawn ISLAND_ESCORT from hidden pup claim")
		return
	hidden_pup_node.call("try_claim", puppy.global_position)
	_session.register_island_escort()
	_special_pup_rescued_this_run = true
	hidden_pup_node.queue_free()
	hidden_pup_node = null
	var pup_name: String = str(pup_def.get("name", "Special pup"))
	_pup_debug("%s rescued this run — discovery pending level completion" % pup_name)
	_set_hint("%s joined you! Finish the level to keep them." % pup_name)


func _had_home_island_pup_present() -> bool:
	if play_island_id == "" or follower_squad == null:
		return false
	var special_id: String = _island_special_companion_id()
	if special_id == "":
		return follower_squad.has_island_escort()
	if follower_squad.has_island_escort():
		return true
	if follower_squad.has_permanent_companion():
		return follower_squad.get_permanent_companion_id() == special_id
	return false


func _had_island_escort_this_level() -> bool:
	return _had_home_island_pup_present()


func _would_earn_escort_badge() -> bool:
	if test_mode or play_island_id == "":
		return false
	if not _had_home_island_pup_present():
		return false
	if _save.has_escort_badge(play_island_id, play_local_level):
		return false
	if _save.is_special_pup_found(play_island_id):
		return true
	if _special_pup_rescued_this_run:
		var hidden_idx: int = IslandCatalogScript.hidden_level_index(play_island_id)
		return play_local_level == hidden_idx
	return false


func _would_unlock_companion_after_completion() -> bool:
	if test_mode or play_island_id == "" or _save.is_island_companion_unlocked(play_island_id):
		return false
	if not _save.is_special_pup_found(play_island_id):
		return false
	if not _would_earn_escort_badge():
		return false
	var badges: int = _save.escort_badge_count(play_island_id)
	var level_count: int = IslandCatalogScript.level_count(play_island_id)
	return badges + 1 >= level_count


func _gather_escort_at_exit(exit_pos: Vector3) -> void:
	if follower_squad != null:
		follower_squad.gather_special_followers_to_exit(exit_pos)


func _on_door_body_entered(body: Node) -> void:
	if body == puppy:
		_try_unlock_door()


func _try_unlock_door_near_puppy() -> void:
	if not has_key or door_opened or door_body == null or puppy == null:
		return
	if _near(puppy.global_position, door_unlock_center):
		_try_unlock_door()


func _try_unlock_door() -> void:
	if door_opened or not has_key:
		if not has_key:
			_set_hint("Door is locked. Need the key.")
		return
	_open_door()


func _open_door() -> void:
	door_opened = true
	SfxManager.play_door()
	_burst_at(door_unlock_center, Color(1.0, 0.55, 0.15))
	_refresh_dynamic_blockers()
	if is_instance_valid(door_body):
		door_body.queue_free()
	door_body = null
	door_area = null
	_set_hint("Door opened!")


func _on_exit_body_entered(body: Node) -> void:
	if body == puppy:
		_try_reach_exit()


func _try_reach_exit_near_puppy() -> void:
	if exit_node == null or puppy == null:
		return
	if _near(puppy.global_position, exit_node.global_position):
		_try_reach_exit()


func _try_reach_exit() -> void:
	if level_won:
		return
	if current_level > 0 and not has_key and (info_has_key_door()):
		_set_hint("Need the key first.")
		return
	if has_pen and not pen_opened:
		_set_hint("Open the rescue room with your key first!")
		return
	if exit_node == null or puppy == null:
		return
	var exit_pos: Vector3 = exit_node.global_position
	if not _near(puppy.global_position, exit_pos):
		_exit_wait_start_ms = -1
		return
	var waiting_for_temp: bool = (
		follower_squad != null
		and follower_squad.is_active()
		and follower_squad.count_temporary_rescues() > 0
	)
	if waiting_for_temp:
		if _save.has_exit_roundup() and not _exit_roundup_snapped:
			follower_squad.snap_all_to(exit_pos)
			_exit_roundup_snapped = true
			SfxManager.play_roundup()
			_gather_escort_at_exit(exit_pos)
			_complete_level()
			return
		if _exit_wait_start_ms < 0:
			_exit_wait_start_ms = Time.get_ticks_msec()
		var gathered: int = follower_squad.count_escorted_at(exit_pos, puppy.global_position)
		var total: int = follower_squad.count_temporary_rescues()
		var need: int = follower_squad.required_at_exit_count()
		var elapsed: int = Time.get_ticks_msec() - _exit_wait_start_ms
		if elapsed < EXIT_GRACE_MS:
			_set_hint("Lead pups to the exit! (%d/%d)" % [gathered, total])
			return
		if gathered < need:
			_set_hint("Lead pups to the exit! (%d/%d)" % [gathered, need])
			return
		_gather_escort_at_exit(exit_pos)
		_complete_level()
		return
	_gather_escort_at_exit(exit_pos)
	_complete_level()


func info_has_key_door() -> bool:
	return current_level > 0 or test_mode


func _complete_level() -> void:
	if level_won:
		return
	level_won = true
	_exit_wait_start_ms = -1
	_sync_session_rescue_count()
	_validate_session_tracking("level_complete")
	_pending_had_island_escort = _had_island_escort_this_level()
	if not _level_coin_awarded:
		_award_level_coins()
		_level_coin_awarded = true
		_save.save_game()
	SfxManager.play_win()
	_burst_at(exit_node.global_position if exit_node else puppy.global_position, Color(0.3, 0.7, 1.0))
	_show_win_panel()


func _info_vec3(info: Dictionary, key: StringName) -> Vector3:
	var v: Variant = info.get(key)
	return v if v is Vector3 else Vector3.ZERO


func _near(a: Vector3, b: Vector3) -> bool:
	return _flat_distance(a, b) <= pickup_radius


func _flat_distance(a: Vector3, b: Vector3) -> float:
	var pa := a
	var pb := b
	pa.y = 0.0
	pb.y = 0.0
	return pa.distance_to(pb)


func _burst_at(world_pos: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 14
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 75.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0.0, -4.0, 0.0)
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.14
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.6
	p.material_override = mat
	maze_root.add_child(p)
	p.global_position = world_pos
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)


# --- UI ---

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui_root)

	var m := ui_safe_margin

	var top_left := VBoxContainer.new()
	top_left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_left.offset_left = m
	top_left.offset_top = m
	top_left.offset_right = m + 420
	top_left.add_theme_constant_override("separation", 4)
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(top_left)

	level_label = Label.new()
	level_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	level_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	level_label.add_theme_color_override("font_outline_color", Color(0.12, 0.22, 0.10))
	level_label.add_theme_constant_override("outline_size", 2)
	top_left.add_child(level_label)

	key_status_label = Label.new()
	key_status_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	key_status_label.add_theme_color_override("font_outline_color", Color(0.12, 0.22, 0.10))
	key_status_label.add_theme_constant_override("outline_size", 2)
	top_left.add_child(key_status_label)

	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(380, 0)
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90))
	hint_label.add_theme_color_override("font_outline_color", Color(0.12, 0.22, 0.10))
	hint_label.add_theme_constant_override("outline_size", 2)
	top_left.add_child(hint_label)

	var top_right := VBoxContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.offset_top = m
	top_right.offset_right = -m
	top_right.offset_left = -240
	top_right.add_theme_constant_override("separation", 8)
	top_right.alignment = BoxContainer.ALIGNMENT_END
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(top_right)

	coins_label = Label.new()
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coins_label.add_theme_font_size_override("font_size", 16)
	coins_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	coins_label.add_theme_color_override("font_outline_color", Color(0.12, 0.22, 0.10))
	coins_label.add_theme_constant_override("outline_size", 3)
	top_right.add_child(coins_label)

	pause_btn = _hud_button("Pause", _on_pause_pressed)
	pause_btn.custom_minimum_size = Vector2(96, 40)
	top_right.add_child(pause_btn)

	boost_label = Label.new()
	boost_label.visible = false
	boost_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boost_label.offset_top = m + 8
	boost_label.offset_left = -220
	boost_label.offset_right = 220
	boost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(boost_label)

	var version_label := Label.new()
	version_label.text = GameVersionScript.version_label()
	version_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version_label.offset_left = m
	version_label.offset_bottom = -m
	version_label.add_theme_font_size_override("font_size", 12)
	version_label.add_theme_color_override("font_color", Color(0.35, 0.38, 0.45, 0.85))
	version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(version_label)

	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Confirm"
	confirm_dialog.ok_button_text = "Yes"
	confirm_dialog.cancel_button_text = "No"
	confirm_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	confirm_dialog.canceled.connect(_update_gameplay_input_block)
	ui_root.add_child(confirm_dialog)

	win_backdrop = _make_modal_backdrop()
	win_backdrop.visible = false
	ui_root.add_child(win_backdrop)

	win_panel = Panel.new()
	win_panel.visible = false
	win_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	win_panel.set_anchors_preset(Control.PRESET_CENTER)
	win_panel.clip_contents = true
	var win_style := StyleBoxFlat.new()
	win_style.bg_color = Color(0.97, 0.98, 0.99, 0.97)
	win_style.border_color = Color(0.55, 0.68, 0.82)
	win_style.set_border_width_all(3)
	win_style.set_corner_radius_all(16)
	win_style.content_margin_left = 12
	win_style.content_margin_right = 12
	win_style.content_margin_top = 12
	win_style.content_margin_bottom = 12
	win_panel.add_theme_stylebox_override("panel", win_style)
	ui_root.add_child(win_panel)
	_layout_win_panel()

	var win_v := VBoxContainer.new()
	win_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_v.offset_left = 14
	win_v.offset_top = 14
	win_v.offset_right = -14
	win_v.offset_bottom = -14
	win_v.add_theme_constant_override("separation", 10)
	win_panel.add_child(win_v)

	win_label = Label.new()
	win_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	win_label.custom_minimum_size = Vector2(0, 40)
	win_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	win_label.add_theme_color_override("font_color", Color(0.12, 0.18, 0.28))
	win_label.add_theme_font_size_override("font_size", 16)
	win_v.add_child(win_label)

	shop_panel = ShopPanelScript.new()
	shop_panel.name = "ShopPanel"
	shop_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_panel.custom_minimum_size = Vector2(0, 180)
	shop_panel.setup(_save)
	shop_panel.purchase_requested.connect(_purchase_shop_item)
	win_v.add_child(shop_panel)

	var win_btns := VBoxContainer.new()
	win_btns.add_theme_constant_override("separation", 10)
	win_btns.size_flags_vertical = Control.SIZE_SHRINK_END
	win_v.add_child(win_btns)

	next_btn = _win_primary_button("Next Level  →", _on_next_level_pressed)
	win_btns.add_child(next_btn)

	var win_secondary_btns := HBoxContainer.new()
	win_secondary_btns.add_theme_constant_override("separation", 10)
	win_secondary_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	win_btns.add_child(win_secondary_btns)

	restart_btn2 = _win_secondary_button("Restart", func(): _confirm_action("Restart this level?", func(): load_level(current_level)))
	win_secondary_btns.add_child(restart_btn2)
	var menu_win_btn := _win_secondary_button("Menu", func(): _confirm_action("Return to menu?", _on_menu_pressed))
	win_secondary_btns.add_child(menu_win_btn)

	_companion_unlock_backdrop = _make_modal_backdrop()
	_companion_unlock_backdrop.visible = false
	ui_root.add_child(_companion_unlock_backdrop)

	var companion_host := CenterContainer.new()
	companion_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	companion_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(companion_host)

	_companion_unlock_panel = CompanionUnlockPanelScript.new()
	_companion_unlock_panel.name = "CompanionUnlockPanel"
	_companion_unlock_panel.acknowledged.connect(_on_companion_unlock_acknowledged)
	_companion_unlock_panel.clubhouse_requested.connect(_on_companion_clubhouse_shortcut)
	companion_host.add_child(_companion_unlock_panel)

	_special_pup_found_backdrop = _make_modal_backdrop()
	_special_pup_found_backdrop.visible = false
	ui_root.add_child(_special_pup_found_backdrop)

	var special_pup_host := CenterContainer.new()
	special_pup_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	special_pup_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(special_pup_host)

	_special_pup_found_panel = SpecialPupFoundPanelScript.new()
	_special_pup_found_panel.name = "SpecialPupFoundPanel"
	_special_pup_found_panel.dismissed.connect(_on_special_pup_celebration_dismissed)
	special_pup_host.add_child(_special_pup_found_panel)

	pause_backdrop = _make_modal_backdrop()
	pause_backdrop.visible = false
	ui_root.add_child(pause_backdrop)

	pause_panel = PanelContainer.new()
	pause_panel.visible = false
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	var pause_style := win_style.duplicate()
	pause_style.content_margin_left = 20
	pause_style.content_margin_right = 20
	pause_style.content_margin_top = 18
	pause_style.content_margin_bottom = 18
	pause_panel.add_theme_stylebox_override("panel", pause_style)
	ui_root.add_child(pause_panel)
	_layout_pause_panel()

	var pause_scroll := ScrollContainer.new()
	pause_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pause_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pause_panel.add_child(pause_scroll)

	var pause_v := VBoxContainer.new()
	pause_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_v.add_theme_constant_override("separation", 10)
	pause_scroll.add_child(pause_v)

	var pause_title := Label.new()
	pause_title.text = "Paused"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 22)
	pause_title.add_theme_color_override("font_color", Color(0.12, 0.18, 0.28))
	pause_v.add_child(pause_title)

	pause_v.add_child(_pause_menu_button("Resume", _hide_pause_menu))

	restart_btn = _pause_menu_button("Restart Level", func():
		_confirm_action("Restart this level?", func():
			_hide_pause_menu()
			load_level(current_level)
		)
	)
	pause_v.add_child(restart_btn)

	menu_btn = _pause_menu_button("Return to Menu", func():
		_confirm_action("Return to menu? Unsaved progress this level may be lost.", _on_menu_pressed)
	)
	pause_v.add_child(menu_btn)

	save_progress_btn = _pause_menu_button("Save Progress", _on_save_progress_pressed)
	save_progress_btn.visible = false
	pause_v.add_child(save_progress_btn)

	test_toggle = CheckButton.new()
	test_toggle.text = "Test maze mode"
	test_toggle.button_pressed = test_mode
	test_toggle.focus_mode = Control.FOCUS_NONE
	test_toggle.add_theme_color_override("font_color", Color(0.12, 0.18, 0.28))
	test_toggle.add_theme_font_size_override("font_size", 14)
	test_toggle.toggled.connect(_on_test_mode_toggled)
	pause_v.add_child(test_toggle)

	var touch_label := Label.new()
	touch_label.text = "Touch controls"
	touch_label.add_theme_color_override("font_color", Color(0.12, 0.18, 0.28))
	touch_label.add_theme_font_size_override("font_size", 14)
	pause_v.add_child(touch_label)

	var touch_row := FlowContainer.new()
	touch_row.add_theme_constant_override("h_separation", 6)
	touch_row.add_theme_constant_override("v_separation", 6)
	touch_row.alignment = FlowContainer.ALIGNMENT_CENTER
	pause_v.add_child(touch_row)
	_touch_control_buttons.clear()
	for mode in range(TouchControlConfigScript.MODE_LABELS.size()):
		var label: String = PAUSE_TOUCH_LABELS[mode] if mode < PAUSE_TOUCH_LABELS.size() else TouchControlConfigScript.MODE_LABELS[mode]
		var btn: Button = SafeButtonScript.new()
		btn.text = label
		btn.custom_minimum_size = Vector2(72, 36)
		btn.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 13)
		btn.set_meta("touch_mode", mode)
		btn.pressed.connect(_select_touch_control_mode.bind(mode))
		touch_row.add_child(btn)
		_touch_control_buttons.append(btn)
	_sync_touch_control_buttons(_save.get_touch_control_mode())


func _make_modal_backdrop() -> ColorRect:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.05, 0.08, 0.12, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	return backdrop


func _setup_player_input() -> void:
	player_input = PlayerInputControllerScript.new()
	player_input.name = "PlayerInputController"
	player_input.debug_enabled = debug_enabled
	add_child(player_input)
	player_input.setup(
		cam,
		puppy,
		self,
		floor_collision_mask,
		target_update_threshold,
		ui_root,
		ui_layer
	)
	player_input.set_touch_control_mode(_save.get_touch_control_mode())
	_update_gameplay_input_block()


func _select_touch_control_mode(mode: int) -> void:
	_save.set_touch_control_mode(mode)
	_save.save_game()
	_sync_touch_control_buttons(mode)
	if player_input != null:
		player_input.set_touch_control_mode(mode)


func _sync_touch_control_buttons(mode: int) -> void:
	mode = TouchControlConfigScript.clamp_mode(mode)
	for btn in _touch_control_buttons:
		if btn == null:
			continue
		var m: int = int(btn.get_meta("touch_mode", -1))
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(8)
		style.set_border_width_all(2)
		if m == mode:
			style.bg_color = Color(0.22, 0.48, 0.82)
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			style.bg_color = Color(0.90, 0.93, 0.98)
			style.border_color = Color(0.62, 0.70, 0.82)
			btn.add_theme_color_override("font_color", Color(0.12, 0.18, 0.28))
		btn.add_theme_stylebox_override("normal", style)


func _update_key_status() -> void:
	if key_status_label == null:
		return
	if current_level == 0 and not test_mode:
		key_status_label.text = "Key: not needed"
	elif has_key:
		key_status_label.text = "Key: collected"
	else:
		key_status_label.text = "Key: not found"


func _update_gameplay_input_block() -> void:
	var blocked: bool = _paused \
		or (win_panel != null and win_panel.visible) \
		or (_companion_unlock_panel != null and _companion_unlock_panel.visible) \
		or (_special_pup_found_panel != null and _special_pup_found_panel.visible) \
		or (confirm_dialog != null and confirm_dialog.visible)
	if player_input != null:
		player_input.set_gameplay_blocked(blocked)


func _show_pause_menu() -> void:
	if _paused or level_won:
		return
	_paused = true
	if pause_backdrop:
		pause_backdrop.visible = true
	if pause_panel:
		pause_panel.visible = true
	_layout_pause_panel()
	get_tree().paused = true
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_update_gameplay_input_block()


func _hide_pause_menu() -> void:
	if not _paused:
		return
	_paused = false
	if pause_backdrop:
		pause_backdrop.visible = false
	if pause_panel:
		pause_panel.visible = false
	get_tree().paused = false
	ui_layer.process_mode = Node.PROCESS_MODE_INHERIT
	_update_gameplay_input_block()


func _on_pause_pressed() -> void:
	if _paused:
		_hide_pause_menu()
	else:
		_show_pause_menu()


func _confirm_action(message: String, callback: Callable) -> void:
	if confirm_dialog == null:
		callback.call()
		return
	if confirm_dialog.visible:
		return
	_pending_confirm = callback
	confirm_dialog.dialog_text = message
	if not confirm_dialog.confirmed.is_connected(_on_confirm_dialog_accepted):
		confirm_dialog.confirmed.connect(_on_confirm_dialog_accepted)
	confirm_dialog.popup_centered()
	_update_gameplay_input_block()


func _on_confirm_dialog_accepted() -> void:
	if _pending_confirm.is_valid():
		_pending_confirm.call()
	_pending_confirm = Callable()
	_update_gameplay_input_block()


func _hud_button(text: String, callback: Callable) -> Button:
	var b: Button = SafeButtonScript.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 44)
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	return b


func _pause_menu_button(text: String, callback: Callable) -> Button:
	var b := _win_button(text, callback)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 16)
	return b


func _layout_pause_panel() -> void:
	if pause_panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var w := clampf(vp.x - 56.0, 300.0, 400.0)
	var h := clampf(vp.y - 64.0, 360.0, 520.0)
	pause_panel.offset_left = -w * 0.5
	pause_panel.offset_right = w * 0.5
	pause_panel.offset_top = -h * 0.5
	pause_panel.offset_bottom = h * 0.5
	call_deferred("_sync_pause_content_width")


func _sync_pause_content_width() -> void:
	if pause_panel == null or pause_panel.get_child_count() == 0:
		return
	var scroll := pause_panel.get_child(0) as ScrollContainer
	if scroll == null or scroll.get_child_count() == 0:
		return
	var content := scroll.get_child(0) as Control
	if content == null:
		return
	content.custom_minimum_size.x = maxf(scroll.size.x - 4.0, 260.0)


func _win_button(text: String, callback: Callable) -> Button:
	var b := _hud_button(text, callback)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.48, 0.82)
	style.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_color_override("font_color", Color.WHITE)
	return b


func _win_primary_button(text: String, callback: Callable) -> Button:
	var b := _hud_button(text, callback)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.62, 0.34)
	style.set_corner_radius_all(12)
	style.set_border_width_all(0)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.22, 0.70, 0.40)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = Color(0.14, 0.52, 0.28)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	return b


func _win_secondary_button(text: String, callback: Callable) -> Button:
	var b := _hud_button(text, callback)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 15)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.90, 0.93, 0.98)
	style.border_color = Color(0.62, 0.70, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_color_override("font_color", Color(0.14, 0.20, 0.30))
	b.add_theme_color_override("font_hover_color", Color(0.14, 0.20, 0.30))
	return b


func _big_button(text: String, callback: Callable) -> Button:
	return _hud_button(text, callback)


func _layout_win_panel() -> void:
	if win_panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var w := clampf(vp.x - 48.0, 340.0, 520.0)
	var h := clampf(vp.y - 72.0, 420.0, 620.0)
	win_panel.offset_left = -w * 0.5
	win_panel.offset_right = w * 0.5
	win_panel.offset_top = -h * 0.5
	win_panel.offset_bottom = h * 0.5


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_layout_win_panel()
		_layout_pause_panel()


func _on_test_mode_toggled(on: bool) -> void:
	test_mode = on
	load_level(current_level)


func _on_menu_pressed() -> void:
	_hide_pause_menu()
	_save.current_level = current_level
	if play_island_id != "":
		_save.current_island_id = play_island_id
		_save.current_local_level = play_local_level
	_save.clear_play_target()
	_save.save_game()
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")


func _on_save_progress_pressed() -> void:
	if test_mode or not _save.progress_features_unlocked():
		return
	_save.save_run_progress(current_level, _current_squad_size(), _temporary_rescues_this_level())
	SfxManager.play_shop_buy()
	_set_hint("Progress saved for %s!" % _save.get_pup_name())


func _current_squad_size() -> int:
	if follower_squad == null:
		return 0
	return follower_squad.count_session_rescue_points()


func _update_progress_ui() -> void:
	if save_progress_btn != null:
		save_progress_btn.visible = _save.progress_features_unlocked() and not test_mode


func _on_next_level_pressed() -> void:
	var commit_discovery := false
	if play_island_id != "" and _special_pup_rescued_this_run and not _save.is_special_pup_found(play_island_id):
		var hidden_idx: int = IslandCatalogScript.hidden_level_index(play_island_id)
		if play_local_level == hidden_idx:
			commit_discovery = true
			_pup_debug("Committing special pup discovery on level %d" % play_local_level)
	_last_completion_result = _save.record_level_complete_with_escort(
		_temporary_rescues_this_level(),
		_current_squad_size(),
		_pending_had_island_escort,
		commit_discovery
	)
	_special_pup_rescued_this_run = false
	_pending_had_island_escort = false
	if bool(_last_completion_result.get("pup_found")):
		_show_special_pup_found_celebration()
		return
	_continue_after_level_rewards()


func _continue_after_level_rewards() -> void:
	var unlocked_id: String = str(_last_completion_result.get("unlocked_companion_id", ""))
	if (
		bool(_last_completion_result.get("companion_newly_unlocked", false))
		and unlocked_id != ""
		and _save.should_show_companion_celebration(unlocked_id)
	):
		_pending_after_companion_celebration = Callable(self, "_continue_after_level_complete")
		_show_companion_unlock_celebration(unlocked_id)
		return
	_continue_after_level_complete()


func _show_special_pup_found_celebration() -> void:
	if _special_pup_found_panel == null or play_island_id == "":
		_continue_after_level_rewards()
		return
	_hide_win_panel()
	var companion: CompanionDefinition = ProgressionRegistryScript.get_special_companion(play_island_id)
	var pup_name: String = companion.default_name if companion else "Special pup"
	var coat: int = companion.coat_index if companion else 0
	if _special_pup_found_backdrop:
		_special_pup_found_backdrop.visible = true
	_special_pup_found_panel.show_discovery(pup_name, coat)
	SfxManager.play_win()
	_update_gameplay_input_block()


func _on_special_pup_celebration_dismissed() -> void:
	_save.acknowledge_special_pup_celebration(play_island_id)
	if _special_pup_found_backdrop:
		_special_pup_found_backdrop.visible = false
	if _special_pup_found_panel:
		_special_pup_found_panel.hide_feedback()
	_update_gameplay_input_block()
	_continue_after_level_rewards()


func _on_companion_clubhouse_shortcut(companion_id: String) -> void:
	_save.acknowledge_companion_unlock(companion_id)
	if _companion_unlock_backdrop:
		_companion_unlock_backdrop.visible = false
	if _companion_unlock_panel:
		_companion_unlock_panel.hide_panel()
	_update_gameplay_input_block()
	_save.set_clubhouse_focus(companion_id)
	get_tree().change_scene_to_file("res://scenes/PuppyClubhouse.tscn")


func _continue_after_level_complete() -> void:
	if test_mode:
		load_level(current_level)
		return
	if play_replay or not bool(_last_completion_result.get("advanced", false)):
		get_tree().change_scene_to_file("res://scenes/IslandMap.tscn")
		return
	var island_id: String = _save.get_play_island_id()
	var next_local: int = _save.get_play_local_level()
	var count: int = IslandCatalogScript.level_count(island_id)
	if next_local >= count:
		get_tree().change_scene_to_file("res://scenes/IslandMap.tscn")
		return
	_save.set_play_target(island_id, next_local, false)
	play_island_id = island_id
	play_local_level = next_local
	play_replay = false
	load_level(_save.resolve_global_level_index(island_id, next_local))


func _show_companion_unlock_celebration(companion_id: String) -> void:
	if _companion_unlock_panel == null:
		_continue_after_level_complete()
		return
	_hide_win_panel()
	if _companion_unlock_backdrop:
		_companion_unlock_backdrop.visible = true
	_companion_unlock_panel.show_unlock(companion_id, _save)
	SfxManager.play_win()
	_update_gameplay_input_block()


func _on_companion_unlock_acknowledged(companion_id: String) -> void:
	_save.acknowledge_companion_unlock(companion_id)
	if _companion_unlock_backdrop:
		_companion_unlock_backdrop.visible = false
	if _companion_unlock_panel:
		_companion_unlock_panel.hide_panel()
	_update_gameplay_input_block()
	var next_step: Callable = _pending_after_companion_celebration
	_pending_after_companion_celebration = Callable()
	if next_step.is_valid():
		next_step.call()


func _show_win_panel() -> void:
	_layout_win_panel()
	_hide_pause_menu()
	if win_backdrop:
		win_backdrop.visible = true
	if win_panel:
		win_panel.visible = true
	_update_gameplay_input_block()
	if win_label:
		var badge_already: bool = (
			play_island_id != ""
			and _save.has_escort_badge(play_island_id, play_local_level)
		)
		var report: Dictionary = _session.build_completion_report(
			_save,
			_had_home_island_pup_present(),
			_would_earn_escort_badge(),
			badge_already
		)
		var session_summary: String = _session.format_completion_summary(report)
		var escort_line := ""
		if play_island_id != "":
			var pup_def: Dictionary = IslandCatalogScript.get_special_pup(play_island_id)
			var pup_name: String = str(pup_def.get("name", "Special pup"))
			if _special_pup_rescued_this_run and not _save.is_special_pup_found(play_island_id):
				escort_line = "\n%s will join your island adventures!" % pup_name
			if _would_unlock_companion_after_completion():
				escort_line += "\nCompanion Unlocked!"
		var level_title := "Level %d complete!" % (current_level + 1)
		if not test_mode and play_island_id != "":
			var island_def: Dictionary = IslandCatalogScript.get_island(play_island_id)
			level_title = "%s level %d complete!" % [
				str(island_def.get("name", play_island_id)),
				play_local_level + 1,
			]
		win_label.text = "%s\n%s%s\n%s — %d total rescued" % [
			level_title,
			session_summary,
			escort_line,
			_save.get_pup_name(),
			_save.total_rescued,
		]
	if next_btn:
		if test_mode:
			next_btn.text = "Next Level  →"
		elif play_replay:
			next_btn.text = "Back to Levels"
		elif play_island_id != "":
			var count: int = IslandCatalogScript.level_count(play_island_id)
			if play_local_level + 1 < count:
				next_btn.text = "Next Level  →"
			else:
				next_btn.text = "Back to Levels"
		else:
			next_btn.text = "Next Level  →"
	if shop_panel:
		shop_panel.set_summary("Spend Treat Coins below!", _last_coin_summary)
		shop_panel.refresh()
	_update_coins_label()
	_set_hint("")


func _hide_win_panel() -> void:
	if win_backdrop:
		win_backdrop.visible = false
	if win_panel:
		win_panel.visible = false
	_update_gameplay_input_block()


func _set_hint(msg: String) -> void:
	if hint_label:
		hint_label.text = msg


func _show_toast(message: String, duration_sec: float = 3.5) -> void:
	if hint_label == null:
		return
	if _toast_timer == null:
		_toast_timer = Timer.new()
		_toast_timer.one_shot = true
		_toast_timer.name = "HintToastTimer"
		add_child(_toast_timer)
		_toast_timer.timeout.connect(_on_toast_timeout)
	if not _toast_timer.is_stopped():
		_toast_timer.stop()
	else:
		_toast_restore_hint = hint_label.text
	hint_label.text = message
	_toast_timer.start(duration_sec)


func _on_toast_timeout() -> void:
	if hint_label:
		hint_label.text = _toast_restore_hint


func _clear_runtime_pickups() -> void:
	_clear_hidden_pup()
	if footprint_trail != null:
		footprint_trail.clear()
	_clear_waiting_pups_in_room()

	for node in speed_nodes:
		if is_instance_valid(node):
			node.queue_free()
	speed_nodes.clear()
	for node in double_boost_nodes:
		if is_instance_valid(node):
			node.queue_free()
	double_boost_nodes.clear()
	coin_nodes.clear()
	accessory_nodes.clear()
	ultra_nodes.clear()
	_accessory_pickup_ids.clear()
	_ultra_pickup_ids.clear()
	speed_boost_until_ms = 0
	double_rescue_until_ms = 0
	coins_this_level = 0
	ultra_buffs.clear()
	if footprint_trail != null and footprint_trail.has_method("set_rainbow_mode"):
		footprint_trail.set_rainbow_mode(_wants_rainbow_trail())
	if puppy != null and "speed" in puppy:
		puppy.speed = puppy_base_speed

	if key_node:
		key_node.queue_free()
	key_node = null
	key_area = null
	if exit_node:
		exit_node.queue_free()
	exit_node = null
	exit_area = null
	if door_area and is_instance_valid(door_area):
		door_area.queue_free()
	door_area = null
	door_body = null
	door_unlock_center = Vector3.ZERO
	has_key = false
	door_opened = false
	pen_gate_body = null
	pen_gate_area = null
	pen_gate_center = Vector3.ZERO
	pen_gate_cell = Vector2i(-1, -1)
	pen_opened = false
	has_pen = false
	_refresh_dynamic_blockers()
	_hide_win_panel()


func _refresh_dynamic_blockers() -> void:
	if puppy == null or not puppy.has_method("set_dynamic_blockers"):
		return
	var blockers: Array = []
	if door_body != null and not door_opened:
		blockers.append(door_unlock_center)
	if pen_gate_body != null and not pen_opened:
		blockers.append(pen_gate_center)
	puppy.call("set_dynamic_blockers", blockers)


func _spawn_pen_gate_if_present(info: Dictionary) -> void:
	if not info.has("pen_gate") or info.pen_gate == null:
		return
	pen_gate_body = info.get("pen_gate_body") as StaticBody3D
	if pen_gate_body == null:
		return
	if info.get("pen_gate_cell") is Vector2i:
		pen_gate_cell = info.pen_gate_cell as Vector2i
	elif info.pen_gate is Vector3:
		var g: Vector3 = info.pen_gate as Vector3
		pen_gate_cell = Vector2i(
			int(round(g.x / builder.tile_size)),
			int(round(g.z / builder.tile_size))
		)
	if pen_gate_cell.x >= 0:
		pen_gate_center = Vector3(
			float(pen_gate_cell.x) * builder.tile_size,
			0.0,
			float(pen_gate_cell.y) * builder.tile_size
		)
	else:
		pen_gate_center = pen_gate_body.global_position
	_refresh_dynamic_blockers()
	pen_gate_area = Area3D.new()
	pen_gate_area.collision_mask = LAYER_PLAYER
	pen_gate_area.monitoring = true
	pen_gate_body.add_child(pen_gate_area)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = door_unlock_radius
	col.shape = shape
	pen_gate_area.add_child(col)
	pen_gate_area.body_entered.connect(_on_pen_gate_body_entered)


func _on_pen_gate_body_entered(body: Node) -> void:
	if body == puppy:
		_try_open_pen()


func _try_open_pen_near_puppy() -> void:
	if not has_key or pen_opened or pen_gate_body == null or puppy == null:
		return
	if _near(puppy.global_position, pen_gate_center):
		_try_open_pen()


func _try_open_pen() -> void:
	if pen_opened or not has_key:
		if not has_key and has_pen:
			_set_hint("Rescue room is locked. Find the key.")
		return
	_open_pen()


func _open_pen() -> void:
	if pen_opened:
		return
	var spawn_positions: Array[Vector3] = []
	for waiting_pup in rescue_room_pups:
		if is_instance_valid(waiting_pup):
			var pos: Vector3 = waiting_pup.global_position
			pos.y = _follower_floor_y()
			spawn_positions.append(pos)
	if is_instance_valid(pen_gate_body):
		pen_gate_body.queue_free()
	pen_gate_body = null
	if pen_gate_area and is_instance_valid(pen_gate_area):
		pen_gate_area.queue_free()
	pen_gate_area = null
	pen_opened = true
	if puppy != null and puppy.has_method("get_nav"):
		var nav: MazeNav = puppy.get_nav()
		if nav != null:
			if pen_gate_cell.x >= 0:
				nav.lines = LevelGeneratorScript.open_rescue_room_door(nav.lines, pen_gate_cell)
			nav.set_pen_open(true)
			nav.set_rescue_door_unlocked(true)
	_refresh_dynamic_blockers()
	_clear_waiting_pups_in_room()
	SfxManager.play_door()
	_burst_at(pen_gate_center, Color(1.0, 0.6, 0.85))
	var nav: MazeNav = puppy.get_nav() if puppy.has_method("get_nav") else null
	var release_count: int = _compute_pen_release_count()
	if nav != null and follower_squad != null and release_count > 0:
		if spawn_positions.is_empty():
			var spawn: Vector3 = pen_center
			if spawn == Vector3.ZERO:
				spawn = pen_gate_center
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			for _i in release_count:
				var offset := Vector3(
					rng.randf_range(-0.25, 0.25),
					0.0,
					rng.randf_range(-0.25, 0.25)
				)
				var pos: Vector3 = spawn + offset
				pos.y = _follower_floor_y()
				spawn_positions.append(pos)
		var validated_positions: Array[Vector3] = []
		for pos: Vector3 in spawn_positions.slice(0, release_count):
			validated_positions.append(
				_resolve_pup_spawn(
					nav,
					pos,
					_follower_floor_y(),
					puppy.global_position,
					false,
					true,
					"temporary_rescue"
				)
			)
		follower_squad.max_followers = _compute_max_followers()
		var spawned: int = follower_squad.release_pen_followers(
			validated_positions,
			nav,
			_follower_floor_y(),
			$World/ActorsRoot,
			puppy.global_position
		)
		_session.record_temporary_rescues_spawned(spawned)
		_validate_session_tracking("pen_release")
		_apply_follower_collar()
		_update_level_label()
		SfxManager.play_rescue()
		_set_hint("%d pups rescued! Lead them to the exit." % spawned)
	else:
		_set_hint("Rescue room open! Lead pups to the exit.")
