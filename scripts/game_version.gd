class_name GameVersion
extends RefCounted

const VERSION := "0.7.0"

const PATCH_NOTES_TEXT := """• Rescue room is a side alcove — main path to exit stays open
• Key always appears before the rescue room branch
• Key = ring + line; boosts = stars/hearts; rounder hats
• Removed rescue room sign and marker clutter"""


static func version_label() -> String:
	return "v%s" % VERSION


static func patch_notes_text() -> String:
	return PATCH_NOTES_TEXT
