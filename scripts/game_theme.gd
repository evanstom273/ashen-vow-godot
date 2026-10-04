class_name GameTheme
extends RefCounted
## One Inspector-editable theme; callers must use local overrides, not mutate it.
const THEME: Theme = preload("res://data/ashen_theme.tres")

static func get_theme() -> Theme:
	return THEME
