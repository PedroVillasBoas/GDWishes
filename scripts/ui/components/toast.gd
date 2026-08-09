extends PanelContainer
## Transient notification
## Kind | "info" | "success" | "error" | "undo"

signal undo_pressed

const LIFETIME := 4.0

func _ready() -> void:
	$Row/UndoButton.pressed.connect(func():
		undo_pressed.emit()
		queue_free())

func setup(message: String, kind: String) -> void:
	$Row/Message.text = message
	$Row/UndoButton.visible = kind == "undo"
	
	# Palette colors cannot live in a 'const'
	# Consts resolve at parse time, before the Themes autoload exists
	# They are read here, at call time, instead
	var accent_color := Themes.surface_hi
	match kind:
		"success": accent_color = Themes.income
		"error": accent_color = Themes.expense
	if kind == "success" or kind == "error":
		var sb: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
		sb.bg_color = accent_color.darkened(0.55)
		sb.border_color = accent_color
		sb.set_border_width_all(1)
		add_theme_stylebox_override("panel", sb)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.tween_interval(LIFETIME)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
