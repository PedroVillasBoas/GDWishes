class_name ThemeRegistry
extends Resource
## The list of themes and fonts the app offers in Settings
## Add an entry here and it appears in the dropdown

@export var themes: Array[GDTheme] = []

## Fonts selectable independently of the theme
## Leave empty to offer only "theme default" | The Settings screen always prepends that option
@export var fonts: Array[Font] = []

## Names shown for the fonts above, index-matched
## If shorter than `fonts`, the resource filename is used as a fallback
@export var font_names: PackedStringArray = []

func theme_by_id(theme_id: StringName) -> GDTheme:
	for entry in themes:
		if entry != null and entry.id == theme_id:
			return entry
	return themes[0] if not themes.is_empty() else null

func font_name_at(index: int) -> String:
	if index >= 0 and index < font_names.size() and font_names[index] != "":
		return font_names[index]
	if index >= 0 and index < fonts.size() and fonts[index] != null:
		return fonts[index].resource_path.get_file().get_basename()
	return "?"
