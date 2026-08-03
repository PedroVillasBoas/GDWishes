class_name ThemeBuilder
extends RefCounted
## Builds the GDWishes "fintech-game" dark theme via code

# --- Palette
const BG := Color("#0D1117")           # Background
const SURFACE := Color("#161B22")      # Cards
const SURFACE_HI := Color("#1C2128")   # Hover
const BORDER := Color("#21262D")
const TEXT := Color("#E6EDF3")
const TEXT_DIM := Color("#8B949E")
const ACCENT := Color("#7C6FF0")       # Purple -> Primary actions | Focus
const INCOME := Color("#3FB950")       # Green -> Inflows
const EXPENSE := Color("#F85149")      # Red -> Outflows
const WISH := Color("#E8B33D")         # Gold -> Wishes
const WARN := Color("#D29922")

const RADIUS := 12
const FONT_REG := "res://assets/fonts/Kenney Future Narrow.ttf"
const FONT_SEMI := "res://assets/fonts/Kenney Future.ttf"
const FONT_BOLD := "res://assets/fonts/ElmsSans.ttf"

static func build() -> Theme:
	var t := Theme.new()
	var reg: FontFile = load(FONT_REG)
	var semi: FontFile = load(FONT_SEMI)
	var bold: FontFile = load(FONT_BOLD)
	t.default_font = reg
	t.default_font_size = 15

	# --- Panel (Window Background)
	t.set_stylebox("panel", "Panel", _flat(BG, 0))

	# --- PanelContainer (Card)
	var card := _flat(SURFACE, RADIUS)
	card.border_width_left = 1; card.border_width_top = 1
	card.border_width_right = 1; card.border_width_bottom = 1
	card.border_color = BORDER
	card.content_margin_left = 16; card.content_margin_right = 16
	card.content_margin_top = 14; card.content_margin_bottom = 14
	t.set_stylebox("panel", "PanelContainer", card)

	# --- Button
	var btn := _flat(SURFACE_HI, 8)
	btn.content_margin_left = 16; btn.content_margin_right = 16
	btn.content_margin_top = 8; btn.content_margin_bottom = 8
	var btn_hover := btn.duplicate(); btn_hover.bg_color = SURFACE_HI.lightened(0.06)
	var btn_press := btn.duplicate(); btn_press.bg_color = BG
	var btn_focus := _flat(Color.TRANSPARENT, 8)
	btn_focus.border_width_left = 2; btn_focus.border_width_top = 2
	btn_focus.border_width_right = 2; btn_focus.border_width_bottom = 2
	btn_focus.border_color = ACCENT
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_press)
	t.set_stylebox("focus", "Button", btn_focus)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_font("font", "Button", semi)

	# --- Variation "Primary" (Purple Button) | theme_type_variation
	t.add_type("PrimaryButton")
	t.set_type_variation("PrimaryButton", "Button")
	var pbtn := btn.duplicate(); pbtn.bg_color = ACCENT
	var pbtn_h := btn.duplicate(); pbtn_h.bg_color = ACCENT.lightened(0.12)
	t.set_stylebox("normal", "PrimaryButton", pbtn)
	t.set_stylebox("hover", "PrimaryButton", pbtn_h)
	t.set_color("font_color", "PrimaryButton", Color.WHITE)

	# --- Variation "Danger" (Delete)
	t.add_type("DangerButton")
	t.set_type_variation("DangerButton", "Button")
	var dbtn := btn.duplicate(); dbtn.bg_color = EXPENSE.darkened(0.35)
	t.set_stylebox("normal", "DangerButton", dbtn)

	# LineEdit | TextEdit | SpinBox
	var input := _flat(BG, 8)
	input.border_width_left = 1; input.border_width_top = 1
	input.border_width_right = 1; input.border_width_bottom = 1
	input.border_color = BORDER
	input.content_margin_left = 10; input.content_margin_right = 10
	input.content_margin_top = 7; input.content_margin_bottom = 7
	var input_focus := input.duplicate(); input_focus.border_color = ACCENT
	for cls in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", cls, input)
		t.set_stylebox("focus", cls, input_focus)
		t.set_color("font_color", cls, TEXT)

	# --- Labels
	t.set_color("font_color", "Label", TEXT)
	t.add_type("H1"); t.set_type_variation("H1", "Label")
	t.set_font("font", "H1", bold); t.set_font_size("font_size", "H1", 26)
	t.add_type("H2"); t.set_type_variation("H2", "Label")
	t.set_font("font", "H2", semi); t.set_font_size("font_size", "H2", 19)
	t.add_type("Dim"); t.set_type_variation("Dim", "Label")
	t.set_color("font_color", "Dim", TEXT_DIM); t.set_font_size("font_size", "Dim", 13)

	# --- Tree (Tables)
	t.set_stylebox("panel", "Tree", _flat(SURFACE, 8))
	t.set_color("font_color", "Tree", TEXT)
	t.set_stylebox("selected", "Tree", _flat(ACCENT.darkened(0.5), 4))
	t.set_stylebox("selected_focus", "Tree", _flat(ACCENT.darkened(0.5), 4))

	# --- OptionButton | PopupMenu | Dialogs
	t.set_stylebox("panel", "PopupMenu", _flat(SURFACE_HI, 8))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_stylebox("panel", "AcceptDialog", _flat(SURFACE_HI, RADIUS))

	# --- Progress Bar
	t.set_stylebox("background", "ProgressBar", _flat(BG, 6))
	t.set_stylebox("fill", "ProgressBar", _flat(ACCENT, 6))
	return t

static func _flat(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	return sb
