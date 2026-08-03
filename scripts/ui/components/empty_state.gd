class_name EmptyState
extends CenterContainer
## Standard block for empty screens/lists
## add_child(EmptyState.make("✨", "Nothing here yet.", "＋ Criar", _on_create))
## compact = true -> small version for use within lists (smaller icon, no expansion).

static func make(icon: String, text: String, action_label := "",
		action := Callable(), compact := false) -> EmptyState:
	var es := EmptyState.new()
	es.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	es.size_flags_vertical = Control.SIZE_SHRINK_CENTER if compact else Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	es.add_child(col)
	var icon_l := Label.new()
	icon_l.text = icon
	icon_l.add_theme_font_size_override("font_size", 24 if compact else 48)
	icon_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(icon_l)
	var text_l := Label.new()
	text_l.text = text
	text_l.theme_type_variation = "Dim"
	text_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(text_l)
	if action_label != "" and action.is_valid():
		var wrap := CenterContainer.new()
		var b := Button.new()
		b.text = action_label
		b.theme_type_variation = "PrimaryButton"
		b.pressed.connect(action)
		wrap.add_child(b)
		col.add_child(wrap)
	return es
