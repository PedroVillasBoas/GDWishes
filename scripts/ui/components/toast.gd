extends PanelContainer

signal undo_pressed

const COLORS := {"info": ThemeBuilder.SURFACE_HI, "success": ThemeBuilder.INCOME,
	"error": ThemeBuilder.EXPENSE, "undo": ThemeBuilder.SURFACE_HI}
const LIFETIME := 4.0

func setup(message: String, kind: String) -> void:
	$Row/Message.text = message
	$Row/UndoButton.visible = kind == "undo"
	var sb: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	if kind == "success" or kind == "error":
		sb.bg_color = COLORS[kind].darkened(0.55)
		sb.border_color = COLORS[kind]
	self.add_theme_stylebox_override("panel", sb)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.tween_interval(LIFETIME)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)

func _ready() -> void:
	$Row/UndoButton.pressed.connect(func():
		undo_pressed.emit()
		queue_free())
