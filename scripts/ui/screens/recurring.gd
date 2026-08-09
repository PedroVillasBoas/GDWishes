extends ScrollContainer
## Recurring incomes and costs, plus this month's pending confirmations

@onready var _dialog: ConfirmationDialog = $Col/EditDialog

var _editing = null # RecurringIncome | RecurringCost | null
var _editing_is_income := true

func _ready() -> void:
	UiUtils.hide_dialogs(self)
	Icons.decorate($Col/IncomeHeader/AddIncomeButton, "add", "Renda")
	Icons.decorate($Col/CostHeader/AddCostButton, "add", "Custo")
	_decorate_pending_header()
	$Col/IncomeHeader/AddIncomeButton.pressed.connect(_open_dialog.bind(null, true))
	$Col/CostHeader/AddCostButton.pressed.connect(_open_dialog.bind(null, false))
	_dialog.confirmed.connect(_save)
	EventBus.data_changed.connect(func(w):
		if w in ["recurring", "transactions"]:
			_refresh())
	Themes.theme_changed.connect(_refresh)
	_refresh()

## Wraps the pending-panel title in a row with a warning icon
## Done in code so the scene stays plain | guarded so repeated calls do not nest rows
func _decorate_pending_header() -> void:
	var title: Label = $Col/PendingPanel/PendingCol/PendingTitle
	if title.get_parent() is HBoxContainer:
		return
	title.text = "Pendentes de confirmação neste mês"
	var col := title.get_parent()
	var index := title.get_index()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.remove_child(title)
	row.add_child(Icons.make_texture_rect("warning", 18, Themes.warn))
	row.add_child(title)
	col.add_child(row)
	col.move_child(row, index)

func _refresh() -> void:
	for list in [$Col/IncomeList, $Col/CostList, $Col/PendingPanel/PendingCol/PendingList]:
		for c in list.get_children():
			c.queue_free()
	
	# Lists are cleared on every refresh, so empty states can just be added here
	if App.project.recurring_incomes.is_empty():
		$Col/IncomeList.add_child(EmptyState.make("income",
			"Nenhuma renda cadastrada — comece pelo seu salário.",
			"Renda", _open_dialog.bind(null, true), true))
	for ri in App.project.recurring_incomes:
		$Col/IncomeList.add_child(_make_row(ri, true))
	if App.project.recurring_costs.is_empty():
		$Col/CostList.add_child(EmptyState.make("recurring",
			"Nenhum custo fixo — cadastre aluguel, assinaturas, faculdade…",
			"Custo", _open_dialog.bind(null, false), true))
	for rc in App.project.recurring_costs:
		$Col/CostList.add_child(_make_row(rc, false))
	_refresh_pending()

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
	kind_l.text = {"fixed": "Fixo", "variable": "Variável", "fixed_variable": "Fixo-variável"}[obj.kind]
	row.add_child(kind_l)
	var amount_l := Label.new()
	amount_l.text = Fmt.money(obj.amount_cents)
	amount_l.modulate = Themes.income if is_income else Themes.expense
	row.add_child(amount_l)
	var edit_b := Button.new()
	Icons.decorate(edit_b, "edit", "Editar")
	edit_b.pressed.connect(_open_dialog.bind(obj, is_income))
	row.add_child(edit_b)
	var del_b := Button.new()
	del_b.theme_type_variation = "DangerButton"
	Icons.decorate(del_b, "delete", "Excluir")
	del_b.pressed.connect(func():
		if is_income: App.project.recurring_incomes.erase(obj)
		else: App.project.recurring_costs.erase(obj)
		App.touch("recurring"))
	row.add_child(del_b)
	return panel

func _refresh_pending() -> void:
	var month := Fmt.current_month()
	var pending := Cashflow.pending_confirmations(App.project, month)
	$Col/PendingPanel.visible = not pending.is_empty()
	for entry in pending:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := Label.new()
		l.text = "%s (%s)" % [entry.obj.name, "renda" if entry.kind == "income" else "custo"]
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
		Icons.decorate(ok_b, "confirm", "Confirmar")
		ok_b.pressed.connect(func():
			Cashflow.confirm(App.project, entry, month, Money.parse_brl(amount_e.text))
			App.touch("transactions"))
		row.add_child(ok_b)
		$Col/PendingPanel/PendingCol/PendingList.add_child(row)

func _open_dialog(obj, is_income: bool) -> void:
	_editing = obj
	_editing_is_income = is_income
	var form := $Col/EditDialog/Form
	form.get_node("NameEdit").text = obj.name if obj else ""
	var kind: OptionButton = form.get_node("KindSelect")
	kind.clear()
	if is_income:
		kind.add_item("Fixa"); kind.add_item("Variável")
		kind.selected = 1 if (obj and obj.kind == "variable") else 0
	else:
		kind.add_item("Fixo"); kind.add_item("Fixo-variável")
		kind.selected = 1 if (obj and obj.kind == "fixed_variable") else 0
	form.get_node("AmountEdit").text = Fmt.money(obj.amount_cents, "") if obj else ""
	var cat_sel: OptionButton = form.get_node("CategorySelect")
	cat_sel.clear()
	var want_type := "income" if is_income else "expense"
	for c in App.project.categories:
		if c.type == want_type:
			cat_sel.add_item(c.name)
			cat_sel.set_item_metadata(cat_sel.item_count - 1, c.id)
			if obj and obj.category_id == c.id:
				cat_sel.selected = cat_sel.item_count - 1
	form.get_node("FromEdit").text = obj.active_from if obj else App.project.start_month
	_dialog.title = ("Renda" if is_income else "Custo") + (" — editar" if obj else " — novo")
	_dialog.popup_centered(Vector2i(400, 320))

func _save() -> void:
	var form := $Col/EditDialog/Form
	var oname: String = form.get_node("NameEdit").text.strip_edges()
	var amount := Money.parse_brl(form.get_node("AmountEdit").text)
	if oname.is_empty() or amount <= 0:
		EventBus.toast("Preencha nome e valor.", "error"); return
	var target = _editing
	if target == null:
		target = RecurringIncome.new() if _editing_is_income else RecurringCost.new()
		target.id = FinanceProject.new_id()
		if _editing_is_income: App.project.recurring_incomes.append(target)
		else: App.project.recurring_costs.append(target)
	target.name = oname
	target.amount_cents = amount
	var kind_idx: int = form.get_node("KindSelect").selected
	target.kind = (["fixed", "variable"] if _editing_is_income else ["fixed", "fixed_variable"])[kind_idx]
	var cat_sel: OptionButton = form.get_node("CategorySelect")
	if cat_sel.selected >= 0:
		target.category_id = cat_sel.get_item_metadata(cat_sel.selected)
	target.active_from = form.get_node("FromEdit").text.strip_edges()
	App.touch("recurring")
