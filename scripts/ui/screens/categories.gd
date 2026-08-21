extends VBoxContainer
## Categories CRUD plus the monthly limits panel (cap, rollover, transfers).
##
## Every expense category gets a limit row, whether or not a cap was set. A row
## reading zero is information ("nothing budgeted here"); a missing row is not.

@onready var _list: VBoxContainer = %CatList
@onready var _limits_list: VBoxContainer = %LimitsList
@onready var _limits_title: Label = %LimitsTitle
@onready var _limit_month = %LimitMonth
@onready var _add_button: Button = %AddCatButton
@onready var _transfer_button: Button = %TransferButton
@onready var _dialog: ConfirmationDialog = %CatDialog
@onready var _cat_name: LineEdit = %CatNameEdit
@onready var _cat_type: OptionButton = %CatTypeSelect
@onready var _color_pick: ColorPicker = %ColorPick
@onready var _limit_dialog: ConfirmationDialog = %LimitDialog
@onready var _cap_label: Label = %CapLabel
@onready var _cap_edit: LineEdit = %CapEdit
@onready var _transfer_dialog: ConfirmationDialog = %TransferDialog
@onready var _from_select: OptionButton = %FromSelect
@onready var _to_select: OptionButton = %ToSelect
@onready var _transfer_amount: LineEdit = %TransferAmountEdit
@onready var _transfer_note: LineEdit = %NoteEdit

var _editing: Category = null
var _limit_cat: Category = null

func _ready() -> void:
	UiUtils.hide_dialogs(self)
	_apply_language()
	_add_button.pressed.connect(_open_dialog.bind(null))
	_dialog.confirmed.connect(_save_dialog)
	_limit_month.month_changed.connect(func(_m): _refresh_limits())
	_transfer_button.pressed.connect(_open_transfer)
	_limit_dialog.confirmed.connect(_save_limit)
	_transfer_dialog.confirmed.connect(_do_transfer)
	EventBus.data_changed.connect(_on_data_changed)
	Themes.theme_changed.connect(func(): _refresh(); _refresh_limits())
	Lang.language_changed.connect(func(): _apply_language(); _refresh(); _refresh_limits())
	_refresh()
	_refresh_limits()

func _apply_language() -> void:
	Icons.decorate(_add_button, "add", Lang.t("cat.title"))
	Icons.decorate(_transfer_button, "transfer", Lang.t("cat.transfer"))
	_limits_title.text = Lang.t("cat.limits_title")
	_cap_label.text = Lang.t("cat.cap")
	_cat_type.clear()
	_cat_type.add_item(Lang.t("type.expense"))   # index 0
	_cat_type.add_item(Lang.t("type.income"))    # index 1

func _on_data_changed(what: String) -> void:
	if what == "categories":
		_refresh()
	if what in ["categories", "limits", "transactions"]:
		_refresh_limits()

# --- Categories

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()

	# The list is cleared on every refresh, so the empty state can just be added here
	if App.project.categories.is_empty():
		_list.add_child(EmptyState.make("categories", Lang.t("cat.empty"),
			Lang.t("cat.title"), _open_dialog.bind(null), true))
	for cat in App.project.categories:
		_list.add_child(_make_row(cat))

func _make_row(cat: Category) -> PanelContainer:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var swatch := ColorRect.new()
	swatch.color = Color(cat.color)
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)
	var name_l := Label.new()
	name_l.text = cat.name
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	var type_l := Label.new()
	type_l.text = Lang.t("type.income") if cat.type == "income" else Lang.t("type.expense")
	type_l.modulate = Themes.income if cat.type == "income" else Themes.expense
	row.add_child(type_l)
	if cat.type == "expense":
		var lim_b := Button.new()
		var lim := App.project.limit_for_category(cat.id)
		Icons.decorate(lim_b, "target", "%s: %s" % [Lang.t("cat.limit"),
			Fmt.money(lim.monthly_cap_cents if lim else 0)])
		lim_b.pressed.connect(_open_limit_dialog.bind(cat))
		row.add_child(lim_b)
	var edit_b := Button.new()
	Icons.decorate(edit_b, "edit", Lang.t("generic.edit"))
	edit_b.pressed.connect(_open_dialog.bind(cat))
	row.add_child(edit_b)
	var del_b := Button.new()
	del_b.theme_type_variation = "DangerButton"
	Icons.decorate(del_b, "delete", Lang.t("generic.delete"))
	del_b.pressed.connect(_delete.bind(cat))
	row.add_child(del_b)
	return panel

func _open_dialog(cat: Category) -> void:
	_editing = cat
	_cat_name.text = cat.name if cat else ""
	_cat_type.selected = (1 if cat.type == "income" else 0) if cat else 0
	_color_pick.color = Color(cat.color) if cat else Themes.accent
	_dialog.title = Lang.t("generic.edit") if cat else Lang.t("cat.new")
	_dialog.popup_centered(Vector2i(380, 420))

func _save_dialog() -> void:
	var cname := _cat_name.text.strip_edges()
	if cname.is_empty():
		EventBus.toast(Lang.t("generic.required"), "error"); return
	var target := _editing
	if target == null:
		target = Category.new()
		target.id = FinanceProject.new_id()
		App.project.categories.append(target)
	target.name = cname
	target.type = "income" if _cat_type.selected == 1 else "expense"
	target.color = "#" + _color_pick.color.to_html(false)
	App.touch("categories")

