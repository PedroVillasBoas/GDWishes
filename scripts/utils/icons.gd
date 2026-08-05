class_name Icons
extends RefCounted
## Central icon registry
## All icons are 24x24 SVGs stroked in #E6EDF3 and recolored at runtime through `modulate`, so one file works in every theme

const DIR := "res://assets/icons/"

## Cache keyed by icon name
## `static var` persists for the whole session, so each SVG is decoded once instead of on every list rebuild
static var _cache := {}

## Returns the texture for `icon_name` ("wish", "plus", …), or null if missing
static func get_icon(icon_name: String) -> Texture2D:
	if icon_name.is_empty():
		return null
	if _cache.has(icon_name):
		return _cache[icon_name]
	var path := DIR + icon_name + ".svg"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if tex == null:
		push_warning("Icons: missing icon '%s' (%s)" % [icon_name, path])
	_cache[icon_name] = tex
	return tex

## Builds a standalone icon node, optionally tinted
static func make_texture_rect(icon_name: String, px := 24,
		tint := Color.WHITE) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = get_icon(icon_name)
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.modulate = tint
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

## Sets icon + text on a Button in one call, with consistent spacing.
## Pass tint to colorize (e.g. Themes.expense on a delete button).
static func decorate(button: Button, icon_name: String, text := "",
		tint := Color.WHITE) -> Button:
	button.icon = get_icon(icon_name)
	if text != "":
		button.text = text
	button.add_theme_constant_override("h_separation", 8)
	if tint != Color.WHITE:
		button.add_theme_color_override("icon_normal_color", tint)
	return button
