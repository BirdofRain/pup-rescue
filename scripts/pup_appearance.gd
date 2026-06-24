class_name PupAppearance
extends Node3D

const AccessoryCatalogScript := preload("res://scripts/accessory_catalog.gd")
const ACCESSORY_SCALE_MULT: float = 2.5

var _slot_nodes: Dictionary = {}
var _mount: Node3D = null


func mount_to(node: Node3D) -> void:
	if node == null:
		return
	if get_parent() != node:
		if get_parent() != null:
			reparent(node)
		else:
			node.add_child(self)
	_mount = node


func apply_loadout(equipped: Dictionary) -> void:
	_clear_slots()
	for slot: String in equipped:
		var id: String = str(equipped[slot])
		if id != "":
			_set_slot(slot, id)


func apply_collar_only(accessory_id: String) -> void:
	if _slot_nodes.has("collar"):
		var old: Node = _slot_nodes["collar"]
		if is_instance_valid(old):
			old.queue_free()
		_slot_nodes.erase("collar")
	if accessory_id != "":
		_set_slot("collar", accessory_id)


func set_slot(slot: String, accessory_id: String) -> void:
	if accessory_id == "":
		if _slot_nodes.has(slot):
			var old: Node = _slot_nodes[slot]
			if is_instance_valid(old):
				old.queue_free()
			_slot_nodes.erase(slot)
		return
	_set_slot(slot, accessory_id)


func _set_slot(slot: String, accessory_id: String) -> void:
	if _slot_nodes.has(slot):
		var old: Node = _slot_nodes[slot]
		if is_instance_valid(old):
			old.queue_free()
	var entry: Dictionary = AccessoryCatalogScript.get_entry(accessory_id)
	if entry.is_empty():
		return
	var accessory_node := _build_accessory_node(entry)
	if accessory_node == null:
		return
	add_child(accessory_node)
	_slot_nodes[slot] = accessory_node


func _build_accessory_node(entry: Dictionary) -> Node3D:
	var shape: String = str(entry.get("shape", "bow"))
	match shape:
		"trail_sparkle":
			return _build_trail_node(entry)
		"aura_glow":
			return _build_aura_node(entry)
		_:
			return _build_accessory_mesh(entry)


func _build_trail_node(entry: Dictionary) -> Node3D:
	var root := Node3D.new()
	var scale_v: float = float(entry.get("scale", 0.16)) * ACCESSORY_SCALE_MULT
	var offset_arr: Array = entry.get("offset", [0.0, 0.12, -0.22])
	var base_offset := Vector3(
		float(offset_arr[0]) if offset_arr.size() > 0 else 0.0,
		float(offset_arr[1]) if offset_arr.size() > 1 else 0.12,
		float(offset_arr[2]) if offset_arr.size() > 2 else -0.22
	)
	base_offset *= ACCESSORY_SCALE_MULT * 0.42
	var color: Color = Color.from_string(str(entry.get("color", "#FFD966")), Color.WHITE)
	for i in 3:
		var spark := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = scale_v * (0.22 - float(i) * 0.04)
		sphere.height = sphere.radius * 2.0
		spark.mesh = sphere
		spark.position = base_offset + Vector3(0.0, 0.0, -float(i) * scale_v * 0.35)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color * 0.55
		spark.material_override = mat
		root.add_child(spark)
	return root


func _build_aura_node(entry: Dictionary) -> Node3D:
	var root := Node3D.new()
	var scale_v: float = float(entry.get("scale", 0.28)) * ACCESSORY_SCALE_MULT
	var offset_arr: Array = entry.get("offset", [0.0, 0.2, 0.0])
	var offset := Vector3(
		float(offset_arr[0]) if offset_arr.size() > 0 else 0.0,
		float(offset_arr[1]) if offset_arr.size() > 1 else 0.2,
		float(offset_arr[2]) if offset_arr.size() > 2 else 0.0
	)
	offset *= ACCESSORY_SCALE_MULT * 0.42
	var color: Color = Color.from_string(str(entry.get("color", "#88CCFF")), Color.WHITE)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.position = offset
	var sphere := SphereMesh.new()
	sphere.radius = scale_v * 0.75
	sphere.height = scale_v * 1.5
	mesh_inst.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color * 0.45
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat
	root.add_child(mesh_inst)
	return root


func _build_accessory_mesh(entry: Dictionary) -> MeshInstance3D:
	var shape: String = entry.get("shape", "bow")
	var scale_v: float = float(entry.get("scale", 0.18)) * ACCESSORY_SCALE_MULT
	var offset_arr: Array = entry.get("offset", [0.0, 0.4, 0.0])
	var offset := Vector3(
		float(offset_arr[0]) if offset_arr.size() > 0 else 0.0,
		float(offset_arr[1]) if offset_arr.size() > 1 else 0.4,
		float(offset_arr[2]) if offset_arr.size() > 2 else 0.0
	)
	offset *= ACCESSORY_SCALE_MULT * 0.42
	var color: Color = Color.from_string(str(entry.get("color", "#FFFFFF")), Color.WHITE)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.35
	mesh_inst.material_override = mat
	match shape:
		"bow":
			var sphere := SphereMesh.new()
			sphere.radius = scale_v * 0.55
			sphere.height = scale_v
			mesh_inst.mesh = sphere
		"cap":
			var sphere := SphereMesh.new()
			sphere.radius = scale_v * 0.52
			sphere.height = scale_v * 0.95
			mesh_inst.mesh = sphere
			mesh_inst.position.y += scale_v * 0.22
		"bandana":
			var plane := PlaneMesh.new()
			plane.size = Vector2(scale_v * 1.4, scale_v * 0.7)
			mesh_inst.mesh = plane
			mesh_inst.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		"star_pin":
			var box := BoxMesh.new()
			box.size = Vector3(scale_v, scale_v * 0.3, scale_v * 0.3)
			mesh_inst.mesh = box
		"goggles":
			var band := BoxMesh.new()
			band.size = Vector3(scale_v * 2.2, scale_v * 0.35, scale_v * 0.5)
			mesh_inst.mesh = band
		"backpack_box":
			var pack := BoxMesh.new()
			pack.size = Vector3(scale_v * 0.9, scale_v, scale_v * 0.5)
			mesh_inst.mesh = pack
		_:
			var fallback := SphereMesh.new()
			fallback.radius = scale_v * 0.4
			fallback.height = scale_v * 0.8
			mesh_inst.mesh = fallback
	return mesh_inst


func _clear_slots() -> void:
	for slot in _slot_nodes.keys():
		var n: Node = _slot_nodes[slot]
		if is_instance_valid(n):
			n.queue_free()
	_slot_nodes.clear()
