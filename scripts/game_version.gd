class_name GameVersion
extends RefCounted

const VERSION := "0.4.0"

const PATCH_NOTES_TEXT := """• Name your leader pup on the main menu
• Save Progress after level 2 (local device)
• Local leaderboard: level, squad size, rescues
• Squad cap: 5 base, up to 10 via shop
• Followers follow your path around corners"""


static func version_label() -> String:
	return "v%s" % VERSION


static func patch_notes_text() -> String:
	return PATCH_NOTES_TEXT
