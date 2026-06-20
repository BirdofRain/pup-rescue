# scripts/game.gd
extends Node3D

@export var test_mode: bool = false
@export var auto_fit_camera_on_load: bool = true
@export var debug_enabled: bool = false
@export var target_update_threshold: float = 0.10
@export var randomize_each_load: bool = true
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
const LAYER_PLAYER := 2

var cam: Camera3D
var builder: MazeBuilder
var run_seed: int = 0
var current_level: int = 0
var last_target: Vector3 = Vector3.ZERO
var has_last_target := false

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

var rescued_this_level: int = 0

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
var reload_btn: Button = null
var menu_btn: Button = null
var test_toggle: CheckButton = null
var next_btn: Button = null
var restart_btn2: Button = null
var save_progress_btn: Button = null

var is_tracking := false
var active_touch_id := -1

var _save: GameSave


func _ready() -> void:
	_save = get_node("/root/SaveGame") as GameSave
	set_process_unhandled_input(true)
	set_process_input(true)
	run_seed = int(Time.get_unix_time_from_system()) ^ randi()
	cam = cam_fitter
	builder = MazeBuilderScript.new()
	_apply_boot_settings()
	_build_ui()
	follower_squad = FollowerSquad.new()
	follower_squad.name = "FollowerSquad"
	add_child(follower_squad)
	footprint_trail = FootprintTrailScript.new()
	footprint_trail.name = "FootprintTrail"
	$World.add_child(footprint_trail)
	set_physics_process(true)
	load_level(_save.current_level)


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
	level_won = false
	_clear_runtime_pickups()

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

	var info := builder.build_from_lines(lines, maze_root, level_index)

	if auto_fit_camera_on_load and cam_fitter != null:
		cam_fitter.set_fit_target(info["center"], info["half_extents"], test_mode)

	has_key = false
	door_opened = false
	pen_opened = false
	has_pen = info.get("pen_gate") is Vector3
	pen_center = _info_vec3(info, "pen_center")
	rescued_this_level = 0
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

	has_last_target = false
	last_target = Vector3.ZERO
	_hide_win_panel()
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
	_update_coins_label()


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
	if follower_squad != null and follower_squad.is_active():
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


func _update_level_label() -> void:
	if level_label == null:
		return
	var name := "Test maze" if test_mode else "Level %d" % (current_level + 1)
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
	var rescue_coins: int = rescued_this_level * per_rescue
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			is_tracking = true
			active_touch_id = e.index
			handle_touch(e.position)
		elif e.index == active_touch_id:
			is_tracking = false
			active_touch_id = -1
		return

	if event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if is_tracking and e.index == active_touch_id:
			handle_touch(e.position)
		return

	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				is_tracking = true
				handle_touch(e.position)
			else:
				is_tracking = false
		return

	if event is InputEventMouseMotion:
		if is_tracking and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			handle_touch(event.position)


