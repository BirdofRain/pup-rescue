class_name PupPatternLabels
extends RefCounted


static func display_name(pattern_id: String) -> String:
	if pattern_id == "":
		return "Classic coat"
	match pattern_id:
		"golden_retriever":
			return "Golden Retriever"
		_:
			return pattern_id.replace("_", " ").capitalize()


static func short_label(pattern_id: String) -> String:
	return display_name(pattern_id)
