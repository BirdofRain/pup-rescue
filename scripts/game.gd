# scripts/game.gd
extends Node3D

# --- Test Mode --- #
@export var test_mode: bool = false  # micro test level
@export var auto_fit_camera_on_load: bool = true

@onready var floor_mesh: MeshInstance3D = $World/Floor/MeshInstance3D
@onready var cam_fitter: CameraFitter = $Camera3D
@onready var floor_body: StaticBody3D = $World/Floor
@onready var floor_collision: CollisionShape3D = $World/Floor/CollisionShape3D

@onready var maze_root: Node3D = $World/MazeRoot
@onready var puppy = $World/ActorsRoot/Puppy

const MazeBuilderScript := preload("res://scripts/maze_builder.gd")

var cam: Camera3D
var builder: MazeBuilder

@export var debug_enabled: bool = true
@export var target_update_threshold: float = 0.10

# --- Level randomness ---
# If true, "Next Level" will generate a fresh map even for the same level index.
@export var randomize_each_load: bool = true
var run_seed: int = 0

var current_level: int = 0
var last_target: Vector3 = Vector3.ZERO
var has_last_target := false

# --- Key/Door/Exit runtime ---
var has_key: bool = false

var key_node: Node3D = null
var key_area: Area3D = null

var exit_node: Node3D = null
var exit_area: Area3D = null

var door_node: Node3D = null
var door_area: Area3D = null
var door_body: StaticBody3D = null
var door_opened: bool = false

# --- UI ---
var ui_layer: CanvasLayer = null
var hint_label: Label = null
var win_panel: Panel = null
var win_label: Label = null
var restart_btn: Button = null
var next_btn: Button = null
var restart_btn2: Button = null

# --- INPUT ---
var is_tracking := false
var active_touch_id := -1

@export var floor_collision_mask: int = 1 << 0  # set this to your Floor layer

func _ready() -> void:
	set_process_unhandled_input(true)
	set_process_input(true)

	# Seed for variety
	run_seed = int(Time.get_unix_time_from_system()) ^ randi()

	cam = cam_fitter
	if cam == null:
		cam = get_viewport().get_camera_3d()
	if cam == null:
		cam = _find_first_camera_3d(get_tree().current_scene)

	# Maze builder
	builder = MazeBuilderScript.new()

	_build_ui()
	load_level(0)

	if debug_enabled:
		print("\n=== Game.gd _ready ===")
		print("Scene:", get_tree().current_scene.scene_file_path)
		print("Camera path:", (str(cam.get_path()) if cam else "NULL"))
		print("Puppy path:", (str(puppy.get_path()) if puppy else "NULL"))
		print("======================\n")


func load_level(level_index: int) -> void:
	current_level = level_index

	_clear_runtime_pickups()

	# Fresh randomness per load (including when you click Next Level)
	if randomize_each_load:
		run_seed = (run_seed + 1337) ^ randi()
	else:
		# still advance a little so Next Level isn't identical if you keep randomize_each_load off
		run_seed = Time.get_ticks_msec()

	var lines := LevelData.make(level_index, run_seed, test_mode)

	var ts: float = builder.tile_size
	fit_floor_to_level(lines, ts)

	# Build maze first so we have bounds
	var info := builder.build_from_lines(lines, $World/MazeRoot)

	if auto_fit_camera_on_load and cam_fitter != null:
		cam_fitter.set_fit_target(info["center"], info["half_extents"], test_mode)

	# Reset state
	has_key = false
	door_opened = false

	# Spawn markers + triggers
	_spawn_key_if_present(info)
	_spawn_exit_if_present(info)
	_spawn_door_if_present(info)

	# Place puppy at start
	puppy.global_position = info["start"] + Vector3(0.0, 0.5, 0.0)

	has_last_target = false
	last_target = Vector3.ZERO
	_hide_win_panel()
	_set_hint("")


func _find_first_camera_3d(root: Node) -> Camera3D:
	if root is Camera3D:
		return root as Camera3D
	for child in root.get_children():
		var c = _find_first_camera_3d(child)
		if c != null:
			return c
	return null


func fit_floor_to_level(lines: PackedStringArray, tile_size: float, margin_tiles: float = 2.0) -> void:
	var cols: int = lines[0].length()
	var rows: int = lines.size()

	var w: float = (float(cols) + margin_tiles) * tile_size
	var h: float = (float(rows) + margin_tiles) * tile_size

	var center: Vector3 = Vector3((cols - 1) * 0.5 * tile_size, 0.0, (rows - 1) * 0.5 * tile_size)

	# Mesh
	var pm := floor_mesh.mesh as PlaneMesh
	if pm != null:
		pm.size = Vector2(w, h)

	# Center under maze
	floor_body.global_position = center

	# Collision
	var bs := floor_collision.shape as BoxShape3D
	if bs == null:
		bs = BoxShape3D.new()
		floor_collision.shape = bs
	bs.size = Vector3(w, 0.1, h)


