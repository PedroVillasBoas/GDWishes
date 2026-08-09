extends Node
## Autoload "Themes"
## Applies the selected theme window-wide, applies an optional font override on top of it, and exposes the palette as plain properties

signal theme_changed

const REGISTRY_PATH := "res://resources/themes/theme_registry.tres"

var registry: ThemeRegistry = null
var current: GDTheme = null
var current_theme_id: StringName = &""
var current_font_index := -1   ## -1 = use the font declared inside the Theme

# --- Palette mirror, refreshed on every theme change
var bg := Color("#0D1117")
var surface := Color("#161B22")
var surface_hi := Color("#1C2128")
var border := Color("#21262D")
var text := Color("#E6EDF3")
var text_dim := Color("#8B949E")
var accent := Color("#7C6FF0")
var income := Color("#3FB950")
var expense := Color("#F85149")
var wish := Color("#E8B33D")
var warn := Color("#D29922")

func _ready() -> void:
	if ResourceLoader.exists(REGISTRY_PATH):
		registry = load(REGISTRY_PATH)
	else:
		push_warning("Themes: no ThemeRegistry at %s — using Godot defaults." % REGISTRY_PATH)
		return
	
	# App autoload loads after this one, so read the stored ids straight from disk
	# rather than through App.app_settings, which does not exist yet
	var stored := _read_stored_settings()
	apply(StringName(stored.get("theme", "")), int(stored.get("font_index", -1)))

# --- Lists for the Settings Dropdowns

func available_themes() -> Array[GDTheme]:
	return registry.themes if registry else [] as Array[GDTheme]

## [{"index": -1, "name": "Padrão do tema"}, {"index": 0, "name": "Inter"}, …]
func available_fonts() -> Array[Dictionary]:
	var list: Array[Dictionary] = [{"index": -1, "name": "Padrão do tema"}]
	if registry == null:
		return list
	for i in registry.fonts.size():
		if registry.fonts[i] != null:
			list.append({"index": i, "name": registry.font_name_at(i)})
	return list

# --- Applying

func apply(theme_id: StringName, font_index: int) -> void:
	if registry == null or registry.themes.is_empty():
		return
	var entry := registry.theme_by_id(theme_id)
	if entry == null or entry.theme == null:
		push_warning("Themes: theme '%s' missing or has no Theme assigned." % theme_id)
		return
	current = entry
	current_theme_id = entry.id
	
	# Duplicate(true) so a font override is never written back into the .tres authored
	# The registry stays exactly as left in the Inspector
	var runtime_theme: Theme = entry.theme.duplicate(true)
	_apply_font(runtime_theme, font_index)
	_refresh_palette(entry)
	
	# Setting the theme on the window root cascades to every Control in the tree
	get_tree().root.theme = runtime_theme
	theme_changed.emit()

func set_theme_id(theme_id: StringName) -> void:
	apply(theme_id, current_font_index)
	App.set_app_setting("theme", String(theme_id))

func set_font_index(font_index: int) -> void:
	apply(current_theme_id, font_index)
	App.set_app_setting("font_index", font_index)

func _apply_font(runtime_theme: Theme, font_index: int) -> void:
	current_font_index = font_index
	if registry == null or font_index < 0 or font_index >= registry.fonts.size():
		current_font_index = -1
		return
	var font: Font = registry.fonts[font_index]
	if font == null:
		current_font_index = -1
		return
	runtime_theme.default_font = font
	
	# Type variations that declare their own font would keep the old family, so every font entry in the theme is redirected to the chosen family
	for type_name in runtime_theme.get_font_type_list():
		for item in runtime_theme.get_font_list(type_name):
			runtime_theme.set_font(item, type_name, font)

func _refresh_palette(entry: GDTheme) -> void:
	for key in ["bg", "surface", "surface_hi", "border", "text", "text_dim",
			"accent", "income", "expense", "wish", "warn"]:
		set(key, entry.get(key))

func _read_stored_settings() -> Dictionary:
	if not FileAccess.file_exists("user://app_settings.json"):
		return {}
	var f := FileAccess.open("user://app_settings.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	return data if data is Dictionary else {}
