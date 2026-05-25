# scripts/game.gd
extends Node3D

@export var test_mode: bool = false
@export var auto_fit_camera_on_load: bool = true
@export var debug_enabled: bool = false
@export var target_update_threshold: float = 0.10
@export var randomize_each_load: bool = true
@export var pickup_radius: float = 0.6
@export var door_unlock_radius: float = 1.1
@export var ui_safe_margin: int = 28
@export var floor_collision_mask: int = 1

@onready var floor_mesh: MeshInstance3D = $World/Floor/MeshInstance3D
@onready var cam_fitter: CameraFitter = $Camera3D
@onready var floor_body: StaticBody3D = $World/Floor
@onready var floor_collision: CollisionShape3D = $World/Floor/CollisionShape3D
@onready var maze_root: Node3D = $World/MazeRoot
@onready var puppy: CharacterBody3D = $World/ActorsRoot/Puppy

const MazeBuilderScript := preload("res://scripts/maze_builder.gd")
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

var rescue_nodes: Array[Node3D] = []
var rescue_total: int = 0
var rescued_this_level: int = 0

var ui_layer: CanvasLayer = null
var ui_root: Control = null
var level_label: Label = null
var hint_label: Label = null
var win_panel: Panel = null
var win_label: Label = null
var restart_btn: Button = null
var reload_btn: Button = null
var menu_btn: Button = null
var test_toggle: CheckButton = null
var next_btn: Button = null
var restart_btn2: Button = null

var is_tracking := false
var active_touch_id := -1


func _ready() -> void:
	set_process_unhandled_input(true)
	set_process_input(true)
	run_seed = int(Time.get_unix_time_from_system()) ^ randi()
	cam = cam_fitter
	builder = MazeBuilderScript.new()
	_apply_boot_settings()
	_build_ui()
	set_physics_process(true)
	load_level(SaveGame.current_level)


func _apply_boot_settings() -> void:
	if SaveGame.boot_test_mode:
		test_mode = true
	if puppy.has_method("set") and "breed" in puppy:
		puppy.set("breed", clampi(SaveGame.breed, 0, 2))
	if puppy.has_method("_apply_breed_mesh"):
		puppy._apply_breed_mesh()


func load_level(level_index: int) -> void:
	current_level = level_index
	SaveGame.current_level = level_index
	_clear_runtime_pickups()

	if randomize_each_load:
		run_seed = (run_seed + 1337) ^ randi()
	else:
		run_seed = Time.get_ticks_msec()

	var lines := LevelData.make(level_index, run_seed, test_mode)
	var ts: float = builder.tile_size
	fit_floor_to_level(lines, ts)

	var info := builder.build_from_lines(lines, maze_root, level_index)

	if auto_fit_camera_on_load and cam_fitter != null:
		cam_fitter.set_fit_target(info["center"], info["half_extents"], test_mode)

	has_key = false
	door_opened = false
	rescued_this_level = 0

	_spawn_key_if_present(info)
	_spawn_exit_if_present(info)
	_spawn_door_if_present(info)
	_spawn_rescues(info)

	if puppy.has_method("set_maze_data"):
		puppy.set_maze_data(lines, ts)

	puppy.global_position = info["start"]
	if puppy.has_method("snap_to_floor"):
		puppy.snap_to_floor()

	has_last_target = false
	last_target = Vector3.ZERO
	_hide_win_panel()
	_update_level_label()

	if current_level == 0 and not test_mode:
		_set_hint("Level 1 — walk to the blue exit!")
	elif test_mode:
		_set_hint("Test maze — collect key, open door, reach exit.")
	else:
		_set_hint("Find the key, open the door, reach the exit. Rescue pups optional!")


func _physics_process(_delta: float) -> void:
	_try_collect_key_near_puppy()
	_try_collect_rescues_near_puppy()
	_try_unlock_door_near_puppy()
	_try_reach_exit_near_puppy()


func _update_level_label() -> void:
	if level_label == null:
		return
	var name := "Test maze" if test_mode else "Level %d" % (current_level + 1)
	level_label.text = "%s  |  Rescued: %d total" % [name, SaveGame.total_rescued]


func fit_floor_to_level(lines: PackedStringArray, tile_size: float, margin_tiles: float = 2.0) -> void:
	var cols: int = lines[0].length()
	var rows: int = lines.size()
	var w: float = (float(cols) + margin_tiles) * tile_size
	var h: float = (float(rows) + margin_tiles) * tile_size
	var center: Vector3 = Vector3((cols - 1) * 0.5 * tile_size, 0.0, (rows - 1) * 0.5 * tile_size)
	var pm := floor_mesh.mesh as PlaneMesh
	if pm != null:
		pm.size = Vector2(w, h)
	floor_body.global_position = center
	var bs := floor_collision.shape as BoxShape3D
	if bs == null:
		bs = BoxShape3D.new()
		floor_collision.shape = bs
	bs.size = Vector3(w, 0.1, h)


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
	key_node = _make_marker("KeyMarker", info.key + Vector3(0.0, 0.35, 0.0), Color(1.0, 0.88, 0.15), 0.12, 0.25)
	key_area = _add_pickup_area(key_node, 0.35, _on_key_body_entered)


