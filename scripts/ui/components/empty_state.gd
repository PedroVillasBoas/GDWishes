class_name EmptyState
extends CenterContainer
## Standard block for empty screens and lists. Example:
##   add_child(EmptyState.make("wishes", "Nothing here yet.", "Create", _on_create))
## compact = true -> smaller variant for use inside a list panel.
## The first argument is an IconSet slot name, not an emoji.

static func make(icon_name: String, text: String, action_label := "",
		action := Callable(), compact := false) -> EmptyState:
	var es := EmptyState.new()
	es.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	es.size_flags_vertical = Control.SIZE_SHRINK_CENTER if compact else Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	es.add_child(col)
	# The icon is dimmed: an empty state should read as quiet, not as an error.
	var icon_wrap := CenterContainer.new()
	icon_wrap.add_child(Icons.make_texture_rect(icon_name, 28 if compact else 56,
		Themes.text_dim))
	col.add_child(icon_wrap)
	var text_l := Label.new()
	text_l.text = text
	text_l.theme_type_variation = "Dim"
	text_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(text_l)
	if action_label != "" and action.is_valid():
		var wrap := CenterContainer.new()
		var b := Button.new()
		b.theme_type_variation = "PrimaryButton"
		Icons.decorate(b, "add", action_label)
		b.pressed.connect(action)
		wrap.add_child(b)
		col.add_child(wrap)
	return es
