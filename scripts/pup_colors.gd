class_name PupColors
extends RefCounted

const MESH_PATH := "res://assets/VoxelHusky.obj"
## Voxel OBJ models face +X; Godot movement forward is -Z.
const MODEL_YAW_OFFSET: float = -PI * 0.5
## Body length (X), height (Y), width (Z) multipliers on uniform scale.
const MODEL_BODY_SCALE := Vector3(1.32, 1.0, 0.86)


static func scaled_body(uniform: float) -> Vector3:
	return Vector3(
		uniform * MODEL_BODY_SCALE.x,
		uniform * MODEL_BODY_SCALE.y,
		uniform * MODEL_BODY_SCALE.z
	)

static var _names: PackedStringArray = PackedStringArray([
	"Golden", "Cream", "Brown", "Gray", "Tan", "Rose",
])

static var _palette: Array = [
	Color(0.85, 0.72, 0.38),
	Color(0.88, 0.82, 0.68),
	Color(0.55, 0.38, 0.26),
	Color(0.62, 0.62, 0.66),
	Color(0.72, 0.58, 0.42),
	Color(0.78, 0.52, 0.48),
]


static func count() -> int:
	return _palette.size()


static func clamp_index(index: int) -> int:
	return clampi(index, 0, _palette.size() - 1)


static func get_color(index: int) -> Color:
	return _palette[clamp_index(index)] as Color


static func get_coat_name(index: int) -> String:
	return _names[clamp_index(index)]
