extends VBoxContainer
## Transactions screen | sortable table, filters, side form, installments and undo

const COLUMNS := ["Data", "Descrição", "Categoria", "Tipo", "Valor Orig", "Método", "Valor", "Obs"]

@onready var _table: Tree = $Table
@onready var _search: LineEdit = $Toolbar/SearchEdit
@onready var _type_filter: OptionButton = $Toolbar/TypeFilter
@onready var _cat_filter: OptionButton = $Toolbar/CategoryFilter
@onready var _form: PanelContainer = $FormPanel
@onready var _amount = $FormPanel/Form/Grid/Amount
@onready var _cat_select: OptionButton = $FormPanel/Form/Grid/CategorySelect

var _editing_id: String = ""   # "" = creating a new one
var _last_deleted: Array = []  # For undo
var _empty: EmptyState = null

func _ready() -> void:
	UiUtils.hide_dialogs(self)
	_setup_table()
	Icons.decorate($Toolbar/AddButton, "add", "Lançamento")
	_search.right_icon = Icons.get_icon("search")
	Icons.decorate($FormPanel/Form/FormButtons/SaveTxButton, "save", "Salvar")
	Icons.decorate($FormPanel/Form/FormButtons/CancelButton, "close", "Cancelar")
	$Toolbar/AddButton.pressed.connect(_open_form)
	$FormPanel/Form/FormButtons/CancelButton.pressed.connect(func(): _form.visible = false)
	$FormPanel/Form/FormButtons/SaveTxButton.pressed.connect(_save_form)
	_search.text_changed.connect(func(_t): _refresh())
	_type_filter.item_selected.connect(func(_i): _refresh())
	_cat_filter.item_selected.connect(func(_i): _refresh())
	_table.item_activated.connect(_on_row_activated)      # Double click = edit
	EventBus.period_changed.connect(_refresh)
	EventBus.data_changed.connect(func(w):
		if w == "transactions" or w == "categories":
			_refresh())
	Themes.theme_changed.connect(_refresh)
	_fill_category_options()
	_refresh()

func _setup_table() -> void:
	_table.columns = COLUMNS.size()
	for i in COLUMNS.size():
		_table.set_column_title(i, COLUMNS[i])
		_table.set_column_expand(i, i == 1 or i == 7)
	_table.set_column_custom_minimum_width(0, 90)
	_table.set_column_custom_minimum_width(6, 110)

func _fill_category_options() -> void:
	_cat_filter.clear()
	_cat_filter.add_item("Todas as categorias")
	_cat_select.clear()
	for c in App.project.categories:
		_cat_filter.add_item(c.name)
		_cat_filter.set_item_metadata(_cat_filter.item_count - 1, c.id)
		_cat_select.add_item(c.name)
		_cat_select.set_item_metadata(_cat_select.item_count - 1, c.id)

# --- Table

func _refresh() -> void:
	_table.clear()
	var root := _table.create_item()
	var months := App.period_months()
	if months.is_empty():
		_update_empty(0)
		return
	var list := Ledger.transactions_in_range(App.project, months[0], months[-1])
	list.sort_custom(func(a, b): return a.date > b.date)
	var query := _search.text.to_lower()
	var shown := 0
	for t in list:
		if _type_filter.selected == 1 and t.type != "income": continue
		if _type_filter.selected == 2 and t.type != "expense": continue
		if _cat_filter.selected > 0 and t.category_id != _cat_filter.get_item_metadata(_cat_filter.selected): continue
		if query != "" and not (query in t.description.to_lower()): continue
		var cat := App.project.category_by_id(t.category_id)
		var row := _table.create_item(root)
		row.set_metadata(0, t.id)
		row.set_text(0, Fmt.date_br(t.date if t.date != "" else t.month))
		row.set_text(1, t.description)
		row.set_text(2, cat.name if cat else "—")
		row.set_text(3, "Entrada" if t.type == "income" else "Saída")
		row.set_custom_color(3, Themes.income if t.type == "income" else Themes.expense)
		row.set_text(4, ("US$ " if t.currency == "USD" else "R$ ") + Fmt.money(t.orig_amount_cents, ""))
		row.set_text(5, {"credit": "Crédito", "debit": "Débito", "pix": "Pix", "cash": "Dinheiro"}.get(t.method, t.method))
		row.set_text(6, Fmt.money(t.amount_cents))
		row.set_custom_color(6, Themes.income if t.type == "income" else Themes.expense)
		row.set_text(7, t.notes)
		shown += 1
	_update_empty(shown)

## No rows -> hide the table and show the empty state in its place
func _update_empty(shown: int) -> void:
	if shown == 0 and not is_instance_valid(_empty):
		_empty = EmptyState.make("transactions", "Nenhum lançamento neste período.",
			"Primeiro lançamento", _open_form)
		add_child(_empty)
		move_child(_empty, _table.get_index() + 1)
	elif shown > 0 and is_instance_valid(_empty):
		_empty.queue_free()
		_empty = null
	_table.visible = shown > 0

# --- Form

