extends ScrollContainer
## Recurring incomes and costs, plus this month's pending confirmations.

@onready var _income_list: VBoxContainer = %IncomeList
@onready var _cost_list: VBoxContainer = %CostList
@onready var _pending_panel: PanelContainer = %PendingPanel
@onready var _pending_list: VBoxContainer = %PendingList
@onready var _pending_title: Label = %PendingTitle
@onready var _income_title: Label = %IncomeTitle
@onready var _cost_title: Label = %CostTitle
@onready var _add_income: Button = %AddIncomeButton
@onready var _add_cost: Button = %AddCostButton
@onready var _dialog: ConfirmationDialog = %EditDialog
@onready var _name_edit: LineEdit = %RecNameEdit
@onready var _kind_select: OptionButton = %KindSelect
@onready var _amount_edit: LineEdit = %RecAmountEdit
@onready var _category_select: OptionButton = %RecCategorySelect
@onready var _from_edit: LineEdit = %FromEdit

var _editing = null # RecurringIncome | RecurringCost | null
var _editing_is_income := true

func _ready() -> void:
	UiUtils.hide_dialogs(self)
	_apply_language()
	_decorate_pending_header()
	_add_income.pressed.connect(_open_dialog.bind(null, true))
	_add_cost.pressed.connect(_open_dialog.bind(null, false))
	_dialog.confirmed.connect(_save)
	EventBus.data_changed.connect(func(w):
		if w in ["recurring", "transactions"]:
			_refresh())
	Themes.theme_changed.connect(_refresh)
	Lang.language_changed.connect(func(): _apply_language(); _refresh())
	_refresh()

func _apply_language() -> void:
	Icons.decorate(_add_income, "add", Lang.t("rec.income"))
	Icons.decorate(_add_cost, "add", Lang.t("rec.cost"))
	_income_title.text = Lang.t("rec.incomes")
	_cost_title.text = Lang.t("rec.costs")
	_pending_title.text = Lang.t("rec.pending")

## Wraps the pending-panel title in a row with a warning icon.
## Done in code so the scene stays plain | guarded so repeated calls do not nest rows
func _decorate_pending_header() -> void:
	if _pending_title.get_parent() is HBoxContainer:
		return
	var col := _pending_title.get_parent()
	var index := _pending_title.get_index()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.remove_child(_pending_title)
	row.add_child(Icons.make_texture_rect("warning", 18, Themes.warn))
	row.add_child(_pending_title)
	col.add_child(row)
	col.move_child(row, index)

func _refresh() -> void:
	for list in [_income_list, _cost_list, _pending_list]:
		for c in list.get_children():
			c.queue_free()

	# Lists are cleared on every refresh, so empty states can just be added here
	if App.project.recurring_incomes.is_empty():
		_income_list.add_child(EmptyState.make("income", Lang.t("rec.no_incomes"),
			Lang.t("rec.income"), _open_dialog.bind(null, true), true))
	for ri in App.project.recurring_incomes:
		_income_list.add_child(_make_row(ri, true))
	if App.project.recurring_costs.is_empty():
		_cost_list.add_child(EmptyState.make("recurring", Lang.t("rec.no_costs"),
			Lang.t("rec.cost"), _open_dialog.bind(null, false), true))
	for rc in App.project.recurring_costs:
		_cost_list.add_child(_make_row(rc, false))
	_refresh_pending()

func _kind_label(kind: String) -> String:
	match kind:
		"fixed": return Lang.t("rec.kind_fixed")
		"variable": return Lang.t("rec.kind_variable")
		"fixed_variable": return Lang.t("rec.kind_fixed_variable")
	return kind