func _delete(cat: Category) -> void:
	for t in App.project.transactions:
		if t.category_id == cat.id:
			EventBus.toast(Lang.t("cat.in_use"), "error")
			return
	App.project.categories.erase(cat)
	var limit := App.project.limit_for_category(cat.id)
	if limit:
		App.project.limits.erase(limit)
	App.touch("categories")

# --- Limits

func _open_limit_dialog(cat: Category) -> void:
	_limit_cat = cat
	var lim := App.project.limit_for_category(cat.id)
	_cap_edit.text = Fmt.money(lim.monthly_cap_cents, "") if lim else ""
	_limit_dialog.title = Lang.t("cat.limit_dialog") % cat.name
	_limit_dialog.popup_centered(Vector2i(360, 200))

func _save_limit() -> void:
	var cap := Money.parse_brl(_cap_edit.text)
	var lim := App.project.limit_for_category(_limit_cat.id)
	if cap <= 0:
		if lim:
			App.project.limits.erase(lim) # Empty/Zero cap removes the limit
	elif lim:
		lim.monthly_cap_cents = cap
	else:
		lim = Limit.new()
		lim.id = FinanceProject.new_id()
		lim.category_id = _limit_cat.id
		lim.monthly_cap_cents = cap
		lim.active_from = App.project.start_month
		App.project.limits.append(lim)
	App.touch("limits")
	_refresh() # Refresh the limit button label on the category rows
	_refresh_limits()

func _refresh_limits() -> void:
	for c in _limits_list.get_children():
		c.queue_free()
	var month: String = _limit_month.month
	var expense_categories := App.project.categories.filter(func(c): return c.type == "expense")
	if expense_categories.is_empty():
		_limits_list.add_child(EmptyState.make("target", Lang.t("cat.empty"),
			Lang.t("cat.title"), _open_dialog.bind(null), true))
		return
	for cat in expense_categories:
		var lim := App.project.limit_for_category(cat.id)
		# Categories without a cap still get a row, filled with zeros, so "not
		# budgeted" is visible instead of simply absent from the list.
		var state := LimitEngine.state_for(App.project, lim, month) if lim else {
			"cap": 0, "carry": 0, "adjustments": 0, "available": 0,
			"spent": Ledger.spent_in_category(App.project, cat.id, month), "leftover": 0,
		}
		_limits_list.add_child(_make_limit_row(cat, state, lim != null))

## Row | name | cap | +rollover | spent | available | colored progress bar
func _make_limit_row(cat: Category, s: Dictionary, has_limit: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var name_l := Label.new()
	name_l.text = cat.name
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	if not has_limit:
		var hint := Label.new()
		hint.text = Lang.t("cat.no_limit")
		hint.theme_type_variation = "Dim"
		row.add_child(hint)
	for pair in [[Lang.t("cat.cap"), s.cap], [Lang.t("cat.rollover"), s.carry + s.adjustments],
			[Lang.t("cat.spent"), s.spent], [Lang.t("cat.available"), s.leftover]]:
		var l := Label.new()
		l.text = "%s: %s" % [pair[0], Fmt.money(pair[1])]
		l.theme_type_variation = "Dim"
		if pair[0] == Lang.t("cat.available") and has_limit:
			l.theme_type_variation = ""
			l.modulate = Themes.income if pair[1] >= 0 else Themes.expense
		row.add_child(l)
	var bar := ProgressBar.new()
	bar.max_value = maxf(float(s.available), 1.0)
	bar.value = float(s.spent)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	var ratio := float(s.spent) / maxf(float(s.available), 1.0)

	# Overrides the theme's neutral fill so each row signals its own state
	var fill := StyleBoxFlat.new()
	if not has_limit:
		fill.bg_color = Themes.border    # nothing budgeted: neutral, not alarming
	else:
		fill.bg_color = Themes.income if ratio < 0.75 \
			else (Themes.warn if ratio <= 1.0 else Themes.expense)
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	col.add_child(bar)
	return panel

# --- Transfer

func _open_transfer() -> void:
	if App.project.limits.size() < 2:
		EventBus.toast(Lang.t("cat.transfer_need_two"), "error")
		return
	for sel in [_from_select, _to_select]:
		sel.clear()
		for lim in App.project.limits:
			var cat := App.project.category_by_id(lim.category_id)
			sel.add_item(cat.name if cat else "?")
			sel.set_item_metadata(sel.item_count - 1, lim.id)
	_transfer_amount.text = ""
	_transfer_note.text = ""
	_transfer_dialog.title = Lang.t("cat.transfer")
	_transfer_dialog.popup_centered(Vector2i(380, 280))

func _do_transfer() -> void:
	var from_lim: Limit = null
	var to_lim: Limit = null
	for lim in App.project.limits:
		if lim.id == _from_select.get_item_metadata(_from_select.selected): from_lim = lim
		if lim.id == _to_select.get_item_metadata(_to_select.selected): to_lim = lim
	var err := LimitEngine.transfer(App.project, from_lim, to_lim,
		_limit_month.month,
		Money.parse_brl(_transfer_amount.text),
		_transfer_note.text)
	if err != "":
		EventBus.toast(err, "error")
		return
	App.touch("limits")
	EventBus.toast(Lang.t("cat.transfer_done"), "success")