func _open_form(tx: Transaction = null) -> void:
	_editing_id = tx.id if tx else ""
	$FormPanel/Form/FormTitle.text = "Editar lançamento" if tx else "Novo lançamento"
	var g := $FormPanel/Form/Grid
	if tx:
		g.get_node("DescEdit").text = tx.description
		g.get_node("TypeSelect").selected = 1 if tx.type == "income" else 0
		_amount.set_value(tx.orig_amount_cents, tx.currency, tx.rate)
		for i in _cat_select.item_count:
			if _cat_select.get_item_metadata(i) == tx.category_id:
				_cat_select.selected = i
		g.get_node("MethodSelect").selected = ["credit", "debit", "pix", "cash"].find(tx.method)
		g.get_node("InstallmentsSpin").value = 1
		g.get_node("InstallmentsSpin").editable = false   # No re-splitting on edit
		g.get_node("DateEdit").text = tx.date
		g.get_node("NotesEdit").text = tx.notes
	else:
		g.get_node("DescEdit").text = ""
		_amount.clear()
		g.get_node("InstallmentsSpin").value = 1
		g.get_node("InstallmentsSpin").editable = true
		var d := Time.get_date_dict_from_system()
		g.get_node("DateEdit").text = "%04d-%02d-%02d" % [d.year, d.month, d.day]
		g.get_node("NotesEdit").text = ""
	_form.visible = true
	g.get_node("DescEdit").grab_focus()

func _save_form() -> void:
	var g := $FormPanel/Form/Grid
	var desc: String = g.get_node("DescEdit").text.strip_edges()
	if desc.is_empty():
		EventBus.toast("Descrição é obrigatória.", "error"); return
	if _amount.orig_cents() <= 0:
		EventBus.toast("Valor deve ser maior que zero.", "error"); return
	if _cat_select.selected < 0:
		EventBus.toast("Escolha uma categoria.", "error"); return
	var date: String = g.get_node("DateEdit").text.strip_edges()
	var data := {
		"description": desc,
		"type": "income" if g.get_node("TypeSelect").selected == 1 else "expense",
		"orig_amount_cents": _amount.orig_cents(),
		"currency": _amount.currency(),
		"rate": _amount.rate_micro(),
		"amount_cents": _amount.converted_cents(),
		"category_id": _cat_select.get_item_metadata(_cat_select.selected),
		"method": ["credit", "debit", "pix", "cash"][g.get_node("MethodSelect").selected],
		"installments_total": int(g.get_node("InstallmentsSpin").value),
		"date": date,
		"month": date.substr(0, 7),
		"notes": g.get_node("NotesEdit").text,
	}
	if _editing_id != "":
		for t in App.project.transactions:
			if t.id == _editing_id:
				for k in ["description", "type", "orig_amount_cents", "currency", "rate",
						"amount_cents", "category_id", "method", "date", "month", "notes"]:
					t.set(k, data[k])
	else:
		Ledger.add_transaction(App.project, data)
	_form.visible = false
	App.touch("transactions")
	_notify_limit(data)

## Toast showing how much of the category limit is left after this expense
func _notify_limit(data: Dictionary) -> void:
	if data.type != "expense":
		return
	var limit := App.project.limit_for_category(data.category_id)
	if limit == null:
		return
	var cat := App.project.category_by_id(data.category_id)
	var s := LimitEngine.state_for(App.project, limit, data.month)
	EventBus.toast("%s: %s restantes este mês" % [cat.name, Fmt.money(s.leftover)],
		"success" if s.leftover >= 0 else "error")

# --- Edit | Delete

func _on_row_activated() -> void:
	var item := _table.get_selected()
	if item == null: return
	var tx_id: String = item.get_metadata(0)
	for t in App.project.transactions:
		if t.id == tx_id:
			_open_form(t)
			return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE and _table.get_selected():
			_delete_selected()
		elif event.ctrl_pressed and event.keycode == KEY_N:
			_open_form()
		elif event.ctrl_pressed and event.keycode == KEY_F:
			_search.grab_focus()

func _delete_selected() -> void:
	var tx_id: String = _table.get_selected().get_metadata(0)
	for t in App.project.transactions:
		if t.id == tx_id:
			if t.installments.has("group_id"):
				_confirm_delete_group(t)
				return
			_last_deleted = [t]
			App.project.transactions.erase(t)
			App.touch("transactions")
			EventBus.toast("Lançamento excluído.", "undo")
			_connect_last_toast_undo()
			return

func _confirm_delete_group(t: Transaction) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = "Este lançamento é a parcela %d/%d.\nExcluir TODAS as parcelas?" % \
		[t.installments.current, t.installments.total]
	dlg.ok_button_text = "Todas"
	dlg.add_button("Só esta", true, "single")
	add_child(dlg)
	dlg.confirmed.connect(func():
		var group: String = t.installments.group_id
		_last_deleted = App.project.transactions.filter(
			func(x): return x.installments.get("group_id", "") == group)
		for x in _last_deleted:
			App.project.transactions.erase(x)
		App.touch("transactions")
		EventBus.toast("%d parcelas excluídas." % _last_deleted.size(), "undo")
		_connect_last_toast_undo())
	dlg.custom_action.connect(func(_action):
		_last_deleted = [t]
		App.project.transactions.erase(t)
		App.touch("transactions")
		EventBus.toast("Parcela excluída.", "undo")
		_connect_last_toast_undo()
		dlg.hide())
	dlg.popup_centered()

func _connect_last_toast_undo() -> void:
	await get_tree().process_frame
	var layer := get_tree().root.get_node("Main/ToastLayer")
	var toast := layer.get_child(layer.get_child_count() - 1)
	toast.undo_pressed.connect(func():
		for x in _last_deleted:
			App.project.transactions.append(x)
		_last_deleted = []
		App.touch("transactions"))
