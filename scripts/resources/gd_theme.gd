class_name GDTheme
extends Resource
## One selectable theme
## The Godot Theme resource plus the semantic palette that code-drawn elements (charts, progress rings, table cells) read at runtime
## Keep the palette in sync with the colors used inside the Theme itself

@export var id: StringName = &""          # Stable key saved in app settings
@export var display_name: String = ""     # Shown in the Settings dropdown
@export var theme: Theme                  # The .tres authored

@export_group("Palette")
@export var bg: Color = Color("#0D1117")          ## Window background
@export var surface: Color = Color("#161B22")     ## Cards
@export var surface_hi: Color = Color("#1C2128")  ## Elevated | Hover
@export var border: Color = Color("#21262D")
@export var text: Color = Color("#E6EDF3")
@export var text_dim: Color = Color("#8B949E")
@export var accent: Color = Color("#7C6FF0")      ## Primary actions, focus, line chart
@export var income: Color = Color("#3FB950")
@export var expense: Color = Color("#F85149")
@export var wish: Color = Color("#E8B33D")
@export var warn: Color = Color("#D29922")
