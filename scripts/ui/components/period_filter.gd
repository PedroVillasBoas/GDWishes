extends HBoxContainer

@onready var _mode: OptionButton = $ModeSelect
@onready var _picker: HBoxContainer = $Picker

func _ready() -> void:
	_mode.item_selected.connect(func(_i): _apply())
	_picker.month_changed.connect(func(_m): _apply())
	_picker.month = App.period.from
	_apply()

func _apply() -> void:
	var anchor: String = _picker.month
	match _mode.selected:
		0: App.set_period("month", anchor, anchor)
		1: App.set_period("quarter", anchor, Fmt.add_months(anchor, 2))
		2:
			var year := anchor.split("-")[0]
			App.set_period("year", year + "-01", year + "-12")
		3: App.set_period("all", "", "")
	_picker.visible = _mode.selected != 3
