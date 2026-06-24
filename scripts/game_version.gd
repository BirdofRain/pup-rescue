class_name GameVersion
extends RefCounted

const VERSION := "0.8.0"

const PATCH_NOTES_TEXT := """• Island progression — Sunny Beach has 5 levels
• Find Sandy the special pup on level 3, then escort for badges
• Collect all escort badges to unlock Sandy as a companion
• Replay completed levels from the level select screen"""


static func version_label() -> String:
	return "v%s" % VERSION


static func patch_notes_text() -> String:
	return PATCH_NOTES_TEXT
