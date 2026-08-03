extends HBoxContainer

signal month_changed(key: String)

var month: String = "":
	set(value):
		month = value
		$MonthLabel.text = Fmt.month_label(value, true)

func _ready() -> void:
	if month == "":
		month = Fmt.current_month()
	$PrevButton.pressed.connect(func(): _shift(-1))
	$NextButton.pressed.connect(func(): _shift(1))
	$MonthLabel.pressed.connect(func(): _shift_to_now())

func _shift(delta: int) -> void:
	month = Fmt.add_months(month, delta)
	month_changed.emit(month)

func _shift_to_now() -> void:
	month = Fmt.current_month()
	month_changed.emit(month)
