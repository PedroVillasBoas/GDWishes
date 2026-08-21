extends VBoxContainer
## Transactions screen | sortable table with row actions, filters, on-demand form.

## Column order. The last one holds the Edit/Delete buttons.
const COL_DATE := 0
const COL_NAME := 1
const COL_CATEGORY := 2
const COL_TYPE := 3
const COL_ORIG := 4
const COL_METHOD := 5
const COL_VALUE := 6
const COL_NOTES := 7
const COL_ACTIONS := 8

## Button ids used by Tree.add_button, so the handler knows which was clicked.
const BTN_EDIT := 0
const BTN_DELETE := 1

const METHOD_IDS := ["credit", "debit", "pix", "cash"]

@onready var _table: Tree = %Table
@onready var _search: LineEdit = %SearchEdit
@onready var _type_filter: OptionButton = %TypeFilter
@onready var _cat_filter: OptionButton = %CategoryFilter
@onready var _add_button: Button = %AddButton
@onready var _form: PanelContainer = %FormPanel
@onready var _form_title: Label = %FormTitle
@onready var _name_edit: LineEdit = %NameEdit
@onready var _type_select: OptionButton = %TypeSelect
@onready var _amount = %CurrencyInput
@onready var _cat_select: OptionButton = %CategorySelect
@onready var _method_select: OptionButton = %MethodSelect
@onready var _installments_label: Label = %InstallmentsLabel
@onready var _installments_spin: SpinBox = %InstallmentsSpin
@onready var _date_edit: LineEdit = %DateEdit
@onready var _notes_edit: LineEdit = %NotesEdit
@onready var _save_button: Button = %SaveTxButton
@onready var _cancel_button: Button = %CancelButton

var _editing_id: String = ""   # "" = creating a new one
var _last_deleted: Array = []  # For undo
var _empty: EmptyState = null

func _ready() -> void:
	UiUtils.hide_dialogs(self)
	_apply_language()
	_setup_table()
	DateMask.attach(_date_edit)

	# Installments only make sense on credit, and never below a single payment.
	_installments_spin.min_value = 1
	_installments_spin.max_value = 48
	_installments_spin.step = 1
	_installments_spin.value = 1

	_add_button.pressed.connect(_on_add_pressed)
	_cancel_button.pressed.connect(_close_form)
	_save_button.pressed.connect(_save_form)
	_search.text_changed.connect(func(_t): _refresh())
	_type_filter.item_selected.connect(func(_i): _refresh())
	_cat_filter.item_selected.connect(func(_i): _refresh())
	_type_select.item_selected.connect(_on_form_type_selected)
	_method_select.item_selected.connect(func(_i): _sync_installments_visibility())
	_table.item_activated.connect(_on_row_activated)      # Double click = edit
	_table.button_clicked.connect(_on_row_button_clicked)
	EventBus.period_changed.connect(_refresh)
	EventBus.data_changed.connect(func(w):
		if w == "transactions" or w == "categories":
			_refresh())
	Themes.theme_changed.connect(_refresh)
	Lang.language_changed.connect(_on_language_changed)

	# The form is a workspace, not part of the listing: it stays hidden until the
	# user explicitly asks to add or edit something.
	_form.visible = false
	_fill_filter_categories()
	_refresh()

func _apply_language() -> void:
	Icons.decorate(_add_button, "add", Lang.t("tx.title"))
	Icons.decorate(_save_button, "save", Lang.t("generic.save"))
	Icons.decorate(_cancel_button, "close", Lang.t("generic.cancel"))
	_search.right_icon = Icons.get_icon("search")
	_search.placeholder_text = Lang.t("tx.search")
	_installments_label.text = Lang.t("tx.installments")

	_type_filter.clear()
	_type_filter.add_item(Lang.t("generic.all"))
	_type_filter.add_item(Lang.t("type.income"))
	_type_filter.add_item(Lang.t("type.expense"))

	_type_select.clear()
	_type_select.add_item(Lang.t("type.expense"))   # index 0
	_type_select.add_item(Lang.t("type.income"))    # index 1

	_method_select.clear()
	for id in METHOD_IDS:
		_method_select.add_item(Lang.t("method." + id))

func _on_language_changed() -> void:
	_apply_language()
	_setup_table()
	_fill_filter_categories()
	_refresh()

func _setup_table() -> void:
	_table.columns = 9
	var titles := ["tx.col_date", "tx.col_name", "tx.col_category", "tx.col_type",
		"tx.col_orig", "tx.col_method", "tx.col_value", "tx.col_notes", "tx.col_actions"]
	for i in titles.size():
		_table.set_column_title(i, Lang.t(titles[i]))
		# Titles left-aligned to match the cell contents underneath them.
		_table.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT)
		_table.set_column_expand(i, i == COL_NAME or i == COL_NOTES)
	_table.set_column_custom_minimum_width(COL_DATE, 100)
	_table.set_column_custom_minimum_width(COL_VALUE, 110)
	_table.set_column_custom_minimum_width(COL_ACTIONS, 76)
	_table.set_column_expand(COL_ACTIONS, false)

# --- Filters

