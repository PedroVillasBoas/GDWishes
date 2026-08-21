extends HBoxContainer
## Global period selector: month / quarter / year / everything.

const MODE_MONTH := 0
const MODE_QUARTER := 1
const MODE_YEAR := 2
const MODE_ALL := 3

@onready var _mode: OptionButton = %ModeSelect
@onready var _picker: HBoxContainer = %Picker

func _ready() -> void:
	_fill_modes()
	_mode.item_selected.connect(func(_i): _apply())
	_picker.month_changed.connect(func(_m): _apply())
	_picker.month = App.period.from
	Lang.language_changed.connect(_fill_modes)
	_apply()

func _fill_modes() -> void:
	var previous := _mode.selected
	_mode.clear()
	_mode.add_item(Lang.t("generic.month"))
	_mode.add_item("Q")
	_mode.add_item("Y")
	_mode.add_item(Lang.t("generic.all"))
	_mode.selected = maxi(previous, 0)

func _apply() -> void:
	var anchor: String = _picker.month
	match _mode.selected:
		MODE_MONTH: App.set_period("month", anchor, anchor)
		MODE_QUARTER: App.set_period("quarter", anchor, Fmt.add_months(anchor, 2))
		MODE_YEAR:
			var year := anchor.split("-")[0]
			App.set_period("year", year + "-01", year + "-12")
		MODE_ALL: App.set_period("all", "", "")
	_picker.visible = _mode.selected != MODE_ALL
