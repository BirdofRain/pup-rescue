class_name CompanionAccessoryConfig
extends RefCounted

const CATEGORY_HEAD := "head"
const CATEGORY_NECK := "neck"
const CATEGORY_BACK := "back"
const CATEGORY_TRAIL := "trail"
const CATEGORY_AURA := "aura"

const ALL_CATEGORIES: Array[String] = [
	CATEGORY_HEAD,
	CATEGORY_NECK,
	CATEGORY_BACK,
	CATEGORY_TRAIL,
	CATEGORY_AURA,
]

const SOCKET_HAT := "hat"
const SOCKET_COLLAR := "collar"
const SOCKET_PACK := "pack"
const SOCKET_TRAIL := "trail"
const SOCKET_AURA := "aura"

const ALL_SOCKETS: Array[String] = [
	SOCKET_HAT,
	SOCKET_COLLAR,
	SOCKET_PACK,
	SOCKET_TRAIL,
	SOCKET_AURA,
]

const _SOCKET_BY_CATEGORY := {
	CATEGORY_HEAD: SOCKET_HAT,
	CATEGORY_NECK: SOCKET_COLLAR,
	CATEGORY_BACK: SOCKET_PACK,
	CATEGORY_TRAIL: SOCKET_TRAIL,
	CATEGORY_AURA: SOCKET_AURA,
}

const _CATEGORY_BY_SOCKET := {
	SOCKET_HAT: CATEGORY_HEAD,
	SOCKET_COLLAR: CATEGORY_NECK,
	SOCKET_PACK: CATEGORY_BACK,
	SOCKET_TRAIL: CATEGORY_TRAIL,
	SOCKET_AURA: CATEGORY_AURA,
}

const _LEGACY_CATEGORY_ALIASES := {
	"hat": CATEGORY_HEAD,
	"collar": CATEGORY_NECK,
	"pack": CATEGORY_BACK,
}


static func normalize_category(raw: String) -> String:
	var key := raw.strip_edges().to_lower()
	if _LEGACY_CATEGORY_ALIASES.has(key):
		return str(_LEGACY_CATEGORY_ALIASES[key])
	if _SOCKET_BY_CATEGORY.has(key):
		return key
	return ""


static func socket_for_category(category: String) -> String:
	var normalized := normalize_category(category)
	return str(_SOCKET_BY_CATEGORY.get(normalized, ""))


static func category_for_socket(socket: String) -> String:
	return str(_CATEGORY_BY_SOCKET.get(socket.strip_edges().to_lower(), ""))


static func category_label(category: String) -> String:
	match normalize_category(category):
		CATEGORY_HEAD:
			return "Head"
		CATEGORY_NECK:
			return "Neck"
		CATEGORY_BACK:
			return "Back"
		CATEGORY_TRAIL:
			return "Trail"
		CATEGORY_AURA:
			return "Aura"
		_:
			return category.capitalize()