func _fill_filter_categories() -> void:
	var previous = _cat_filter.get_item_metadata(_cat_filter.selected) if _cat_filter.selected > 0 else null
	_cat_filter.clear()
	_cat_filter.add_item(Lang.t("tx.all_categories"))
	for c in App.project.categories:
		_cat_filter.add_item(c.name)
		_cat_filter.set_item_metadata(_cat_filter.item_count - 1, c.id)
		if previous != null and c.id == previous:
			_cat_filter.selected = _cat_filter.item_count - 1

## The form's category list only offers categories matching the selected type —
## an expense can never be filed under an income category.
func _fill_form_categories(selected_id := "") -> void:
	var want_type := _form_type()
	_cat_select.clear()
	for c in App.project.categories:
		if c.type != want_type:
			continue
		_cat_select.add_item(c.name)
		_cat_select.set_item_metadata(_cat_select.item_count - 1, c.id)
		if c.id == selected_id:
			_cat_select.selected = _cat_select.item_count - 1
	_cat_select.disabled = _cat_select.item_count == 0

func _form_type() -> String:
	return "income" if _type_select.selected == 1 else "expense"

func _on_form_type_selected(_index: int) -> void:
	# Switching type invalidates the current category, so the list is rebuilt.
	_fill_form_categories()

## Installments are a credit-card concept; the field is hidden for every other method.
func _sync_installments_visibility() -> void:
	var is_credit := _method_select.selected == METHOD_IDS.find("credit")
	var editable := is_credit and _editing_id == ""   # never re-split on edit
	_installments_label.visible = is_credit
	_installments_spin.visible = is_credit
	_installments_spin.editable = editable
	if not is_credit:
		_installments_spin.value = 1

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
		_make_row(root, t)
		shown += 1
	_update_empty(shown)

func _make_row(root: TreeItem, t: Transaction) -> void:
	var cat := App.project.category_by_id(t.category_id)
	var tone := Themes.income if t.type == "income" else Themes.expense
	var row := _table.create_item(root)
	row.set_metadata(0, t.id)
	row.set_text(COL_DATE, Fmt.date_display(t.date if t.date != "" else t.month))
	row.set_text(COL_NAME, t.description)
	row.set_text(COL_CATEGORY, cat.name if cat else "—")
	row.set_text(COL_TYPE, Lang.t("type.income") if t.type == "income" else Lang.t("type.expense"))
	row.set_custom_color(COL_TYPE, tone)
	row.set_text(COL_ORIG, ("US$ " if t.currency == "USD" else "R$ ") + Fmt.money(t.orig_amount_cents, ""))
	row.set_text(COL_METHOD, Lang.t("method." + t.method) if t.method in METHOD_IDS else t.method)
	row.set_text(COL_VALUE, Fmt.money(t.amount_cents))
	row.set_custom_color(COL_VALUE, tone)
	row.set_text(COL_NOTES, t.notes)
	# Per-row action buttons, so editing and deleting do not depend on a hidden
	# double-click or on the Delete key.
	row.add_button(COL_ACTIONS, Icons.get_icon("edit"), BTN_EDIT, false, Lang.t("generic.edit"))
	row.add_button(COL_ACTIONS, Icons.get_icon("delete"), BTN_DELETE, false, Lang.t("generic.delete"))

## No rows -> hide the table and show the empty state in its place
func _update_empty(shown: int) -> void:
	if shown == 0 and not is_instance_valid(_empty):
		_empty = EmptyState.make("transactions", Lang.t("tx.empty"),
			Lang.t("dash.first_transaction"), _on_add_pressed)
		add_child(_empty)
		move_child(_empty, _table.get_index() + 1)
	elif shown > 0 and is_instance_valid(_empty):
		_empty.queue_free()
		_empty = null
	_table.visible = shown > 0

func _transaction_by_id(tx_id: String) -> Transaction:
	for t in App.project.transactions:
		if t.id == tx_id:
			return t
	return null

# --- Form

func _on_add_pressed() -> void:
	_open_form(null)

func _open_form(tx: Transaction) -> void:
	if App.project.categories.is_empty():
		EventBus.toast(Lang.t("tx.no_category_for_type"), "error")
		return
	_editing_id = tx.id if tx else ""
	_form_title.text = Lang.t("tx.edit") if tx else Lang.t("tx.new")
	if tx:
		_name_edit.text = tx.description
		_type_select.selected = 1 if tx.type == "income" else 0
		_fill_form_categories(tx.category_id)
		_amount.set_value(tx.orig_amount_cents, tx.currency, tx.rate)
		_method_select.selected = maxi(0, METHOD_IDS.find(tx.method))
		_installments_spin.value = 1
		_date_edit.text = DateMask.from_iso(tx.date)
		_notes_edit.text = tx.notes
	else:
		_name_edit.text = ""
		_type_select.selected = 0
		_fill_form_categories()
		_amount.clear()
		_method_select.selected = 0
		_installments_spin.value = 1
		_date_edit.text = DateMask.today_display()
		_notes_edit.text = ""
	_sync_installments_visibility()
	_form.visible = true
	_name_edit.grab_focus()

