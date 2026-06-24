extends Node3D

const PupColorsScript := preload("res://scripts/pup_colors.gd")

@export var pickup_radius: float = 1.1
@export var model_scale: float = 0.52
@export var bob_height: float = 0.08
@export var bob_speed: float = 2.4

var _coat_index: int = 0
var _pup_name: String = "Pup"
var _claimed: bool = false
var _base_y: float = 0.24
var _mesh: MeshInstance3D
var _bob_time: float = 0.0


func setup(spawn_pos: Vector3, floor_y: float, coat_index: int, pup_name: String) -> void:
	_coat_index = coat_index
	_pup_name = pup_name
	_base_y = floor_y
	global_position = spawn_pos
	global_position.y = floor_y
	_build_mesh()


func _build_mesh() -> void:
	if _mesh != null:
		return
	_mesh = MeshInstance3D.new()
	_mesh.name = "HiddenPupMesh"
	add_child(_mesh)
	_mesh.scale = PupColorsScript.scaled_body(model_scale)
	var mesh_res: Mesh = load(PupColorsScript.MESH_PATH) as Mesh
	if mesh_res != null:
		_mesh.mesh = mesh_res
	var col: Color = PupColorsScript.get_color(_coat_index)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	mat.emission_enabled = true
	mat.emission = col * 0.35
	_mesh.material_override = mat
	if _mesh.mesh != null:
		for i in range(_mesh.mesh.get_surface_count()):
			_mesh.set_surface_override_material(i, mat)


func _process(delta: float) -> void:
	if _claimed or _mesh == null:
		return
	_bob_time += delta * bob_speed
	global_position.y = _base_y + sin(_bob_time) * bob_height


func try_claim(player_pos: Vector3) -> bool:
	if _claimed:
		return false
	var flat := global_position
	flat.y = 0.0
	var player_flat := player_pos
	player_flat.y = 0.0
	if flat.distance_to(player_flat) > pickup_radius:
		return false
	_claimed = true
	visible = false
	return true


func get_pup_name() -> String:
	return _pup_name
