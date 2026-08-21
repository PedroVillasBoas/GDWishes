extends HBoxContainer
## Month stepper | Clicking the middle label jumps back to the current month

signal month_changed(key: String)

@onready var _prev: Button = %PrevButton
@onready var _next: Button = %NextButton
@onready var _label: Button = %MonthLabel

var month: String = "":
	set(value):
		month = value
		if is_node_ready():
			_label.text = Fmt.month_label(value, true)

func _ready() -> void:
	_prev.text = ""
	_next.text = ""
	_prev.icon = Icons.get_icon("chevron_left")
	_next.icon = Icons.get_icon("chevron_right")
	if month == "":
		month = Fmt.current_month()
	else:
		_label.text = Fmt.month_label(month, true)
	_prev.pressed.connect(func(): _shift(-1))
	_next.pressed.connect(func(): _shift(1))
	_label.pressed.connect(_shift_to_now)
	# Month names are translated, so the label has to be redrawn on a language switch.
	Lang.language_changed.connect(func(): _label.text = Fmt.month_label(month, true))

func _shift(delta: int) -> void:
	month = Fmt.add_months(month, delta)
	month_changed.emit(month)

func _shift_to_now() -> void:
	month = Fmt.current_month()
	month_changed.emit(month)