func _make_row(obj, is_income: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(Icons.make_texture_rect(
		"income" if is_income else "expense", 18,
		Themes.income if is_income else Themes.expense))
	var name_l := Label.new()
	name_l.text = obj.name
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	var kind_l := Label.new()
	kind_l.theme_type_variation = "Dim"
	kind_l.text = _kind_label(obj.kind)
	row.add_child(kind_l)
	var amount_l := Label.new()
	amount_l.text = Fmt.money(obj.amount_cents)
	amount_l.modulate = Themes.income if is_income else Themes.expense
	row.add_child(amount_l)
	var edit_b := Button.new()
	Icons.decorate(edit_b, "edit", Lang.t("generic.edit"))
	edit_b.pressed.connect(_open_dialog.bind(obj, is_income))
	row.add_child(edit_b)
	var del_b := Button.new()
	del_b.theme_type_variation = "DangerButton"
	Icons.decorate(del_b, "delete", Lang.t("generic.delete"))
	del_b.pressed.connect(func():
		if is_income: App.project.recurring_incomes.erase(obj)
		else: App.project.recurring_costs.erase(obj)
		App.touch("recurring"))
	row.add_child(del_b)
	return panel

func _refresh_pending() -> void:
	var month := Fmt.current_month()
	var pending := Cashflow.pending_confirmations(App.project, month)
	_pending_panel.visible = not pending.is_empty()
	for entry in pending:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := Label.new()
		l.text = "%s (%s)" % [entry.obj.name,
			Lang.t("rec.income") if entry.kind == "income" else Lang.t("rec.cost")]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var amount_e := LineEdit.new()
		amount_e.text = Fmt.money(entry.obj.amount_for(month) if entry.obj is RecurringCost \
			else entry.obj.amount_cents, "")
		amount_e.custom_minimum_size = Vector2(120, 0)
		amount_e.alignment = HORIZONTAL_ALIGNMENT_RIGHT

		# Fixed entries have a locked value | Variable ones are edited before confirming
		amount_e.editable = entry.obj.kind != "fixed"
		row.add_child(amount_e)
		var ok_b := Button.new()
		ok_b.theme_type_variation = "PrimaryButton"
		Icons.decorate(ok_b, "confirm", Lang.t("generic.confirm"))
		ok_b.pressed.connect(func():
			Cashflow.confirm(App.project, entry, month, Money.parse_brl(amount_e.text))
			App.touch("transactions"))
		row.add_child(ok_b)
		_pending_list.add_child(row)

func _open_dialog(obj, is_income: bool) -> void:
	_editing = obj
	_editing_is_income = is_income
	_name_edit.text = obj.name if obj else ""
	_kind_select.clear()
	if is_income:
		_kind_select.add_item(Lang.t("rec.kind_fixed"))
		_kind_select.add_item(Lang.t("rec.kind_variable"))
		_kind_select.selected = 1 if (obj and obj.kind == "variable") else 0
	else:
		_kind_select.add_item(Lang.t("rec.kind_fixed"))
		_kind_select.add_item(Lang.t("rec.kind_fixed_variable"))
		_kind_select.selected = 1 if (obj and obj.kind == "fixed_variable") else 0
	_amount_edit.text = Fmt.money(obj.amount_cents, "") if obj else ""
	_category_select.clear()
	var want_type := "income" if is_income else "expense"
	for c in App.project.categories:
		if c.type == want_type:
			_category_select.add_item(c.name)
			_category_select.set_item_metadata(_category_select.item_count - 1, c.id)
			if obj and obj.category_id == c.id:
				_category_select.selected = _category_select.item_count - 1
	_from_edit.text = obj.active_from if obj else App.project.start_month
	_dialog.title = (Lang.t("rec.income") if is_income else Lang.t("rec.cost")) \
		+ " — " + (Lang.t("generic.edit") if obj else Lang.t("generic.add"))
	_dialog.popup_centered(Vector2i(400, 340))

func _save() -> void:
	var oname := _name_edit.text.strip_edges()
	var amount := Money.parse_brl(_amount_edit.text)
	if oname.is_empty() or amount <= 0:
		EventBus.toast(Lang.t("rec.fill_fields"), "error"); return
	var target = _editing
	if target == null:
		target = RecurringIncome.new() if _editing_is_income else RecurringCost.new()
		target.id = FinanceProject.new_id()
		if _editing_is_income: App.project.recurring_incomes.append(target)
		else: App.project.recurring_costs.append(target)
	target.name = oname
	target.amount_cents = amount
	var kind_idx: int = _kind_select.selected
	target.kind = (["fixed", "variable"] if _editing_is_income else ["fixed", "fixed_variable"])[kind_idx]
	if _category_select.selected >= 0:
		target.category_id = _category_select.get_item_metadata(_category_select.selected)
	target.active_from = _from_edit.text.strip_edges()
	App.touch("recurring")