func handle_touch(screen_pos: Vector2) -> void:
	if cam == null or puppy == null:
		return
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 500.0)
	query.collision_mask = floor_collision_mask
	query.exclude = [puppy.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var p: Vector3 = result.position
	if has_last_target and p.distance_to(last_target) < target_update_threshold:
		return
	last_target = p
	has_last_target = true
	puppy.call("set_target", p)


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
	if follower_squad != null and follower_squad.is_active():
		var exit_pos: Vector3 = exit_node.global_position if exit_node else Vector3.ZERO
		if exit_pos == Vector3.ZERO:
			return
		if not _near(puppy.global_position, exit_pos):
			_exit_wait_start_ms = -1
			return
		if _save.has_exit_roundup() and not _exit_roundup_snapped:
			follower_squad.snap_all_to(exit_pos)
			_exit_roundup_snapped = true
			SfxManager.play_roundup()
			_complete_level()
			return
		if _exit_wait_start_ms < 0:
			_exit_wait_start_ms = Time.get_ticks_msec()
		var gathered: int = follower_squad.count_escorted_at(exit_pos, puppy.global_position)
		var total: int = follower_squad.count_followers()
		var need: int = follower_squad.required_at_exit_count()
		var elapsed: int = Time.get_ticks_msec() - _exit_wait_start_ms
		if elapsed < EXIT_GRACE_MS:
			_set_hint("Lead pups to the exit! (%d/%d)" % [gathered, total])
			return
		if gathered < need:
			_set_hint("Lead pups to the exit! (%d/%d)" % [gathered, need])
			return
		_complete_level()
		return
	if exit_node != null and _near(puppy.global_position, exit_node.global_position):
		_complete_level()


func info_has_key_door() -> bool:
	return current_level > 0 or test_mode


func _complete_level() -> void:
	if level_won:
		return
	level_won = true
	_exit_wait_start_ms = -1
	if follower_squad != null and follower_squad.is_active():
		rescued_this_level = maxi(rescued_this_level, follower_squad.count_followers())
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
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui_root)

	var m := ui_safe_margin
	var top_bar := HBoxContainer.new()
	top_bar.position = Vector2(m, m)
	top_bar.add_theme_constant_override("separation", 10)
	ui_root.add_child(top_bar)

	menu_btn = _big_button("Menu", _on_menu_pressed)
	top_bar.add_child(menu_btn)
	restart_btn = _big_button("Restart", func(): load_level(current_level))
	top_bar.add_child(restart_btn)
	reload_btn = _big_button("Reload", func(): load_level(current_level))
	top_bar.add_child(reload_btn)

	save_progress_btn = _big_button("Save", _on_save_progress_pressed)
	save_progress_btn.visible = false
	top_bar.add_child(save_progress_btn)

	test_toggle = CheckButton.new()
	test_toggle.text = "Test maze"
	test_toggle.button_pressed = test_mode
	test_toggle.toggled.connect(_on_test_mode_toggled)
	top_bar.add_child(test_toggle)

	level_label = Label.new()
	level_label.position = Vector2(m, m + 52)
	level_label.size = Vector2(700, 24)
	level_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	level_label.add_theme_color_override("font_outline_color", Color(0.12, 0.22, 0.10))
	level_label.add_theme_constant_override("outline_size", 2)
	ui_root.add_child(level_label)

	coins_label = Label.new()
	coins_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	coins_label.offset_top = m + 8
	coins_label.offset_right = -m
	coins_label.offset_left = -220
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coins_label.add_theme_font_size_override("font_size", 16)
	coins_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	coins_label.add_theme_color_override("font_outline_color", Color(0.12, 0.22, 0.10))
	coins_label.add_theme_constant_override("outline_size", 3)
	ui_root.add_child(coins_label)

	boost_label = Label.new()
	boost_label.visible = false
	boost_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boost_label.offset_top = m + 8
	boost_label.offset_left = -220
	boost_label.offset_right = 220
	boost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_root.add_child(boost_label)

	hint_label = Label.new()
	hint_label.position = Vector2(m, m + 78)
	hint_label.size = Vector2(900, 28)
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90))
	hint_label.add_theme_color_override("font_outline_color", Color(0.12, 0.22, 0.10))
	hint_label.add_theme_constant_override("outline_size", 2)
	ui_root.add_child(hint_label)

	var version_label := Label.new()
	version_label.text = GameVersionScript.version_label()
	version_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version_label.offset_left = m
	version_label.offset_bottom = -m
	version_label.add_theme_font_size_override("font_size", 12)
	version_label.add_theme_color_override("font_color", Color(0.35, 0.38, 0.45, 0.85))
	ui_root.add_child(version_label)

	win_panel = Panel.new()
	win_panel.visible = false
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

	var win_btns := HBoxContainer.new()
	win_btns.add_theme_constant_override("separation", 12)
	win_btns.size_flags_vertical = Control.SIZE_SHRINK_END
	win_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	win_v.add_child(win_btns)

	next_btn = _win_button("Next Level", _on_next_level_pressed)
	win_btns.add_child(next_btn)
	restart_btn2 = _win_button("Restart", func(): load_level(current_level))
	win_btns.add_child(restart_btn2)
	var menu_win_btn := _win_button("Menu", _on_menu_pressed)
	win_btns.add_child(menu_win_btn)


func _win_button(text: String, callback: Callable) -> Button:
	var b := _big_button(text, callback)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.48, 0.82)
	style.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_color_override("font_color", Color.WHITE)
	return b


func _big_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 44)
	b.pressed.connect(callback)
	return b


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


func _on_test_mode_toggled(on: bool) -> void:
	test_mode = on
	load_level(current_level)


func _on_menu_pressed() -> void:
	_save.current_level = current_level
	_save.total_rescued += rescued_this_level
	if _save.progress_features_unlocked():
		_save.record_progress_snapshot(_current_squad_size(), rescued_this_level)
	_save.save_game()
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")


func _on_save_progress_pressed() -> void:
	if test_mode or not _save.progress_features_unlocked():
		return
	_save.save_run_progress(current_level, _current_squad_size(), rescued_this_level)
	SfxManager.play_shop_buy()
	_set_hint("Progress saved for %s!" % _save.get_pup_name())


func _current_squad_size() -> int:
	if follower_squad == null or not follower_squad.is_active():
		return 0
	return follower_squad.count_followers()


func _update_progress_ui() -> void:
	if save_progress_btn != null:
		save_progress_btn.visible = _save.progress_features_unlocked() and not test_mode


func _on_next_level_pressed() -> void:
	_save.record_level_complete(rescued_this_level, _current_squad_size())
	load_level(_save.current_level)


func _show_win_panel() -> void:
	_layout_win_panel()
	if win_panel:
		win_panel.visible = true
	if win_label:
		var rescue_line := ""
		if rescued_this_level > 0:
			rescue_line = "\nRescued %d pups from the rescue room" % rescued_this_level
		win_label.text = "Level %d complete!%s\n%s — %d total rescued" % [
			current_level + 1, rescue_line, _save.get_pup_name(), _save.total_rescued
		]
	if shop_panel:
		shop_panel.set_summary("Spend Treat Coins below!", _last_coin_summary)
		shop_panel.refresh()
	_update_coins_label()
	_set_hint("")


func _hide_win_panel() -> void:
	if win_panel:
		win_panel.visible = false


func _set_hint(msg: String) -> void:
	if hint_label:
		hint_label.text = msg


func _clear_runtime_pickups() -> void:
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
		follower_squad.max_followers = _compute_max_followers()
		var spawned: int = follower_squad.release_pen_followers(
			spawn_positions.slice(0, release_count),
			nav,
			_follower_floor_y(),
			$World/ActorsRoot,
			puppy.global_position
		)
		rescued_this_level = spawned
		_apply_follower_collar()
		_update_level_label()
		SfxManager.play_rescue()
		_set_hint("%d pups rescued! Lead them to the exit." % spawned)
	else:
		_set_hint("Rescue room open! Lead pups to the exit.")