# ------------------------------------------------------------
# Input -> move puppy target
# ------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# Keep your debug click print
	if debug_enabled and (event is InputEventMouseButton and event.pressed):
		print("Click:", event.position)

func _unhandled_input(event: InputEvent) -> void:
	# --- TOUCH (Android/iOS) ---
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			is_tracking = true
			active_touch_id = e.index
			handle_touch(e.position, "touch_down")
		else:
			# Only release the same finger that started tracking
			if e.index == active_touch_id:
				is_tracking = false
				active_touch_id = -1
		return

	if event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		# Only drag if we are tracking AND it’s the same finger
		if is_tracking and e.index == active_touch_id:
			handle_touch(e.position, "touch_drag")
		return

	# --- MOUSE (Desktop) ---
	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				is_tracking = true
				handle_touch(e.position, "mouse_down")
			else:
				is_tracking = false
		return

	if event is InputEventMouseMotion:
		if is_tracking and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			handle_touch(event.position, "mouse_drag")
		return

func handle_touch(screen_pos: Vector2, src: String) -> void:
	if cam == null or puppy == null:
		if debug_enabled:
			print("handle_touch(", src, "): missing cam or puppy.")
		return

	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var to := from + dir * 500.0

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = floor_collision_mask
	# Optional safety: don’t hit the puppy if it has colliders
	if puppy is Node3D:
		query.exclude = [ (puppy as Node3D).get_rid() ]

	var result := space.intersect_ray(query)

	if result.is_empty():
		if debug_enabled:
			print("Ray hit NOTHING (", src, ")")
		return

	var p: Vector3 = result.position

	if has_last_target and p.distance_to(last_target) < target_update_threshold:
		return

	last_target = p
	has_last_target = true
	puppy.call("set_target", p)

# ------------------------------------------------------------
# Key / Door / Exit runtime objects
# ------------------------------------------------------------

func _spawn_key_if_present(info: Dictionary) -> void:
	if not info.has("key") or info.key == null:
		if debug_enabled:
			print("No key in this level.")
		return

	var pos: Vector3 = info.key
	key_node = Node3D.new()
	key_node.name = "KeyMarker"
	key_node.position = pos + Vector3(0.0, 0.35, 0.0)
	maze_root.add_child(key_node)

	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.12
	cyl.height = 0.25
	mesh.mesh = cyl
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	key_node.add_child(mesh)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.88, 0.15)
	mat.metallic = 0.0
	mat.roughness = 0.7
	mesh.material_override = mat

	key_area = Area3D.new()
	key_area.name = "KeyArea"
	key_node.add_child(key_area)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.35
	col.shape = shape
	key_area.add_child(col)

	key_area.monitoring = true
	key_area.body_entered.connect(_on_key_body_entered)


func _spawn_exit_if_present(info: Dictionary) -> void:
	if not info.has("exit") or info.exit == null:
		if debug_enabled:
			print("No exit in this level.")
		return

	var pos: Vector3 = info.exit
	exit_node = Node3D.new()
	exit_node.name = "ExitMarker"
	exit_node.position = pos + Vector3(0.0, 0.25, 0.0)
	maze_root.add_child(exit_node)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.35, 0.35)
	mesh.mesh = box
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	exit_node.add_child(mesh)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 1.0)
	mat.metallic = 0.0
	mat.roughness = 0.7
	mesh.material_override = mat

	exit_area = Area3D.new()
	exit_area.name = "ExitArea"
	exit_node.add_child(exit_area)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.45
	col.shape = shape
	exit_area.add_child(col)

	exit_area.monitoring = true
	exit_area.body_entered.connect(_on_exit_body_entered)


func _spawn_door_if_present(info: Dictionary) -> void:
	if not info.has("door") or info.door == null:
		if debug_enabled:
			print("No door in this level.")
		return

	# Find the door body created by MazeBuilder (named "Door")
	# Choose the closest to the expected door position.
	var pos: Vector3 = info.door
	var doors := maze_root.find_children("Door", "StaticBody3D", true, false)
	door_body = null
	var best_d := 999999.0

	for d in doors:
		var sb := d as StaticBody3D
		if sb == null:
			continue
		var dist := sb.global_position.distance_to(pos)
		if dist < best_d:
			best_d = dist
			door_body = sb

	# Add a simple trigger area at the door position
	door_node = Node3D.new()
	door_node.name = "DoorTrigger"
	door_node.position = pos + Vector3(0.0, 0.35, 0.0)
	maze_root.add_child(door_node)

	door_area = Area3D.new()
	door_area.name = "DoorArea"
	door_node.add_child(door_area)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.45
	col.shape = shape
	door_area.add_child(col)

	door_area.monitoring = true
	door_area.body_entered.connect(_on_door_body_entered)