func _spawn_exit_if_present(info: Dictionary) -> void:
	if not info.has("exit") or info.exit == null:
		return
	exit_node = _make_marker("ExitMarker", info.exit + Vector3(0.0, 0.25, 0.0), Color(0.2, 0.6, 1.0), 0.18, 0.35, true)
	exit_area = _add_pickup_area(exit_node, 0.45, _on_exit_body_entered)


func _spawn_rescues(info: Dictionary) -> void:
	rescue_nodes.clear()
	if not info.has("rescue"):
		return
	rescue_total = info.rescue.size()
	for pos: Vector3 in info.rescue:
		var node := _make_marker("RescueMarker", pos + Vector3(0.0, 0.3, 0.0), Color(1.0, 0.45, 0.75), 0.14, 0.28)
		maze_root.add_child(node)
		rescue_nodes.append(node)
		_add_pickup_area(node, 0.4, _on_rescue_body_entered)


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
	if puppy.has_method("set_door_blocking"):
		puppy.set_door_blocking(true, door_unlock_center)
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
	_set_hint("Key collected! Touch the door.")
	_try_unlock_door_near_puppy()


func _on_rescue_body_entered(body: Node) -> void:
	if body == puppy:
		_try_collect_rescues_near_puppy()


func _try_collect_rescues_near_puppy() -> void:
	if puppy == null:
		return
	for node in rescue_nodes:
		if is_instance_valid(node) and _near(puppy.global_position, node.global_position):
			_collect_rescue_node(node)


func _collect_rescue_node(node: Node3D) -> void:
	if node == null or not rescue_nodes.has(node):
		return
	rescue_nodes.erase(node)
	rescued_this_level += 1
	SfxManager.play_rescue()
	_burst_at(node.global_position, Color(1.0, 0.5, 0.8))
	node.queue_free()
	_update_level_label()
	_set_hint("Rescued a pup! (%d this level)" % rescued_this_level)


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
	if puppy.has_method("set_door_blocking"):
		puppy.set_door_blocking(false)
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
	if current_level > 0 and not has_key:
		_set_hint("Need the key first.")
		return
	_complete_level()


func _complete_level() -> void:
	SfxManager.play_win()
	_burst_at(exit_node.global_position if exit_node else puppy.global_position, Color(0.3, 0.7, 1.0))
	_show_win_panel()


func _near(a: Vector3, b: Vector3) -> bool:
	var pa := a
	var pb := b
	pa.y = 0.0
	pb.y = 0.0
	return pa.distance_to(pb) <= pickup_radius


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

	test_toggle = CheckButton.new()
	test_toggle.text = "Test maze"
	test_toggle.button_pressed = test_mode
	test_toggle.toggled.connect(_on_test_mode_toggled)
	top_bar.add_child(test_toggle)

	level_label = Label.new()
	level_label.position = Vector2(m, m + 52)
	level_label.size = Vector2(700, 24)
	ui_root.add_child(level_label)

	hint_label = Label.new()
	hint_label.position = Vector2(m, m + 78)
	hint_label.size = Vector2(900, 28)
	ui_root.add_child(hint_label)

	win_panel = Panel.new()
	win_panel.visible = false
	win_panel.set_anchors_preset(Control.PRESET_CENTER)
	win_panel.offset_left = -220
	win_panel.offset_top = -120
	win_panel.offset_right = 220
	win_panel.offset_bottom = 120
	ui_root.add_child(win_panel)

	var win_v := VBoxContainer.new()
	win_v.position = Vector2(20, 16)
	win_v.add_theme_constant_override("separation", 12)
	win_panel.add_child(win_v)

	win_label = Label.new()
	win_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	win_label.custom_minimum_size = Vector2(380, 80)
	win_v.add_child(win_label)

	var win_btns := HBoxContainer.new()
	win_btns.add_theme_constant_override("separation", 12)
	win_v.add_child(win_btns)

	next_btn = _big_button("Next Level", _on_next_level_pressed)
	win_btns.add_child(next_btn)
	restart_btn2 = _big_button("Restart", func(): load_level(current_level))
	win_btns.add_child(restart_btn2)


func _big_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 44)
	b.pressed.connect(callback)
	return b


func _on_test_mode_toggled(on: bool) -> void:
	test_mode = on
	load_level(current_level)


func _on_menu_pressed() -> void:
	SaveGame.current_level = current_level
	SaveGame.total_rescued += rescued_this_level
	SaveGame.save_game()
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")


func _on_next_level_pressed() -> void:
	SaveGame.record_level_complete(rescued_this_level)
	load_level(SaveGame.current_level)


func _show_win_panel() -> void:
	if win_panel:
		win_panel.visible = true
	if win_label:
		var rescue_line := ""
		if rescue_total > 0:
			rescue_line = "\nRescued this level: %d / %d" % [rescued_this_level, rescue_total]
		win_label.text = "Level %d complete!%s\nTotal rescued: %d" % [
			current_level + 1, rescue_line, SaveGame.total_rescued + rescued_this_level
		]
	_set_hint("")


func _hide_win_panel() -> void:
	if win_panel:
		win_panel.visible = false


func _set_hint(msg: String) -> void:
	if hint_label:
		hint_label.text = msg


func _clear_runtime_pickups() -> void:
	for node in rescue_nodes:
		if is_instance_valid(node):
			node.queue_free()
	rescue_nodes.clear()
	rescue_total = 0

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
	if puppy != null and puppy.has_method("set_door_blocking"):
		puppy.set_door_blocking(false)
	_hide_win_panel()
