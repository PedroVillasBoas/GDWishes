extends HBoxContainer
## Month stepper | Clicking the middle label jumps back to the current month

signal month_changed(key: String)

var month: String = "":
	set(value):
		month = value
		if is_inside_tree():
			$MonthLabel.text = Fmt.month_label(value, true)

func _ready() -> void:
	$PrevButton.text = ""
	$NextButton.text = ""
	$PrevButton.icon = Icons.get_icon("chevron_left")
	$NextButton.icon = Icons.get_icon("chevron_right")
	if month == "":
		month = Fmt.current_month()
	else:
		$MonthLabel.text = Fmt.month_label(month, true)
	$PrevButton.pressed.connect(func(): _shift(-1))
	$NextButton.pressed.connect(func(): _shift(1))
	$MonthLabel.pressed.connect(_shift_to_now)

func _shift(delta: int) -> void:
	month = Fmt.add_months(month, delta)
	month_changed.emit(month)

func _shift_to_now() -> void:
	month = Fmt.current_month()
	month_changed.emit(month)
