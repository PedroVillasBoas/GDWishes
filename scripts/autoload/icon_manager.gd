extends Node
## Autoload "Icons" | serves textures from the IconSet resource

const ICON_SET_PATH := "res://assets/icons/icon_set.tres"

var current: IconSet = null
var _cache := {}

func _ready() -> void:
	load_set(ICON_SET_PATH)

func load_set(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("Icons: no IconSet at %s — icons will be blank." % path)
		return
	current = load(path)
	_cache = current.as_dictionary()

## Returns the texture for a slot name ("add", "wishes", …), or null.
func get_icon(icon_name: String) -> Texture2D:
	if icon_name.is_empty():
		return null
	if not _cache.has(icon_name):
		push_warning("Icons: unknown icon '%s'" % icon_name)
		return null
	var tex: Texture2D = _cache[icon_name]
	if tex == null:
		push_warning("Icons: slot '%s' is empty in the IconSet." % icon_name)
	return tex

## Builds a standalone icon node, tinted.
func make_texture_rect(icon_name: String, px := 24, tint := Color.WHITE) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = get_icon(icon_name)
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.modulate = tint
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

## Sets icon + text on a Button in one call, with consistent spacing.
## Icons are white, so tint carries all the meaning: pass Themes.expense on a
## delete button, Themes.income on a confirm, and so on.
func decorate(button: Button, icon_name: String, text := "",
		tint := Color.WHITE) -> Button:
	button.icon = get_icon(icon_name)
	if text != "":
		button.text = text
	button.add_theme_constant_override("h_separation", 8)
	if tint != Color.WHITE:
		button.add_theme_color_override("icon_normal_color", tint)
		button.add_theme_color_override("icon_hover_color", tint)
	return button