func _close_form() -> void:
	_form.visible = false
	_editing_id = ""

func _save_form() -> void:
	var tx_name := _name_edit.text.strip_edges()
	if tx_name.is_empty():
		EventBus.toast(Lang.t("tx.name_required"), "error"); return
	if _amount.orig_cents() <= 0:
		EventBus.toast(Lang.t("tx.amount_required"), "error"); return
	if _cat_select.selected < 0 or _cat_select.item_count == 0:
		EventBus.toast(Lang.t("tx.category_required"), "error"); return
	var iso_date: String = DateMask.to_iso(_date_edit.text)
	if iso_date.is_empty():
		EventBus.toast("%s (%s)" % [Lang.t("generic.date"), DateMask.current_format()], "error"); return
	var data := {
		"description": tx_name,
		"type": _form_type(),
		"orig_amount_cents": _amount.orig_cents(),
		"currency": _amount.currency(),
		"rate": _amount.rate_micro(),
		"amount_cents": _amount.converted_cents(),
		"category_id": _cat_select.get_item_metadata(_cat_select.selected),
		"method": METHOD_IDS[_method_select.selected],
		"installments_total": int(_installments_spin.value) if _installments_spin.visible else 1,
		"date": iso_date,
		"month": iso_date.substr(0, 7),
		"notes": _notes_edit.text,
	}
	if _editing_id != "":
		var target := _transaction_by_id(_editing_id)
		if target:
			for k in ["description", "type", "orig_amount_cents", "currency", "rate",
					"amount_cents", "category_id", "method", "date", "month", "notes"]:
				target.set(k, data[k])
	else:
		Ledger.add_transaction(App.project, data)
	_close_form()
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
	EventBus.toast(Lang.t("tx.limit_left") % [cat.name, Fmt.money(s.leftover)],
		"success" if s.leftover >= 0 else "error")

# --- Row actions

func _on_row_activated() -> void:
	var item := _table.get_selected()
	if item == null:
		return
	var tx := _transaction_by_id(item.get_metadata(0))
	if tx:
		_open_form(tx)

func _on_row_button_clicked(item: TreeItem, _column: int, id: int, mouse_button: int) -> void:
	if mouse_button != MOUSE_BUTTON_LEFT:
		return
	var tx := _transaction_by_id(item.get_metadata(0))
	if tx == null:
		return
	if id == BTN_EDIT:
		_open_form(tx)
	elif id == BTN_DELETE:
		_delete(tx)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE and _table.get_selected():
			var tx := _transaction_by_id(_table.get_selected().get_metadata(0))
			if tx:
				_delete(tx)
		elif event.ctrl_pressed and event.keycode == KEY_N:
			_on_add_pressed()
		elif event.ctrl_pressed and event.keycode == KEY_F:
			_search.grab_focus()
		elif event.keycode == KEY_ESCAPE and _form.visible:
			_close_form()

func _delete(t: Transaction) -> void:
	if t.installments.has("group_id"):
		_confirm_delete_group(t)
		return
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = Lang.t("tx.confirm_delete") % t.description
	dlg.ok_button_text = Lang.t("generic.delete")
	add_child(dlg)
	dlg.confirmed.connect(func():
		_last_deleted = [t]
		App.project.transactions.erase(t)
		# If the deleted row was open in the form, close it so a later Save cannot
		# resurrect a record that no longer exists.
		if _editing_id == t.id:
			_close_form()
		App.touch("transactions")
		EventBus.toast(Lang.t("tx.deleted"), "undo")
		_connect_last_toast_undo())
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free())
	dlg.popup_centered()

func _confirm_delete_group(t: Transaction) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = Lang.t("tx.delete_group") % [t.installments.current, t.installments.total]
	dlg.ok_button_text = Lang.t("tx.delete_all")
	dlg.add_button(Lang.t("tx.delete_one"), true, "single")
	add_child(dlg)
	dlg.confirmed.connect(func():
		var group: String = t.installments.group_id
		_last_deleted = App.project.transactions.filter(
			func(x): return x.installments.get("group_id", "") == group)
		for x in _last_deleted:
			App.project.transactions.erase(x)
		if _editing_id != "":
			_close_form()
		App.touch("transactions")
		EventBus.toast(Lang.t("tx.installments_deleted") % _last_deleted.size(), "undo")
		_connect_last_toast_undo())
	dlg.custom_action.connect(func(_action):
		_last_deleted = [t]
		App.project.transactions.erase(t)
		if _editing_id == t.id:
			_close_form()
		App.touch("transactions")
		EventBus.toast(Lang.t("tx.installment_deleted"), "undo")
		_connect_last_toast_undo()
		dlg.hide())
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free())
	dlg.popup_centered()

func _connect_last_toast_undo() -> void:
	await get_tree().process_frame
	var layer := get_tree().root.get_node_or_null("Main/ToastLayer")
	if layer == null or layer.get_child_count() == 0:
		return
	var toast := layer.get_child(layer.get_child_count() - 1)
	toast.undo_pressed.connect(func():
		for x in _last_deleted:
			App.project.transactions.append(x)
		_last_deleted = []
		App.touch("transactions"))