func _on_key_body_entered(body: Node) -> void:
	if body != puppy:
		return
	if has_key:
		return

	has_key = true
	if debug_enabled:
		print("KEY collected!")

	_set_hint("Key collected! Door is now unlockable (touch the door).")

	# Remove key visual
	if key_node:
		key_node.queue_free()
	key_node = null
	key_area = null


func _on_door_body_entered(body: Node) -> void:
	if body != puppy:
		return
	if door_opened:
		return

	if not has_key:
		_set_hint("Door is locked. Need the key.")
		return

	_open_door()


func _open_door() -> void:
	door_opened = true
	_set_hint("Door opened!")

	# Remove the actual blocking door body created by the builder
	if is_instance_valid(door_body):
		door_body.queue_free()
	door_body = null

	# Optional: remove trigger too
	if door_node:
		door_node.queue_free()
	door_node = null
	door_area = null


func _on_exit_body_entered(body: Node) -> void:
	if body != puppy:
		return

	# If you want exit to require key, keep this:
	if not has_key:
		_set_hint("Need the key first.")
		return

	_show_win_panel()


# ------------------------------------------------------------
# UI
# ------------------------------------------------------------

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)

	var root := Control.new()
	root.name = "Root"
	root.anchor_left = 0
	root.anchor_top = 0
	root.anchor_right = 1
	root.anchor_bottom = 1
	root.offset_left = 0
	root.offset_top = 0
	root.offset_right = 0
	root.offset_bottom = 0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	# Restart button
	restart_btn = Button.new()
	restart_btn.text = "Restart"
	restart_btn.position = Vector2(14, 14)
	restart_btn.size = Vector2(120, 36)
	restart_btn.pressed.connect(func(): load_level(current_level))
	root.add_child(restart_btn)

	# Hint label
	hint_label = Label.new()
	hint_label.text = ""
	hint_label.position = Vector2(160, 18)
	hint_label.size = Vector2(800, 28)
	root.add_child(hint_label)

	# Win panel
	win_panel = Panel.new()
	win_panel.visible = false
	win_panel.size = Vector2(420, 200)
	win_panel.position = Vector2(0, 0)
	root.add_child(win_panel)

	win_panel.anchor_left = 0.5
	win_panel.anchor_top = 0.5
	win_panel.anchor_right = 0.5
	win_panel.anchor_bottom = 0.5
	win_panel.offset_left = -210
	win_panel.offset_top = -100
	win_panel.offset_right = 210
	win_panel.offset_bottom = 100

	win_label = Label.new()
	win_label.text = "You made it!"
	win_label.position = Vector2(20, 20)
	win_label.size = Vector2(380, 40)
	win_panel.add_child(win_label)

	next_btn = Button.new()
	next_btn.text = "Next Level"
	next_btn.position = Vector2(20, 90)
	next_btn.size = Vector2(180, 40)
	next_btn.pressed.connect(func():
		load_level(current_level + 1)
	)
	win_panel.add_child(next_btn)

	restart_btn2 = Button.new()
	restart_btn2.text = "Restart Level"
	restart_btn2.position = Vector2(220, 90)
	restart_btn2.size = Vector2(180, 40)
	restart_btn2.pressed.connect(func():
		load_level(current_level)
	)
	win_panel.add_child(restart_btn2)


func _show_win_panel() -> void:
	if win_panel:
		win_panel.visible = true
	if win_label:
		win_label.text = "Level complete!\nNext level or restart?"
	_set_hint("")


func _hide_win_panel() -> void:
	if win_panel:
		win_panel.visible = false


func _set_hint(msg: String) -> void:
	if hint_label:
		hint_label.text = msg


# ------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------

func _clear_runtime_pickups() -> void:
	if key_node:
		key_node.queue_free()
	key_node = null
	key_area = null

	if exit_node:
		exit_node.queue_free()
	exit_node = null
	exit_area = null

	if door_node:
		door_node.queue_free()
	door_node = null
	door_area = null

	door_body = null
	has_key = false
	door_opened = false

	_hide_win_panel()
