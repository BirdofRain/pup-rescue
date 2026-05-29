class_name GameVersion
extends RefCounted

const VERSION := "0.3.2"

const PATCH_NOTES_TEXT := """• Coat color picker on main menu
• Squad cap: 5 base, up to 10 via shop
• Shop: rainbow trail, round-up, squad +2
• Followers follow your path around corners
• Leader pup is 25% larger than followers"""


static func version_label() -> String:
	return "v%s" % VERSION


static func patch_notes_text() -> String:
	return PATCH_NOTES_TEXT
