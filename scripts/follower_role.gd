class_name FollowerRole
extends RefCounted

enum Role {
	PLAYER,
	PERMANENT_COMPANION,
	ISLAND_ESCORT,
	TEMPORARY_RESCUE,
}

const ROLE_PLAYER: int = Role.PLAYER
const ROLE_PERMANENT_COMPANION: int = Role.PERMANENT_COMPANION
const ROLE_ISLAND_ESCORT: int = Role.ISLAND_ESCORT
const ROLE_TEMPORARY_RESCUE: int = Role.TEMPORARY_RESCUE


static func label(role: int) -> String:
	match role:
		Role.PLAYER:
			return "PLAYER"
		Role.PERMANENT_COMPANION:
			return "PERMANENT_COMPANION"
		Role.ISLAND_ESCORT:
			return "ISLAND_ESCORT"
		_:
			return "TEMPORARY_RESCUE"
