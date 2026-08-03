extends VBoxContainer

signal value_changed

@onready var _amount: LineEdit = $Row/AmountEdit
@onready var _currency: OptionButton = $Row/CurrencySelect
@onready var _rate_row: HBoxContainer = $RateRow
@onready var _rate: LineEdit = $RateRow/RateEdit
@onready var _preview: Label = $Preview

func _ready() -> void:
	_amount.text_changed.connect(func(_t): _refresh())
	_rate.text_changed.connect(func(_t): _refresh())
	_currency.item_selected.connect(_on_currency_selected)

func _on_currency_selected(_idx: int) -> void:
	var usd := currency() == "USD"
	_rate_row.visible = usd
	_preview.visible = usd
	if usd and _rate.text.strip_edges().is_empty() and App.has_project():
		_rate.text = Fmt.rate(App.project.rate_usd_brl)
	_refresh()

func currency() -> String:
	return "USD" if _currency.selected == 1 else "BRL"

func orig_cents() -> int:
	return Money.parse_brl(_amount.text)

func rate_micro() -> int:
	return Money.parse_rate(_rate.text) if currency() == "USD" else Money.RATE_ONE

## Final amount converted to BRL (cents)
func converted_cents() -> int:
	return Money.convert_cents(orig_cents(), rate_micro())

func set_value(cents: int, curr := "BRL", rate := Money.RATE_ONE) -> void:
	_currency.selected = 1 if curr == "USD" else 0
	_amount.text = Fmt.money(cents, "")
	_rate.text = Fmt.rate(rate)
	_on_currency_selected(0)

func clear() -> void:
	_amount.text = ""
	_currency.selected = 0
	_on_currency_selected(0)

func _refresh() -> void:
	_preview.text = "= " + Fmt.money(converted_cents())
	value_changed.emit()
